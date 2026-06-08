import Foundation
import Observation

/// The user's tab-bar layout: the order of every feature plus which ones are
/// hidden. Persisted to UserDefaults and shared via the environment.
///
/// Layout rule: up to `maxBarSlots` enabled tabs show directly in the bar. If the
/// user enables more than that, the last slot becomes a "More" menu holding the
/// overflow. With Duhaa's current five features everything fits, so "More" stays
/// dormant until a sixth feature (or the user) pushes past the limit.
@Observable
final class TabSettings {
    static let maxBarSlots = 5

    /// Every tab, in the user's chosen order (includes hidden ones).
    private(set) var order: [DuhaaTab]
    /// Tabs the user has switched off entirely.
    private(set) var hidden: Set<DuhaaTab>

    @ObservationIgnored private let orderKey = "duhaa.tabs.order"
    @ObservationIgnored private let hiddenKey = "duhaa.tabs.hidden"
    @ObservationIgnored private let defaults: UserDefaults

    /// `defaults` is injectable so tests can use an isolated suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = (defaults.stringArray(forKey: orderKey) ?? [])
            .compactMap(DuhaaTab.init(rawValue:))
        // Start from the saved order, then append any tabs it doesn't mention yet
        // (e.g. a feature added in a later app version) so nothing ever disappears.
        var merged = saved
        for tab in DuhaaTab.defaultOrder where !merged.contains(tab) { merged.append(tab) }
        order = merged.isEmpty ? DuhaaTab.defaultOrder : merged

        hidden = Set((defaults.stringArray(forKey: hiddenKey) ?? [])
            .compactMap(DuhaaTab.init(rawValue:)))
    }

    // MARK: Derived layout

    /// Enabled tabs, in order — what the user actually sees.
    var enabled: [DuhaaTab] { order.filter { !hidden.contains($0) } }

    /// Tabs shown directly in the bar.
    var barTabs: [DuhaaTab] {
        let e = enabled
        guard e.count > Self.maxBarSlots else { return e }
        return Array(e.prefix(Self.maxBarSlots - 1))
    }

    /// Tabs tucked under the "More" menu (empty unless there are too many).
    var moreTabs: [DuhaaTab] {
        let e = enabled
        guard e.count > Self.maxBarSlots else { return [] }
        return Array(e.dropFirst(Self.maxBarSlots - 1))
    }

    /// Where a tab currently lives — used by the customize screen.
    enum Placement { case bar, more, hidden }
    func placement(of tab: DuhaaTab) -> Placement {
        if hidden.contains(tab) { return .hidden }
        return barTabs.contains(tab) ? .bar : .more
    }

    // MARK: Mutations

    func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func isHidden(_ tab: DuhaaTab) -> Bool { hidden.contains(tab) }

    /// Show/hide a tab. Refuses to hide the last visible tab.
    func toggleHidden(_ tab: DuhaaTab) {
        if hidden.contains(tab) {
            hidden.remove(tab)
        } else {
            guard enabled.count > 1 else { return }
            hidden.insert(tab)
        }
        persist()
    }

    func resetToDefault() {
        order = DuhaaTab.defaultOrder
        hidden = []
        persist()
    }

    private func persist() {
        defaults.set(order.map(\.rawValue), forKey: orderKey)
        defaults.set(Array(hidden).map(\.rawValue), forKey: hiddenKey)
    }
}
