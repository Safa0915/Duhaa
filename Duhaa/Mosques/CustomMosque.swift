import Foundation
import Observation

/// A masjid the user added themselves, when Apple Maps' nearby search didn't
/// list it. Stored **privately on-device only** — no network, no analytics. It
/// shows in the user's own Nearby Mosques list alongside the MapKit results.
///
/// The URL builders are pure (no UIKit/MapKit) so they're unit-testable.
struct CustomMosque: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    /// Address or written directions to the masjid — **required**. Drives the
    /// "Directions" button (opens Apple Maps with this as the destination).
    var address: String
    var phoneNumber: String?
    var website: String?

    init(id: UUID = UUID(), name: String, address: String,
         phoneNumber: String? = nil, website: String? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.phoneNumber = phoneNumber
        self.website = website
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayName: String {
        trimmedName.isEmpty ? "My mosque" : trimmedName
    }

    var displayAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `tel://` URL when a dialable number was saved — mirrors `MosquePlace` so
    /// the Call button only appears for a real phone number.
    var callURL: URL? {
        guard let phoneNumber else { return nil }
        let digits = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard digits.filter(\.isNumber).count >= 7 else { return nil }
        return URL(string: "tel://\(digits)")
    }

    /// Website URL, tolerating input without a scheme ("masjid.org" → https://…).
    var websiteURL: URL? { Self.normalizedWebURL(website) }

    /// Apple Maps directions to the saved mosque (MapKit ecosystem, no API key).
    /// Uses the name + address as the destination so Maps can geocode it.
    var directionsURL: URL? {
        let destination = [trimmedName, displayAddress]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !destination.isEmpty else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "daddr", value: destination)]
        return components?.url
    }

    /// Normalizes free-typed website text into a URL: trims, prepends `https://`
    /// when no scheme is present, and rejects input with no host.
    static func normalizedWebURL(_ raw: String?) -> URL? {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        let lower = text.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            text = "https://" + text
        }
        guard let url = URL(string: text), let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

/// Persists the user's own added mosques as JSON in `UserDefaults`
/// (`duhaa.customMosques`). `@Observable` so SwiftUI re-renders on change;
/// `init(defaults:)` keeps it isolated for unit tests.
@Observable
final class CustomMosqueStore {
    private(set) var mosques: [CustomMosque]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "duhaa.customMosques"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CustomMosque].self, from: data) {
            mosques = decoded
        } else {
            mosques = []
        }
    }

    func add(_ mosque: CustomMosque) {
        mosques.append(mosque)
        persist()
    }

    /// Replaces an existing mosque (matched by id), keeping its position.
    func update(_ mosque: CustomMosque) {
        guard let index = mosques.firstIndex(where: { $0.id == mosque.id }) else {
            add(mosque)
            return
        }
        mosques[index] = mosque
        persist()
    }

    func remove(_ mosque: CustomMosque) {
        mosques.removeAll { $0.id == mosque.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(mosques) {
            defaults.set(data, forKey: key)
        }
    }
}
