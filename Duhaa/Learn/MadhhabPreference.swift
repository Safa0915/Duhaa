import Foundation
import Observation

/// The user's stated school for Learn content. This is **framework prep**: Duhaa
/// does not yet render madhhab-specific rulings. The only behaviour wired today is
/// "shared basics mode" — choosing `notSure` must never silently pick a school.
enum MadhhabPreference: String, Codable, CaseIterable, Identifiable, Hashable {
    case notSure = "not_sure"
    case hanafi
    case maliki
    case shafii
    case hanbali
    case localImamOrTeacher = "local_imam_or_teacher"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notSure: "Not sure yet"
        case .hanafi: "Hanafi"
        case .maliki: "Maliki"
        case .shafii: "Shafi'i"
        case .hanbali: "Hanbali"
        case .localImamOrTeacher: "My local imam or teacher"
        }
    }

    /// `true` when Duhaa should teach the broadly-agreed beginner basics and show a
    /// gentle "scholars differ" note instead of asserting one school's ruling.
    /// `notSure` and `localImamOrTeacher` both defer rather than fix a madhhab.
    var usesSharedBasics: Bool {
        switch self {
        case .notSure, .localImamOrTeacher: true
        case .hanafi, .maliki, .shafii, .hanbali: false
        }
    }

    /// The specific school, if one was chosen. `nil` keeps Duhaa from inventing one.
    var specificSchool: MadhhabPreference? {
        usesSharedBasics ? nil : self
    }
}

/// User-facing copy for the madhhab framework. Kept here so the wording stays
/// consistent and calm wherever it is eventually shown.
enum MadhhabGuidance {
    /// Shown when the user is in shared-basics mode (`not_sure`).
    static let sharedBasics =
        "Duhaa teaches the shared beginner-safe basics first. Some details differ between scholars and madhhabs. For specifics, follow a trusted scholar, local imam, or the madhhab you study with."

    /// Generic note for a madhhab-sensitive detail. Steps may override this with
    /// their own `madhhabNote`; this is the fallback.
    static let madhhabSensitive =
        "Scholars differ on some details here. Duhaa shows a beginner-safe summary. Follow the position you were taught by a trusted scholar or your madhhab."

    /// Whether a gentle note should be surfaced for a given step in a given mode.
    /// Pure function, no ruling logic — only decides "show a heads-up or not".
    static func shouldShowNote(for sensitivity: MadhhabSensitivity,
                               preference: MadhhabPreference) -> Bool {
        sensitivity.warrantsNote
    }
}

/// Lightweight, testable store for the chosen school. Mirrors the project's
/// `init(defaults:)` convention (PrayerTracker / TabSettings). Not yet injected
/// into the app environment — no UI reads it until the madhhab display ships.
@Observable
final class MadhhabSettings {
    private let defaults: UserDefaults
    private static let key = "duhaa.learn.madhhab"

    var preference: MadhhabPreference {
        didSet { defaults.set(preference.rawValue, forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.key) ?? ""
        self.preference = MadhhabPreference(rawValue: raw) ?? .notSure
    }

    /// `true` when Duhaa is in shared-basics mode for the current selection.
    var isSharedBasicsMode: Bool { preference.usesSharedBasics }
}
