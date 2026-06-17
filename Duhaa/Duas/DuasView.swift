import SwiftUI

/// The Du'as tab: occasion-based categories (After Prayer, Morning, Evening, …).
struct DuasView: View {
    @State private var categories: [DuaCategory]?

    var body: some View {
        Group {
            if let categories {
                // Host provides the NavigationStack (see MainTabView / MoreView).
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(categories) { category in
                            NavigationLink {
                                DuaListView(category: category)
                            } label: {
                                card(category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            } else {
                ProgressView()
                    .tint(Palette.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Du'as")
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .task {
            guard categories == nil else { return }
            categories = await Duas.loadAsync()
        }
    }

    private func card(_ category: DuaCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .duhaaFont(20)
                .foregroundStyle(Palette.gold)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .duhaaFont(17, .semibold)
                    .foregroundStyle(.primary)
                Text(category.subtitle ?? "\(category.duas.count) du'as")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .duhaaFont(13, .semibold)
                .foregroundStyle(Palette.blue.opacity(0.5))
        }
        .padding(16)
        .duhaaCardStyle()
    }
}
