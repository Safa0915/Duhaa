import XCTest
@testable import Duhaa

/// Guards the bundled offline country→city dataset: it ships, decodes, and carries
/// valid coordinates + IANA time zones so manual location works with no network.
final class WorldLocationsTests: XCTestCase {

    private var countries: [WorldCountry] { WorldLocations.all }

    func testDatasetLoadsWithManyCountries() {
        XCTAssertGreaterThan(countries.count, 200, "expected the full world country list")
        XCTAssertTrue(countries.allSatisfy { !$0.cities.isEmpty })
    }

    func testCountriesAreSortedByName() {
        let names = countries.map(\.name)
        XCTAssertEqual(names, names.sorted(), "countries should be alphabetical for the picker")
    }

    func testKnownCitiesResolve() {
        let sa = countries.first { $0.code == "SA" }
        let makkah = sa?.cities.first { $0.n.localizedCaseInsensitiveContains("makkah") }
        XCTAssertNotNil(makkah)
        XCTAssertEqual(makkah?.tz, "Asia/Riyadh")
        XCTAssertEqual(makkah.map { Int($0.lat) }, 21)

        let us = countries.first { $0.code == "US" }
        let ny = us?.cities.first { $0.n.localizedCaseInsensitiveContains("new york") }
        XCTAssertEqual(ny?.tz, "America/New_York")
    }

    func testEveryCountrysTopCityHasValidTimeZoneAndCoords() {
        for country in countries {
            guard let city = country.cities.first else { continue }
            XCTAssertNotNil(TimeZone(identifier: city.tz), "\(country.name)/\(city.n): bad tz \(city.tz)")
            XCTAssertTrue((-90...90).contains(city.lat), "\(city.n): bad latitude")
            XCTAssertTrue((-180...180).contains(city.lon), "\(city.n): bad longitude")
        }
    }

    func testFlagEmojiFromCode() {
        let us = countries.first { $0.code == "US" }
        XCTAssertEqual(us?.flag, "🇺🇸")
    }
}
