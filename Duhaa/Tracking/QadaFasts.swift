import Foundation
import Observation

/// Tracks make-up (qaḍāʾ) fasts a person owes — e.g. days missed in Ramadan for
/// travel, illness or menstruation. Count-only and hopeful: set how many are owed,
/// then check them off as you make them up. Persisted to UserDefaults; injectable
/// for tests.
@Observable
final class QadaFasts {
    /// How many make-up fasts are still owed.
    private(set) var owed: Int
    /// How many have been made up (lifetime) — a quiet sense of progress.
    private(set) var completed: Int

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        owed = max(0, defaults.integer(forKey: Key.owed))
        completed = max(0, defaults.integer(forKey: Key.completed))
    }

    /// Set the number owed directly (from the stepper), clamped at zero.
    func setOwed(_ value: Int) {
        owed = max(0, value)
        persist()
    }

    func incrementOwed() { setOwed(owed + 1) }
    func decrementOwed() { setOwed(owed - 1) }

    /// Log one made-up fast: reduce what's owed and grow the completed tally.
    func logMakeUp() {
        guard owed > 0 else { return }
        owed -= 1
        completed += 1
        persist()
    }

    /// Undo the most recent make-up (e.g. a mis-tap), returning it to owed.
    func undoMakeUp() {
        guard completed > 0 else { return }
        completed -= 1
        owed += 1
        persist()
    }

    var hasAny: Bool { owed > 0 || completed > 0 }

    private func persist() {
        defaults.set(owed, forKey: Key.owed)
        defaults.set(completed, forKey: Key.completed)
    }

    private enum Key {
        static let owed = "duhaa.fasting.qada.owed"
        static let completed = "duhaa.fasting.qada.completed"
    }
}
