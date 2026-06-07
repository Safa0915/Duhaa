import Foundation

/// The bundled Quran (Arabic Uthmani + Sahih International English).
/// NOTE before App Store submission: verify the Sahih International translation's
/// licensing/permission — the Arabic text is public domain, the translation is not.
struct QuranData: Decodable {
    let bismillah: Bismillah
    let surahs: [Surah]
}

struct Bismillah: Decodable {
    let arabic: String
    let english: String
    enum CodingKeys: String, CodingKey { case arabic = "a", english = "e" }
}

struct Surah: Decodable, Identifiable {
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

struct Ayah: Decodable, Identifiable {
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
        shared.surahs.first { $0.number == number }
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
