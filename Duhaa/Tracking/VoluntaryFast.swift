import Foundation

/// A recommended voluntary (Sunnah) fast.
enum VoluntaryFastKind: String, Identifiable, CaseIterable {
    case monday, thursday, whiteDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monday:   return "Monday fast"
        case .thursday: return "Thursday fast"
        case .whiteDay: return "White day fast"
        }
    }

    /// A short, source-grounded reason (kept neutral and gentle).
    var reason: String {
        switch self {
        case .monday, .thursday:
            return "The Prophet ﷺ used to fast on Mondays and Thursdays."
        case .whiteDay:
            return "The white days — the 13th, 14th & 15th of the Hijri month — are a Sunnah to fast."
        }
    }

    var icon: String {
        switch self {
        case .monday, .thursday: return "calendar"
        case .whiteDay:          return "moon.circle"
        }
    }
}

/// One upcoming recommended fast day (it may match more than one reason, e.g. a
/// white day that also falls on a Monday).
struct VoluntaryFastDay: Identifiable {
    let date: Date
    let dayKey: String
    let kinds: [VoluntaryFastKind]
    var id: String { dayKey }

    /// The headline reason to show (white day takes precedence, then weekday).
    var primaryKind: VoluntaryFastKind { kinds.first ?? .monday }
}

/// Works out which days carry a recommended voluntary fast. Mondays and Thursdays
/// come from the Gregorian weekday; the white days (Ayyām al-Bīḍ) come from the
/// offset-adjusted Hijri date via `HijriCalendar`.
enum VoluntaryFast {

    static func kinds(for date: Date, timeZone: TimeZone, hijriOffsetDays: Int) -> [VoluntaryFastKind] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let weekday = cal.component(.weekday, from: date)   // Sunday = 1 … Saturday = 7
        var kinds: [VoluntaryFastKind] = []
        // White day first so it leads the label when it coincides with Mon/Thu.
        if HijriCalendar.isWhiteDay(date, timeZone: timeZone, offsetDays: hijriOffsetDays) {
            kinds.append(.whiteDay)
        }
        if weekday == 2 { kinds.append(.monday) }
        if weekday == 5 { kinds.append(.thursday) }
        return kinds
    }

    static func isRecommended(_ date: Date, timeZone: TimeZone, hijriOffsetDays: Int) -> Bool {
        !kinds(for: date, timeZone: timeZone, hijriOffsetDays: hijriOffsetDays).isEmpty
    }

    /// Recommended fast days within the next `days` calendar days (including today).
    static func upcoming(from start: Date = Date(), days: Int = 14,
                         timeZone: TimeZone, hijriOffsetDays: Int) -> [VoluntaryFastDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let today = cal.startOfDay(for: start)
        var result: [VoluntaryFastDay] = []
        for offset in 0..<max(1, days) {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let kinds = kinds(for: date, timeZone: timeZone, hijriOffsetDays: hijriOffsetDays)
            guard !kinds.isEmpty else { continue }
            result.append(VoluntaryFastDay(date: date,
                                           dayKey: PrayerTracker.dayKey(date, timeZone),
                                           kinds: kinds))
        }
        return result
    }
}
