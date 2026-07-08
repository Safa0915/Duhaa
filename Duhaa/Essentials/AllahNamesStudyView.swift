import SwiftUI

/// Allah's Names study hub — meanings first, then gentle review. Soft-accent
/// tinting so it reads especially warmly in the Light Pink and Rose themes.
/// Deliberately framed as *starter Names for learning*, never as "the" list.
struct AllahNamesStudyView: View {
    let set: StudySet

    @Environment(EssentialsProgressStore.self) private var progress

    init(set: StudySet? = nil) {
        self.set = set
            ?? Essentials.allahNames
            ?? StudySet(id: "names", category: .allahNames, subtitle: "", displayOrder: 0, cards: [])
    }

    // `self.` needed: a computed body starting with bare `set` parses as a setter.
    private var namePairCards: [EssentialsCard] { self.set.cards.filter { $0.type == .namePair } }
    private var reflectionCards: [EssentialsCard] { self.set.cards.filter { $0.type == .reflection } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("Learn meanings with flashcards and match")
                    .duhaaFont(14)
                    .foregroundStyle(.primary.opacity(0.66))

                heroCard
                modesSection
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .duhaaReadableWidth()
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Allah's Names")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // softAccent stays decorative (gradient/stroke); it's too pale for
            // text on light themes, so captions/chips use blue instead.
            Label("STARTER NAMES", systemImage: "heart")
                .duhaaFont(11, .semibold)
                .tracking(1)
                .foregroundStyle(Palette.blue.opacity(0.9))

            Text("A few starter Names for learning — meanings first, then gentle review.")
                .duhaaFont(15, .semibold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 6) {
                LearnChip(text: "\(namePairCards.count) Names in this sample",
                          systemImage: "rectangle.portrait.on.rectangle.portrait",
                          tint: Palette.blue)
                LearningPill(mastery: progress.headlineMastery(for: set))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duhaaGradientCardStyle(
            colors: [Palette.softAccent.opacity(0.16), Palette.softAccent.opacity(0.05)],
            stroke: Palette.softAccent.opacity(0.35))
        .accessibilityElement(children: .combine)
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
                NavigationLink {
                    FlashcardStudyView(title: "Name → Meaning", cards: namePairCards)
                } label: {
                    StudyModeRow(icon: "arrow.right.circle",
                                 title: "Name → Meaning",
                                 subtitle: "See the Name, recall its meaning")
                }
                .buttonStyle(.duhaaPress)

                NavigationLink {
                    FlashcardStudyView(title: "Meaning → Name",
                                       cards: Essentials.meaningFirst(namePairCards))
                } label: {
                    StudyModeRow(icon: "arrow.left.circle",
                                 title: "Meaning → Name",
                                 subtitle: "See the meaning, recall the Name")
                }
                .buttonStyle(.duhaaPress)

                NavigationLink {
                    MatchModeView(pairs: set.namePairs)
                } label: {
                    StudyModeRow(icon: "square.grid.2x2",
                                 title: "Match Names",
                                 subtitle: "Pair each Name with its meaning")
                }
                .buttonStyle(.duhaaPress)

                NavigationLink {
                    FlashcardStudyView(title: "Reflection Cards", cards: reflectionCards)
                } label: {
                    StudyModeRow(icon: "heart.text.square",
                                 title: "Reflection Cards",
                                 subtitle: "A quiet thought for each Name")
                }
                .buttonStyle(.duhaaPress)
            }
        }
    }
}
