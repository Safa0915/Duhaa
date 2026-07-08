import SwiftUI

/// Match terms to their meanings. Pairs come from the study set's `name_pair`
/// cards; the meanings column is shuffled once per visit. Falls back to the
/// Allah's Names pairs when the set has none of its own.
struct MatchModeView: View {
    private let pairs: [MatchPair]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var meaningTiles: [MatchPair]
    @State private var matched: Set<String> = []
    @State private var selectedName: String?
    @State private var selectedMeaning: String?

    init(pairs: [MatchPair]? = nil) {
        // Keep the grid calm: at most four pairs per round.
        let resolved: [MatchPair]
        if let pairs, !pairs.isEmpty {
            resolved = Array(pairs.prefix(4))
        } else {
            resolved = Array((Essentials.allahNames?.namePairs ?? []).prefix(4))
        }
        self.pairs = resolved
        _meaningTiles = State(initialValue: resolved.shuffled())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Match each term to its meaning")
                    .duhaaFont(14)
                    .foregroundStyle(.primary.opacity(0.66))

                if pairs.isEmpty {
                    Text("No pairs to match in this set yet")
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        column(header: "Names", tiles: pairs, isNameColumn: true)
                        column(header: "Meanings", tiles: meaningTiles, isNameColumn: false)
                    }
                }

                if !pairs.isEmpty, matched.count == pairs.count {
                    Text("All matched — beautifully done.")
                        .duhaaFont(13, .medium)
                        .foregroundStyle(Palette.success)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .duhaaReadableWidth()
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !pairs.isEmpty { footerButtons }
        }
    }

    private func column(header: String, tiles: [MatchPair], isNameColumn: Bool) -> some View {
        VStack(spacing: 10) {
            Text(header.uppercased())
                .duhaaFont(11, .semibold)
                .tracking(1)
                .foregroundStyle(Palette.blue.opacity(0.75))
                .accessibilityAddTraits(.isHeader)

            ForEach(tiles) { pair in
                MatchTile(text: isNameColumn ? pair.name : pair.meaning,
                          state: tileState(pair.id, isNameColumn: isNameColumn)) {
                    select(pair.id, isNameColumn: isNameColumn)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tileState(_ id: String, isNameColumn: Bool) -> MatchTileState {
        if matched.contains(id) { return .matched }
        let selection = isNameColumn ? selectedName : selectedMeaning
        return selection == id ? .selected : .idle
    }

    private func select(_ id: String, isNameColumn: Bool) {
        DuhaaHaptics.tap()
        if isNameColumn { selectedName = id } else { selectedMeaning = id }
        tryMatch()
    }

    private func tryMatch() {
        guard let name = selectedName, let meaning = selectedMeaning else { return }
        if name == meaning {
            DuhaaHaptics.success()
            if reduceMotion {
                matched.insert(name)
            } else {
                withAnimation(DuhaaMotion.markSettle) { _ = matched.insert(name) }
            }
        }
        selectedName = nil
        selectedMeaning = nil
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button {
                DuhaaHaptics.reset()
                matched = []
                selectedName = nil
                selectedMeaning = nil
                meaningTiles = pairs.shuffled()
            } label: {
                Text("Reset")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(.primary.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Palette.card))
                    .overlay(Capsule().stroke(Palette.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.duhaaPress)

            Button {
                dismiss()
            } label: {
                Text("Finish")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Palette.gold))
            }
            .buttonStyle(.duhaaPress)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .duhaaReadableWidth()
        .background(Palette.appBg.opacity(0.92))
    }
}
