import SwiftUI
import UIKit

/// The Tasbih tab: a dhikr counter for remembrance. Two modes:
/// • Adhkar — the after-prayer flow, SubhanAllah ×33 → Alhamdulillah ×33 →
///   Allahu Akbar ×34, celebrating at 100.
/// • Custom — count toward any goal you choose (presets or a stepper). It's a plain
///   running tally that never loops back to zero; only Reset clears it.
///
/// All progress is persisted (each mode separately) and only ever cleared by the
/// Reset button — leaving the tab, switching modes, changing the target, or
/// relaunching the app never resets the count.
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

    private enum Mode: String { case adhkar, custom }

    @AppStorage("duhaa.tasbih.mode") private var modeRaw = Mode.adhkar.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped when a goal is reached — pulses the dial once in celebration.
    @State private var completionPulse = 0
    @AppStorage("duhaa.tasbih.target") private var customTarget = 33

    // Adhkar progress (persisted, kept separate from Custom).
    @AppStorage("duhaa.tasbih.adhkar.phase") private var aPhase = 0
    @AppStorage("duhaa.tasbih.adhkar.count") private var aCount = 0
    @AppStorage("duhaa.tasbih.adhkar.total") private var aTotal = 0
    @AppStorage("duhaa.tasbih.adhkar.completed") private var aCompleted = false

    // Custom progress — a single running tally (persisted). Counts up freely and is
    // only ever cleared by Reset (no looping back to zero at the target).
    @AppStorage("duhaa.tasbih.custom.count") private var cCount = 0

    private var mode: Mode { Mode(rawValue: modeRaw) ?? .adhkar }
    private var phase: Dhikr { phases[max(0, min(aPhase, phases.count - 1))] }
    /// The number the current circle counts to.
    private var target: Int { mode == .adhkar ? phase.target : max(1, customTarget) }
    /// The beads counted in the current circle.
    private var count: Int { mode == .adhkar ? aCount : cCount }
    private var progress: Double {
        if mode == .adhkar && aCompleted { return 1 }
        return min(1, Double(count) / Double(target))
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 20) {
                Text("TASBIH")
                    .duhaaFont(13, .semibold).tracking(3)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .padding(.top, 18)

                modeToggle
                middleSection
                dial
                footer
                Spacer()
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }

    // MARK: Mode toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            toggleButton("Adhkar", .adhkar)
            toggleButton("Custom", .custom)
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().stroke(Palette.cardBorder, lineWidth: 1))
    }

    private func toggleButton(_ title: String, _ m: Mode) -> some View {
        let selected = mode == m
        return Button {
            // Switching modes never resets — each mode keeps its own saved count.
            withAnimation(.spring(duration: 0.3)) { modeRaw = m.rawValue }
        } label: {
            Text(title)
                .duhaaFont(13, .semibold)
                .foregroundStyle(selected ? Palette.onAccent : Palette.blue.opacity(0.85))
                .padding(.horizontal, 24).padding(.vertical, 8)
                .background(selected ? Palette.gold : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) mode")
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    // MARK: Middle — dhikr (Adhkar) or target picker (Custom)

    private var middleSection: some View {
        Group {
            if mode == .adhkar {
                VStack(spacing: 16) {
                    phaseDots
                    dhikrText
                }
            } else {
                targetSelector
            }
        }
        .frame(height: 150)
    }

    private var phaseDots: some View {
        HStack(spacing: 10) {
            ForEach(0..<phases.count, id: \.self) { i in
                let isCurrent = (i == aPhase) && !aCompleted
                let isDone = aCompleted || i < aPhase
                Capsule()
                    .fill(isDone || isCurrent ? Palette.gold : Color.primary.opacity(0.2))
                    .frame(width: isCurrent ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.3), value: aPhase)
        .animation(.spring(duration: 0.3), value: aCompleted)
    }

    private var dhikrText: some View {
        VStack(spacing: 8) {
            Text(phase.arabic)
                .font(QuranFont.uthmani(40))
                .foregroundStyle(Palette.gold)
            Text(phase.latin)
                .duhaaFont(17, .medium)
                .foregroundStyle(.primary)
            Text(phase.meaning)
                .duhaaFont(13)
                .foregroundStyle(Palette.blue.opacity(0.8))
        }
        .frame(height: 110)
    }

    private var targetSelector: some View {
        VStack(spacing: 14) {
            Text("COUNT TO")
                .duhaaFont(11, .semibold).tracking(2)
                .foregroundStyle(Palette.blue.opacity(0.6))

            HStack(spacing: 20) {
                stepButton("minus", enabled: customTarget > 1) { setTarget(customTarget - 1) }
                Text("\(target)")
                    .duhaaFont(42, .light)
                    .foregroundStyle(Palette.gold)
                    .frame(minWidth: 78)
                    .contentTransition(.numericText())
                    .lineLimit(1).minimumScaleFactor(0.5)
                stepButton("plus", enabled: customTarget < 9999) { setTarget(customTarget + 1) }
            }

            HStack(spacing: 8) {
                ForEach([33, 99, 100], id: \.self) { preset in
                    presetChip(preset)
                }
            }
        }
    }

    private func stepButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .duhaaFont(18, .semibold)
                .foregroundStyle(Palette.blue)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.primary.opacity(0.06)))
                .overlay(Circle().stroke(Palette.blue.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func presetChip(_ value: Int) -> some View {
        let selected = customTarget == value
        return Button { setTarget(value) } label: {
            Text("\(value)")
                .duhaaFont(13, .medium)
                .foregroundStyle(selected ? Palette.onAccent : Palette.blue)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(selected ? Palette.gold : Color.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(Palette.blue.opacity(selected ? 0 : 0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Dial

    private var dial: some View {
        Button(action: tap) {
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

                if mode == .adhkar && aCompleted {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark").duhaaFont(44, .light).foregroundStyle(Palette.gold)
                        Text("100").duhaaFont(20, .medium).foregroundStyle(.primary)
                    }
                } else {
                    VStack(spacing: 2) {
                        Text("\(count)")
                            .duhaaFont(76, .thin)
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        Text(mode == .custom && count >= target ? "goal \(target) ✓" : "of \(target)")
                            .duhaaFont(15)
                            .foregroundStyle(Palette.blue.opacity(0.7))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        // One celebratory swell when a goal is reached — mirrors the prayer-mark moment.
        .phaseAnimator([false, true], trigger: completionPulse) { content, swelling in
            content.scaleEffect(swelling && !reduceMotion ? 1.04 : 1)
        } animation: { swelling in
            swelling ? DuhaaMotion.markSwell : DuhaaMotion.markSettle
        }
        .accessibilityLabel("Tasbih counter")
        .accessibilityValue(dialAccessibilityValue)
    }

    private var dialAccessibilityValue: String {
        switch mode {
        case .adhkar:
            let value = "\(phase.latin), \(count) of \(target)"
            return aCompleted ? "\(value), complete" : value
        case .custom:
            return "Custom, \(count) of \(target)"
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 14) {
            if mode == .adhkar && aCompleted {
                Text("Tasbih complete — alhamdulillah.")
                    .duhaaFont(14, .medium)
                    .foregroundStyle(Palette.gold)
            } else if mode == .adhkar {
                Text("Total \(aTotal) / 100")
                    .duhaaFont(14)
                    .foregroundStyle(Palette.blue.opacity(0.8))
                Text("Tap the circle to count")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.5))
            } else {
                if cCount >= target {
                    Text("Goal of \(target) reached 🤍")
                        .duhaaFont(14, .medium)
                        .foregroundStyle(Palette.gold)
                }
                Text("Tap the circle to count")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.5))
            }

            Button(action: reset) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .duhaaFont(14, .medium)
                    .foregroundStyle(Palette.blue)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .overlay(Capsule().stroke(Palette.blue.opacity(0.4), lineWidth: 1))
            }
            .padding(.top, 4)
            .accessibilityLabel("Reset tasbih counter")
        }
    }

    // MARK: Actions

    private func tap() {
        switch mode {
        case .adhkar:
            // A finished tasbih stays finished until Reset — tapping does nothing.
            guard !aCompleted else { return }
            withAnimation { aCount += 1 }
            aTotal += 1
            DuhaaHaptics.count()
            guard aCount >= phase.target else { return }
            DuhaaHaptics.success()
            if aPhase < phases.count - 1 {
                aPhase += 1
                aCount = 0
            } else {
                aCompleted = true
                completionPulse += 1
            }

        case .custom:
            // A plain running tally: counts up and never loops back to zero.
            withAnimation { cCount += 1 }
            DuhaaHaptics.count()
            // Gentle celebration the moment you reach your goal — but keep counting.
            if cCount == target {
                DuhaaHaptics.success()
                completionPulse += 1
            }
        }
    }

    /// Changing the target does NOT reset the count (only the Reset button does).
    private func setTarget(_ value: Int) {
        let clamped = min(max(value, 1), 9999)
        guard clamped != customTarget else { return }
        withAnimation { customTarget = clamped }
        DuhaaHaptics.count()
    }

    /// The only thing that clears the count — and only for the mode in view.
    private func reset() {
        withAnimation {
            switch mode {
            case .adhkar:
                aPhase = 0; aCount = 0; aTotal = 0; aCompleted = false
            case .custom:
                cCount = 0
            }
        }
        DuhaaHaptics.reset()
    }
}
