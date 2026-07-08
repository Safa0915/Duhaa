import Foundation

enum QuranWordTrace {
    static func words(in rawArabic: String) -> [String] {
        let layout = wordRanges(in: rawArabic)
        return layout.ranges.map { String(layout.display[$0]) }
    }

    /// The display string (what gets rendered) together with the character range of
    /// each content word within it. Standalone pause/sajdah-mark tokens are skipped,
    /// so a range's position lines up with the word-by-word segment indices — this
    /// lets the Listen player highlight the active word *inside one shaped run*
    /// (by coloring its range) instead of splitting the ayah into separate views,
    /// which corrupts Uthmani letter-joining.
    ///
    /// The returned `ranges` are only valid against the returned `display` string —
    /// always render that exact string, never a freshly-derived copy.
    static func wordRanges(in rawArabic: String) -> (display: String, ranges: [Range<String.Index>]) {
        let display = QuranArabicText.display(rawArabic)
        var ranges: [Range<String.Index>] = []
        var index = display.startIndex
        while index < display.endIndex {
            if display[index].isWhitespace {
                index = display.index(after: index)
                continue
            }
            let start = index
            while index < display.endIndex, !display[index].isWhitespace {
                index = display.index(after: index)
            }
            let range = start..<index
            if containsLetter(String(display[range])) {
                ranges.append(range)
            }
        }
        return (display, ranges)
    }

    static func activeWordIndex(progress: Double, wordCount: Int) -> Int? {
        guard wordCount > 0 else { return nil }
        let clamped = max(0, min(1, progress))
        if clamped >= 1 { return wordCount - 1 }
        return min(wordCount - 1, Int((clamped * Double(wordCount)).rounded(.down)))
    }

    private static func containsLetter(_ token: String) -> Bool {
        token.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
                return true
            default:
                return false
            }
        }
    }
}
