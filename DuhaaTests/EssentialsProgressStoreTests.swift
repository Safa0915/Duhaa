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
        XCTAssertEqual(store.headlineMastery(for: set), .learning)
        XCTAssertEqual(store.dueCount(across: [set]), 0)

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
}
