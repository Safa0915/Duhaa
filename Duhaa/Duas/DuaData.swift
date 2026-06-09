import Foundation

/// A category of du'as (e.g. "After Prayer", "Morning").
struct DuaCategory: Decodable, Identifiable {
    let name: String
    let icon: String         // SF Symbol
    let subtitle: String?    // optional override for the count line (e.g. "4 verified adhkar")
    let duas: [Dua]
    var id: String { name }
}

/// One supplication: Arabic, transliteration, English, note, source, and optional
/// authenticity status / fiqh note. New fields are optional so older entries — and
/// the existing `duas.json` — keep decoding unchanged.
struct Dua: Decodable, Identifiable {
    let title: String
    let arabic: String
    let latin: String        // transliteration
    let en: String           // translation
    let note: String         // repetition badge ("Read 3x") OR a short instruction
    let source: String
    let status: String?      // e.g. "Verified" — shown as a small badge when present
    let fiqhNote: String?    // small, secondary scholarly note shown at the card's foot
    let id = UUID()

    enum CodingKeys: String, CodingKey {
        case title, arabic, latin, en, note, source, status, fiqhNote
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

    private struct File: Decodable { let categories: [DuaCategory] }

    private static func load() -> [DuaCategory] {
        guard let url = Bundle.main.url(forResource: "duas", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.categories
    }
}
