import SwiftUI

// MARK: - Learning pill

/// Mastery state as a calm chip. Thin wrapper over `LearnChip` so the pill
/// language ("Learning", "Mastered") stays consistent with the Learn tab.
struct LearningPill: View {
    let mastery: MasteryState

    var body: some View {
        LearnChip(text: mastery.label, systemImage: mastery.icon, tint: mastery.tint)
            .accessibilityLabel("Progress: \(mastery.label)")
    }
}

// MARK: - Learn-tab entry card

/// The gold gradient card on the Learn home that opens Islamic Essentials.
/// Lives here (not in LearnView) so the whole feature stays in one folder.
struct EssentialsEntryCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Circle()
                    .fill(Palette.gold.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: "square.stack")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Islamic Essentials")
                    .duhaaFont(17, .semibold)
                    .foregroundStyle(.primary)

                Text("Study common Islamic knowledge with calm daily review")
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 6) {
                    LearnChip(text: "\(Essentials.sets.count) study sets",
                              systemImage: "square.stack", tint: Palette.blue)
                    LearnChip(text: "New", systemImage: "sparkle", tint: Palette.gold)
                }
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
        .duhaaGradientCardStyle(
            colors: [Palette.gold.opacity(0.14), Palette.gold.opacity(0.05)],
            stroke: Palette.gold.opacity(0.3))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Islamic Essentials. Study common Islamic knowledge with calm daily review. \(Essentials.sets.count) study sets.")
    }
}

// MARK: - Study set card

/// One study set on the Essentials home — mirrors `LearnGuideCard` so the two
/// halves of the Learn tab read as one family. Mastery/status come from the
/// progress store via the parent (the card itself stays a dumb view).
struct StudySetCard: View {
    let set: StudySet
    let mastery: MasteryState
    let statusLine: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                Circle()
                    .fill(Palette.gold.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: set.icon)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(set.title)
                    .duhaaFont(17, .semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(set.subtitle)
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.66))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                FlowLayout(spacing: 6) {
                    LearnChip(text: "\(set.cards.count) cards",
                              systemImage: "rectangle.portrait.on.rectangle.portrait",
                              tint: Palette.blue)
                    LearningPill(mastery: mastery)
                }
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
        .accessibilityLabel("\(set.title). \(set.subtitle). \(set.cards.count) cards. \(statusLine).")
    }
}

// MARK: - Study mode row

struct StudyModeRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var tint: Color = Palette.gold

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(tint)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .duhaaFont(16, .semibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .duhaaFont(12)
                    .foregroundStyle(.primary.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .duhaaFont(13, .semibold)
                .foregroundStyle(Palette.blue.opacity(0.45))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duhaaCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle).")
    }
}

// MARK: - Quiz option

enum QuizOptionState {
    case idle, selected, correct, incorrect
}

struct QuizOptionButton: View {
    let letter: String
    let text: String
    let state: QuizOptionState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(letter)
                    .duhaaFont(13, .bold)
                    .foregroundStyle(letterForeground)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(letterBackground))

                Text(text)
                    .duhaaFont(15, .medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .duhaaFont(17)
                        .foregroundStyle(Palette.success)
                } else if state == .incorrect {
                    Image(systemName: "xmark.circle")
                        .duhaaFont(17)
                        .foregroundStyle(Palette.destructive.opacity(0.8))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .duhaaCardStyle(fill: fill, stroke: stroke, lineWidth: state == .idle ? 1 : 1.5)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.duhaaPress)
        .accessibilityLabel("Option \(letter): \(text)")
        .accessibilityValue(accessibilityValue)
    }

    private var fill: Color {
        switch state {
        case .idle: Palette.card
        case .selected: Palette.elevatedCardBackground
        case .correct: Palette.success.opacity(0.10)
        case .incorrect: Palette.destructive.opacity(0.08)
        }
    }

    private var stroke: Color {
        switch state {
        case .idle: Palette.cardBorder
        case .selected: Palette.gold
        case .correct: Palette.success.opacity(0.6)
        case .incorrect: Palette.destructive.opacity(0.5)
        }
    }

    private var letterForeground: Color {
        state == .selected ? Palette.onAccent : Palette.blue.opacity(0.9)
    }

    private var letterBackground: Color {
        state == .selected ? Palette.gold : Palette.blue.opacity(0.12)
    }

    private var accessibilityValue: String {
        switch state {
        case .idle: "not selected"
        case .selected: "selected"
        case .correct: "correct answer"
        case .incorrect: "your answer, incorrect"
        }
    }
}

// MARK: - Source note card

/// A calm "here's where this comes from" card. Carries the card's review
/// status chip (Learn's `ReviewStatus` — it has no "Verified" case by design).
struct SourceNoteCard: View {
    let note: String
    var citation: String?
    var status: ReviewStatus = .needsReview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "text.book.closed")
                    .duhaaFont(11, .semibold)
                Text("SOURCE-BACKED NOTE")
                    .duhaaFont(11, .semibold)
                    .tracking(1)
                Spacer()
            }
            .foregroundStyle(Palette.gold.opacity(0.9))

            Text(note)
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            if let citation {
                Text(citation)
                    .duhaaFont(11.5, .medium)
                    .foregroundStyle(Palette.blue.opacity(0.75))
            }

            LearnStatusChip(status: status)
                .padding(.top, 1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.blue.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.blue.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Progress bar & mastery row

/// Shared thin capsule progress fill, animated once on appear (skipped under
/// Reduce Motion).
struct EssentialsProgressBar: View {
    let fraction: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(Palette.gold)
                    .frame(width: geo.size.width * (filled ? min(max(fraction, 0), 1) : 0))
            }
        }
        .frame(height: 6)
        .onAppear {
            if reduceMotion {
                filled = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { filled = true }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MasteryProgressRow: View {
    let title: String
    let mastered: Int
    let total: Int
    let status: String

    private var fraction: Double { total == 0 ? 0 : Double(mastered) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(status)
                    .duhaaFont(12, .medium)
                    .foregroundStyle(Palette.blue.opacity(0.75))
            }

            EssentialsProgressBar(fraction: fraction)

            Text("\(mastered) of \(total) mastered")
                .duhaaFont(11.5)
                .foregroundStyle(.primary.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duhaaCardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(mastered) of \(total) mastered. \(status).")
    }
}

// MARK: - Match tile

enum MatchTileState {
    case idle, selected, matched
}

struct MatchTile: View {
    let text: String
    let state: MatchTileState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(text)
                    .duhaaFont(14, .semibold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if state == .matched {
                    Image(systemName: "checkmark.circle.fill")
                        .duhaaFont(13)
                        .foregroundStyle(Palette.success)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 74)
            .duhaaCardStyle(fill: fill, stroke: stroke, lineWidth: state == .idle ? 1 : 1.5)
            .opacity(state == .matched ? 0.55 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.duhaaPress)
        .disabled(state == .matched)
        .accessibilityLabel(text)
        .accessibilityValue(accessibilityValue)
    }

    private var fill: Color {
        switch state {
        case .idle: Palette.card
        case .selected: Palette.elevatedCardBackground
        case .matched: Palette.success.opacity(0.08)
        }
    }

    private var stroke: Color {
        switch state {
        case .idle: Palette.cardBorder
        case .selected: Palette.gold
        case .matched: Palette.success.opacity(0.45)
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .idle: ""
        case .selected: "selected"
        case .matched: "matched"
        }
    }
}
