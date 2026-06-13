import SwiftUI

/// Root tab bar. The set, order and visibility of tabs is user-customizable
/// (Settings → Customize Tabs), driven by `TabSettings`. Up to five tabs show
/// directly; any overflow lands in a "More" tab.
struct MainTabView: View {
    @Environment(TabSettings.self) private var tabs
    @AppStorage("duhaa.profile.gender") private var profileGenderRaw = UserProfileGender.notSet.rawValue
    @AppStorage("duhaa.shortcut.targetTab") private var shortcutTargetTab = ""
    @State private var selection: String = DuhaaTab.prayer.rawValue

    private var profile: UserProfileGender {
        UserProfileGender.from(profileGenderRaw)
    }

    private var barTabs: [DuhaaTab] {
        tabs.barTabs(for: profile)
    }

    private var moreTabs: [DuhaaTab] {
        tabs.moreTabs(for: profile)
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(barTabs) { tab in
                tabRoot(tab)
                    .tag(tab.rawValue)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
            }
            if !moreTabs.isEmpty {
                MoreView(tabs: moreTabs)
                    .tag("__more__")
                    .tabItem { Label("More", systemImage: "ellipsis") }
            }
        }
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
        .onAppear {
            consumeShortcutTarget()
            ensureValidSelection()
        }
        .onChange(of: barTabs) {
            ensureValidSelection()
        }
        .onChange(of: moreTabs) {
            ensureValidSelection()
        }
        .onChange(of: profileGenderRaw) {
            ensureValidSelection()
        }
        .onChange(of: shortcutTargetTab) {
            consumeShortcutTarget()
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

    private func ensureValidSelection() {
        let valid = barTabs.map(\.rawValue) + (moreTabs.isEmpty ? [] : ["__more__"])
        if !valid.contains(selection) {
            selection = barTabs.first?.rawValue ?? "__more__"
        }
    }

    private func consumeShortcutTarget() {
        guard let target = DuhaaTab(rawValue: shortcutTargetTab),
              target.isAvailable(for: profile) else {
            shortcutTargetTab = ""
            return
        }

        if barTabs.contains(target) {
            selection = target.rawValue
        } else if moreTabs.contains(target) {
            selection = "__more__"
        }
        shortcutTargetTab = ""
    }
}
