import SwiftUI
import UIKit

/// The Tasbih tab: a dhikr counter for after-prayer remembrance. Tap the dial to
/// count; it advances SubhanAllah ×33 → Alhamdulillah ×33 → Allahu Akbar ×34 with
/// gentle haptics, and celebrates at 100.
struct TasbihView: View {
    private struct Dhikr {
        let arabic: String
        let latin: String
        let meaning: String
        let target: Int
    }

    private let phases: [Dhikr] = [
        Dhikr(arabic: "سُبْحَانَ ٱللَّهِ", latin: "SubhanAllah", meaning: "Glory be to Allah", target: 33),
        Dhikr(arabic: "ٱلْحَمْدُ لِلَّهِ", latin: "Alhamdulillah", meaning: "All praise is due to Allah", target: 33),
        Dhikr(arabic: "ٱللَّهُ أَكْبَرُ", latin: "Allahu Akbar", meaning: "Allah is the Greatest", target: 34),
    ]

    @State private var phaseIndex = 0
    @State private var count = 0
    @State private var total = 0
    @State private var completed = false

    private var phase: Dhikr { phases[min(phaseIndex, phases.count - 1)] }
    private var progress: Double { completed ? 1 : Double(count) / Double(phase.target) }

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 22) {
                Text("TASBIH")
                    .duhaFont(13, .semibold).tracking(3)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .padding(.top, 20)

                phaseDots
                dhikrText
                dial
                footer
                Spacer()
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }

    private var phaseDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<phases.count, id: \.self) { i in
                let isCurrent = (i == phaseIndex) && !completed
                let isDone = completed || i < phaseIndex
                Capsule()
                    .fill(isDone || isCurrent ? Palette.gold : Color.primary.opacity(0.2))
                    .frame(width: isCurrent ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.3), value: phaseIndex)
        .animation(.spring(duration: 0.3), value: completed)
    }

    private var dhikrText: some View {
        VStack(spacing: 8) {
            Text(phase.arabic)
                .font(QuranFont.uthmani(40))
                .foregroundStyle(Palette.gold)
            Text(phase.latin)
                .duhaFont(17, .medium)
                .foregroundStyle(.primary)
            Text(phase.meaning)
                .duhaFont(13)
                .foregroundStyle(Palette.blue.opacity(0.8))
        }
        .frame(height: 110)
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(Palette.gold.opacity(0.12), lineWidth: 16)
                .frame(width: 250, height: 250)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Palette.gold, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 250, height: 250)
                .shadow(color: Palette.gold.opacity(0.4), radius: 8)
                .animation(.easeOut(duration: 0.25), value: progress)

            if completed {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark").duhaFont(44, .light).foregroundStyle(Palette.gold)
                    Text("100").duhaFont(20, .medium).foregroundStyle(.primary)
                }
            } else {
                VStack(spacing: 2) {
                    Text("\(count)")
                        .duhaFont(76, .thin)
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text("of \(phase.target)")
                        .duhaFont(15)
                        .foregroundStyle(Palette.blue.opacity(0.7))
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture { tap() }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            if completed {
                Text("Tasbih complete — alhamdulillah.")
                    .duhaFont(14, .medium)
                    .foregroundStyle(Palette.gold)
            } else {
                Text("Total \(total) / 100")
                    .duhaFont(14)
                    .foregroundStyle(Palette.blue.opacity(0.8))
                Text("Tap the circle to count")
                    .duhaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.5))
            }

            Button(action: reset) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .duhaFont(14, .medium)
                    .foregroundStyle(Palette.blue)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .overlay(Capsule().stroke(Palette.blue.opacity(0.4), lineWidth: 1))
            }
            .padding(.top, 4)
        }
    }

    private func tap() {
        if completed { reset(); return }
        withAnimation { count += 1 }
        total += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if count >= phase.target {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if phaseIndex < phases.count - 1 {
                phaseIndex += 1
                count = 0
            } else {
                completed = true
            }
        }
    }

    private func reset() {
        withAnimation {
            phaseIndex = 0
            count = 0
            total = 0
            completed = false
        }
    }
}
