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
    /// Consecutive correct answers — drives the spacing ladder.
    var correctStreak = 0
    /// When this card next comes back to the review queue; nil until studied.
    var dueAt: Date?

    init() {}

    // Progress saved before spaced repetition existed has no streak/due
    // fields — decode those leniently so nobody loses their history.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mastery = try container.decodeIfPresent(MasteryState.self, forKey: .mastery) ?? .new
        timesSeen = try container.decodeIfPresent(Int.self, forKey: .timesSeen) ?? 0
        timesCorrect = try container.decodeIfPresent(Int.self, forKey: .timesCorrect) ?? 0
        lastReviewedAt = try container.decodeIfPresent(Date.self, forKey: .lastReviewedAt)
        correctStreak = try container.decodeIfPresent(Int.self, forKey: .correctStreak) ?? 0
        dueAt = try container.decodeIfPresent(Date.self, forKey: .dueAt)
    }
}

// MARK: - Store

/// Local progress for Islamic Essentials. Persists to UserDefaults under
/// `duhaa.essentials.progress` (the PrayerTracker pattern; `init(defaults:)`
/// keeps tests isolated).
///
/// Mastery stays the simple, hopeful model:
///   • a wrong answer puts the card in `.review` (it's "due")
///   • a correct answer moves it to `.learning`
///   • `masteryThreshold` lifetime corrects settle it as `.mastered`
///
/// On top of that sits gentle spaced repetition: every correct answer
/// schedules the card further out (1 → 3 → 7 → 14 → 30 days), a wrong answer
/// brings it back into today's queue, and even mastered cards return for an
/// occasional refresh — framed as "ready for a refresh", never as a failure.
@Observable
final class EssentialsProgressStore {
    static let masteryThreshold = 3
    static let storageKey = "duhaa.essentials.progress"

    /// The spacing ladder: days until the next revisit, by consecutive-correct
    /// streak. Deliberately gentle and capped — no runaway multi-month gaps.
    static let reviewIntervalDays: [Double] = [1, 3, 7, 14, 30]

    static func reviewInterval(forStreak streak: Int) -> TimeInterval {
        let index = max(0, min(streak - 1, reviewIntervalDays.count - 1))
        return reviewIntervalDays[index] * 86_400
    }

    @ObservationIgnored private let defaults: UserDefaults
    private(set) var byCard: [String: CardProgress]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
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

    /// A card is due when it was missed (including pre-schedule saved data)
    /// or its scheduled revisit time has arrived.
    func isDue(_ cardID: String, at date: Date = Date()) -> Bool {
        let p = progress(for: cardID)
        if p.mastery == .review { return true }
        if let dueAt = p.dueAt { return dueAt <= date }
        return false
    }

    // MARK: Recording

    func recordAnswer(cardID: String, correct: Bool, at date: Date = Date()) {
        var p = progress(for: cardID)
        p.timesSeen += 1
        p.lastReviewedAt = date
        if correct {
            p.timesCorrect += 1
            p.correctStreak += 1
            p.dueAt = date.addingTimeInterval(Self.reviewInterval(forStreak: p.correctStreak))
            p.mastery = p.timesCorrect >= Self.masteryThreshold ? .mastered : .learning
        } else {
            p.correctStreak = 0
            p.dueAt = date // gently back into today's queue
            p.mastery = .review
        }
        byCard[cardID] = p
        save()
    }

    /// Flashcards: "Got it" counts like a correct answer; "Still learning"
    /// marks the card seen and keeps it gently in `.learning` — never a "miss",
    /// but it stays in today's queue until it lands.
    func recordFlashcard(cardID: String, knewIt: Bool, at date: Date = Date()) {
        if knewIt {
            recordAnswer(cardID: cardID, correct: true, at: date)
            return
        }
        var p = progress(for: cardID)
        p.timesSeen += 1
        p.lastReviewedAt = date
        p.correctStreak = 0
        p.dueAt = date
        if p.mastery == .new { p.mastery = .learning }
        byCard[cardID] = p
        save()
    }

    // MARK: Aggregates

    func masteredCount(in set: StudySet) -> Int {
        set.cards.filter { mastery(of: $0.id) == .mastered }.count
    }

    /// Cards in the review queue right now — missed ones plus scheduled revisits.
    func dueCards(in set: StudySet, at date: Date = Date()) -> [EssentialsCard] {
        set.cards.filter { isDue($0.id, at: date) }
    }

    func dueCount(across sets: [StudySet], at date: Date = Date()) -> Int {
        sets.reduce(0) { $0 + dueCards(in: $1, at: date).count }
    }

    /// Questions answered wrong and not yet recovered — kept apart from
    /// scheduled revisits so "missed" copy stays truthful.
    func missedQuestions(across sets: [StudySet]) -> [EssentialsCard] {
        sets.flatMap { set in
            set.cards.filter { mastery(of: $0.id) == .review }
        }
        .filter(\.isMultipleChoice)
    }

    /// Today's playable review session: every due card,
    /// missed and scheduled alike.
    func reviewQueue(across sets: [StudySet], at date: Date = Date()) -> [EssentialsCard] {
        sets.flatMap { dueCards(in: $0, at: date) }
    }

    /// The next moment a card comes back to the queue (nil when nothing is
    /// scheduled ahead) — lets the home card say "next review tomorrow".
    func nextScheduledReview(across sets: [StudySet], at date: Date = Date()) -> Date? {
        sets.flatMap(\.cards)
            .compactMap { byCard[$0.id]?.dueAt }
            .filter { $0 > date }
            .min()
    }

    func progressFraction(for set: StudySet) -> Double {
        set.cards.isEmpty ? 0 : Double(masteredCount(in: set)) / Double(set.cards.count)
    }

    /// The single most useful state to surface on a set card. Anything due —
    /// missed or a scheduled refresh — outranks the settled states.
    func headlineMastery(for set: StudySet, at date: Date = Date()) -> MasteryState {
        guard !set.cards.isEmpty else { return .new }
        if !dueCards(in: set, at: date).isEmpty { return .review }
        if masteredCount(in: set) == set.cards.count { return .mastered }
        if set.cards.contains(where: { mastery(of: $0.id) != .new }) { return .learning }
        return .new
    }

    /// Calm one-line status for VoiceOver and set cards.
    func statusLine(for set: StudySet, at date: Date = Date()) -> String {
        switch headlineMastery(for: set, at: date) {
        case .mastered: "All mastered"
        case .review:
            // A fully-mastered set coming back on schedule is a refresh,
            // not something the user got wrong.
            masteredCount(in: set) == set.cards.count
                ? "\(dueCards(in: set, at: date).count) ready for a refresh"
                : "\(dueCards(in: set, at: date).count) due for review"
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
        defaults.set(data, forKey: Self.storageKey)
    }
}
