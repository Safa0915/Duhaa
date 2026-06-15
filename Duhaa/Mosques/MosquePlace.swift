import Foundation
import CoreLocation

/// A nearby mosque, mapped from an Apple MapKit `MKMapItem`. Pure value type so
/// the merge / dedupe / sort / formatting logic is unit-testable without MapKit.
struct MosquePlace: Identifiable, Equatable {
    /// Stable dedupe key: normalized name + coordinate rounded to ~110m.
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double
    let phoneNumber: String?
    let websiteURL: URL?
    let isOpen: Bool?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Address for the card, with a graceful fallback when MapKit gave none.
    var displayAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Address unavailable" : address
    }

    /// A `tel://` URL when a dialable phone exists — drives whether the Call
    /// button shows at all. Nil (no button) when the phone is missing/garbage.
    var callURL: URL? {
        guard let phone = phoneNumber else { return nil }
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard digits.filter(\.isNumber).count >= 7 else { return nil }
        return URL(string: "tel://\(digits)")
    }

    /// Distance shown on the card. Miles for now (see formatting rules in spec):
    /// under 0.1 mi → "Nearby", under 10 mi → one decimal, 10+ mi → whole miles.
    var distanceLabel: String {
        let miles = distanceMeters / 1609.344
        if miles < 0.1 { return "Nearby" }
        if miles < 10 { return String(format: "%.1f mi", miles) }
        return "\(Int(miles.rounded())) mi"
    }

    static func == (lhs: MosquePlace, rhs: MosquePlace) -> Bool {
        lhs.id == rhs.id
            && lhs.distanceMeters == rhs.distanceMeters
            && lhs.phoneNumber == rhs.phoneNumber
            && lhs.websiteURL == rhs.websiteURL
            && lhs.isOpen == rhs.isOpen
    }
}

extension MosquePlace {
    /// Builds the dedupe id from a name + coordinate. Folds diacritics, drops
    /// non-alphanumerics, and rounds the coordinate so two listings of the same
    /// masjid (slightly different spelling or pin) collapse into one.
    static func makeID(name: String, latitude: Double, longitude: Double) -> String {
        let normalized = name
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        let lat = (latitude * 1000).rounded() / 1000
        let lon = (longitude * 1000).rounded() / 1000
        return "\(normalized)@\(lat),\(lon)"
    }
}
