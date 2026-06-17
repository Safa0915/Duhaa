import SwiftUI

struct NotificationOptInView: View {
    let onEnable: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        ZStack {
            Palette.appBg.ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Palette.gold.opacity(0.34), .clear],
                                             center: .center, startRadius: 0, endRadius: 70))
                        .frame(width: 132, height: 132)
                    Image(systemName: "bell.badge.fill")
                        .duhaaFont(46, .semibold)
                        .foregroundStyle(Palette.gold)
                        .shadow(color: Palette.gold.opacity(0.35), radius: 12)
                }
                .frame(height: 108)

                VStack(spacing: 8) {
                    Text("Gentle prayer reminders?")
                        .duhaaFont(24, .semibold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Duhaa can remind you when each prayer comes in. You can make any prayer silent or turn it off later in Settings.")
                        .duhaaFont(14)
                        .foregroundStyle(Palette.blue.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 16)
                }

                VStack(spacing: 10) {
                    Button(action: onEnable) {
                        Label("Enable Reminders", systemImage: "bell.fill")
                            .duhaaFont(16, .semibold)
                            .foregroundStyle(Palette.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Palette.gold, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onNotNow) {
                        Text("Not Now")
                            .duhaaFont(15, .semibold)
                            .foregroundStyle(Palette.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Palette.card, in: Capsule())
                            .overlay(Capsule().stroke(Palette.cardBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)

                Text("No ads, no guilt, no spam. Just the reminders you choose.")
                    .duhaaFont(12)
                    .foregroundStyle(.primary.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }
}

#Preview {
    NotificationOptInView(onEnable: {}, onNotNow: {})
}
