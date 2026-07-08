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

    func testFeedbackEmailDraftIncludesTriageMetadataAndDiagnostics() {
        let draft = FeedbackEmailDraft.make(
            reason: .quranRead,
            category: .quran,
            message: "Please add a page view.",
            contact: "reader@example.com",
            diagnostics: FeedbackDiagnostics(
                appVersion: "1.0",
                buildNumber: "4",
                device: "iPhone",
                systemName: "iOS",
                systemVersion: "26.5"
            )
        )

        XCTAssertEqual(draft.recipient, "duhaaapp@gmail.com")
        XCTAssertEqual(draft.subject, "Duhaa Feedback [quran] [v1.0 b4]")
        XCTAssertTrue(draft.body.contains("Please add a page view."))
        XCTAssertTrue(draft.body.contains("Type: feedback"))
        XCTAssertTrue(draft.body.contains("Topic: Quran"))
        XCTAssertTrue(draft.body.contains("Area: quran"))
        XCTAssertTrue(draft.body.contains("Reason: quranRead"))
        XCTAssertTrue(draft.body.contains("Contact: reader@example.com"))
        XCTAssertTrue(draft.body.contains("App: 1.0 (4)"))
        XCTAssertTrue(draft.body.contains("Device: iPhone"))
        XCTAssertTrue(draft.body.contains("System: iOS 26.5"))
        XCTAssertTrue(draft.body.contains("Triage: area=quran; severity=untriaged; source=in-app-email"))
        XCTAssertTrue(draft.body.contains("Privacy: No prayer data is attached."))
    }

    func testBugEmailDraftUsesBugSubjectAndNoDiagnosticsMarker() {
        let draft = FeedbackEmailDraft.make(
            reason: .bug,
            category: .bug,
            message: "Notifications did not fire.",
            contact: " ",
            diagnostics: nil
        )

        XCTAssertEqual(draft.subject, "Duhaa Bug Report [bug] [no-diagnostics]")
        XCTAssertTrue(draft.body.contains("Type: bug"))
        XCTAssertTrue(draft.body.contains("Contact: Not provided"))
        XCTAssertTrue(draft.body.contains("Diagnostics: Not included by user"))
    }

    private func makeStore(cooldown: TimeInterval = 0,
                           maxPrompts: Int = 4) -> FeedbackStore {
        FeedbackStore(defaults: defaults,
                      now: { self.now },
                      promptCooldown: cooldown,
                      maxAutomaticPrompts: maxPrompts)
    }
}
