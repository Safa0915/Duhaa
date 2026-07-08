import SwiftUI

/// Review Missed: questions answered wrong come back here, plus calm per-set
/// learning progress. Only progress is counted — never what went wrong.
struct ReviewMasteryView: View {
    @Environment(EssentialsProgressStore.self) private var progress

    private let sets = Essentials.sets

    /// Real missed questions from the progress store.
    private var missed: [EssentialsCard] { progress.missedQuestions(across: sets) }

    /// Until something is actually missed, offer a gentle practice mix
    /// (one question per set) so the review button always has content.
    private var practiceMix: [EssentialsCard] {
        sets.compactMap { $0.cards.first(where: \.isMultipleChoice) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                heroCard
                progressSection

                Text("Only progress is counted — never what you got wrong.")
                    .duhaaFont(11)
                    .foregroundStyle(.primary.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .duhaaReadableWidth()
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Review Missed")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("REVIEW MISSED", systemImage: "arrow.counterclockwise")
                .duhaaFont(11, .semibold)
                .tracking(1)
                .foregroundStyle(Palette.gold.opacity(0.9))

            Text(missed.isEmpty
                 ? "Nothing missed right now"
                 : "\(missed.count) questions you missed are due today")
                .duhaaFont(18, .semibold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(missed.isEmpty
                 ? "When a question slips, it gently returns here."
                 : "A short, calm review — a few minutes is plenty.")
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                LearnQuizView(title: "Review",
                              chipText: "Review Missed",
                              chipIcon: "arrow.counterclockwise",
                              cards: missed.isEmpty ? practiceMix : missed)
            } label: {
                Text(missed.isEmpty ? "Practice a quick mix" : "Start Review")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Palette.gold))
            }
            .buttonStyle(.duhaaPress)
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duhaaGradientCardStyle(
            colors: [Palette.gold.opacity(0.14), Palette.gold.opacity(0.05)],
            stroke: Palette.gold.opacity(0.3))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(Palette.gold.opacity(0.9))
                Text("LEARNING PROGRESS")
                    .duhaaFont(13, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 2)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                ForEach(progress.summaries(for: sets)) { summary in
                    MasteryProgressRow(title: summary.title,
                                       mastered: summary.mastered,
                                       total: summary.total,
                                       status: summary.status)
                }
            }
        }
    }
}
