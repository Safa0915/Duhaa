import SwiftUI

// MARK: - Category

/// The six starter study categories. Title and icon live here so the bundled
/// JSON stays content-only.
enum EssentialsCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case prophets
    case seerah
    case quranBasics = "quran_basics"
    case tawheed
    case prayerBasics = "prayer_basics"
    case allahNames = "allah_names"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prophets: "Prophets"
        case .seerah: "Seerah Basics"
        case .quranBasics: "Qur'an Basics"
        case .tawheed: "Tawheed Basics"
        case .prayerBasics: "Prayer Basics"
        case .allahNames: "Allah's Names"
        }
    }

    var icon: String {
        switch self {
        case .prophets: "person.2"
        case .seerah: "book.closed"
        case .quranBasics: "text.book.closed"
        case .tawheed: "moon.stars"
        case .prayerBasics: "sun.and.horizon"
        case .allahNames: "heart"
        }
    }
}

// MARK: - Difficulty

/// Calm difficulty levels — describes depth, never "easy/hard".
enum EssentialsDifficulty: String, Codable, CaseIterable, Hashable, Sendable {
    case foundations, building, deepening

    var label: String {
        switch self {
        case .foundations: "Foundations"
        case .building: "Building"
        case .deepening: "Deepening"
        }
    }
}

// MARK: - Card type

enum EssentialsCardType: String, Codable, Hashable, Sendable {
    case flashcard
    case multipleChoice = "multiple_choice"
    case namePair = "name_pair"
    case reflection
}

// MARK: - Mastery

/// Calm learning states — deliberately no scores, ranks, or streak pressure.
/// Language stays gentle: knowledge is "settling in", never "failing".
enum MasteryState: String, Codable, CaseIterable, Hashable, Sendable {
    case new, learning, review, mastered

    var label: String {
        switch self {
        case .new: "New"
        case .learning: "Learning"
        case .review: "Review"
        case .mastered: "Mastered"
        }
    }

    var icon: String {
        switch self {
        case .new: "sparkle"
        case .learning: "book"
        case .review: "arrow.clockwise"
        case .mastered: "checkmark.seal"
        }
    }

    // Distinct in every theme: several themes alias softAccent/blue/gold, so
    // "new" stays neutral, "review" rides gold (matching the needs-review chip).
    var tint: Color {
        switch self {
        case .new: Color.primary.opacity(0.55)
        case .learning: Palette.blue
        case .review: Palette.gold
        case .mastered: Palette.success
        }
    }
}

// MARK: - Study modes

enum StudyMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case flashcards, learn, match, test, reviewMissed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flashcards: "Flashcards"
        case .learn: "Learn"
        case .match: "Match"
        case .test: "Test"
        case .reviewMissed: "Review Missed"
        }
    }

    var icon: String {
        switch self {
        case .flashcards: "rectangle.portrait.on.rectangle.portrait"
        case .learn: "lightbulb"
        case .match: "square.grid.2x2"
        case .test: "checklist"
        case .reviewMissed: "arrow.counterclockwise"
        }
    }

    var blurb: String {
        switch self {
        case .flashcards: "Flip through cards at your own pace"
        case .learn: "Multiple choice with gentle explanations"
        case .match: "Pair each term with its meaning"
        case .test: "A short check of what has settled in"
        case .reviewMissed: "Revisit the questions you missed"
        }
    }
}

// MARK: - Source reference

/// Where a card's fact comes from. Never implies scholar verification — the
/// card's `reviewStatus` (Learn's `ReviewStatus`, no "Verified" case) does that
/// bookkeeping.
struct SourceReference: Codable, Hashable, Sendable {
    /// The citation itself, e.g. "Qur'an 33:40".
    let text: String
    /// Optional qualifier, e.g. "General seerah literature".
    var note: String?
}

// MARK: - Card

/// One study item. Content only — user progress (mastery, timesSeen, …) lives
/// in `EssentialsProgressStore`, keyed by this card's `id`.
struct EssentialsCard: Identifiable, Codable, Hashable {
    let id: String
    let setID: String
    let category: EssentialsCategory
    let type: EssentialsCardType
    let difficulty: EssentialsDifficulty
    let prompt: String
    let answer: String
    var arabic: String? = nil
    var choices: [String]? = nil
    var correctIndex: Int? = nil
    var explanation: String? = nil
    var sourceSummary: String? = nil
    var sourceReference: SourceReference? = nil
    let reviewStatus: ReviewStatus
    let sensitivity: MadhhabSensitivity
    let learningModes: [StudyMode]

    /// A card the Learn/Test quiz can actually render.
    var isMultipleChoice: Bool {
        type == .multipleChoice && choices != nil && correctIndex != nil
    }

    func supports(_ mode: StudyMode) -> Bool {
        learningModes.contains(mode)
    }

    /// The single answer-checking rule for every quiz mode.
    func isCorrectChoice(_ index: Int) -> Bool {
        isMultipleChoice && index == correctIndex
    }
}

// MARK: - Study set

struct StudySet: Identifiable, Codable {
    let id: String
    let category: EssentialsCategory
    let subtitle: String
    let displayOrder: Int
    let cards: [EssentialsCard]

    var title: String { category.title }
    var icon: String { category.icon }

    func cards(for mode: StudyMode) -> [EssentialsCard] {
        cards.filter { $0.supports(mode) }
    }

    /// Term/meaning pairs for Match mode (from `name_pair` cards).
    var namePairs: [MatchPair] {
        cards.filter { $0.type == .namePair }
            .map { MatchPair(id: $0.id, name: $0.prompt, meaning: $0.answer) }
    }
}

// MARK: - Match pair

struct MatchPair: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let meaning: String
}

// MARK: - Review summary (Review Missed screen)

struct ReviewSetSummary: Identifiable {
    let id: String
    let title: String
    let mastered: Int
    let total: Int
    let status: String
}

// MARK: - Loader
//
// Mirrors `Learn` (Learn/LearnData.swift): bundled JSON, decoded once, with an
// async accessor available for launch-path callers.

enum Essentials {
    static let sets: [StudySet] = load()

    static func set(id: String) -> StudySet? {
        sets.first { $0.id == id }
    }

    static var allahNames: StudySet? {
        sets.first { $0.category == .allahNames }
    }

    static func loadAsync(priority: TaskPriority = .userInitiated) async -> [StudySet] {
        await Task.detached(priority: priority) {
            sets
        }.value
    }

    /// Meaning-first flashcards (e.g. "The Creator" → "Al-Khaliq"), derived so
    /// the JSON never stores both directions.
    static func meaningFirst(_ cards: [EssentialsCard]) -> [EssentialsCard] {
        cards.map { card in
            EssentialsCard(id: "reverse-\(card.id)",
                           setID: card.setID,
                           category: card.category,
                           type: card.type,
                           difficulty: card.difficulty,
                           prompt: card.answer,
                           answer: card.prompt,
                           arabic: card.arabic,
                           explanation: card.explanation,
                           sourceSummary: card.sourceSummary,
                           sourceReference: card.sourceReference,
                           reviewStatus: card.reviewStatus,
                           sensitivity: card.sensitivity,
                           learningModes: [.flashcards])
        }
    }

    private struct File: Decodable { let sets: [StudySet] }
    private final class BundleToken {}

    private static func load() -> [StudySet] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "essentials_sets", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(File.self, from: data) else {
            return []
        }
        return decoded.sets.sorted { $0.displayOrder < $1.displayOrder }
    }
}
