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

    func pageGroups(using index: QuranPageIndex = .shared) -> [QuranPageGroup] {
        guard !ayahs.isEmpty else { return [] }

        var groups: [QuranPageGroup] = []
        for ayah in ayahs {
            let page = index.pageNumber(surah: number, ayah: ayah.number)
            if let lastIndex = groups.indices.last, groups[lastIndex].page == page {
                groups[lastIndex].ayahs.append(ayah)
            } else {
                let isContinuation = page != nil && index.pageStartNumber(surah: number, ayah: ayah.number) == nil
                groups.append(QuranPageGroup(page: page, isContinuation: isContinuation, ayahs: [ayah]))
            }
        }

        if groups.isEmpty {
            return [QuranPageGroup(page: nil, isContinuation: false, ayahs: ayahs)]
        }
        return groups
    }
}

struct Ayah: Decodable, Equatable, Identifiable, Sendable {
    let number: Int
    let arabic: String
    let english: String

    var id: Int { number }

    enum CodingKeys: String, CodingKey { case number = "n", arabic = "a", english = "e" }
}

struct QuranPageGroup: Identifiable, Sendable {
    let page: Int?
    let isContinuation: Bool
    var ayahs: [Ayah]

    var id: String {
        if let page { return "page-\(page)" }
        return "unpaged-\(ayahs.first?.number ?? 0)"
    }
}

struct QuranPageStart: Decodable, Equatable, Sendable {
    let page: Int
    let surah: Int
    let ayah: Int

    enum CodingKeys: String, CodingKey {
        case page = "p", surah = "s", ayah = "a"
    }
}

/// Madani mushaf page starts, generated from Quran.com verse page metadata.
struct QuranPageIndex: Sendable {
    static let shared = load()

    let pages: [QuranPageStart]

    func pageNumber(surah: Int, ayah: Int) -> Int? {
        pages.last { start in
            start.surah < surah || (start.surah == surah && start.ayah <= ayah)
        }?.page
    }

    func pageStartNumber(surah: Int, ayah: Int) -> Int? {
        pages.first { $0.surah == surah && $0.ayah == ayah }?.page
    }

    private struct File: Decodable {
        let pages: [QuranPageStart]
    }

    private static func load() -> QuranPageIndex {
        guard let url = Bundle.main.url(forResource: "quran_pages", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return QuranPageIndex(pages: [])
        }
        return QuranPageIndex(pages: decoded.pages)
    }
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
