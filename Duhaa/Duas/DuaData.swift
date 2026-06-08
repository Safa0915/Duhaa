import Foundation

/// A category of du'as (e.g. "After Prayer", "Morning").
struct DuaCategory: Decodable, Identifiable {
    let name: String
    let icon: String   // SF Symbol
    let duas: [Dua]
    var id: String { name }
}

/// One supplication: Arabic, transliteration, English, repetition note, source.
struct Dua: Decodable, Identifiable {
    let title: String
    let arabic: String
    let latin: String     // transliteration
    let en: String        // translation
    let note: String      // e.g. "Read 3x"
    let source: String
    let id = UUID()

    enum CodingKeys: String, CodingKey { case title, arabic, latin, en, note, source }
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
