import SwiftUI

// MARK: - Step / evidence view-model helpers
//
// These pure computed properties decide what a step card shows. Keeping them out
// of the View makes the UI declarative and the behaviour unit-testable without a
// UI-testing dependency.

extension GuideStep {
    var hasArabic: Bool { !(arabicText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasTransliteration: Bool { !(transliteration ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasTranslation: Bool { !(translation ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// There is pronunciation/meaning material worth its own collapsible section.
    var hasMeaning: Bool { hasTransliteration || hasTranslation }
    var hasEvidence: Bool { !dalilReferences.isEmpty }
    /// A gentle "scholars differ" note is warranted for this step.
    var isMadhhabSensitive: Bool { madhhabSensitivity.warrantsNote }
    var hasMadhhabNote: Bool { !(madhhabNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// Compact source label for the chip. Never empty.
    var sourceChipText: String {
        let s = (sourceSummary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Evidence" : s
    }
}

extension ReviewStatus {
    var chipIcon: String {
        switch self {
        case .sourceBacked: "text.book.closed"
        case .reviewed: "checkmark.seal"
        case .needsReview: "exclamationmark.circle"
        }
    }
}

extension MadhhabSensitivity {
    /// Calm, non-sectarian chip wording. Deliberately never the word "verified".
    var chipLabel: String { "Scholars differ" }
    var chipIcon: String { "questionmark.circle" }
}

// MARK: - Flow layout (wrapping chips)

/// A minimal wrapping layout so a row of chips reflows instead of clipping at
/// large Dynamic Type sizes. Native `Layout`, no third-party dependency.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let intrinsic = rows.map(\.width).max() ?? 0
        // Report the full width we were proposed (when finite) — not just the
        // widest row. Returning the narrower widest-row value made SwiftUI place
        // us inside that smaller box, where `placeSubviews` re-wraps into MORE
        // rows than this height accounts for; the extra row then overlaps whatever
        // sits below (the "tags on top of each other" bug).
        return CGSize(width: maxWidth.isFinite ? maxWidth : intrinsic, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = arrange(subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for placed in row.items {
                subviews[placed.index].place(at: CGPoint(x: x, y: y),
                                             proposal: ProposedViewSize(placed.size))
                x += placed.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    // MARK: Shared row arrangement

    private struct Placed { let index: Int; let size: CGSize }
    private struct Row { var items: [Placed] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    /// Group the subviews into rows for a given width. Used by *both* passes so the
    /// height reported by `sizeThatFits` always matches what `placeSubviews` draws.
    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let candidate = current.items.isEmpty ? size.width : current.width + spacing + size.width
            if !current.items.isEmpty, candidate > maxWidth {
                rows.append(current)
                current = Row(items: [Placed(index: index, size: size)],
                              width: size.width, height: size.height)
            } else {
                current.items.append(Placed(index: index, size: size))
                current.width = candidate
                current.height = max(current.height, size.height)
            }
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Chip

/// A small, calm capsule used across Learn (status, category, source, madhhab).
struct LearnChip: View {
    let text: String
    var systemImage: String?
    var tint: Color = Palette.blue
    /// `true` paints the accent as a solid fill (used sparingly, e.g. Qur'an).
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).duhaaFont(10.5, .semibold)
            }
            Text(text).duhaaFont(11.5, .medium)
        }
        .foregroundStyle(filled ? Palette.onAccent : tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.13)))
        .clipShape(Capsule())
        .fixedSize()
    }
}

/// Status chip for a guide/step's review state. Stays calm; "Verified" is never
/// an option (the `ReviewStatus` enum has no such case by design).
struct LearnStatusChip: View {
    let status: ReviewStatus
    var body: some View {
        LearnChip(text: status.label,
                  systemImage: status.chipIcon,
                  tint: status == .needsReview ? Palette.gold : Palette.blue)
            .accessibilityLabel("Status: \(status.label)")
    }
}

// MARK: - Expandable section

/// Reusable expand/collapse container with a calm, Reduce-Motion-aware transition.
struct ExpandableLearnSection<Trigger: View, Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var trigger: (_ toggle: @escaping () -> Void) -> Trigger
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            trigger(toggle)
            if isExpanded {
                content()
                    .transition(reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func toggle() {
        if reduceMotion { isExpanded.toggle() }
        else { withAnimation(.easeInOut(duration: 0.22)) { isExpanded.toggle() } }
    }
}

/// A chip-style trigger with a rotating chevron, used for expandable sections.
struct LearnDisclosureTrigger: View {
    let text: String
    var systemImage: String
    var tint: Color = Palette.gold
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage).duhaaFont(11, .semibold)
                Text(text).duhaaFont(12.5, .semibold)
                Image(systemName: "chevron.down")
                    .duhaaFont(10, .semibold)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .foregroundStyle(tint.opacity(0.95))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.duhaaPress)
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
    }
}

// MARK: - Arabic block

/// Arabic rendered in the bundled Uthmani mushaf font, RTL, with breathing room.
/// Mirrors the du'a-card punctuation fallback so commas don't draw as Quran stops.
struct ArabicTextBlock: View {
    let text: String
    var size: CGFloat = 27

    var body: some View {
        Text(attributed)
            .lineSpacing(13)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .foregroundStyle(.primary)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Palette.blue.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(text)
    }

    private var attributed: AttributedString {
        var attr = AttributedString(text)
        attr.font = QuranFont.uthmani(size)
        for punctuation in ["،", "؛"] {
            var search = attr.startIndex
            while search < attr.endIndex,
                  let r = attr[search...].range(of: punctuation) {
                attr[r].font = .system(size: size - 4)
                search = r.upperBound
            }
        }
        return attr
    }
}

// MARK: - Evidence row

/// One expanded reference: source, grade, grader, and any optional metadata.
struct LearnEvidenceRow: View {
    let reference: DalilReference

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reference.sourceText)
                    .duhaaFont(12.5, .semibold)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                gradeBadge
            }

            Text(reference.displayGradingText)
                .duhaaFont(11.5, .medium)
                .foregroundStyle(Palette.blue.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            if let what = reference.whatItSupports, !what.isEmpty {
                secondary("Supports: \(what)")
            }
            if let note = reference.note, !note.isEmpty {
                secondary(note)
            }
            if let scholar = reference.scholarSource, !scholar.isEmpty {
                secondary("Scholar check: \(scholar)")
            }
            if reference.needsReview == true {
                LearnChip(text: "Needs review", systemImage: "exclamationmark.circle", tint: Palette.gold)
                    .padding(.top, 1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.blue.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.blue.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func secondary(_ s: String) -> some View {
        Text(s)
            .duhaaFont(11.5)
            .foregroundStyle(.primary.opacity(0.6))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var gradeBadge: some View {
        Text(reference.grade.displayName)
            .duhaaFont(10.5, .bold)
            .foregroundStyle(reference.grade == .quranic ? Palette.onAccent : Palette.gold)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(reference.grade == .quranic ? AnyShapeStyle(Palette.gold) : AnyShapeStyle(Palette.gold.opacity(0.14)))
            .clipShape(Capsule())
    }
}
