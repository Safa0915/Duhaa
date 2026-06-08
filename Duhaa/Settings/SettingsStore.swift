import Foundation
import Adhan
import Observation

// MARK: - User-facing choices

/// Calculation methods Duhaa exposes, with display names. Maps to Adhan internally.
enum CalcMethod: String, CaseIterable, Identifiable {
    case muslimWorldLeague, northAmerica, egyptian, ummAlQura, karachi
    case dubai, qatar, kuwait, singapore, tehran, turkey, moonsighting

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muslimWorldLeague: return "Muslim World League"
        case .northAmerica:      return "ISNA (North America)"
        case .egyptian:          return "Egyptian General Authority"
        case .ummAlQura:         return "Umm al-Qura (Makkah)"
        case .karachi:           return "University of Karachi"
        case .dubai:             return "Dubai"
        case .qatar:             return "Qatar"
        case .kuwait:            return "Kuwait"
        case .singapore:         return "Singapore"
        case .tehran:            return "Tehran"
        case .turkey:            return "Turkey (Diyanet)"
        case .moonsighting:      return "Moonsighting Committee"
        }
    }

    var adhan: CalculationMethod {
        switch self {
        case .muslimWorldLeague: return .muslimWorldLeague
        case .northAmerica:      return .northAmerica
        case .egyptian:          return .egyptian
        case .ummAlQura:         return .ummAlQura
        case .karachi:           return .karachi
        case .dubai:             return .dubai
        case .qatar:             return .qatar
        case .kuwait:            return .kuwait
        case .singapore:         return .singapore
        case .tehran:            return .tehran
        case .turkey:            return .turkey
        case .moonsighting:      return .moonsightingCommittee
        }
    }
}

/// Asr shadow rule, in the spec's own labels (§4).
enum AsrMadhab: String, CaseIterable, Identifiable {
    case standard, hanafi

    var id: String { rawValue }
    var label: String { self == .hanafi ? "Hanafi" : "Shafi'i, Hanbali, Maliki" }
    var adhanMadhab: Madhab { self == .hanafi ? .hanafi : .shafi }
}

// MARK: - Store

/// The single, persisted source of settings. Created once at app launch and
/// shared via the environment; every change is written to UserDefaults (the same
/// store `@AppStorage` uses) and the home screen recomputes live.
@Observable
final class SettingsStore {
    var method: CalcMethod { didSet { persist() } }
    var madhab: AsrMadhab { didSet { persist() } }

    /// ±days to nudge the Hijri date for local moon-sighting differences (§12).
    var hijriOffsetDays: Int { didSet { persist() } }
    /// Whether the Hijri date is shown as the larger/primary date (§12).
    var hijriIsPrimary: Bool { didSet { persist() } }

    /// Manual per-prayer offsets in minutes (high-latitude stopgap, §13).
    var offsets: PrayerOffsets { didSet { persist() } }

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        method = CalcMethod(rawValue: defaults.string(forKey: Key.method) ?? "") ?? .muslimWorldLeague
        madhab = AsrMadhab(rawValue: defaults.string(forKey: Key.madhab) ?? "") ?? .standard
        hijriOffsetDays = defaults.integer(forKey: Key.hijriOffset) // 0 if unset
        hijriIsPrimary = defaults.bool(forKey: Key.hijriPrimary)
        if let data = defaults.data(forKey: Key.offsets),
           let decoded = try? JSONDecoder().decode(PrayerOffsets.self, from: data) {
            offsets = decoded
        } else {
            offsets = PrayerOffsets()
        }
    }

    /// The engine config derived from these settings.
    var prayerConfig: PrayerConfig {
        PrayerConfig(method: method.adhan,
                     madhab: madhab.adhanMadhab,
                     highLatitudeRule: .middleOfTheNight, // auto (spec §4); no visible toggle
                     offsets: offsets)
    }

    private func persist() {
        defaults.set(method.rawValue, forKey: Key.method)
        defaults.set(madhab.rawValue, forKey: Key.madhab)
        defaults.set(hijriOffsetDays, forKey: Key.hijriOffset)
        defaults.set(hijriIsPrimary, forKey: Key.hijriPrimary)
        if let data = try? JSONEncoder().encode(offsets) {
            defaults.set(data, forKey: Key.offsets)
        }
    }

    private enum Key {
        static let method = "duhaa.settings.method"
        static let madhab = "duhaa.settings.madhab"
        static let hijriOffset = "duhaa.settings.hijriOffsetDays"
        static let hijriPrimary = "duhaa.settings.hijriIsPrimary"
        static let offsets = "duhaa.settings.offsets"
    }
}
