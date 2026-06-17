import SwiftUI

/// One guide as a calm vertical flow of step cards. Arabic stays visible; meaning,
/// evidence, and madhhab notes fold away so the screen reads softly, not like a PDF.
struct GuideDetailView: View {
    let guide: Guide

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header

                ForEach(Array(guide.sortedSteps.enumerated()), id: \.element.id) { index, step in
                    LearnStepCard(step: step, position: index + 1, total: guide.steps.count)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(guide.title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: guide.group.icon)
                    .duhaaFont(14, .semibold)
                    .foregroundStyle(Palette.gold)
                Text(guide.group.title.uppercased())
                    .duhaaFont(12, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.85))
                Spacer()
                metric(icon: "list.bullet", text: "\(guide.steps.count) steps")
                metric(icon: "clock", text: "\(guide.estimatedMinutes) min")
            }

            Text(guide.title)
                .duhaaFont(25, .bold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(guide.subtitle ?? guide.summary)
                .duhaaFont(15)
                .foregroundStyle(.primary.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            FlowLayout(spacing: 6) {
                LearnChip(text: guide.category.title, systemImage: guide.category.icon, tint: Palette.blue)
                LearnStatusChip(status: guide.reviewStatus)
                if guide.madhhabSensitivity.warrantsNote {
                    LearnChip(text: guide.madhhabSensitivity.chipLabel,
                              systemImage: guide.madhhabSensitivity.chipIcon, tint: Palette.gold)
                }
            }

            if guide.scholarReviewStatus == .needsReview {
                Text("Sources provided · pending scholar review.")
                    .duhaaFont(11.5)
                    .foregroundStyle(.primary.opacity(0.5))
            }
        }
        .padding(.bottom, 4)
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).duhaaFont(11, .semibold)
            Text(text).duhaaFont(11.5, .medium)
        }
        .foregroundStyle(Palette.blue.opacity(0.78))
    }
}

/// A single step. Instruction + Arabic read at a glance; the rest is one tap away.
struct LearnStepCard: View {
    let step: GuideStep
    let position: Int
    let total: Int

    @State private var showMeaning = false
    @State private var showEvidence = false
    @State private var showMadhhab = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Step \(position) of \(total)")
                .duhaaFont(11, .bold)
                .foregroundStyle(Palette.blue.opacity(0.75))
                .accessibilityLabel("Step \(position) of \(total)")

            Text(step.title)
                .duhaaFont(17, .semibold)
                .foregroundStyle(Palette.gold)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.body)
                .duhaaFont(14.5)
                .lineSpacing(3)
                .foregroundStyle(.primary.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if step.hasArabic, let arabic = step.arabicText {
                ArabicTextBlock(text: arabic)
            }

            if step.hasMeaning {
                meaningSection
            }

            if step.hasEvidence {
                evidenceSection
            }

            if step.isMadhhabSensitive {
                madhhabSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Meaning & pronunciation

    private var meaningSection: some View {
        ExpandableLearnSection(isExpanded: $showMeaning) { toggle in
            LearnDisclosureTrigger(text: "Meaning & pronunciation",
                                   systemImage: "character.book.closed",
                                   tint: Palette.blue,
                                   isExpanded: showMeaning, action: toggle)
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                if let translit = step.transliteration, !translit.isEmpty {
                    Text(translit)
                        .duhaaFont(13.5, italic: true)
                        .foregroundStyle(Palette.blue.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let translation = step.translation, !translation.isEmpty {
                    Text(translation)
                        .duhaaFont(13.5)
                        .foregroundStyle(.primary.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Sources / evidence

    private var evidenceSection: some View {
        ExpandableLearnSection(isExpanded: $showEvidence) { toggle in
            LearnDisclosureTrigger(text: step.sourceChipText,
                                   systemImage: "text.book.closed",
                                   tint: Palette.blue,
                                   isExpanded: showEvidence, action: toggle)
                .accessibilityLabel("Sources: \(step.sourceChipText). Double tap to show evidence.")
        } content: {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(step.dalilReferences) { LearnEvidenceRow(reference: $0) }
            }
        }
    }

    // MARK: Madhhab note

    private var madhhabSection: some View {
        ExpandableLearnSection(isExpanded: $showMadhhab) { toggle in
            LearnDisclosureTrigger(text: step.madhhabSensitivity.chipLabel,
                                   systemImage: step.madhhabSensitivity.chipIcon,
                                   tint: Palette.gold,
                                   isExpanded: showMadhhab, action: toggle)
                .accessibilityLabel("Scholars differ on this detail. Double tap to learn more.")
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Text(step.madhhabNote ?? MadhhabGuidance.madhhabSensitive)
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                if let scholarNotes = step.scholarNotes, !scholarNotes.isEmpty {
                    Text(scholarNotes)
                        .duhaaFont(11.5)
                        .foregroundStyle(.primary.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(MadhhabGuidance.sharedBasics)
                    .duhaaFont(11.5)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.gold.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold.opacity(0.14), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
