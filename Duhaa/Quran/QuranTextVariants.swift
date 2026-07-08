import Foundation

actor QuranTextVariantAPI {
    static let shared = QuranTextVariantAPI()

    private var cache: [String: [Int: String]] = [:]

    func chapter(_ chapter: Int, preference: QuranFontPreference) async throws -> [Int: String] {
        let field = preference.verseTextField
        guard field != .textUthmani else { return [:] }

        let clampedChapter = min(max(chapter, 1), 114)
        let cacheKey = "\(clampedChapter)-\(field)"
        if let cached = cache[cacheKey] { return cached }

        var components = URLComponents(string: "https://api.quran.com/api/v4/verses/by_chapter/\(clampedChapter)")!
        components.queryItems = [
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "words", value: "true"),
            URLQueryItem(name: "word_fields", value: preference.apiWordFields),
            URLQueryItem(name: "fields", value: preference.apiVerseFields),
            URLQueryItem(name: "mushaf", value: "\(preference.mushafID)"),
            URLQueryItem(name: "per_page", value: "300")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(QuranTextVariantResponse.self, from: data)
        let variants = decoded.verseText(field: field)
        cache[cacheKey] = variants
        return variants
    }
}

private struct QuranTextVariantResponse: Decodable {
    let verses: [Verse]

    func verseText(field: QuranTextField) -> [Int: String] {
        Dictionary(uniqueKeysWithValues: verses.map { verse in
            let words = verse.words
                .filter { $0.charTypeName == "word" }
                .map { QuranArabicText.display($0.text(for: field)) }
                .filter { !$0.isEmpty }
            return (verse.verseNumber, words.joined(separator: " "))
        })
    }

    struct Verse: Decodable {
        let verseNumber: Int
        let words: [Word]

        enum CodingKeys: String, CodingKey {
            case verseNumber = "verse_number"
            case words
        }
    }

    struct Word: Decodable {
        let charTypeName: String
        let textUthmani: String?
        let textQPCHafs: String?
        let textIndopak: String?
        let codeV2: String?

        enum CodingKeys: String, CodingKey {
            case charTypeName = "char_type_name"
            case textUthmani = "text_uthmani"
            case textQPCHafs = "text_qpc_hafs"
            case textIndopak = "text_indopak"
            case codeV2 = "code_v2"
        }

        func text(for field: QuranTextField) -> String {
            switch field {
            case .textUthmani:
                return textUthmani ?? textQPCHafs ?? textIndopak ?? codeV2 ?? ""
            case .textQPCHafs:
                return textQPCHafs ?? textUthmani ?? textIndopak ?? codeV2 ?? ""
            case .textIndopak:
                return textIndopak ?? textQPCHafs ?? textUthmani ?? codeV2 ?? ""
            case .codeV2:
                return codeV2 ?? textQPCHafs ?? textUthmani ?? textIndopak ?? ""
            }
        }
    }
}
