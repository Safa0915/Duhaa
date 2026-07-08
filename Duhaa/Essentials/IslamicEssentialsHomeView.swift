import SwiftUI

/// Islamic Essentials home: a calm daily-review hero plus the study sets from
/// the bundled question bank. Due counts and mastery come from the local
/// progress store — nothing is hardcoded.
struct IslamicEssentialsHomeView: View {
    @Environment(EssentialsProgressStore.self) private var progress

    private let sets = Essentials.sets

    private var dueCount: Int { progress.dueCount(across: sets) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("Study common Islamic knowledge with calm daily review")
                    .duhaaFont(14)
                    .foregroundStyle(.primary.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                heroCard

                setsSection

                Text("Starter content — every fact here is pending scholar review.")
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
        .navigationTitle("Islamic Essentials")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("TODAY'S REVIEW", systemImage: "sparkles")
                .duhaaFont(11, .semibold)
                .tracking(1)
                .foregroundStyle(Palette.gold.opacity(0.9))

            Text(dueCount > 0 ? "\(dueCount) cards due" : "Nothing due today")
                .duhaaFont(24, .bold)
                .foregroundStyle(.primary)

            Text(dueCount > 0
                 ? "A few calm minutes keeps what you've learned fresh."
                 : "Explore a set below — short, calm sessions.")
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                ReviewMasteryView()
            } label: {
                Text(dueCount > 0 ? "Start Review" : "See Progress")
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

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack")
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(Palette.gold.opacity(0.9))
                Text("STUDY SETS")
                    .duhaaFont(13, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 2)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 12) {
                ForEach(sets) { set in
                    NavigationLink {
                        if set.category == .allahNames {
                            AllahNamesStudyView(set: set)
                        } else {
                            StudySetDetailView(set: set)
                        }
                    } label: {
                        StudySetCard(set: set,
                                     mastery: progress.headlineMastery(for: set),
                                     statusLine: progress.statusLine(for: set))
                    }
                    .buttonStyle(.duhaaPress)
                }
            }
        }
    }
}
