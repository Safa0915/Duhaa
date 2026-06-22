import XCTest
@testable import Duhaa

final class FeedbackStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var now: Date!

    override func setUp() {
        super.setUp()
        suiteName = "feedback.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        now = Date(timeIntervalSince1970: 1_800_000_000)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        now = nil
        super.tearDown()
    }

    func testSecondAppOpenPresentsPrompt() {
        let store = makeStore()

        store.recordAppOpen()
        XCTAssertNil(store.presentation)

        store.recordAppOpen()
        XCTAssertEqual(store.presentation, .prompt(.appOpen))
    }

    func testDismissedPromptDoesNotImmediatelyReappearDuringCooldown() {
        let store = makeStore(cooldown: 1_000)

        store.recordAppOpen()
        store.recordAppOpen()
        XCTAssertEqual(store.presentation, .prompt(.appOpen))

        store.dismissPrompt()
        store.recordMeaningfulAction(.prayerMarked)
        store.recordMeaningfulAction(.prayerMarked)
        store.recordMeaningfulAction(.prayerMarked)

        XCTAssertNil(store.presentation)
    }

    func testDisableAutomaticPromptsPersistsAndSuppressesFuturePrompts() {
        let store = makeStore()

        store.disableAutomaticPrompts()
        store.recordAppOpen()
        store.recordAppOpen()

        XCTAssertNil(store.presentation)
        XCTAssertFalse(store.automaticPromptsEnabled)

        let reloaded = makeStore()
        XCTAssertFalse(reloaded.automaticPromptsEnabled)
    }

    func testManualComposerStillWorksWhenAutomaticPromptsAreDisabled() {
        let store = makeStore()

        store.disableAutomaticPrompts()
        store.presentComposer(reason: .manual)

        XCTAssertEqual(store.presentation, .composer(.manual))
    }

    func testPrayerMarkedThresholdPresentsPrompt() {
        let store = makeStore()

        store.recordMeaningfulAction(.prayerMarked)
        store.recordMeaningfulAction(.prayerMarked)
        XCTAssertNil(store.presentation)

        store.recordMeaningfulAction(.prayerMarked)
        XCTAssertEqual(store.presentation, .prompt(.prayerMarked))
    }

    func testPromptLimitPreventsPromptSpam() {
        let store = makeStore(cooldown: 0, maxPrompts: 1)

        store.recordAppOpen()
        store.recordAppOpen()
        XCTAssertEqual(store.presentation, .prompt(.appOpen))

        store.dismissPrompt()
        store.recordMeaningfulAction(.quranRead)
        store.recordMeaningfulAction(.quranRead)
        store.recordMeaningfulAction(.quranRead)

        XCTAssertNil(store.presentation)
    }

    private func makeStore(cooldown: TimeInterval = 0,
                           maxPrompts: Int = 4) -> FeedbackStore {
        FeedbackStore(defaults: defaults,
                      now: { self.now },
                      promptCooldown: cooldown,
                      maxAutomaticPrompts: maxPrompts)
    }
}
