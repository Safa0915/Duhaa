import SwiftUI

/// Multiple-choice study ("Learn", "Test", and the Review Missed queue).
/// Answers are checked against the card model and recorded in the local
/// progress store. The answer result is a state of this screen
/// (Quizlet-style), not a separate push.
struct LearnQuizView: View {
    let title: String
    let chipText: String
    let chipIcon: String
    let cards: [EssentialsCard]
    var isTest = false

    init(title: String, chipText: String, chipIcon: String,
         cards: [EssentialsCard], isTest: Bool = false) {
        self.title = title
        self.chipText = chipText
        self.chipIcon = chipIcon
        self.cards = cards
        self.isTest = isTest
    }

    init(set: StudySet, isTest: Bool = false) {
        self.init(title: isTest ? "Test" : "Learn",
                  chipText: set.title,
                  chipIcon: set.icon,
                  cards: set.cards(for: isTest ? .test : .learn),
                  isTest: isTest)
    }

    @Environment(EssentialsProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var selected: Int?
    @State private var checked = false

    private let letters = ["A", "B", "C", "D"]

    private var questions: [EssentialsCard] {
        cards.filter(\.isMultipleChoice)
    }

    private var question: EssentialsCard? {
        questions.indices.contains(index) ? questions[index] : nil
    }

    private var isCorrect: Bool {
        guard let question, let selected else { return false }
        return question.isCorrectChoice(selected)
    }

    var body: some View {
        Group {
            if let question {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        progressHeader
                        pills(for: question)
                        questionCard(question)
                        options(question)

                        if checked {
                            QuizAnswerResultView(isCorrect: isCorrect,
                                                 answer: question.answer,
                                                 explanation: question.explanation,
                                                 sourceNote: question.sourceSummary,
                                                 sourceCitation: question.sourceReference?.text,
                                                 status: question.reviewStatus)
                                .transition(reduceMotion
                                            ? .opacity
                                            : .opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .duhaaReadableWidth()
                }
                .scrollIndicators(.hidden)
            } else {
                emptyState
            }
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if question != nil { bottomButton }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question \(index + 1) of \(questions.count)")
                .duhaaFont(12, .medium)
                .foregroundStyle(.primary.opacity(0.55))
            EssentialsProgressBar(fraction: Double(index) / Double(max(questions.count, 1)))
        }
        .accessibilityElement(children: .combine)
    }

    private func pills(for question: EssentialsCard) -> some View {
        FlowLayout(spacing: 6) {
            LearnChip(text: chipText, systemImage: chipIcon, tint: Palette.blue)
            LearnChip(text: isTest ? "Test" : "Learn",
                      systemImage: isTest ? "checklist" : "lightbulb",
                      tint: Palette.gold)
            LearnChip(text: question.difficulty.label, systemImage: "leaf", tint: Palette.blue)
        }
    }

    private func questionCard(_ question: EssentialsCard) -> some View {
        Text(question.prompt)
            .duhaaFont(19, .semibold)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .duhaaCardStyle()
    }

    private func options(_ question: EssentialsCard) -> some View {
        VStack(spacing: 10) {
            ForEach(Array((question.choices ?? []).enumerated()), id: \.offset) { i, choice in
                QuizOptionButton(letter: letters.indices.contains(i) ? letters[i] : "\(i + 1)",
                                 text: choice,
                                 state: optionState(i, question: question)) {
                    guard !checked else { return }
                    selected = i
                    DuhaaHaptics.tap()
                }
            }
        }
    }

    private func optionState(_ i: Int, question: EssentialsCard) -> QuizOptionState {
        if checked {
            if question.isCorrectChoice(i) { return .correct }
            if i == selected { return .incorrect }
            return .idle
        }
        return i == selected ? .selected : .idle
    }

    private var bottomButton: some View {
        Button {
            checked ? next() : check()
        } label: {
            Text(buttonTitle)
                .duhaaFont(16, .semibold)
                .foregroundStyle(selected == nil ? Palette.onAccent.opacity(0.6) : Palette.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Palette.gold.opacity(selected == nil ? 0.45 : 1)))
        }
        .buttonStyle(.duhaaPress)
        .disabled(selected == nil)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .duhaaReadableWidth()
        .background(Palette.appBg.opacity(0.92))
    }

    private var buttonTitle: String {
        if !checked { return "Check Answer" }
        return index + 1 < questions.count ? "Next Question" : "Done"
    }

    private func check() {
        guard let question, let selected else { return }
        let correct = question.isCorrectChoice(selected)
        progress.recordAnswer(cardID: question.id, correct: correct)

        if reduceMotion {
            checked = true
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { checked = true }
        }
        if correct { DuhaaHaptics.success() } else { DuhaaHaptics.tap() }
    }

    private func next() {
        guard index + 1 < questions.count else {
            dismiss()
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            index += 1
            selected = nil
            checked = false
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lightbulb")
                .duhaaFont(24)
                .foregroundStyle(Palette.gold.opacity(0.8))
            Text("No questions in this set yet")
                .duhaaFont(16, .semibold)
                .foregroundStyle(.primary)
            Text("Try Flashcards instead.")
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.62))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The gentle answer panel shown after checking: correct/keep-reviewing state,
/// the answer, an explanation, and where it comes from.
struct QuizAnswerResultView: View {
    let isCorrect: Bool
    let answer: String
    var explanation: String?
    var sourceNote: String?
    var sourceCitation: String?
    var status: ReviewStatus = .needsReview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle")
                    .duhaaFont(24)
                    .foregroundStyle(isCorrect ? Palette.success : Palette.gold)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isCorrect ? "Correct" : "Not quite — it stays in review")
                        .duhaaFont(17, .semibold)
                        .foregroundStyle(.primary)
                    Text(answer)
                        .duhaaFont(14, .medium)
                        .foregroundStyle(Palette.gold)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let explanation {
                Text(explanation)
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let sourceNote {
                SourceNoteCard(note: sourceNote, citation: sourceCitation, status: status)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .duhaaCardStyle(
            fill: isCorrect ? Palette.success.opacity(0.07) : Palette.gold.opacity(0.06),
            stroke: isCorrect ? Palette.success.opacity(0.35) : Palette.gold.opacity(0.3))
        .accessibilityElement(children: .combine)
    }
}
