import Foundation
import Observation

/// How a given prayer notifies. Per-prayer control (spec §8).
enum PrayerNotificationMode: String, CaseIterable, Identifiable {
    case adhan   // plays a sound
    case silent  // banner only, no sound
    case off     // no notification

    var id: String { rawValue }
    var label: String {
        switch self {
        case .adhan:  return "Adhan"
        case .silent: return "Silent"
        case .off:    return "Off"
        }
    }
}

/// Per-prayer notification preferences + optional pre-prayer reminders.
/// Persisted to UserDefaults and shared via the environment. Changing anything
/// reschedules the rolling notification window.
@Observable
final class NotificationSettings {
    /// Per-prayer mode, keyed by `Prayer.rawValue`. Default: every prayer = adhan.
    private var modes: [String: PrayerNotificationMode]

    /// Optional reminder before each prayer — OFF by default (protects the
    /// ~64 pending-notification budget, spec §8).
    var preReminderEnabled: Bool { didSet { persist() } }
    var preReminderMinutes: Int { didSet { persist() } }

    /// A special Friday Jumu'ah reminder (a morning prep nudge + Jumu'ah-flavoured
    /// midday notification). On by default.
    var jumuahReminder: Bool { didSet { persist() } }

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        if let data = UserDefaults.standard.data(forKey: Key.modes),
           let raw = try? JSONDecoder().decode([String: String].self, from: data) {
            modes = raw.reduce(into: [:]) { $0[$1.key] = PrayerNotificationMode(rawValue: $1.value) }
        } else {
            modes = [:]
        }
        preReminderEnabled = UserDefaults.standard.bool(forKey: Key.reminderOn)
        let savedMinutes = UserDefaults.standard.integer(forKey: Key.reminderMinutes)
        preReminderMinutes = savedMinutes == 0 ? 15 : savedMinutes
        // Default ON: an absent key reads as true.
        jumuahReminder = UserDefaults.standard.object(forKey: Key.jumuah) as? Bool ?? true
    }

    func mode(for prayer: Prayer) -> PrayerNotificationMode {
        modes[prayer.rawValue] ?? .adhan
    }

    func setMode(_ mode: PrayerNotificationMode, for prayer: Prayer) {
        modes[prayer.rawValue] = mode
        persist()
    }

    private func persist() {
        let raw = modes.reduce(into: [String: String]()) { $0[$1.key] = $1.value.rawValue }
        if let data = try? JSONEncoder().encode(raw) { defaults.set(data, forKey: Key.modes) }
        defaults.set(preReminderEnabled, forKey: Key.reminderOn)
        defaults.set(preReminderMinutes, forKey: Key.reminderMinutes)
        defaults.set(jumuahReminder, forKey: Key.jumuah)
    }

    private enum Key {
        static let modes = "duhaa.notif.modes"
        static let jumuah = "duhaa.notif.jumuah"
        static let reminderOn = "duhaa.notif.reminderOn"
        static let reminderMinutes = "duhaa.notif.reminderMinutes"
    }
}
