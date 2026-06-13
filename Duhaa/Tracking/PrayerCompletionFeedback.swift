import Foundation

enum PrayerCompletionFeedback {
    static func shouldPlayPerfectDay(nowPrayed: Bool, prayedCount: Int) -> Bool {
        nowPrayed && prayedCount == Prayer.allCases.count
    }
}
