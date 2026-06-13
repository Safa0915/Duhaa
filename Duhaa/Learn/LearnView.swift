import SwiftUI

/// Offline Learn guides: category sections, title search, and plain guide cards.
struct LearnView: View {
    @State private var query = ""

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var groupedGuides: [(category: GuideCategory, guides: [Guide])] {
        guard !trimmed.isEmpty else { return Learn.guidesByCategory }
        return GuideCategory.allCases.compactMap { category in
            let matches = Learn.guides
                .filter { $0.category == category && $0.title.localizedStandardContains(trimmed) }
                .sorted { $0.sortOrder < $1.sortOrder }
            return matches.isEmpty ? nil : (category, matches)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ForEach(groupedGuides, id: \.category) { group in
                    guideSection(group.category, guides: group.guides)
                }

                if groupedGuides.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Learn")
        .searchable(text: $query, prompt: "Search guides")
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
    }

    private func guideSection(_ category: GuideCategory, guides: [Guide]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(Palette.gold.opacity(0.9))
                Text(category.title.uppercased())
                    .duhaaFont(13, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.85))
                Spacer()
                Text("\(guides.count)")
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(Palette.blue.opacity(0.7))
            }
            .padding(.horizontal, 2)

            VStack(spacing: 12) {
                ForEach(guides) { guide in
                    NavigationLink {
                        GuideDetailView(guide: guide)
                    } label: {
                        guideCard(guide)
                    }
                    .buttonStyle(.duhaaPress)
                }
            }
        }
    }

    private func guideCard(_ guide: Guide) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(guide.title)
                    .duhaaFont(17, .semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(guide.summary)
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.68))
                    .lineLimit(2)

                HStack(spacing: 14) {
                    metric(icon: "list.bullet", text: "\(guide.steps.count) steps")
                    metric(icon: "clock", text: "\(guide.estimatedMinutes) min")
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .duhaaFont(14, .semibold)
                .foregroundStyle(Palette.blue.opacity(0.48))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guide.title), \(guide.steps.count) steps, about \(guide.estimatedMinutes) minutes")
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .duhaaFont(12, .semibold)
            Text(text)
                .duhaaFont(12, .medium)
        }
        .foregroundStyle(Palette.blue.opacity(0.78))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .duhaaFont(24)
                .foregroundStyle(Palette.gold.opacity(0.8))
            Text("No guides found")
                .duhaaFont(16, .semibold)
                .foregroundStyle(.primary)
            Text("Try a different title.")
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .accessibilityElement(children: .combine)
    }
}
