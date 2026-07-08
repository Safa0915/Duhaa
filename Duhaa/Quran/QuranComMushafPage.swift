import Foundation

/// One word on a mushaf page, with everything the tap-to-lookup card needs:
/// display Arabic, its English gloss + transliteration, and the word-audio URL.
/// Verse-end markers (`﴿n﴾`) are carried as non-tappable words (`isWord == false`).
struct MushafWord: Identifiable, Equatable, Sendable {
    let id: Int
    let text: String          // page display text: Unicode Arabic or QCF glyph code
    let arabicText: String    // readable Arabic for sheets and accessibility
    let surah: Int
    let ayah: Int
    let position: Int         // 1-based word position within its ayah
    let isWord: Bool          // false for verse-end markers (not tappable)
    let translation: String
    let transliteration: String
    let audioPath: String?    // relative, e.g. "wbw/001_001_001.mp3"

    /// Quran.com word-by-word audio CDN.
    static let audioHost = "https://audio.qurancdn.com/"

    init(id: Int, text: String, arabicText: String? = nil, surah: Int, ayah: Int,
         position: Int, isWord: Bool, translation: String, transliteration: String,
         audioPath: String?) {
        self.id = id
        self.text = text
        self.arabicText = arabicText ?? text
        self.surah = surah
        self.ayah = ayah
        self.position = position
        self.isWord = isWord
        self.translation = translation
        self.transliteration = transliteration
        self.audioPath = audioPath
    }

    var audioURL: URL? {
        guard isWord, let audioPath, !audioPath.isEmpty else { return nil }
        return URL(string: Self.audioHost + audioPath)
    }
}

struct QuranComMushafLine: Identifiable, Equatable, Sendable {
    let number: Int
    let text: String
    let refs: Set<QuranVerseRef>
    /// Ordered words making up this line (used for tap-to-lookup word meanings).
    let words: [MushafWord]

    var id: Int { number }

    var accessibilityText: String {
        words.map(\.arabicText).joined(separator: " ")
    }
}

struct QuranComMushafPage: Equatable, Sendable {
    let page: Int
    let juzNumber: Int?
    let lines: [QuranComMushafLine]
    let firstRef: QuranVerseRef?
    let lastRef: QuranVerseRef?

    func lines(forSurah surah: Int, ayahs: Set<Int>) -> [QuranComMushafLine] {
        lines.filter { line in
            line.refs.contains { ref in ref.surah == surah && ayahs.contains(ref.ayah) }
        }
    }

    func firstLineNumber(forSurah surah: Int) -> Int? {
        lines.first { line in
            line.refs.contains { $0.surah == surah }
        }?.number
    }
}

actor QuranComMushafPageAPI {
    static let shared = QuranComMushafPageAPI()

    private var cache: [String: QuranComMushafPage] = [:]

    func page(_ page: Int, preference: QuranFontPreference = .kfgqpc) async throws -> QuranComMushafPage {
        let clampedPage = min(max(page, 1), 604)
        let cacheKey = "\(clampedPage)-\(preference.rawValue)"
        if let cached = cache[cacheKey] { return cached }

        var components = URLComponents(string: "https://api.quran.com/api/v4/verses/by_page/\(clampedPage)")!
        components.queryItems = [
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "words", value: "true"),
            URLQueryItem(name: "word_translation_language", value: "en"),
            URLQueryItem(name: "word_fields", value: preference.apiWordFields),
            URLQueryItem(name: "fields", value: preference.apiVerseFields),
            URLQueryItem(name: "mushaf", value: "\(preference.mushafID)"),
            URLQueryItem(name: "per_page", value: "50")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let page = try Self.decodePage(data, page: clampedPage, preference: preference)
        cache[cacheKey] = page
        return page
    }

    static func decodePage(_ data: Data, page: Int, preference: QuranFontPreference) throws -> QuranComMushafPage {
        try JSONDecoder().decode(QuranComPageResponse.self, from: data)
            .mushafPage(page: page, preference: preference)
    }
}

private struct QuranComPageResponse: Decodable {
    let verses: [Verse]

    func mushafPage(page pageNumber: Int, preference: QuranFontPreference) -> QuranComMushafPage {
        var lineBuckets: [Int: [MushafWord]] = [:]
        var firstRef: QuranVerseRef?
        var lastRef: QuranVerseRef?

        for verse in verses {
            guard let ref = verse.ref else { continue }
            firstRef = firstRef ?? ref
            lastRef = ref

            if verse.words.isEmpty, let line = verse.pageNumber {
                lineBuckets[line, default: []].append(MushafWord(
                    id: verse.id ?? -(line * 10_000),
                    text: QuranArabicText.display(verse.text(for: preference.lineTextField)),
                    arabicText: QuranArabicText.display(verse.text(for: preference.verseTextField)),
                    surah: ref.surah, ayah: ref.ayah, position: 0, isWord: false,
                    translation: "", transliteration: "", audioPath: nil))
            }

            for word in verse.words {
                guard let lineNumber = word.lineNumber else { continue }
                let isEnd = word.charTypeName == "end"
                let display = word.displayText(for: preference, verseNumber: verse.verseNumber, isEnd: isEnd)
                let arabic = word.readableText(for: preference, verseNumber: verse.verseNumber, isEnd: isEnd)
                lineBuckets[lineNumber, default: []].append(MushafWord(
                    id: word.id,
                    text: display,
                    arabicText: arabic,
                    surah: ref.surah, ayah: ref.ayah,
                    position: word.position ?? 0,
                    isWord: word.charTypeName == "word",
                    translation: word.translation?.text ?? "",
                    transliteration: word.transliteration?.text ?? "",
                    audioPath: word.audioUrl))
            }
        }

        let lines = lineBuckets.keys.sorted().map { lineNumber in
            let chunks = lineBuckets[lineNumber] ?? []
            return QuranComMushafLine(
                number: lineNumber,
                text: chunks.map(\.text).joined(separator: " "),
                refs: Set(chunks.map { QuranVerseRef(surah: $0.surah, ayah: $0.ayah) }),
                words: chunks
            )
        }

        return QuranComMushafPage(
            page: pageNumber,
            juzNumber: verses.first?.juzNumber,
            lines: lines,
            firstRef: firstRef,
            lastRef: lastRef
        )
    }

    struct Verse: Decodable {
        let id: Int?
        let verseNumber: Int
        let verseKey: String
        let textUthmani: String?
        let textQPCHafs: String?
        let textIndopak: String?
        let codeV2: String?
        let pageNumber: Int?
        let juzNumber: Int?
        let words: [Word]

        var ref: QuranVerseRef? {
            let parts = verseKey.split(separator: ":")
            guard parts.count == 2,
                  let surah = Int(parts[0]),
                  let ayah = Int(parts[1]) else { return nil }
            return QuranVerseRef(surah: surah, ayah: ayah)
        }

        enum CodingKeys: String, CodingKey {
            case id
            case verseNumber = "verse_number"
            case verseKey = "verse_key"
            case textUthmani = "text_uthmani"
            case textQPCHafs = "text_qpc_hafs"
            case textIndopak = "text_indopak"
            case codeV2 = "code_v2"
            case pageNumber = "page_number"
            case juzNumber = "juz_number"
            case words
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

    struct Word: Decodable {
        let id: Int
        let position: Int?
        let charTypeName: String
        let textUthmani: String?
        let textQPCHafs: String?
        let textIndopak: String?
        let codeV2: String?
        let lineNumber: Int?
        let audioUrl: String?
        let translation: Glossed?
        let transliteration: Glossed?

        enum CodingKeys: String, CodingKey {
            case id, position, translation, transliteration
            case charTypeName = "char_type_name"
            case textUthmani = "text_uthmani"
            case textQPCHafs = "text_qpc_hafs"
            case textIndopak = "text_indopak"
            case codeV2 = "code_v2"
            case lineNumber = "line_number"
            case audioUrl = "audio_url"
        }

        func displayText(for preference: QuranFontPreference, verseNumber: Int, isEnd: Bool) -> String {
            if isEnd, !preference.isPageFont {
                return MushafPage.verseMarker(verseNumber, easternDigits: preference.usesEasternArabicDigits)
            }
            return QuranArabicText.display(text(for: preference.lineTextField))
        }

        func readableText(for preference: QuranFontPreference, verseNumber: Int, isEnd: Bool) -> String {
            if isEnd {
                return MushafPage.verseMarker(verseNumber, easternDigits: preference.usesEasternArabicDigits)
            }
            return QuranArabicText.display(text(for: preference.verseTextField))
        }

        private func text(for field: QuranTextField) -> String {
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

    struct Glossed: Decodable { let text: String? }
}
