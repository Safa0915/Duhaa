import Foundation

/// Gentle, hope-not-guilt messages (spec §5). Shown briefly after marking a
/// prayer, and as a warm welcome when returning after a gap. Never boastful,
/// never shaming — Duhaa is built on Ad-Duhaa: "your Lord has not forsaken you."
enum Encouragements {

    /// A short reassurance shown after marking a prayer as prayed.
    static let afterPrayer: [String] = [
        "“Your Lord has not forsaken you, nor does He despise you.” — Ad-Duhaa",
        "Allah is with those who are patient.",
        "A light added to your day.",
        "Every prayer is a turning toward the dawn.",
        "Indeed, with hardship comes ease.",
        "He is nearer to you than your jugular vein.",
        "One step closer to the morning brightness.",
    ]

    /// A warm welcome for someone returning after time away — no scolding.
    static let welcomeBack: [String] = [
        "Welcome back. Your Lord has not forsaken you.",
        "However long it's been, the door was always open.",
        "Returning is its own kind of worship. Welcome back.",
        "No scolding here — only: welcome home.",
    ]

    static func afterPrayerMessage() -> String { afterPrayer.randomElement() ?? afterPrayer[0] }
    static func welcomeBackMessage() -> String { welcomeBack.randomElement() ?? welcomeBack[0] }
}
