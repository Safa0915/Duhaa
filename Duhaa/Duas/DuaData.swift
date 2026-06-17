import Foundation

/// A category of du'as (e.g. "After Prayer", "Morning").
struct DuaCategory: Decodable, Identifiable, Sendable {
    let name: String
    let icon: String         // SF Symbol
    let subtitle: String?    // optional override for the count line (e.g. "4 verified adhkar")
    let duas: [Dua]
    var id: String { name }
}

/// One supplication: Arabic, transliteration, English, note, source, and optional
/// authenticity status / fiqh note. New fields are optional so older entries — and
/// the existing `duas.json` — keep decoding unchanged.
struct Dua: Decodable, Identifiable, Sendable {
    let title: String
    let arabic: String
    let latin: String        // transliteration
    let en: String           // translation
    let note: String         // repetition badge ("Read 3x") OR a short instruction
    let source: String
    let status: String?      // e.g. "Verified" — shown as a small badge when present
    let fiqhNote: String?    // small, secondary scholarly note shown at the card's foot
    let count: Int?          // Sunnah repetition count — badge "10×" (hidden when 1)
    let prayerScope: String? // e.g. "Fajr & Maghrib" when a dhikr isn't for all five
    let countNote: String?   // conditional counts, e.g. "Fajr/Maghrib: 3× each"
    let variations: [String]? // alternate Sunnah counts, collapsed behind a disclosure
    let id = UUID()

    enum CodingKeys: String, CodingKey {
        case title, arabic, latin, en, note, source, status, fiqhNote
        case count, prayerScope, countNote, variations
    }

    /// True when `note` is a repetition count (e.g. "Read 3x") rather than an
    /// instruction sentence — used to decide capsule-badge vs. inline line.
    var noteIsRepetition: Bool {
        note.range(of: #"\d+\s*x"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

/// Loads `duas.json` from the bundle once (Hisnul Muslim, fitrahive/dua-dhikr).
enum Duas {
    static let categories: [DuaCategory] = load()

    static func loadAsync(priority: TaskPriority = .userInitiated) async -> [DuaCategory] {
        await Task.detached(priority: priority) {
            categories
        }.value
    }

    private struct File: Decodable { let categories: [DuaCategory] }
    /// Anchors the lookup to the app module's bundle (not Bundle.main), so unit
    /// tests resolve the same duas.json the app ships.
    private final class BundleToken {}

    private static func load() -> [DuaCategory] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "duas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.categories
    }
}
