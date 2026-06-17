import SwiftUI

/// Learn home: beginner-first grouped sections (Start Here → Purification →
/// Prayer Help → Foundations) of light, scannable guide cards, plus title search.
struct LearnView: View {
    @State private var query = ""
    @State private var guides: [Guide]?

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var groupedGuides: [(group: GuideGroup, guides: [Guide])] {
        guard let guides else { return [] }
        guard !trimmed.isEmpty else { return Learn.grouped(guides) }
        return GuideGroup.allCases
            .sorted { $0.displayIndex < $1.displayIndex }
            .compactMap { group in
                let matches = guides
                    .filter { $0.group == group && $0.title.localizedStandardContains(trimmed) }
                    .sorted { $0.displayOrder < $1.displayOrder }
                return matches.isEmpty ? nil : (group, matches)
            }
    }

    var body: some View {
        Group {
            if guides != nil {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedGuides, id: \.group) { section in
                            guideSection(section.group, guides: section.guides)
                        }

                        if groupedGuides.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
            } else {
                ProgressView()
                    .tint(Palette.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Learn")
        .searchable(text: $query, prompt: "Search guides")
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .task {
            guard guides == nil else { return }
            guides = await Learn.loadAsync()
        }
    }

    private func guideSection(_ group: GuideGroup, guides: [Guide]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: group.icon)
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(Palette.gold.opacity(0.9))
                Text(group.title.uppercased())
                    .duhaaFont(13, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 2)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                ForEach(guides) { guide in
                    NavigationLink {
                        GuideDetailView(guide: guide)
                    } label: {
                        LearnGuideCard(guide: guide)
                    }
                    .buttonStyle(.duhaaPress)
                }
            }
        }
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

/// A light, scannable guide card: soft group icon, title, one-line summary, a
/// wrapping chip row (category · status · optional "scholars differ"), and a
/// compact step/time metric line. No Arabic or evidence here — that lives inside.
struct LearnGuideCard: View {
    let guide: Guide

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            icon

            VStack(alignment: .leading, spacing: 8) {
                Text(guide.title)
                    .duhaaFont(17, .semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(guide.subtitle ?? guide.summary)
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 6) {
                    LearnChip(text: guide.category.title, systemImage: guide.category.icon, tint: Palette.blue)
                    LearnStatusChip(status: guide.reviewStatus)
                    if guide.madhhabSensitivity.warrantsNote {
                        LearnChip(text: guide.madhhabSensitivity.chipLabel,
                                  systemImage: guide.madhhabSensitivity.chipIcon, tint: Palette.gold)
                    }
                }
                .padding(.top, 1)

                metricLine
                    .padding(.top, 1)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .duhaaFont(13, .semibold)
                .foregroundStyle(Palette.blue.opacity(0.45))
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duhaaCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guide.title). \(guide.subtitle ?? guide.summary). \(guide.steps.count) steps, about \(guide.estimatedMinutes) minutes. \(guide.reviewStatus.label).")
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Palette.gold.opacity(0.12))
                .frame(width: 38, height: 38)
            Image(systemName: guide.group.icon)
                .duhaaFont(15, .semibold)
                .foregroundStyle(Palette.gold)
        }
        .accessibilityHidden(true)
    }

    private var metricLine: some View {
        HStack(spacing: 14) {
            metric(icon: "list.bullet", text: "\(guide.steps.count) steps")
            metric(icon: "clock", text: "~\(guide.estimatedMinutes) min")
        }
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).duhaaFont(11.5, .semibold)
            Text(text).duhaaFont(12, .medium)
        }
        .foregroundStyle(Palette.blue.opacity(0.72))
    }
}
