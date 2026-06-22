import Foundation

/// A country in the bundled, offline location dataset (GeoNames, CC BY 4.0).
struct WorldCountry: Decodable, Identifiable, Sendable {
    let code: String          // ISO 3166-1 alpha-2, e.g. "US"
    let name: String          // e.g. "United States"
    let cities: [WorldCity]   // sorted biggest-first at build time
    var id: String { code }

    /// 🇺🇸 — the flag emoji for this country's ISO code (empty if not 2 letters).
    var flag: String {
        let upper = code.uppercased()
        guard upper.count == 2 else { return "" }
        return upper.unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value).map(String.init)
        }.joined()
    }
}

/// One city the user can pick by hand. Carries everything prayer times need, so the
/// choice works fully offline (no geocoding).
struct WorldCity: Decodable, Identifiable, Sendable {
    let n: String             // city name
    let r: String?            // region / state, for disambiguation (optional)
    let lat: Double
    let lon: Double
    let tz: String            // IANA time-zone id

    var id: String { "\(n)|\(lat)|\(lon)" }
}

/// Loads `locations.json` (countries → cities) from the bundle once. Decoded off the
/// main thread (~2.75 MB) and only on first use — the picker triggers it, never launch.
/// Anchored to the app module bundle so unit tests resolve the shipped file.
enum WorldLocations {
    static let all: [WorldCountry] = load()

    static func loadAsync(priority: TaskPriority = .userInitiated) async -> [WorldCountry] {
        await Task.detached(priority: priority) { all }.value
    }

    private struct File: Decodable { let countries: [WorldCountry] }
    private final class BundleToken {}

    private static func load() -> [WorldCountry] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "locations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.countries
    }
}
