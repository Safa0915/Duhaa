import Foundation
import Observation

/// The opt-in "prayer insights" preference (on-time / late / missed). Off by
/// default — Duhaa stays hope-first unless the user chooses to see this. Enabling
/// (re)starts the measurement window at "today", so the numbers only ever reflect
/// the period the user asked to be tracked.
@Observable
final class InsightsStore {
    private(set) var enabled: Bool
    /// "yyyy-MM-dd" the current measurement window began (when insights were enabled).
    private(set) var startDay: String

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: Key.enabled)
        startDay = defaults.string(forKey: Key.startDay) ?? ""
    }

    /// Turn insights on or off. Turning it on starts a fresh window at `today` so the
    /// stats never reach back over time the user wasn't opted in.
    func setEnabled(_ on: Bool, today: String) {
        enabled = on
        defaults.set(on, forKey: Key.enabled)
        if on {
            startDay = today
            defaults.set(today, forKey: Key.startDay)
        }
    }

    private enum Key {
        static let enabled = "duhaa.insights.enabled"
        static let startDay = "duhaa.insights.startDay"
    }
}
