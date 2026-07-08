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
    @State private var showingTargetEntry = false
    @State private var targetDraft = "33"
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
        GeometryReader { proxy in
            let layout = TasbihScreenLayout(size: proxy.size)

            ZStack {
                CelestialBackground()

                ScrollView {
                    content(layout: layout)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(0, proxy.size.height - layout.tabBarClearance),
                               alignment: .top)
                        .padding(.bottom, layout.tabBarClearance)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .sheet(isPresented: $showingTargetEntry) {
            TasbihTargetKeypadSheet(draft: $targetDraft, maxTarget: 9999) { value in
                setTarget(value)
                showingTargetEntry = false
            } onCancel: {
                showingTargetEntry = false
            }
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.pageBg)
            .preferredColorScheme(Palette.active.colorScheme)
        }
    }

    private func content(layout: TasbihScreenLayout) -> some View {
        VStack(spacing: layout.spacing) {
            Text("TASBIH")
                .duhaaFont(13, .semibold).tracking(3)
                .foregroundStyle(Palette.blue.opacity(0.7))
                .padding(.top, layout.titleTopPadding)

            modeToggle
            middleSection(layout: layout)
            dial(layout: layout)
            footer(layout: layout)
            Spacer(minLength: 0)
            fingerNote
        }
        .padding(.horizontal, 20)
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

    private func middleSection(layout: TasbihScreenLayout) -> some View {
        Group {
            if mode == .adhkar {
                VStack(spacing: layout.dhikrGroupSpacing) {
                    phaseDots
                    dhikrText(layout: layout)
                }
            } else {
                targetSelector
            }
        }
        .frame(height: mode == .adhkar ? layout.adhkarMiddleHeight : layout.customMiddleHeight)
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

    private func dhikrText(layout: TasbihScreenLayout) -> some View {
        VStack(spacing: layout.dhikrTextSpacing) {
            Text(phase.arabic)
                .font(QuranFont.uthmani(layout.arabicFontSize))
                .foregroundStyle(Palette.gold)
            Text(phase.latin)
                .duhaaFont(layout.latinFontSize, .medium)
                .foregroundStyle(.primary)
            Text(phase.meaning)
                .duhaaFont(layout.meaningFontSize)
                .foregroundStyle(Palette.blue.opacity(0.8))
        }
        .frame(height: layout.dhikrTextHeight)
    }

    private var targetSelector: some View {
        VStack(spacing: 10) {
            Text("COUNT TO")
                .duhaaFont(11, .semibold).tracking(2)
                .foregroundStyle(Palette.blue.opacity(0.6))

            HStack(spacing: 18) {
                stepButton("minus", enabled: customTarget > 1) { setTarget(customTarget - 1) }
                targetNumberButton
                stepButton("plus", enabled: customTarget < 9999) { setTarget(customTarget + 1) }
            }

            Button { openTargetEntry() } label: {
                Label("Type any goal — like 200", systemImage: "keyboard")
                    .duhaaFont(12, .medium)
                    .foregroundStyle(Palette.blue)
                    .padding(.vertical, 7).padding(.horizontal, 14)
                    .background(Capsule().fill(Palette.blue.opacity(0.10)))
                    .overlay(Capsule().stroke(Palette.blue.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Type a custom goal")
            .accessibilityHint("Opens a keypad to enter any number")

            HStack(spacing: 8) {
                ForEach([33, 99, 100], id: \.self) { preset in
                    presetChip(preset)
                }
            }
        }
    }

    private var targetNumberButton: some View {
        Button {
            openTargetEntry()
        } label: {
            Text("\(target)")
                .duhaaFont(42, .light)
                .foregroundStyle(Palette.gold)
                .frame(minWidth: 88, minHeight: 54)
                .padding(.horizontal, 8)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.gold.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.gold.opacity(0.26), lineWidth: 1))
                // A small pencil badge signals the number itself is tappable to edit.
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "pencil")
                        .duhaaFont(10, .semibold)
                        .foregroundStyle(Palette.onAccent)
                        .padding(4)
                        .background(Circle().fill(Palette.gold))
                        .offset(x: 6, y: -6)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Custom target")
        .accessibilityValue("\(target)")
        .accessibilityHint("Double tap to enter a custom number")
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

    private func dial(layout: TasbihScreenLayout) -> some View {
        Button(action: tap) {
            ZStack {
                Circle()
                    .stroke(Palette.gold.opacity(0.12), lineWidth: layout.dialLineWidth)
                    .frame(width: layout.dialSize, height: layout.dialSize)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Palette.gold, style: StrokeStyle(lineWidth: layout.dialLineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: layout.dialSize, height: layout.dialSize)
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
                            .duhaaFont(layout.counterFontSize, .thin)
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

    private func footer(layout: TasbihScreenLayout) -> some View {
        VStack(spacing: layout.footerSpacing) {
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
            .padding(.top, layout.resetTopPadding)
            .accessibilityLabel("Reset tasbih counter")
        }
    }

    /// A quiet, sourced reminder that the Sunnah is to count dhikr on the fingers.
    private var fingerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.point.up.left")
                .duhaaFont(11)
            Text("Sunnah to count on your fingers · Abū Dāwūd 1502")
                .duhaaFont(11)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Palette.blue.opacity(0.5))
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("It is Sunnah to count dhikr on your fingers. Source: Abu Dawud, hadith 1502.")
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

    private func openTargetEntry() {
        targetDraft = "\(target)"
        showingTargetEntry = true
        DuhaaHaptics.tap()
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

private struct TasbihScreenLayout {
    let spacing: CGFloat
    let titleTopPadding: CGFloat
    let adhkarMiddleHeight: CGFloat
    let customMiddleHeight: CGFloat
    let dhikrGroupSpacing: CGFloat
    let dhikrTextSpacing: CGFloat
    let dhikrTextHeight: CGFloat
    let arabicFontSize: CGFloat
    let latinFontSize: CGFloat
    let meaningFontSize: CGFloat
    let dialSize: CGFloat
    let dialLineWidth: CGFloat
    let counterFontSize: CGFloat
    let footerSpacing: CGFloat
    let resetTopPadding: CGFloat
    let tabBarClearance: CGFloat

    init(size: CGSize) {
        let compact = size.height < 820 || size.width <= 375
        let veryCompact = size.height < 720
        let availableWidth = max(0, size.width - 88)

        spacing = veryCompact ? 10 : (compact ? 14 : 20)
        titleTopPadding = compact ? 8 : 18
        adhkarMiddleHeight = veryCompact ? 118 : (compact ? 128 : 150)
        customMiddleHeight = veryCompact ? 142 : (compact ? 148 : 150)
        dhikrGroupSpacing = compact ? 12 : 16
        dhikrTextSpacing = compact ? 6 : 8
        dhikrTextHeight = veryCompact ? 96 : (compact ? 102 : 110)
        arabicFontSize = veryCompact ? 32 : (compact ? 35 : 40)
        latinFontSize = compact ? 16 : 17
        meaningFontSize = compact ? 12 : 13
        dialSize = min(veryCompact ? 198 : (compact ? 218 : 250), availableWidth)
        dialLineWidth = veryCompact ? 12 : (compact ? 14 : 16)
        counterFontSize = veryCompact ? 58 : (compact ? 66 : 76)
        footerSpacing = compact ? 10 : 14
        resetTopPadding = compact ? 0 : 4
        // The floating tab bar overlays full-bleed tab content on compact phones.
        tabBarClearance = veryCompact ? 124 : (compact ? 132 : 150)
    }
}

private struct TasbihTargetKeypadSheet: View {
    @Binding var draft: String
    let maxTarget: Int
    let onSave: (Int) -> Void
    let onCancel: () -> Void
    @State private var shouldReplaceDraft = true

    private let rows = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9]
    ]

    private var displayText: String {
        draft.isEmpty ? "0" : draft
    }

    private var parsedValue: Int? {
        guard let value = Int(draft), value > 0 else { return nil }
        return min(value, maxTarget)
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            display
            keypad
            doneButton
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
        .background(Palette.pageBg.ignoresSafeArea())
        .onAppear { shouldReplaceDraft = true }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CUSTOM GOAL")
                    .duhaaFont(11, .semibold).tracking(2)
                    .foregroundStyle(Palette.blue.opacity(0.65))
                Text("Enter any number from 1 to \(maxTarget).")
                    .duhaaFont(13)
                    .foregroundStyle(Palette.blue.opacity(0.72))
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .duhaaFont(14, .semibold)
                    .foregroundStyle(Palette.blue)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close custom goal keypad")
        }
    }

    private var display: some View {
        Text(displayText)
            .duhaaFont(52, .light)
            .foregroundStyle(parsedValue == nil ? Palette.blue.opacity(0.45) : Palette.gold)
            .frame(maxWidth: .infinity, minHeight: 72)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.card))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.cardBorder, lineWidth: 1))
            .accessibilityLabel("Entered custom goal")
            .accessibilityValue(displayText)
    }

    private var keypad: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        digitButton(digit)
                    }
                }
            }

            HStack(spacing: 10) {
                iconButton("xmark") { clearDraft() }
                    .accessibilityLabel("Clear")
                digitButton(0)
                iconButton("delete.left") { deleteLastDigit() }
                    .accessibilityLabel("Delete last digit")
            }
        }
    }

    private var doneButton: some View {
        Button {
            guard let parsedValue else { return }
            onSave(parsedValue)
        } label: {
            Label("Done", systemImage: "checkmark")
                .duhaaFont(15, .semibold)
                .foregroundStyle(parsedValue == nil ? Palette.blue.opacity(0.45) : Palette.onAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(parsedValue == nil ? Color.primary.opacity(0.06) : Palette.gold)
                )
        }
        .buttonStyle(.plain)
        .disabled(parsedValue == nil)
        .accessibilityLabel("Save custom goal")
    }

    private func digitButton(_ digit: Int) -> some View {
        Button {
            appendDigit(digit)
        } label: {
            Text("\(digit)")
                .duhaaFont(24, .medium)
                .foregroundStyle(Palette.primaryText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Digit \(digit)")
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .duhaaFont(18, .medium)
                .foregroundStyle(Palette.blue)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func appendDigit(_ digit: Int) {
        let maxDigits = String(maxTarget).count
        if shouldReplaceDraft {
            draft = ""
            shouldReplaceDraft = false
        }
        guard draft.count < maxDigits else { return }
        if draft == "0" {
            draft = "\(digit)"
        } else {
            draft.append(String(digit))
        }
        if let value = Int(draft), value > maxTarget {
            draft = "\(maxTarget)"
        }
        DuhaaHaptics.count()
    }

    private func deleteLastDigit() {
        guard !draft.isEmpty else { return }
        shouldReplaceDraft = false
        draft.removeLast()
        DuhaaHaptics.count()
    }

    private func clearDraft() {
        guard !draft.isEmpty else { return }
        shouldReplaceDraft = false
        draft = ""
        DuhaaHaptics.tap()
    }
}
