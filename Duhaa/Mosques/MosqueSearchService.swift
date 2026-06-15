import Foundation
import MapKit

/// Finds nearby mosques with Apple's MapKit only — no Google/Yelp/OSM, no API
/// key, no analytics. Runs three `MKLocalSearch` queries around the user, then
/// merges, dedupes, sorts by distance, and caps the list.
///
/// The pure parts (`merge`, `isLikelyFood`) are static so they're unit-testable
/// without MapKit.
struct MosqueSearchService: MosqueSearching {
    /// The only search terms — mosques/masjids, never food or anything else.
    static let queries = ["mosque", "masjid", "islamic center"]

    /// ~20 mile box around the user.
    static let regionMeters: CLLocationDistance = 32_000
    static let resultLimit = 15

    /// Merge result groups → dedupe by id (keep the nearest copy) → sort by
    /// distance → cap. Pure and synchronous, so tests can drive it with mocks.
    static func merge(_ groups: [[MosquePlace]], limit: Int = resultLimit) -> [MosquePlace] {
        var nearestByID: [String: MosquePlace] = [:]
        for place in groups.flatMap({ $0 }) {
            if let existing = nearestByID[place.id], existing.distanceMeters <= place.distanceMeters {
                continue
            }
            nearestByID[place.id] = place
        }
        return nearestByID.values
            .sorted { $0.distanceMeters < $1.distanceMeters }
            .prefix(limit)
            .map { $0 }
    }

    /// Live search around a coordinate (the `MosqueSearching` conformance).
    /// Runs the three queries concurrently. Throws only if *all* fail, so the
    /// caller can tell "couldn't load" (error) from "found nothing" (empty).
    /// Partial success — at least one query returns — still yields results.
    func searchNearbyMosques(from center: CLLocationCoordinate2D) async throws -> [MosquePlace] {
        let origin = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let region = MKCoordinateRegion(center: center,
                                        latitudinalMeters: Self.regionMeters,
                                        longitudinalMeters: Self.regionMeters)

        let outcomes = await withTaskGroup(of: Result<[MosquePlace], Error>.self) { group -> [Result<[MosquePlace], Error>] in
            for term in Self.queries {
                group.addTask {
                    do { return .success(try await Self.runSearch(term, region: region, origin: origin)) }
                    catch { return .failure(error) }
                }
            }
            var collected: [Result<[MosquePlace], Error>] = []
            for await result in group { collected.append(result) }
            return collected
        }

        let groups = outcomes.compactMap { try? $0.get() }
        if groups.isEmpty { throw MosqueSearchError.allQueriesFailed }   // every query failed
        return Self.merge(groups)
    }

    private static func runSearch(_ term: String,
                                  region: MKCoordinateRegion,
                                  origin: CLLocation) async throws -> [MosquePlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = term
        request.region = region
        request.resultTypes = [.pointOfInterest]

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap { place(from: $0, origin: origin) }
    }

    /// Maps a MapKit item to our model, dropping food POIs as a safety net.
    private static func place(from item: MKMapItem, origin: CLLocation) -> MosquePlace? {
        if let category = item.pointOfInterestCategory, isFood(category) { return nil }
        let rawName = item.name ?? item.placemark.name ?? "Mosque"
        if isLikelyFood(name: rawName) { return nil }   // name-based backstop
        let placemark = item.placemark
        let name = rawName
        let coord = placemark.coordinate
        let distance = origin.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
        return MosquePlace(
            id: MosquePlace.makeID(name: name, latitude: coord.latitude, longitude: coord.longitude),
            name: name,
            address: formattedAddress(placemark),
            latitude: coord.latitude,
            longitude: coord.longitude,
            distanceMeters: distance,
            phoneNumber: item.phoneNumber,
            websiteURL: item.url,
            isOpen: nil   // MKMapItem exposes no public open/closed flag yet.
        )
    }

    private static func isFood(_ category: MKPointOfInterestCategory) -> Bool {
        [.restaurant, .cafe, .bakery, .foodMarket, .brewery, .winery].contains(category)
    }

    /// Conservative name backstop for the "no halal food" rule: excludes a place
    /// only when the name clearly signals food AND has no mosque word — so real
    /// masjids (incl. "Islamic Center", "Muslim Community Center") are kept.
    static func isLikelyFood(name: String) -> Bool {
        let lower = name.lowercased()
        let mosqueWords = ["mosque", "masjid", "musalla", "musallah", "islamic center",
                           "islamic centre", "muslim community", "jami", "jamia", "prayer"]
        if mosqueWords.contains(where: lower.contains) { return false }
        let foodWords = ["restaurant", "grill", "kitchen", "cafe", "café", "bakery",
                         "kabob", "kebab", "biryani", "shawarma", "halal guys", "deli",
                         "pizza", "burger", "diner", "eatery", "bistro", "food", "meat market"]
        return foodWords.contains(where: lower.contains)
    }

    private static func formattedAddress(_ placemark: MKPlacemark) -> String {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }.joined(separator: " ")
        let parts = [street, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }
}
