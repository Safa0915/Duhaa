import Foundation
import UserNotifications

extension DuhaPrayerTimes {
    /// The instant for a given daily prayer.
    func time(for prayer: Prayer) -> Date {
        switch prayer {
        case .fajr:    return fajr
        case .dhuhr:   return dhuhr
        case .asr:     return asr
        case .maghrib: return maghrib
        case .isha:    return isha
        }
    }
}

/// Schedules prayer notifications using the spec's rolling-window pattern (§8):
/// iOS only keeps ~64 pending local notifications and prayer times change daily,
/// so we pre-schedule a window of upcoming days and **re-fill on every app open**.
/// Each trigger carries the location's IANA time zone, so it's DST-correct.
enum NotificationScheduler {
    private static let center = UNUserNotificationCenter.current()
    /// Stay under iOS's ~64 cap with headroom.
    private static let maxPending = 60
    private static let maxDays = 12

    /// Ask for notification permission (first launch shows the system prompt).
    static func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Wipe and rebuild the pending window from current location + settings.
    /// Safe to call on every app open; snapshots inputs before going async.
    static func reschedule(location: ActiveLocation, config: PrayerConfig, notifs: NotificationSettings) {
        let modeMap = Dictionary(uniqueKeysWithValues: Prayer.allCases.map { ($0, notifs.mode(for: $0)) })
        let reminderOn = notifs.preReminderEnabled
        let reminderMin = notifs.preReminderMinutes
        Task {
            await rebuild(location: location, config: config,
                          modeMap: modeMap, reminderOn: reminderOn, reminderMin: reminderMin)
        }
    }

    private static func rebuild(location: ActiveLocation, config: PrayerConfig,
                                modeMap: [Prayer: PrayerNotificationMode],
                                reminderOn: Bool, reminderMin: Int) async {
        let settings = await center.notificationSettings()
        let allowed = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        center.removeAllPendingNotificationRequests()
        guard allowed else { return }

        let enabled = Prayer.allCases.filter { (modeMap[$0] ?? .adhan) != .off }
        guard !enabled.isEmpty else { return }

        // Fit the window inside the budget: more prayers/reminders → fewer days.
        let perDay = enabled.count * (reminderOn ? 2 : 1)
        let days = max(1, min(maxDays, maxPending / max(perDay, 1)))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        let now = Date()
        var scheduled = 0

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let dayComps = calendar.dateComponents([.year, .month, .day], from: day)
            guard let times = PrayerEngine.times(latitude: location.latitude,
                                                 longitude: location.longitude,
                                                 date: dayComps, config: config) else { continue }

            for prayer in enabled {
                let mode = modeMap[prayer] ?? .adhan
                let fire = times.time(for: prayer)
                if fire > now,
                   let request = makeRequest(prayer: prayer, fire: fire, tz: location.timeZone,
                                             mode: mode, isReminder: false, lead: 0) {
                    try? await center.add(request); scheduled += 1
                }
                if reminderOn {
                    let reminderFire = fire.addingTimeInterval(-Double(reminderMin) * 60)
                    if reminderFire > now,
                       let request = makeRequest(prayer: prayer, fire: reminderFire, tz: location.timeZone,
                                                 mode: mode, isReminder: true, lead: reminderMin) {
                        try? await center.add(request); scheduled += 1
                    }
                }
            }
        }

        #if DEBUG
        print("🔔 Duha scheduled \(scheduled) notifications across \(days) day(s) for \(location.name)")
        #endif
    }

    private static func makeRequest(prayer: Prayer, fire: Date, tz: TimeZone,
                                    mode: PrayerNotificationMode, isReminder: Bool, lead: Int) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        if isReminder {
            content.title = "\(prayer.rawValue) soon"
            content.body = "\(prayer.rawValue) is in \(lead) minutes."
        } else {
            content.title = prayer.rawValue
            content.body = "It's time to pray \(prayer.rawValue)."
        }

        switch mode {
        case .adhan:  content.sound = .default // TODO (audio drop-in): bundled Makkah/Madinah adhan .caf
        case .silent: content.sound = nil
        case .off:    return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
        comps.timeZone = tz // keep it correct across DST and manual cities in other zones
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let kind = isReminder ? "reminder." : ""
        let id = "duha.\(kind)\(prayer.rawValue).\(Int(fire.timeIntervalSince1970))"
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
