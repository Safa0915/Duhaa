import SwiftUI

/// Root tab bar. The set, order and visibility of tabs is user-customizable
/// (Settings → Customize Tabs), driven by `TabSettings`. Up to five tabs show
/// directly; any overflow lands in a "More" tab.
struct MainTabView: View {
    @Environment(TabSettings.self) private var tabs
    @State private var selection: String = DuhaaTab.prayer.rawValue

    var body: some View {
        TabView(selection: $selection) {
            ForEach(tabs.barTabs) { tab in
                tabRoot(tab)
                    .tag(tab.rawValue)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
            }
            if !tabs.moreTabs.isEmpty {
                MoreView(tabs: tabs.moreTabs)
                    .tag("__more__")
                    .tabItem { Label("More", systemImage: "ellipsis") }
            }
        }
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
        .onChange(of: tabs.barTabs) { _, bar in
            // Keep a valid selection if the selected tab was reordered or hidden.
            let valid = bar.map(\.rawValue) + (tabs.moreTabs.isEmpty ? [] : ["__more__"])
            if !valid.contains(selection) { selection = bar.first?.rawValue ?? selection }
        }
    }

    /// Full-bleed tabs render as-is; the rest get their own NavigationStack so they
    /// can navigate internally (and so MoreView's stack stays single-bar).
    @ViewBuilder
    private func tabRoot(_ tab: DuhaaTab) -> some View {
        if tab.isFullBleed {
            tab.makeView()
        } else {
            NavigationStack { tab.makeView() }
        }
    }
}
