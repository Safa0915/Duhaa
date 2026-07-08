import Foundation

struct QuranVerseRef: Hashable, Sendable {
    let surah: Int
    let ayah: Int
}

/// One Madani-mushaf page (1…604), reconstructed from the bundled page-start
/// index + the full Quran text. Unlike `Surah.pageGroups()` (which only spans a
/// single surah), a mushaf page can cross surah boundaries — so this carries an
/// ordered list of segments: a surah header (when a surah begins on the page),
/// then a run of that surah's ayahs. Pure value type, so the build is testable.
struct MushafPage: Identifiable, Sendable {
    let page: Int
    let segments: [Segment]

    var id: Int { page }

    enum Segment: Identifiable, Sendable {
        /// A surah that *begins* on this page — an ornamental title, optionally
        /// followed by the Bismillah (every surah except Al-Fatihah and At-Tawbah).
        case surahHeader(number: Int, arabicName: String, englishName: String, showsBismillah: Bool)
        /// A consecutive run of ayahs from one surah that fall on this page.
        case ayahRun(surah: Int, ayahs: [Ayah])

        var id: String {
            switch self {
            case .surahHeader(let n, _, _, _): return "h-\(n)"
            case .ayahRun(let s, let a): return "r-\(s)-\(a.first?.number ?? 0)"
            }
        }
    }

    /// Ayah-end marker with Arabic-Indic digits inside the ornamental brackets
    /// (e.g. ﴿٢﴾) — matches the brackets used in the inline page mode.
    ///
    /// `easternDigits` switches to the Extended Arabic-Indic (Urdu) digit set —
    /// required for the Indo-Pak Nastaleeq font, whose standard U+0660–0669 digit
    /// glyphs are blank, so the number would otherwise render invisibly.
    static func verseMarker(_ number: Int, easternDigits: Bool = false) -> String {
        "﴿\(arabicIndic(number, eastern: easternDigits))﴾"
    }

    /// Quran.com line data gives ayah endings as a separate word. Prefixing the
    /// Arabic end-of-ayah sign lets the KFGQPC font render a mushaf-like rosette.
    static func rosetteVerseMarker(_ number: Int, easternDigits: Bool = false) -> String {
        "\u{06DD}\(arabicIndic(number, eastern: easternDigits))"
    }

    static func arabicIndic(_ number: Int, eastern: Bool = false) -> String {
        let digits: [Character] = eastern
            ? ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]   // U+06F0–06F9 (Indo-Pak / Urdu)
            : ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]   // U+0660–0669 (Arabic-Indic)
        return String(String(number).compactMap { char in
            char.wholeNumberValue.map { digits[$0] }
        })
    }

    /// The surah a reader would consider this page to "belong" to — the first one
    /// with ayahs on the page. Drives the page's title.
    var primarySurah: Int? {
        for segment in segments {
            if case .ayahRun(let surah, _) = segment { return surah }
        }
        if case .surahHeader(let n, _, _, _)? = segments.first { return n }
        return nil
    }

    var firstAyahRef: QuranVerseRef? {
        for segment in segments {
            if case .ayahRun(let surah, let ayahs) = segment, let first = ayahs.first {
                return QuranVerseRef(surah: surah, ayah: first.number)
            }
        }
        return nil
    }

    var lastAyahRef: QuranVerseRef? {
        for segment in segments.reversed() {
            if case .ayahRun(let surah, let ayahs) = segment, let last = ayahs.last {
                return QuranVerseRef(surah: surah, ayah: last.number)
            }
        }
        return nil
    }

    var juzNumber: Int {
        Self.juzNumber(forPage: page)
    }

    static func juzNumber(forPage page: Int) -> Int {
        let starts = [
            1, 22, 42, 62, 82, 102, 122, 142, 162, 182,
            202, 222, 242, 262, 282, 302, 322, 342, 362, 382,
            402, 422, 442, 462, 482, 502, 522, 542, 562, 582
        ]
        return (starts.lastIndex { page >= $0 } ?? 0) + 1
    }
}

/// Builds and caches all 604 mushaf pages once, from the bundled data.
enum Mushaf {
    static let pages: [MushafPage] = build()

    static func page(_ number: Int) -> MushafPage? {
        guard number >= 1, number <= pages.count else { return nil }
        return pages[number - 1]
    }

    /// The mushaf page a (surah, ayah) sits on — reuses the existing page index.
    static func pageNumber(surah: Int, ayah: Int, index: QuranPageIndex = .shared) -> Int {
        index.pageNumber(surah: surah, ayah: ayah) ?? 1
    }

    /// Reconstruct each page's content by slicing the global ayah order between
    /// consecutive page-start markers. Injectable for tests.
    static func build(data: QuranData = Quran.shared, index: QuranPageIndex = .shared) -> [MushafPage] {
        let starts = index.pages.sorted { $0.page < $1.page }
        guard !starts.isEmpty else { return [] }

        let surahByNumber = Dictionary(uniqueKeysWithValues: data.surahs.map { ($0.number, $0) })

        var result: [MushafPage] = []
        result.reserveCapacity(starts.count)

        for (i, start) in starts.enumerated() {
            let next = i + 1 < starts.count ? starts[i + 1] : nil
            let lastSurahOnPage = next?.surah ?? (data.surahs.last?.number ?? 114)

            var segments: [MushafPage.Segment] = []
            for surahNumber in start.surah...lastSurahOnPage {
                guard let surah = surahByNumber[surahNumber] else { continue }

                // The ayah window of this surah that lands on this page.
                let lower = (surahNumber == start.surah) ? start.ayah : 1
                let upper: Int   // exclusive
                if let next, surahNumber == next.surah {
                    upper = next.ayah
                } else {
                    upper = (surah.ayahs.last?.number ?? 0) + 1
                }
                guard lower < upper else { continue }   // surah doesn't reach this page

                let ayahs = surah.ayahs.filter { $0.number >= lower && $0.number < upper }
                guard !ayahs.isEmpty else { continue }

                // A run that opens at ayah 1 means the surah begins here.
                if lower == 1 {
                    segments.append(.surahHeader(
                        number: surah.number,
                        arabicName: surah.arabicName,
                        englishName: surah.englishName,
                        showsBismillah: surah.number != 1 && surah.number != 9
                    ))
                }
                segments.append(.ayahRun(surah: surah.number, ayahs: ayahs))
            }

            result.append(MushafPage(page: start.page, segments: segments))
        }
        return result
    }
}
