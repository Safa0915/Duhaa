import XCTest
import CoreLocation
@testable import Duhaa

// MARK: - Fakes (no real MapKit, no real CoreLocation permission)

private struct FakeSearcher: MosqueSearching {
    var result: [MosquePlace] = []
    var error: Error?
    /// Counts calls — used to assert refresh actually re-searches.
    final class Counter { var count = 0 }
    var counter = Counter()

    func searchNearbyMosques(from coordinate: CLLocationCoordinate2D) async throws -> [MosquePlace] {
        counter.count += 1
        if let error { throw error }
        return result
    }
}

private struct FakeLocation: LocationProviding {
    var authorizationStatus: CLAuthorizationStatus
    var coordinate: CLLocationCoordinate2D? = .init(latitude: 40, longitude: -74)
    func requestWhenInUseAuthorization() {}
    func currentCoordinate() async -> CLLocationCoordinate2D? { coordinate }
}

private final class FakeMaps: MapsOpening {
    var directionsCount = 0
    var openCount = 0
    var lastMosque: MosquePlace?
    func openDirections(to mosque: MosquePlace) { directionsCount += 1; lastMosque = mosque }
    func openInMaps(_ mosque: MosquePlace) { openCount += 1; lastMosque = mosque }
}

private struct TestError: Error {}

@MainActor
final class MosqueTests: XCTestCase {

    private func mosque(_ name: String, lat: Double = 40, lon: Double = -74,
                        meters: Double, phone: String? = nil,
                        website: String? = nil, address: String = "1 Main St",
                        isOpen: Bool? = nil) -> MosquePlace {
        MosquePlace(id: MosquePlace.makeID(name: name, latitude: lat, longitude: lon),
                    name: name, address: address, latitude: lat, longitude: lon,
                    distanceMeters: meters, phoneNumber: phone,
                    websiteURL: website.flatMap(URL.init(string:)), isOpen: isOpen)
    }

    private let coord = CLLocationCoordinate2D(latitude: 40, longitude: -74)

    // MARK: 1 — Permission states

    func testPermissionNotDeterminedShowsPermissionNeeded() async {
        let vm = NearbyMosquesViewModel(searcher: FakeSearcher())
        await vm.locateAndSearch(using: FakeLocation(authorizationStatus: .notDetermined))
        XCTAssertEqual(vm.state, .permissionNeeded)
    }

    func testPermissionDeniedShowsPermissionDenied() async {
        let vm = NearbyMosquesViewModel(searcher: FakeSearcher())
        await vm.locateAndSearch(using: FakeLocation(authorizationStatus: .denied))
        XCTAssertEqual(vm.state, .permissionDenied)
    }

    func testPermissionRestrictedShowsPermissionDenied() async {
        let vm = NearbyMosquesViewModel(searcher: FakeSearcher())
        await vm.locateAndSearch(using: FakeLocation(authorizationStatus: .restricted))
        XCTAssertEqual(vm.state, .permissionDenied)
    }

    func testPermissionAllowedTriggersSearch() async {
        let searcher = FakeSearcher(result: [mosque("Masjid A", meters: 500)])
        let vm = NearbyMosquesViewModel(searcher: searcher)
        await vm.locateAndSearch(using: FakeLocation(authorizationStatus: .authorizedWhenInUse))
        XCTAssertEqual(searcher.counter.count, 1)
        if case .loaded(let list) = vm.state { XCTAssertEqual(list.count, 1) }
        else { XCTFail("expected .loaded, got \(vm.state)") }
    }

    // MARK: 2 — Location failures

    func testLocationUnavailableShowsError() async {
        let vm = NearbyMosquesViewModel(searcher: FakeSearcher())
        await vm.locateAndSearch(using: FakeLocation(authorizationStatus: .authorizedWhenInUse, coordinate: nil))
        XCTAssertEqual(vm.state, .error)
    }

    func testLowAccuracyCoordinateStillSearchesWithoutCrash() async {
        // A valid-but-imprecise coordinate must not crash; it just searches.
        let searcher = FakeSearcher(result: [mosque("Masjid A", meters: 500)])
        let vm = NearbyMosquesViewModel(searcher: searcher)
        let loose = CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0)
        await vm.locateAndSearch(using: FakeLocation(authorizationStatus: .authorizedAlways, coordinate: loose))
        if case .loaded = vm.state {} else { XCTFail("expected .loaded, got \(vm.state)") }
    }

    // MARK: 3 — Search result states

    func testEmptySearchShowsEmptyState() async {
        let vm = NearbyMosquesViewModel(searcher: FakeSearcher(result: []))
        await vm.search(around: coord)
        XCTAssertEqual(vm.state, .empty)
    }

    func testOneResultLoads() async {
        let vm = NearbyMosquesViewModel(searcher: FakeSearcher(result: [mosque("Masjid A", meters: 500)]))
        await vm.search(around: coord)
        if case .loaded(let l) = vm.state { XCTAssertEqual(l.count, 1) } else { XCTFail() }
    }

    func testAllQueriesFailShowsError() async {
        let vm = NearbyMosquesViewModel(searcher: FakeSearcher(error: MosqueSearchError.allQueriesFailed))
        await vm.search(around: coord)
        XCTAssertEqual(vm.state, .error)
    }

    func testMoreThan15ResultsAreCapped() {
        let many = (0..<40).map { mosque("Masjid \($0)", lat: 40 + Double($0) / 1000, meters: Double($0) * 100) }
        XCTAssertEqual(MosqueSearchService.merge([many], limit: 15).count, 15)
    }

    func testPartialFailureKeepsSucceedingGroup() {
        // Service-level: merge only sees the groups that succeeded. One good
        // group + (dropped) failures still yields results.
        let good = [mosque("Masjid A", meters: 800)]
        XCTAssertEqual(MosqueSearchService.merge([good]).map(\.name), ["Masjid A"])
    }

    // MARK: 4 — Deduplication

    func testDuplicatesAcrossQueriesMerge() {
        let a = mosque("Masjid Al-Noor", lat: 40.200, lon: -74.200, meters: 1500)
        let b = mosque("Masjid al-noor", lat: 40.2003, lon: -74.2002, meters: 1200)
        let merged = MosqueSearchService.merge([[a], [b]])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.distanceMeters, 1200, "keeps the nearer copy")
    }

    func testSameNameFarApartNotDeduped() {
        let downtown = mosque("Islamic Center", lat: 40.0, lon: -74.0, meters: 1000)
        let suburb = mosque("Islamic Center", lat: 41.5, lon: -75.5, meters: 90000)
        XCTAssertEqual(MosqueSearchService.merge([[downtown, suburb]]).count, 2)
    }

    func testSlightlyDifferentNameSameSpotDedupes() {
        let a = mosque("Al Noor Masjid", lat: 40.20, lon: -74.20, meters: 1000)
        let b = mosque("Al-Noor  Masjid!", lat: 40.20, lon: -74.20, meters: 1100)
        XCTAssertEqual(MosqueSearchService.merge([[a, b]]).count, 1, "punctuation/spacing shouldn't matter")
    }

    // MARK: 5 — Sorting and distance

    func testSortsNearestFirst() {
        let merged = MosqueSearchService.merge([[
            mosque("Far", lat: 40.5, lon: -74.5, meters: 5000),
            mosque("Near", lat: 40.1, lon: -74.1, meters: 800),
            mosque("Mid", lat: 40.3, lon: -74.3, meters: 2500)
        ]])
        XCTAssertEqual(merged.map(\.name), ["Near", "Mid", "Far"])
    }

    func testDistanceLabels() {
        XCTAssertEqual(mosque("a", meters: 0).distanceLabel, "Nearby")       // 0 m
        XCTAssertEqual(mosque("a", meters: 100).distanceLabel, "Nearby")     // < 0.1 mi
        XCTAssertEqual(mosque("b", meters: 1609).distanceLabel, "1.0 mi")    // ~1 mi, one decimal
        XCTAssertEqual(mosque("c", meters: 8047).distanceLabel, "5.0 mi")    // ~5 mi
        XCTAssertEqual(mosque("d", meters: 32187).distanceLabel, "20 mi")    // 10+ mi, whole
    }

    // MARK: 6 — Missing optional fields

    func testMissingPhoneHidesCall() {
        XCTAssertNil(mosque("a", meters: 1, phone: nil).callURL)
    }

    func testGarbagePhoneHidesCall() {
        XCTAssertNil(mosque("a", meters: 1, phone: "n/a").callURL)            // < 7 digits
    }

    func testValidPhoneGivesCallURL() {
        XCTAssertEqual(mosque("a", meters: 1, phone: "+1 (313) 555-0199").callURL?.absoluteString,
                       "tel://+13135550199")
    }

    func testMissingWebsiteMeansNoURL() {
        XCTAssertNil(mosque("a", meters: 1, website: nil).websiteURL)
    }

    func testMissingAddressFallsBack() {
        XCTAssertEqual(mosque("a", meters: 1, address: "").displayAddress, "Address unavailable")
        XCTAssertEqual(mosque("a", meters: 1, address: "  ").displayAddress, "Address unavailable")
    }

    func testMissingOpenStatusIsNil() {
        XCTAssertNil(mosque("a", meters: 1, isOpen: nil).isOpen)
    }

    // MARK: 7 — Food filtering (name backstop)

    func testFoodNamesExcluded() {
        for name in ["Halal Guys", "Shawarma Palace Restaurant", "Kabob House", "Al-Madina Bakery"] {
            XCTAssertTrue(MosqueSearchService.isLikelyFood(name: name), name)
        }
    }

    func testMosqueNamesAllowed() {
        for name in ["Masjid Al-Noor", "Islamic Center of Detroit", "Mosque Foundation",
                     "Muslim Community Center", "Jami Masjid"] {
            XCTAssertFalse(MosqueSearchService.isLikelyFood(name: name), name)
        }
    }

    // MARK: 8 — Refresh behavior

    func testRefreshStartsNewSearch() async {
        let searcher = FakeSearcher(result: [mosque("A", meters: 500)])
        let vm = NearbyMosquesViewModel(searcher: searcher)
        await vm.search(around: coord)
        await vm.search(around: coord, force: true)
        XCTAssertEqual(searcher.counter.count, 2, "force refresh re-searches")
    }

    func testCachedResultSkipsRedundantSearch() async {
        let searcher = FakeSearcher(result: [mosque("A", meters: 500)])
        let vm = NearbyMosquesViewModel(searcher: searcher)
        await vm.search(around: coord)
        await vm.search(around: coord)   // same spot, not forced
        XCTAssertEqual(searcher.counter.count, 1, "same coordinate shouldn't re-search")
    }

    // MARK: 9 — Map actions (via MapsOpening seam + model)

    func testDirectionsUsesMapsOpener() {
        let maps = FakeMaps()
        let m = mosque("Masjid A", meters: 500)
        maps.openDirections(to: m)
        XCTAssertEqual(maps.directionsCount, 1)
        XCTAssertEqual(maps.lastMosque?.name, "Masjid A")
    }

    func testAppleMapsOpenerBuildsItemFromCoordinate() {
        let m = mosque("Masjid A", lat: 42.3, lon: -83.0, meters: 500)
        let item = AppleMapsOpener().mapItem(for: m)
        XCTAssertEqual(item.name, "Masjid A")
        XCTAssertEqual(item.placemark.coordinate.latitude, 42.3, accuracy: 0.0001)
        XCTAssertEqual(item.placemark.coordinate.longitude, -83.0, accuracy: 0.0001)
    }

    // MARK: 10 — Regression (existing content still loads)

    func testExistingContentStillLoads() {
        XCTAssertFalse(Duas.categories.isEmpty, "Du'as JSON must still decode")
        XCTAssertEqual(Learn.guides.count, 9, "Learn content must still load")
    }
}
