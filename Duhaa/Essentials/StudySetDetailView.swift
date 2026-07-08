import SwiftUI

/// One study set: a hero with learning progress, then the five study modes.
struct StudySetDetailView: View {
    let set: StudySet

    @Environment(EssentialsProgressStore.self) private var progress

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                heroCard
                modesSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .duhaaReadableWidth()
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(set.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(Palette.gold.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: set.icon)
                        .duhaaFont(19, .semibold)
                        .foregroundStyle(Palette.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(set.title)
                        .duhaaFont(20, .bold)
                        .foregroundStyle(.primary)
                    Text(set.subtitle)
                        .duhaaFont(13)
                        .foregroundStyle(.primary.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Learning Progress")
                        .duhaaFont(12, .semibold)
                        .foregroundStyle(Palette.blue.opacity(0.85))
                    Spacer()
                    Text("\(progress.masteredCount(in: set)) of \(set.cards.count) mastered")
                        .duhaaFont(11.5)
                        .foregroundStyle(.primary.opacity(0.55))
                }
                EssentialsProgressBar(fraction: progress.progressFraction(for: set))
            }
            .padding(.top, 2)

            FlowLayout(spacing: 6) {
                LearnChip(text: "\(set.cards.count) cards",
                          systemImage: "rectangle.portrait.on.rectangle.portrait",
                          tint: Palette.blue)
                LearningPill(mastery: progress.headlineMastery(for: set))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duhaaGradientCardStyle(
            colors: [Palette.gold.opacity(0.14), Palette.gold.opacity(0.05)],
            stroke: Palette.gold.opacity(0.3))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(set.title). \(set.subtitle). \(progress.masteredCount(in: set)) of \(set.cards.count) mastered.")
    }

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.grid.1x2")
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(Palette.gold.opacity(0.9))
                Text("STUDY MODES")
                    .duhaaFont(13, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 2)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                ForEach(StudyMode.allCases) { mode in
                    NavigationLink {
                        destination(for: mode)
                    } label: {
                        StudyModeRow(icon: mode.icon,
                                     title: mode.title,
                                     subtitle: mode.blurb)
                    }
                    .buttonStyle(.duhaaPress)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for mode: StudyMode) -> some View {
        switch mode {
        case .flashcards: FlashcardStudyView(set: set)
        case .learn: LearnQuizView(set: set)
        case .match: MatchModeView(pairs: set.namePairs)
        case .test: LearnQuizView(set: set, isTest: true)
        case .reviewMissed: ReviewMasteryView()
        }
    }
}
