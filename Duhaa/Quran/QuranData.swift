import Foundation

/// The bundled Quran (Arabic Uthmani + English: ClearQuran by Talal Itani,
/// the "Allah" edition — CC BY-NC-ND, free for this free app with attribution,
/// credited in About).
struct QuranData: Decodable, Sendable {
    let bismillah: Bismillah
    let surahs: [Surah]

    func surah(_ number: Int) -> Surah? {
        surahs.first { $0.number == number }
    }
}

struct Bismillah: Decodable, Sendable {
    let arabic: String
    let english: String
    enum CodingKeys: String, CodingKey { case arabic = "a", english = "e" }
}

struct Surah: Decodable, Identifiable, Sendable {
    let number: Int
    let arabicName: String
    let englishName: String
    let translation: String
    let revelation: String   // "Meccan" / "Medinan"
    let ayahs: [Ayah]

    var id: Int { number }

    enum CodingKeys: String, CodingKey {
        case number = "n", arabicName = "ar", englishName = "en"
        case translation = "tr", revelation = "type", ayahs
    }
}

struct Ayah: Decodable, Identifiable, Sendable {
    let number: Int
    let arabic: String
    let english: String

    var id: Int { number }

    enum CodingKeys: String, CodingKey { case number = "n", arabic = "a", english = "e" }
}

/// Loads `quran.json` from the bundle once, on first access.
enum Quran {
    static let shared: QuranData = load()

    static func surah(_ number: Int) -> Surah? {
        shared.surah(number)
    }

    static func loadAsync(priority: TaskPriority = .userInitiated) async -> QuranData {
        await Task.detached(priority: priority) {
            shared
        }.value
    }

    static func surahAsync(_ number: Int, priority: TaskPriority = .userInitiated) async -> Surah? {
        await loadAsync(priority: priority).surah(number)
    }

    private static func load() -> QuranData {
        guard let url = Bundle.main.url(forResource: "quran", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(QuranData.self, from: data) else {
            return QuranData(bismillah: Bismillah(arabic: "", english: ""), surahs: [])
        }
        return decoded
    }
}
