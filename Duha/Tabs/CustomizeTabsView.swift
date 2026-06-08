import SwiftUI

/// Lets the user reorder the tab bar and switch features on or off. Reached from
/// Settings, so it lives inside Settings' navigation stack (no stack of its own).
struct CustomizeTabsView: View {
    @Environment(TabSettings.self) private var tabs

    var body: some View {
        @Bindable var tabs = tabs
        List {
            Section {
                ForEach(tabs.order) { tab in
                    row(tab)
                }
                .onMove { tabs.move(from: $0, to: $1) }
            } header: {
                Text("Drag to reorder")
            } footer: {
                Text("Tap the dot to show or hide a tab. The first \(TabSettings.maxBarSlots) appear in the bar — any extras move into a “More” tab.")
            }

            Section {
                Button("Reset to Default", role: .destructive) {
                    tabs.resetToDefault()
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Customize Tabs")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.gold)
    }

    private func row(_ tab: DuhaTab) -> some View {
        let enabled = !tabs.isHidden(tab)
        return HStack(spacing: 14) {
            Button {
                tabs.toggleHidden(tab)
            } label: {
                Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                    .duhaFont(20)
                    .foregroundStyle(enabled ? Palette.gold : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: tab.icon)
                .duhaFont(16)
                .foregroundStyle(enabled ? Palette.blue : .secondary)
                .frame(width: 26)

            Text(tab.title)
                .duhaFont(16, .medium)
                .foregroundStyle(enabled ? .primary : .secondary)

            Spacer()

            Text(placementLabel(tab))
                .duhaFont(12, .semibold)
                .foregroundStyle(placementColor(tab))
        }
        .padding(.vertical, 2)
        .listRowBackground(Palette.card)
    }

    private func placementLabel(_ tab: DuhaTab) -> String {
        switch tabs.placement(of: tab) {
        case .bar:    "Tab bar"
        case .more:   "More"
        case .hidden: "Hidden"
        }
    }

    private func placementColor(_ tab: DuhaTab) -> Color {
        switch tabs.placement(of: tab) {
        case .bar:    Palette.gold
        case .more:   Palette.blue.opacity(0.8)
        case .hidden: .secondary
        }
    }
}
