import SwiftUI

/// One guide in a vertical step-card flow. Evidence is present at the point of
/// instruction, but folded away so the guide still feels calm and usable.
struct GuideDetailView: View {
    let guide: Guide

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header

                ForEach(guide.sortedSteps) { step in
                    stepCard(step)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: guide.category.icon)
                    .duhaaFont(14, .semibold)
                    .foregroundStyle(Palette.gold)
                Text(guide.category.title.uppercased())
                    .duhaaFont(12, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.85))
                Spacer()
                HStack(spacing: 12) {
                    metric(icon: "list.bullet", text: "\(guide.steps.count) steps")
                    metric(icon: "clock", text: "\(guide.estimatedMinutes) min")
                }
            }

            Text(guide.title)
                .duhaaFont(25, .bold)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(guide.summary)
                .duhaaFont(15)
                .foregroundStyle(.primary.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }

    private func stepCard(_ step: GuideStep) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 11) {
                stepNumber(step.order)

                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .duhaaFont(17, .semibold)
                        .foregroundStyle(Palette.gold)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(step.body)
                        .duhaaFont(14.5)
                        .lineSpacing(3)
                        .foregroundStyle(.primary.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let arabic = step.arabicText, !arabic.isEmpty {
                Text(arabicText(arabic))
                    .lineSpacing(12)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .foregroundStyle(.primary)
                    .padding(.top, 2)
                    .accessibilityLabel(arabic)
            }

            if let transliteration = step.transliteration, !transliteration.isEmpty {
                Text(transliteration)
                    .duhaaFont(13.5, italic: true)
                    .foregroundStyle(Palette.blue.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let translation = step.translation, !translation.isEmpty {
                Text(translation)
                    .duhaaFont(13.5)
                    .foregroundStyle(.primary.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            evidenceDisclosure(step.dalilReferences)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func stepNumber(_ order: Int) -> some View {
        ZStack {
            Circle()
                .fill(Palette.gold.opacity(0.14))
                .frame(width: 32, height: 32)
            Text("\(order)")
                .duhaaFont(13, .bold)
                .foregroundStyle(Palette.gold)
        }
        .accessibilityHidden(true)
    }

    private func evidenceDisclosure(_ references: [DalilReference]) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 9) {
                ForEach(references) { reference in
                    evidenceRow(reference)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "text.book.closed")
                    .duhaaFont(12, .semibold)
                Text("Evidence")
                    .duhaaFont(13, .semibold)
            }
            .foregroundStyle(Palette.gold.opacity(0.9))
        }
        .tint(Palette.gold)
        .padding(.top, 2)
    }

    private func evidenceRow(_ reference: DalilReference) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reference.sourceText)
                    .duhaaFont(12.5, .semibold)
                    .foregroundStyle(.primary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                gradeBadge(reference.grade)
            }

            Text("Grading: \(reference.grade.displayName) · \(reference.graderAttribution)")
                .duhaaFont(11.5, .medium)
                .foregroundStyle(Palette.blue.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if let note = reference.note, !note.isEmpty {
                Text(note)
                    .duhaaFont(11.5)
                    .foregroundStyle(.primary.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.blue.opacity(0.07))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.blue.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func gradeBadge(_ grade: EvidenceGrade) -> some View {
        Text(grade.displayName)
            .duhaaFont(10.5, .bold)
            .foregroundStyle(grade == .quranic ? Palette.onAccent : Palette.gold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(grade == .quranic ? Palette.gold : Palette.gold.opacity(0.14))
            .clipShape(Capsule())
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .duhaaFont(11, .semibold)
            Text(text)
                .duhaaFont(11.5, .medium)
        }
        .foregroundStyle(Palette.blue.opacity(0.78))
    }

    /// Same punctuation fallback as the du'a cards: the Uthmani font draws some
    /// punctuation as Quran stop signs, which reads oddly in guide snippets.
    private func arabicText(_ s: String) -> AttributedString {
        var attr = AttributedString(s)
        attr.font = QuranFont.uthmani(26)
        for punctuation in ["،", "؛"] {
            var search = attr.startIndex
            while search < attr.endIndex,
                  let range = attr[search...].range(of: punctuation) {
                attr[range].font = .system(size: 22)
                search = range.upperBound
            }
        }
        return attr
    }
}
