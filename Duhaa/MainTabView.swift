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
                tab.makeView()
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
}
