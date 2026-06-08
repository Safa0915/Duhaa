import SwiftUI

/// The "More" tab — holds any enabled tabs that overflow past the bar's capacity.
/// Dormant while Duha has five or fewer features; appears automatically once a
/// user enables more than fit in the bar.
struct MoreView: View {
    let tabs: [DuhaTab]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tabs) { tab in
                        NavigationLink {
                            tab.makeView()
                                .toolbar(.hidden, for: .navigationBar)
                        } label: {
                            Label(tab.title, systemImage: tab.icon)
                                .duhaFont(16)
                        }
                        .listRowBackground(Palette.card)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("More")
            .tint(Palette.gold)
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }
}
