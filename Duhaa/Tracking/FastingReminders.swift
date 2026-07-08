import Foundation
import UserNotifications

/// Gentle weekly reminders for the Monday & Thursday Sunnah fasts. Self-contained
/// (independent of the prayer-time scheduler): two repeating local notifications
/// the user can switch on from the Fasting screen. If notifications aren't
/// authorized the requests simply never fire — harmless.
enum FastingReminders {
    static let mondayID = "duhaa.fasting.reminder.monday"
    static let thursdayID = "duhaa.fasting.reminder.thursday"

    /// Re-create (or clear) the Monday/Thursday reminders to match `enabled`.
    static func reschedule(enabled: Bool, hour: Int = 7,
                           center: UNUserNotificationCenter = .current()) {
        center.removePendingNotificationRequests(withIdentifiers: [mondayID, thursdayID])
        guard enabled else { return }
        add(id: mondayID, weekday: 2, hour: hour, day: "Monday", center: center)
        add(id: thursdayID, weekday: 5, hour: hour, day: "Thursday", center: center)
    }

    private static func add(id: String, weekday: Int, hour: Int, day: String,
                            center: UNUserNotificationCenter) {
        var comps = DateComponents()
        comps.weekday = weekday    // Sunday = 1 … so Monday = 2, Thursday = 5
        comps.hour = hour
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Sunnah fast today 🌙"
        content.body = "It's \(day) — a beautiful day to fast, if you're able. 🤍"
        content.sound = .default

        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
