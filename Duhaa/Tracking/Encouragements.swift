import Foundation

/// Gentle, hope-not-guilt messages (spec §5). Shown briefly after marking a
/// prayer, and as a warm welcome when returning after a gap. Never boastful,
/// never shaming — Duhaa is built on Ad-Duhaa: "your Lord has not forsaken you."
enum Encouragements {

    /// A short reassurance shown after marking a prayer as prayed.
    /// Scriptural lines paraphrase Ad-Duhaa / Ash-Sharh — translators should
    /// prefer an established rendering; pending scholar review like the rest.
    static let afterPrayer: [String] = [
        String(localized: "“Your Lord has not forsaken you, nor does He despise you.” — Ad-Duhaa"),
        String(localized: "Allah is with those who are patient."),
        String(localized: "A light added to your day."),
        String(localized: "Every prayer is a turning toward the dawn."),
        String(localized: "Indeed, with hardship comes ease."),
        String(localized: "He is nearer to you than your jugular vein."),
        String(localized: "One step closer to the morning brightness."),
    ]

    /// A warm welcome for someone returning after time away — no scolding.
    static let welcomeBack: [String] = [
        String(localized: "Welcome back. Your Lord has not forsaken you."),
        String(localized: "However long it's been, the door was always open."),
        String(localized: "Returning is its own kind of worship. Welcome back."),
        String(localized: "No scolding here — only: welcome home."),
    ]

    static func afterPrayerMessage() -> String { afterPrayer.randomElement() ?? afterPrayer[0] }
    static func welcomeBackMessage() -> String { welcomeBack.randomElement() ?? welcomeBack[0] }
}
