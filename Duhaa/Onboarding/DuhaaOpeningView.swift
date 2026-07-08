import AudioToolbox
import AVFoundation
import SwiftUI

/// The first-launch "Duhaa moment": the user chooses the dawn, then the app
/// moves from held darkness into the morning brightness before setup begins.
struct DuhaaOpeningView: View {
    enum Phase {
        case waitingForTaps
        case holdingDarkness
        case basmala
        case dawn
        case settled
    }

    var isReplay = false
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tapCount = 0
    @State private var phase = Phase.waitingForTaps
    @State private var showSkip = false
    @State private var showBasmala = false
    @State private var showDuhaaVerse = false
    @State private var showHopeLine = false
    @State private var showFinishButton = false
    @State private var lightProgress = 0.0
    @State private var sequenceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            OpeningDawnBackground(progress: lightProgress)

            Group {
                switch phase {
                case .waitingForTaps:
                    tapPrompt
                case .holdingDarkness:
                    Color.clear
                case .basmala, .dawn, .settled:
                    revelationContent
                }
            }
            .padding(.horizontal, 28)

            skipButton
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .task { await revealSkipAfterDelay() }
        .onDisappear {
            sequenceTask?.cancel()
            DuhaaOpeningAudio.stopAll()
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
    }

    private var tapPrompt: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("tap three times")
                .duhaaFont(18, .medium)
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.58))
                .textCase(.lowercase)

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < tapCount ? OpeningColors.gold : Color.white.opacity(0.16))
                        .frame(width: index < tapCount ? 10 : 8,
                               height: index < tapCount ? 10 : 8)
                        .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
                        .shadow(color: OpeningColors.gold.opacity(index < tapCount ? 0.5 : 0),
                                radius: 8)
                }
            }
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: tapCount)
            .accessibilityHidden(true)

            Spacer()
        }
        .accessibilityLabel("Tap three times to begin")
    }

    private var revelationContent: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                if showBasmala {
                    Text("بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ")
                        .duhaaFont(25, .medium)
                        .foregroundStyle(Color.white.opacity(0.86))
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .accessibilityLabel("Bismillahir Rahmanir Raheem")
                }

                if showDuhaaVerse {
                    VStack(spacing: 16) {
                        Text("وَالضُّحَىٰ")
                            .duhaaFont(64, .semibold)
                            .foregroundStyle(OpeningColors.gold)
                            .shadow(color: OpeningColors.gold.opacity(0.75), radius: 30)
                            .minimumScaleFactor(0.72)

                        Text("By the morning brightness")
                            .duhaaFont(18, .medium)
                            .tracking(0.6)
                            .foregroundStyle(Color.white.opacity(0.84))
                            .multilineTextAlignment(.center)

                        if showHopeLine {
                            Text("Your Lord has not forsaken you.")
                                .duhaaFont(17, .semibold)
                                .foregroundStyle(OpeningColors.blue.opacity(0.95))
                                .multilineTextAlignment(.center)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Surah Ad-Duhaa. By the morning brightness. Your Lord has not forsaken you.")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)

            Spacer()

            if showFinishButton {
                Button(action: finish) {
                    Text(isReplay ? "Done" : "Continue")
                        .duhaaFont(17, .semibold)
                        .foregroundStyle(OpeningColors.onGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(OpeningColors.gold, in: Capsule())
                        .shadow(color: OpeningColors.gold.opacity(0.35), radius: 18)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .padding(.bottom, 28)
            }
        }
    }

    @ViewBuilder
    private var skipButton: some View {
        if showSkip && !showFinishButton {
            VStack {
                HStack {
                    Spacer()
                    Button(isReplay ? "Close" : "Skip", action: finish)
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)
            .transition(.opacity)
        }
    }

    private func handleTap() {
        guard phase == .waitingForTaps else { return }
        DuhaaHaptics.tap()
        tapCount = min(3, tapCount + 1)
        if tapCount == 3 {
            startSequence()
        }
    }

    private func startSequence() {
        guard sequenceTask == nil else { return }
        phase = .holdingDarkness

        sequenceTask = Task { @MainActor in
            await wait(reduceMotion ? 0.7 : 1.5)
            guard !Task.isCancelled else { return }

            phase = .basmala
            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.7)) {
                showBasmala = true
            }

            await wait(reduceMotion ? 0.7 : 1.25)
            guard !Task.isCancelled else { return }

            DuhaaOpeningAudio.playLightCue()
            DuhaaOpeningAudio.playRecitationIfAvailable()
            DuhaaHaptics.success()
            phase = .dawn
            withAnimation(.easeOut(duration: reduceMotion ? 0.01 : 1.55)) {
                showBasmala = false
                showDuhaaVerse = true
                lightProgress = 1
            }

            await wait(reduceMotion ? 0.45 : 1.15)
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.9)) {
                showHopeLine = true
            }

            await wait(reduceMotion ? 0.45 : 1.25)
            guard !Task.isCancelled else { return }

            phase = .settled
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                showFinishButton = true
            }
        }
    }

    @MainActor
    private func revealSkipAfterDelay() async {
        await wait(isReplay ? 2.2 : 4.6)
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.45)) {
            showSkip = true
        }
    }

    private func finish() {
        sequenceTask?.cancel()
        DuhaaOpeningAudio.stopAll()
        DuhaaHaptics.tap()
        onFinish()
    }

    private func wait(_ seconds: TimeInterval) async {
        let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private enum OpeningColors {
    static let page = Color.black
    static let deepSky = Color(hex: 0x08111F)
    static let gold = Color(hex: 0xF0C040)
    static let blue = Color(hex: 0x8ECFE8)
    static let onGold = Color(hex: 0x10182A)
}

private struct OpeningDawnBackground: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let longestSide = max(proxy.size.width, proxy.size.height)

            ZStack {
                OpeningColors.page
                OpeningColors.deepSky.opacity(progress)
                OpeningStars(opacity: progress)

                RadialGradient(colors: [
                    OpeningColors.gold.opacity(0.72),
                    OpeningColors.gold.opacity(0.22),
                    .clear
                ], center: .top, startRadius: 0, endRadius: longestSide * 0.72)
                .scaleEffect(0.65 + progress * 0.55, anchor: .top)
                .opacity(progress)

                RadialGradient(colors: [
                    OpeningColors.blue.opacity(0.28),
                    .clear
                ], center: .bottomTrailing, startRadius: 0, endRadius: longestSide * 0.58)
                .opacity(progress)
            }
            .ignoresSafeArea()
        }
    }
}

private struct OpeningStar {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let opacity: Double
    let color: Color
}

private struct OpeningStars: View {
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            for star in OpeningStarFactory.stars {
                let center = CGPoint(x: star.x * size.width, y: star.y * size.height)
                let rect = CGRect(x: center.x - star.radius,
                                  y: center.y - star.radius,
                                  width: star.radius * 2,
                                  height: star.radius * 2)
                context.opacity = star.opacity * opacity
                context.fill(Path(ellipseIn: rect), with: .color(star.color))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private enum OpeningStarFactory {
    static let stars: [OpeningStar] = {
        var rng = OpeningSeededGenerator(seed: 0xD0AA_DA7A)
        return (0..<72).map { index in
            let y = CGFloat(Double.random(in: 0.02...0.86, using: &rng))
            let isGold = index.isMultiple(of: 9)
            let isBlue = index.isMultiple(of: 5)
            return OpeningStar(
                x: CGFloat(Double.random(in: 0.02...0.98, using: &rng)),
                y: y,
                radius: CGFloat(Double.random(in: 0.45...1.45, using: &rng)),
                opacity: Double.random(in: 0.12...0.7, using: &rng) * (1.05 - Double(y) * 0.55),
                color: isGold ? OpeningColors.gold : (isBlue ? OpeningColors.blue : .white)
            )
        }
    }()
}

private struct OpeningSeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

@MainActor
private enum DuhaaOpeningAudio {
    private static var players: [AVAudioPlayer] = []

    static func playLightCue() {
        for fileExtension in ["wav", "caf", "m4a", "mp3"] {
            if playBundled(resource: "duhaa-light-switch", fileExtension: fileExtension) { return }
            if playBundled(resource: "light-switch", fileExtension: fileExtension) { return }
        }

        if playBundled(resource: "duhaa-chime", fileExtension: "wav") { return }

        AudioServicesPlaySystemSound(SystemSoundID(1104))
    }

    static func playRecitationIfAvailable() {
        let resources = [
            "duhaa-opening-recitation",
            "surah-duhaa-opening",
            "duhaa-recitation"
        ]
        for resource in resources {
            for fileExtension in ["m4a", "mp3", "wav", "caf"] {
                if playBundled(resource: resource, fileExtension: fileExtension) { return }
            }
        }
    }

    static func stopAll() {
        players.forEach { $0.stop() }
        players.removeAll()
    }

    @discardableResult
    private static func playBundled(resource: String, fileExtension: String) -> Bool {
        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return false
        }

        players.append(player)
        player.prepareToPlay()
        player.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.4, player.duration + 0.4)) {
            players.removeAll { $0 === player }
        }
        return true
    }
}

#Preview {
    DuhaaOpeningView(onFinish: {})
}
