import XCTest
@testable import Duhaa

final class EssentialsProgressStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.essentials.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeCard(_ id: String, mcq: Bool = false) -> EssentialsCard {
        EssentialsCard(id: id,
                       setID: "fixture",
                       category: .quranBasics,
                       type: mcq ? .multipleChoice : .flashcard,
                       difficulty: .foundations,
                       prompt: "Prompt \(id)",
                       answer: mcq ? "A" : "Answer \(id)",
                       choices: mcq ? ["A", "B", "C", "D"] : nil,
                       correctIndex: mcq ? 0 : nil,
                       reviewStatus: .needsReview,
                       sensitivity: .sharedBasic,
                       learningModes: mcq ? [.flashcards, .learn, .test] : [.flashcards])
    }

    private func makeSet(_ cards: [EssentialsCard]) -> StudySet {
        StudySet(id: "fixture", category: .quranBasics, subtitle: "", displayOrder: 1, cards: cards)
    }

    func testFreshCardIsNew() {
        let store = EssentialsProgressStore(defaults: defaults)
        let p = store.progress(for: "anything")
        XCTAssertEqual(p.mastery, .new)
        XCTAssertEqual(p.timesSeen, 0)
        XCTAssertEqual(p.timesCorrect, 0)
        XCTAssertNil(p.lastReviewedAt)
    }

    func testCorrectAnswerMovesToLearning() {
        let store = EssentialsProgressStore(defaults: defaults)
        let now = Date()
        store.recordAnswer(cardID: "c1", correct: true, at: now)

        let p = store.progress(for: "c1")
        XCTAssertEqual(p.mastery, .learning)
        XCTAssertEqual(p.timesSeen, 1)
        XCTAssertEqual(p.timesCorrect, 1)
        XCTAssertEqual(p.lastReviewedAt, now)
    }

    func testWrongAnswerMovesToReview() {
        let store = EssentialsProgressStore(defaults: defaults)
        store.recordAnswer(cardID: "c1", correct: true)
        store.recordAnswer(cardID: "c1", correct: false)

        let p = store.progress(for: "c1")
        XCTAssertEqual(p.mastery, .review)
        XCTAssertEqual(p.timesSeen, 2)
        XCTAssertEqual(p.timesCorrect, 1)
    }

    func testEnoughCorrectAnswersMaster() {
        let store = EssentialsProgressStore(defaults: defaults)
        for _ in 0..<EssentialsProgressStore.masteryThreshold {
            store.recordAnswer(cardID: "c1", correct: true)
        }
        XCTAssertEqual(store.mastery(of: "c1"), .mastered)
    }

    func testFlashcardStillLearningIsNeverAMiss() {
        let store = EssentialsProgressStore(defaults: defaults)
        store.recordFlashcard(cardID: "c1", knewIt: false)

        let p = store.progress(for: "c1")
        XCTAssertEqual(p.mastery, .learning, "'Still learning' must not mark a miss")
        XCTAssertEqual(p.timesSeen, 1)
        XCTAssertEqual(p.timesCorrect, 0)
    }

    func testFlashcardGotItCountsAsCorrect() {
        let store = EssentialsProgressStore(defaults: defaults)
        store.recordFlashcard(cardID: "c1", knewIt: true)

        let p = store.progress(for: "c1")
        XCTAssertEqual(p.mastery, .learning)
        XCTAssertEqual(p.timesCorrect, 1)
    }

    func testPersistenceRoundtrip() {
        let store = EssentialsProgressStore(defaults: defaults)
        store.recordAnswer(cardID: "c1", correct: true)
        store.recordAnswer(cardID: "c2", correct: false)

        let reloaded = EssentialsProgressStore(defaults: defaults)
        XCTAssertEqual(reloaded.mastery(of: "c1"), .learning)
        XCTAssertEqual(reloaded.mastery(of: "c2"), .review)
        XCTAssertEqual(reloaded.progress(for: "c1"), store.progress(for: "c1"))
    }

    func testSetAggregates() {
        let cards = [makeCard("c1", mcq: true), makeCard("c2", mcq: true), makeCard("c3")]
        let set = makeSet(cards)
        let store = EssentialsProgressStore(defaults: defaults)

        XCTAssertEqual(store.headlineMastery(for: set), .new)
        XCTAssertEqual(store.statusLine(for: set), "Not started yet")

        store.recordAnswer(cardID: "c1", correct: false)
        XCTAssertEqual(store.headlineMastery(for: set), .review)
        XCTAssertEqual(store.dueCards(in: set).map(\.id), ["c1"])
        XCTAssertEqual(store.statusLine(for: set), "1 due for review")

        // Only multiple-choice cards can be replayed as missed questions.
        store.recordFlashcard(cardID: "c3", knewIt: false)
        XCTAssertEqual(store.missedQuestions(across: [set]).map(\.id), ["c1"])

        store.recordAnswer(cardID: "c1", correct: true)
        // c1 recovered and is scheduled for later; c3 ("still learning")
        // remains gently in today's queue until it lands.
        XCTAssertEqual(store.dueCards(in: set).map(\.id), ["c3"])
        XCTAssertEqual(store.headlineMastery(for: set), .review)
        XCTAssertTrue(store.missedQuestions(across: [set]).isEmpty)

        for id in ["c1", "c2", "c3"] {
            for _ in 0..<EssentialsProgressStore.masteryThreshold {
                store.recordAnswer(cardID: id, correct: true)
            }
        }
        XCTAssertEqual(store.masteredCount(in: set), 3)
        XCTAssertEqual(store.headlineMastery(for: set), .mastered)
        XCTAssertEqual(store.statusLine(for: set), "All mastered")
        XCTAssertEqual(store.progressFraction(for: set), 1.0)
    }

    // MARK: Spaced repetition

    func testCorrectAnswersClimbTheSpacingLadder() {
        let store = EssentialsProgressStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let day: TimeInterval = 86_400

        let expectedGaps: [TimeInterval] = [1, 3, 7, 14, 30, 30].map { $0 * day }
        for (index, gap) in expectedGaps.enumerated() {
            let answeredAt = start.addingTimeInterval(Double(index) * day)
            store.recordAnswer(cardID: "c1", correct: true, at: answeredAt)
            let dueAt = store.progress(for: "c1").dueAt
            XCTAssertEqual(dueAt, answeredAt.addingTimeInterval(gap),
                           "streak \(index + 1) should schedule \(gap / day) days out (capped)")
        }
    }

    func testWrongAnswerResetsStreakAndReturnsToTodaysQueue() {
        let store = EssentialsProgressStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        store.recordAnswer(cardID: "c1", correct: true, at: start)
        store.recordAnswer(cardID: "c1", correct: true, at: start)
        store.recordAnswer(cardID: "c1", correct: false, at: start)

        let p = store.progress(for: "c1")
        XCTAssertEqual(p.correctStreak, 0)
        XCTAssertEqual(p.dueAt, start)
        XCTAssertTrue(store.isDue("c1", at: start))

        // Recovering restarts the ladder from the first (1-day) rung.
        store.recordAnswer(cardID: "c1", correct: true, at: start)
        XCTAssertEqual(store.progress(for: "c1").dueAt, start.addingTimeInterval(86_400))
    }

    func testScheduledCardBecomesDueAfterItsInterval() {
        let set = makeSet([makeCard("c1", mcq: true)])
        let store = EssentialsProgressStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        store.recordAnswer(cardID: "c1", correct: true, at: start)

        let beforeDue = start.addingTimeInterval(86_400 - 60)
        let afterDue = start.addingTimeInterval(86_400 + 60)
        XCTAssertFalse(store.isDue("c1", at: beforeDue))
        XCTAssertEqual(store.dueCount(across: [set], at: beforeDue), 0)
        XCTAssertTrue(store.isDue("c1", at: afterDue))
        XCTAssertEqual(store.dueCards(in: set, at: afterDue).map(\.id), ["c1"])
        XCTAssertEqual(store.headlineMastery(for: set, at: afterDue), .review)
    }

    func testMasteredSetComesBackAsARefreshNeverAMiss() {
        let set = makeSet([makeCard("c1", mcq: true)])
        let store = EssentialsProgressStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        for _ in 0..<EssentialsProgressStore.masteryThreshold {
            store.recordAnswer(cardID: "c1", correct: true, at: start)
        }
        XCTAssertEqual(store.mastery(of: "c1"), .mastered)

        // Streak 3 → 7 days out. Eight days on, it's back as a gentle refresh.
        let eightDaysOn = start.addingTimeInterval(8 * 86_400)
        XCTAssertEqual(store.statusLine(for: set, at: eightDaysOn), "1 ready for a refresh")
        XCTAssertEqual(store.headlineMastery(for: set, at: eightDaysOn), .review)
        XCTAssertEqual(store.reviewQueue(across: [set], at: eightDaysOn).map(\.id), ["c1"])
        XCTAssertTrue(store.missedQuestions(across: [set]).isEmpty,
                      "a scheduled refresh must never read as a miss")
    }

    func testStillLearningFlashcardStaysInQueueWithoutBeingAMiss() {
        let set = makeSet([makeCard("c1")])
        let store = EssentialsProgressStore(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        store.recordFlashcard(cardID: "c1", knewIt: false, at: now)

        XCTAssertTrue(store.isDue("c1", at: now))
        XCTAssertEqual(store.dueCards(in: set, at: now).map(\.id), ["c1"])
        XCTAssertTrue(store.missedQuestions(across: [set]).isEmpty)
        XCTAssertEqual(store.mastery(of: "c1"), .learning)
        XCTAssertEqual(store.reviewQueue(across: [set], at: now).map(\.id), ["c1"])
    }

    func testNextScheduledReviewFindsTheEarliestFutureDate() {
        let set = makeSet([makeCard("c1", mcq: true), makeCard("c2", mcq: true)])
        let store = EssentialsProgressStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertNil(store.nextScheduledReview(across: [set], at: start))

        store.recordAnswer(cardID: "c1", correct: true, at: start) // due +1d
        store.recordAnswer(cardID: "c2", correct: true, at: start)
        store.recordAnswer(cardID: "c2", correct: true, at: start) // due +3d

        XCTAssertEqual(store.nextScheduledReview(across: [set], at: start),
                       start.addingTimeInterval(86_400))
    }

    func testProgressSavedBeforeSpacedRepetitionStillDecodes() throws {
        // The exact on-disk shape written before the streak/due fields existed.
        let legacyJSON = """
        {"c1":{"mastery":"mastered","timesSeen":4,"timesCorrect":3},
         "c2":{"mastery":"review","timesSeen":1,"timesCorrect":0}}
        """
        defaults.set(Data(legacyJSON.utf8), forKey: EssentialsProgressStore.storageKey)

        let store = EssentialsProgressStore(defaults: defaults)
        XCTAssertEqual(store.mastery(of: "c1"), .mastered)
        XCTAssertEqual(store.mastery(of: "c2"), .review)
        XCTAssertEqual(store.progress(for: "c1").correctStreak, 0)
        XCTAssertNil(store.progress(for: "c1").dueAt)
        // Legacy mastered cards aren't due (no schedule yet); missed ones are.
        XCTAssertFalse(store.isDue("c1"))
        XCTAssertTrue(store.isDue("c2"))
    }
}
