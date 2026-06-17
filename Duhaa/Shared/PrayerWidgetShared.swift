import Foundation
import WidgetKit

// MARK: - App Group

/// The single App-Group identifier shared by the app and the widget extension.
///
/// ⚠️ This group is only *truly* shared once the App Groups capability is enabled
/// (with this exact id) on BOTH the app target and the widget target — see
/// `docs/widgets-setup.md`. Until then `UserDefaults(suiteName:)` still returns a
/// working, app-private suite, so the app keeps functioning; the widget simply
/// won't see the same data until the capability is wired up. We never hardcode a
/// Team ID here — the group id is portable across signing identities.
enum DuhaaAppGroup {
    static let identifier = "group.com.duhaa.app"
}

extension UserDefaults {
    /// The shared defaults the app and widget both read/write. Resolved once,
    /// lazily and thread-safely. The first access runs the one-time migration of
    /// legacy `.standard` tracker data into the group suite (see `SharedPrayerStore`).
    ///
    /// Falls back to `.standard` only if the suite can't be created at all (a
    /// safety net for unusual local builds) — documented, never silent in prod.
    static let duhaaShared: UserDefaults = {
        guard let suite = UserDefaults(suiteName: DuhaaAppGroup.identifier) else {
            return .standard
        }
        SharedPrayerStore.migrateLegacyData(into: suite)
        return suite
    }()
}

// MARK: - Prayer identity (widget/intent layer)

/// Stable, lowercase identifiers for the five daily prayers — the IDs used by the
/// widget snapshot, the App Intents, and the shared store's public API.
///
/// Deliberately distinct from the app's `Prayer` enum (whose raw values are the
/// capitalized *display* names, "Fajr"…). `trackerKey` bridges back to that
/// storage format so the widget and the app share the exact same persisted set —
/// no display name is ever used as a storage key.
enum PrayerID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case fajr, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    /// Display name shown in the widget UI.
    var displayName: String {
        switch self {
        case .fajr:    return "Fajr"
        case .dhuhr:   return "Dhuhr"
        case .asr:     return "Asr"
        case .maghrib: return "Maghrib"
        case .isha:    return "Isha"
        }
    }

    /// The key this prayer is stored under in the shared completion set. Matches
    /// the app's `Prayer.rawValue` exactly so both processes agree on storage.
    var trackerKey: String { displayName }

    /// Fixed order Fajr → Isha.
    var order: Int {
        switch self {
        case .fajr: return 0
        case .dhuhr: return 1
        case .asr: return 2
        case .maghrib: return 3
        case .isha: return 4
        }
    }

    var sfSymbol: String {
        switch self {
        case .fajr:    return "sunrise"
        case .dhuhr:   return "sun.max"
        case .asr:     return "sun.min"
        case .maghrib: return "sunset"
        case .isha:    return "moon.stars"
        }
    }

    /// Two-letter abbreviation for the tight circular accessory widgets.
    var abbreviation: String {
        switch self {
        case .fajr:    return "FA"
        case .dhuhr:   return "DH"
        case .asr:     return "AS"
        case .maghrib: return "MG"
        case .isha:    return "IS"
        }
    }

    /// Reverse bridge from the app's stored raw value ("Fajr") to a stable ID.
    init?(trackerKey: String) {
        guard let match = PrayerID.allCases.first(where: { $0.trackerKey == trackerKey })
        else { return nil }
        self = match
    }

    /// The five prayers in canonical order.
    static let ordered: [PrayerID] = allCases.sorted { $0.order < $1.order }
}

// MARK: - Prayer state

/// The five-state prayer model, plus `upcoming`. Built five-ready: `excused` and
/// `madeUp` are real cases, but the app's current persisted data can only ever
/// produce `onTime`, `late`, `missed`, and `upcoming` — `derive` never fabricates
/// the other two. When the app gains real made-up / excused tracking, the widgets
/// light up automatically with no UI change.
///
/// On the Lock Screen (vibrant / near-monochrome) state is read from `monoSymbol`
/// — fill/outline/symbol differences, never color. Home Screen widgets add color
/// on top via `WidgetTheme.color(for:)`.
enum PrayerState: String, Codable, Hashable, Sendable {
    case onTime
    case late
    case missed
    case upcoming
    case excused
    case madeUp

    /// Derive a prayer's state from the data the app actually persists.
    ///
    /// - `prayed`: in the day's marks set.
    /// - `late`: in the day's late subset (only meaningful when `prayed`).
    /// - `windowPassed`: the prayer's window has closed (the next prayer began).
    ///   Nothing is "missed" until its window truly closes — gentle by design.
    /// - `dayExcused`: the whole day is excused (currently always false — the
    ///   cycle feature is parked; the hook stays ready).
    static func derive(prayed: Bool, late: Bool, windowPassed: Bool, dayExcused: Bool = false) -> PrayerState {
        if dayExcused { return .excused }
        if prayed { return late ? .late : .onTime }
        return windowPassed ? .missed : .upcoming
    }

    /// True for any state where the prayer was performed.
    var isPrayed: Bool { self == .onTime || self == .late || self == .madeUp }

    /// SF Symbol that conveys the state by **shape/fill alone** (Lock-Screen safe).
    /// No "x" for a miss — an empty circle is gentle, honoring "hope, not guilt".
    var monoSymbol: String {
        switch self {
        case .onTime:   return "checkmark.circle.fill"
        case .late:     return "checkmark.circle"
        case .madeUp:   return "checkmark.circle.badge.questionmark"
        case .upcoming: return "circle.dashed"
        case .missed:   return "circle"
        case .excused:  return "minus.circle"
        }
    }

    /// A compact glyph for the tight 7×5 weekly grid cells.
    var gridSymbol: String {
        switch self {
        case .onTime:   return "circle.fill"
        case .late:     return "circle.bottomhalf.filled"
        case .madeUp:   return "circle.righthalf.filled"
        case .upcoming: return "circle.dashed"
        case .missed:   return "circle"
        case .excused:  return "minus"
        }
    }

    /// VoiceOver wording.
    var label: String {
        switch self {
        case .onTime:   return "prayed on time"
        case .late:     return "prayed, late"
        case .madeUp:   return "made up"
        case .upcoming: return "not yet"
        case .missed:   return "not prayed"
        case .excused:  return "excused"
        }
    }
}

/// One day's five prayer states, Fajr→Isha, for the weekly grid.
struct PrayerDayStates: Codable, Hashable, Sendable, Identifiable {
    let dayKey: String
    let weekdayLetter: String        // narrow weekday, e.g. "M"
    let isToday: Bool
    let states: [PrayerState]        // exactly 5, Fajr→Isha
    var id: String { dayKey }
}

// MARK: - Day keys (shared, app-compatible)

/// Produces the same "yyyy-MM-dd" day key the app's `PrayerTracker.dayKey` does,
/// without the widget needing to depend on the app-only tracker. Both use a POSIX
/// formatter with the location's time zone, so the strings match to the character.
enum SharedDayKey {
    static func make(_ date: Date, _ timeZone: TimeZone) -> String {
        let f = formatter
        f.timeZone = timeZone
        return f.string(from: date)
    }

    static func isValid(_ key: String) -> Bool {
        guard key.count == 10,
              key[key.index(key.startIndex, offsetBy: 4)] == "-",
              key[key.index(key.startIndex, offsetBy: 7)] == "-",
              let parsed = formatter.date(from: key) else {
            return false
        }
        return formatter.string(from: parsed) == key
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - Widget reload (testable indirection)

/// A tiny seam over `WidgetCenter` so completion writes can reload widget
/// timelines, and tests can observe that a reload was requested without touching
/// the real WidgetKit machinery.
enum WidgetReloader {
    /// Swap in tests to capture reload requests. Defaults to a real timeline reload.
    static var handler: () -> Void = { WidgetCenter.shared.reloadAllTimelines() }

    static func reload() { handler() }

    /// Reload just the prayer widget kinds (used after a completion change).
    static func reloadPrayerWidgets() { handler() }
}
