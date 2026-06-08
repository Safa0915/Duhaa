import Foundation

/// Warm, hopeful notification text (spec §5, §8). Every prayer gets an emoji and
/// a gently rotating line — an invitation toward the dawn, never a command or a
/// guilt-trip. Picked at schedule time, so the wording varies day to day.
enum NotificationCopy {

    /// The custom bundled chime (a soft celestial bell). Falls back to the system
    /// sound automatically if the file isn't found.
    static let soundFileName = "duhaa-chime.wav"

    static func emoji(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr:    "🌅"
        case .dhuhr:   "☀️"
        case .asr:     "🌇"
        case .maghrib: "🌆"
        case .isha:    "🌙"
        }
    }

    /// Title for an "it's time" notification, e.g. "🌅 Fajr".
    static func title(for prayer: Prayer) -> String {
        "\(emoji(for: prayer)) \(prayer.rawValue)"
    }

    /// Body for an "it's time" notification — prayer-flavoured where it's lovely,
    /// otherwise a gentle general line.
    static func body(for prayer: Prayer) -> String {
        let specific = flavour[prayer] ?? []
        let pool = specific + general
        return pool.randomElement() ?? "It's time for \(prayer.rawValue). 🤍"
    }

    /// Title + body for a pre-prayer heads-up.
    static func reminderTitle(for prayer: Prayer) -> String {
        "\(emoji(for: prayer)) \(prayer.rawValue) soon"
    }

    static func reminderBody(for prayer: Prayer, minutes: Int) -> String {
        let pool = [
            "\(prayer.rawValue) is in about \(minutes) minutes — a gentle heads-up. 🤍",
            "Almost time for \(prayer.rawValue). Find a quiet moment in \(minutes).",
            "\(prayer.rawValue) in \(minutes) min. No rush — just a soft reminder.",
            "A little while until \(prayer.rawValue). Let your heart get ready.",
        ]
        return pool.randomElement() ?? pool[0]
    }

    // MARK: Jumu'ah (Friday)

    static let jumuahTitle = "🕌 Jumu'ah Mubarak"

    static func jumuahBody() -> String {
        let pool = [
            "It's time for Jumu'ah. May your Friday be full of light.",
            "The best day the sun rises upon is Friday. Time for Jumu'ah. 🤍",
            "Jumu'ah has come — gather, listen, and pray. Mubarak.",
        ]
        return pool.randomElement() ?? pool[0]
    }

    static let jumuahPrepTitle = "🕌 It's Friday"

    static func jumuahPrepBody() -> String {
        let pool = [
            "Jumu'ah today. Ghusl, your nicest clothes, a little scent — and Surah Al-Kahf. 🤍",
            "It's Jumu'ah. Don't forget Surah Al-Kahf and plenty of salawat upon the Prophet ﷺ.",
            "A blessed Friday. Make time for Jumu'ah, Al-Kahf, and du'a in its final hour. 🌿",
        ]
        return pool.randomElement() ?? pool[0]
    }

    // MARK: Pools

    private static let general: [String] = [
        "A moment of peace is waiting for you.",
        "Turn toward the One who never forgets you.",
        "Your Lord has not forsaken you. 🤍",
        "Pause, breathe, and pray.",
        "A light to add to your day.",
        "Come as you are — He is near.",
    ]

    private static let flavour: [Prayer: [String]] = [
        .fajr:    ["The morning brightness is here — begin the day with Him. 🌅",
                   "Dawn has come. The hardest one, and the most beloved.",
                   "Whoever prays Fajr is under Allah's protection all day."],
        .dhuhr:   ["A still point in the middle of the day. Time for Dhuhr. ☀️",
                   "Step away from the noise for a moment of Dhuhr."],
        .asr:     ["The light is softening — don't let Asr slip by. 🌇",
                   "Guard the middle prayer. Time for Asr."],
        .maghrib: ["The sun is setting — time for Maghrib. 🌆",
                   "As the day closes, turn to Him for Maghrib."],
        .isha:    ["The night has settled. End your day with Isha. 🌙",
                   "Rest your heart with Isha before you sleep."],
    ]
}
