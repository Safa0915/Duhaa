import SwiftUI

/// Front/back flashcards. Tap (or "Reveal") flips the card — a calm 3D flip,
/// or a plain crossfade under Reduce Motion.
struct FlashcardStudyView: View {
    let title: String
    let cards: [EssentialsCard]

    init(title: String, cards: [EssentialsCard]) {
        self.title = title
        self.cards = cards
    }

    init(set: StudySet) {
        self.init(title: set.title, cards: set.cards(for: .flashcards))
    }

    @Environment(EssentialsProgressStore.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var revealed = false

    private var card: EssentialsCard? {
        cards.indices.contains(index) ? cards[index] : nil
    }

    var body: some View {
        VStack(spacing: 20) {
            if let card {
                Text("Card \(index + 1) of \(cards.count)")
                    .duhaaFont(12, .medium)
                    .foregroundStyle(.primary.opacity(0.55))

                flashcard(card)

                Spacer(minLength: 0)

                controls
            } else {
                Spacer()
                Text("No cards in this set yet")
                    .duhaaFont(16, .semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .padding(18)
        .duhaaReadableWidth()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func flashcard(_ card: EssentialsCard) -> some View {
        ZStack {
            face {
                VStack(spacing: 14) {
                    if let arabic = card.arabic {
                        Text(arabic)
                            .font(QuranFont.uthmani(34))
                            .foregroundStyle(.primary)
                    }
                    Text(card.prompt)
                        .duhaaFont(20, .semibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    Text("Tap to reveal the answer")
                        .duhaaFont(12)
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }
            .opacity(revealed ? 0 : 1)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : (revealed ? 180 : 0)),
                              axis: (x: 0, y: 1, z: 0))

            face {
                VStack(spacing: 12) {
                    Text("ANSWER")
                        .duhaaFont(11, .semibold)
                        .tracking(1)
                        .foregroundStyle(Palette.gold.opacity(0.9))
                    Text(card.answer)
                        .duhaaFont(19, .semibold)
                        .foregroundStyle(Palette.gold)
                        .multilineTextAlignment(.center)
                    if let citation = card.sourceReference?.text {
                        Text(citation)
                            .duhaaFont(11.5, .medium)
                            .foregroundStyle(Palette.blue.opacity(0.75))
                    }
                }
            }
            .opacity(revealed ? 1 : 0)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : (revealed ? 0 : -180)),
                              axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 320)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { toggleReveal() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(revealed
                            ? "Answer: \(card.answer)"
                            : "\(card.prompt). Tap to reveal the answer.")
        .accessibilityAddTraits(.isButton)
    }

    private func face<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 320)
            .duhaaCardStyle(cornerRadius: 24, fill: Palette.elevatedCardBackground)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                record(knewIt: false)
                advance()
            } label: {
                Text("Still learning")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(.primary.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Palette.card))
                    .overlay(Capsule().stroke(Palette.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.duhaaPress)

            Button {
                if revealed {
                    record(knewIt: true)
                    advance()
                } else {
                    toggleReveal()
                }
            } label: {
                Text(revealed ? "Got it" : "Reveal")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Palette.gold))
            }
            .buttonStyle(.duhaaPress)
        }
    }

    private func toggleReveal() {
        if reduceMotion {
            revealed.toggle()
        } else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { revealed.toggle() }
        }
        DuhaaHaptics.tap()
    }

    private func record(knewIt: Bool) {
        guard let card else { return }
        progress.recordFlashcard(cardID: card.id, knewIt: knewIt)
    }

    /// Move to the next card (wrapping) with no flip-back animation.
    private func advance() {
        DuhaaHaptics.tap()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            revealed = false
            index = cards.isEmpty ? 0 : (index + 1) % cards.count
        }
    }
}
