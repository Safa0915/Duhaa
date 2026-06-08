import Foundation

/// The location Duha is currently showing prayer times for. Persisted to
/// UserDefaults so the app works offline on next launch (spec §4).
struct ActiveLocation: Equatable, Codable {
    var name: String          // e.g. "New York, USA"
    var latitude: Double
    var longitude: Double
    var timeZoneID: String    // IANA id, e.g. "America/New_York" — never a fixed offset
    /// True when the user picked this city by hand; false for GPS/auto-detect.
    /// A manual choice is respected across launches (we don't silently re-GPS it).
    var isManual: Bool

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// Sensible first-run fallback before we have GPS or a cached value: Makkah.
    static let fallback = ActiveLocation(
        name: "Makkah, Saudi Arabia",
        latitude: 21.4225, longitude: 39.8262,
        timeZoneID: "Asia/Riyadh", isManual: false
    )
}

/// A search result the user can tap to set their location manually.
struct CitySuggestion: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String
}
