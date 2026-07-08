import SwiftUI

/// The "More" tab — holds any enabled tabs that overflow past the bar's capacity.
/// Dormant while Duhaa has five or fewer features; appears automatically once a
/// user enables more than fit in the bar. Owns the NavigationStack so each opened
/// tab gets a natural "‹ More" back button (feature views no longer self-wrap).
struct MoreView: View {
    let tabs: [DuhaaTab]
    @State private var path: [DuhaaTab] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(tabs) { tab in
                        NavigationLink(value: tab) {
                            // Color the icon from the theme explicitly: List-row
                            // Label symbols otherwise fall back to the static
                            // AccentColor asset (gold) instead of the live theme.
                            Label {
                                Text(tab.title).duhaaFont(16)
                            } icon: {
                                Image(systemName: tab.icon)
                                    .foregroundStyle(Palette.gold)
                            }
                        }
                        .listRowBackground(Palette.card)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(ThemeDecorativeBackground())
            .navigationTitle("More")
            .tint(Palette.gold)
            .navigationDestination(for: DuhaaTab.self) { tab in
                tab.makeView()
                    .navigationTitle(tab.isFullBleed ? "" : tab.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }
}
