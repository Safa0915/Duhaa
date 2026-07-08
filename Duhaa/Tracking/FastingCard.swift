import SwiftUI

/// A gentle home-screen card that surfaces fasting only when it's relevant: on a
/// recommended Sunnah fast day (Monday / Thursday / white day) or when make-up
/// (qaḍāʾ) fasts are still owed. Tapping the header opens the full Fasting screen.
struct FastingCard: View {
    @Environment(FastingTracker.self) private var fasting
    @Environment(QadaFasts.self) private var qada

    let dayKey: String
    /// Today's recommended-fast reasons (empty when today isn't a Sunnah fast day).
    let kinds: [VoluntaryFastKind]
    let onOpen: () -> Void

    private var fastedToday: Bool { fasting.isFasted(dayKey) }
    private var recommended: Bool { !kinds.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpen) {
                HStack {
                    Label("FASTING", systemImage: "moon.stars")
                        .duhaaFont(11, .semibold).tracking(1.2)
                        .foregroundStyle(Palette.gold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .duhaaFont(12).foregroundStyle(Palette.blue.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            if recommended {
                Text(kinds.first?.title ?? "Sunnah fast today")
                    .duhaaFont(17, .semibold).foregroundStyle(.primary)
                fastingToggle
            }

            if qada.owed > 0 {
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .duhaaFont(14).foregroundStyle(Palette.blue.opacity(0.85))
                        Text("\(qada.owed) make-up fast\(qada.owed == 1 ? "" : "s") to go")
                            .duhaaFont(13).foregroundStyle(Palette.blue.opacity(0.85))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .duhaaGradientCardStyle(
            colors: [Palette.gold.opacity(0.14), Palette.gold.opacity(0.05)],
            stroke: Palette.gold.opacity(0.32)
        )
    }

    private var fastingToggle: some View {
        Button {
            fasting.toggle(dayKey)
            DuhaaHaptics.tap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: fastedToday ? "checkmark.circle.fill" : "circle")
                    .duhaaFont(20)
                    .foregroundStyle(fastedToday ? Palette.gold : Color.primary.opacity(0.3))
                    .symbolEffect(.bounce, value: fastedToday)
                Text(fastedToday ? "Fasting logged today — taqabbal Allah 🤍" : "I'm fasting today")
                    .duhaaFont(14, .medium).foregroundStyle(.primary)
                Spacer()
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
