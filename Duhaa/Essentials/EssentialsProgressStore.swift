import Foundation
import Observation

// MARK: - Per-card progress

/// User progress for one card, keyed by the card's id. Kept apart from the
/// bundled content so the question bank stays read-only.
struct CardProgress: Codable, Equatable {
    var mastery: MasteryState = .new
    var timesSeen = 0
    var timesCorrect = 0
    var lastReviewedAt: Date?
}

// MARK: - Store

/// Local progress for Islamic Essentials. Persists to UserDefaults under
/// `duhaa.essentials.progress` (the PrayerTracker pattern; `init(defaults:)`
/// keeps tests isolated).
///
/// The mastery rules are deliberately simple counters — not spaced repetition:
///   • a wrong answer puts the card in `.review` (it's "due")
///   • a correct answer moves it to `.learning`
///   • `masteryThreshold` lifetime corrects settle it as `.mastered`
@Observable
final class EssentialsProgressStore {
    static let masteryThreshold = 3
    private static let key = "duhaa.essentials.progress"

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var byCard: [String: CardProgress]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String: CardProgress].self, from: data) {
            byCard = decoded
        } else {
            byCard = [:]
        }
    }

    // MARK: Reading

    func progress(for cardID: String) -> CardProgress {
        byCard[cardID] ?? CardProgress()
    }

    func mastery(of cardID: String) -> MasteryState {
        progress(for: cardID).mastery
    }

    // MARK: Recording

    func recordAnswer(cardID: String, correct: Bool, at date: Date = Date()) {
        var p = progress(for: cardID)
        p.timesSeen += 1
        if correct { p.timesCorrect += 1 }
        p.lastReviewedAt = date
        p.mastery = correct
            ? (p.timesCorrect >= Self.masteryThreshold ? .mastered : .learning)
            : .review
        byCard[cardID] = p
        save()
    }

    /// Flashcards: "Got it" counts like a correct answer; "Still learning"
    /// marks the card seen and keeps it gently in `.learning` — never a "miss".
    func recordFlashcard(cardID: String, knewIt: Bool, at date: Date = Date()) {
        if knewIt {
            recordAnswer(cardID: cardID, correct: true, at: date)
            return
        }
        var p = progress(for: cardID)
        p.timesSeen += 1
        p.lastReviewedAt = date
        if p.mastery == .new { p.mastery = .learning }
        byCard[cardID] = p
        save()
    }

    // MARK: Aggregates

    func masteredCount(in set: StudySet) -> Int {
        set.cards.filter { mastery(of: $0.id) == .mastered }.count
    }

    /// Cards due for review (answered wrong at some point, not yet recovered).
    func dueCards(in set: StudySet) -> [EssentialsCard] {
        set.cards.filter { mastery(of: $0.id) == .review }
    }

    func dueCount(across sets: [StudySet]) -> Int {
        sets.reduce(0) { $0 + dueCards(in: $1).count }
    }

    /// The missed questions the Review Missed quiz can actually replay.
    func missedQuestions(across sets: [StudySet]) -> [EssentialsCard] {
        sets.flatMap { dueCards(in: $0) }.filter(\.isMultipleChoice)
    }

    func progressFraction(for set: StudySet) -> Double {
        set.cards.isEmpty ? 0 : Double(masteredCount(in: set)) / Double(set.cards.count)
    }

    /// The single most useful state to surface on a set card.
    func headlineMastery(for set: StudySet) -> MasteryState {
        guard !set.cards.isEmpty else { return .new }
        if masteredCount(in: set) == set.cards.count { return .mastered }
        if !dueCards(in: set).isEmpty { return .review }
        if set.cards.contains(where: { mastery(of: $0.id) != .new }) { return .learning }
        return .new
    }

    /// Calm one-line status for VoiceOver and set cards.
    func statusLine(for set: StudySet) -> String {
        switch headlineMastery(for: set) {
        case .mastered: "All mastered"
        case .review: "\(dueCards(in: set).count) due for review"
        case .learning: "In progress"
        case .new: "Not started yet"
        }
    }

    func summaries(for sets: [StudySet]) -> [ReviewSetSummary] {
        sets.map { set in
            ReviewSetSummary(id: set.id,
                             title: set.title,
                             mastered: masteredCount(in: set),
                             total: set.cards.count,
                             status: statusLine(for: set))
        }
    }

    // MARK: Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(byCard) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
