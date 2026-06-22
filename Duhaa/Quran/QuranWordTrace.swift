import Foundation

enum QuranWordTrace {
    static func words(in rawArabic: String) -> [String] {
        let tokens = QuranArabicText.display(rawArabic)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        return tokens.reduce(into: [String]()) { words, token in
            if containsLetter(token) {
                words.append(token)
            }
        }
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
