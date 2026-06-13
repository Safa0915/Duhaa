import XCTest
@testable import Duhaa

final class PrayerCompletionFeedbackTests: XCTestCase {
    func testPerfectDayFeedbackOnlyPlaysWhenFifthPrayerIsMarked() {
        XCTAssertFalse(PrayerCompletionFeedback.shouldPlayPerfectDay(nowPrayed: true, prayedCount: 4))
        XCTAssertTrue(PrayerCompletionFeedback.shouldPlayPerfectDay(nowPrayed: true, prayedCount: 5))
        XCTAssertFalse(PrayerCompletionFeedback.shouldPlayPerfectDay(nowPrayed: false, prayedCount: 4))
    }
}
