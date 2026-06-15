import SwiftUI

/// Shared decorative background. Light Pink gets gentle ambient hearts; other
/// themes receive their normal solid app background.
///
/// Opt-in by usage: only screens that apply this view (Prayer home, More, Settings)
/// get hearts. Reading-heavy screens (Quran, Du'a, Learn) use `Palette.appBg`
/// directly and never see hearts. A screen that *does* use this view but wants the
/// plain background anyway can pass `allowsHearts: false`.
struct ThemeDecorativeBackground: View {
    var allowsHearts: Bool = true

    var body: some View {
        ZStack {
            Palette.appBg
            if Self.showsHearts(allowsHearts: allowsHearts, palette: Palette.active) {
                LightPinkHeartsBackground()
            }
        }
        .ignoresSafeArea()
    }

    /// Pure gate so the show/hide decision is unit-testable without rendering.
    static func showsHearts(allowsHearts: Bool, palette: ThemeColors) -> Bool {
        allowsHearts && palette.showsFloatingHearts
    }
}

/// A subtle, deterministic heart field for the Light Pink free-preview theme.
///
/// Design: sparse (16), low opacity (≤ 0.12), small-to-medium, biased to the side
/// gutters so the central reading column stays clear, drifting slowly upward.
/// No glow, capped at 20fps for battery. Sits behind content and is decorative
/// only — never under primary text, never interactive, hidden from VoiceOver.
struct LightPinkHeartsBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            Group {
                if reduceMotion {
                    // Reduce Motion: faint static hearts, no drift.
                    hearts(in: proxy.size, time: 0)
                } else {
                    // 20fps is plenty for a slow drift and far kinder to the battery
                    // than the default per-frame schedule.
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                        hearts(in: proxy.size, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func hearts(in size: CGSize, time: TimeInterval) -> some View {
        ForEach(FloatingHeartFactory.hearts) { heart in
            let progress = heart.progress(at: reduceMotion ? 0 : time)
            let progressCGFloat = CGFloat(progress)
            // Rise from just below the bottom (staggered) to just above the top.
            let startY = size.height + heart.size + heart.y * size.height * 0.28
            let endY = -heart.size - 40
            let drift = reduceMotion ? 0 : CGFloat(sin(progress * 2 * .pi + heart.phase)) * heart.wobble
            let x = heart.x * size.width + drift
            let y = startY + (endY - startY) * progressCGFloat
            let tilt = reduceMotion ? 0 : sin(progress * 2 * .pi) * 3

            Image(systemName: heart.symbol)
                .font(.system(size: heart.size, weight: .light))
                .foregroundStyle(heart.usesAccent ? Palette.accent : Palette.softAccent)
                .opacity(heart.opacity)
                .rotationEffect(.degrees(heart.rotation + tilt))
                .position(x: x, y: y)
        }
    }
}

struct FloatingHeartSpec: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let travel: CGFloat
    let duration: Double
    let phase: Double
    let wobble: CGFloat
    let rotation: Double
    let symbol: String
    let usesAccent: Bool

    func progress(at time: TimeInterval) -> Double {
        let offset = phase / (2 * .pi)
        let local = (time / duration + offset).truncatingRemainder(dividingBy: 1)
        return local < 0 ? local + 1 : local
    }
}

private struct FloatingHeartSeededGenerator: RandomNumberGenerator {
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

enum FloatingHeartFactory {
    /// Sparse, edge-biased, low-opacity ambient hearts. Deterministic (seeded) so
    /// the field never reflows between launches and never feels chaotic.
    static let hearts: [FloatingHeartSpec] = {
        var rng = FloatingHeartSeededGenerator(seed: 0xD0AA_1FEE)
        return (0..<16).map { index in
            let isFeatureHeart = index.isMultiple(of: 5)
            // Keep the central reading column clear: hearts live in the side gutters.
            let onLeft = Bool.random(using: &rng)
            let x = onLeft
                ? Double.random(in: 0.02...0.18, using: &rng)
                : Double.random(in: 0.82...0.98, using: &rng)
            return FloatingHeartSpec(
                id: index,
                x: CGFloat(x),
                y: CGFloat(Double.random(in: 0.05...0.98, using: &rng)),
                size: CGFloat(Double.random(in: isFeatureHeart ? 24...30 : 12...22, using: &rng)),
                opacity: Double.random(in: isFeatureHeart ? 0.10...0.12 : 0.05...0.10, using: &rng),
                travel: CGFloat(Double.random(in: 0.10...0.26, using: &rng)),
                duration: Double.random(in: 34...58, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng),
                wobble: CGFloat(Double.random(in: 5...14, using: &rng)),
                rotation: Double.random(in: -16...16, using: &rng),
                symbol: index.isMultiple(of: 3) ? "heart" : "heart.fill",
                usesAccent: index.isMultiple(of: 2)
            )
        }
    }()
}
