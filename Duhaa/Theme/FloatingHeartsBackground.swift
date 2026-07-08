    import SwiftUI

/// Shared decorative background. Light Pink gets gentle ambient hearts, Chinese
/// Blossom gets falling blossoms; other themes receive their solid app background.
struct ThemeDecorativeBackground: View {
    var body: some View {
        ZStack {
            Palette.appBg
            switch Palette.active.decoration {
            case .hearts:
                LightPinkHeartsBackground()
            case .blossoms:
                FloatingBlossomsBackground()
            case .leaves:
                FloatingLeavesBackground()
            case .tatreez:
                KeffiyehTatreezBackground()
            case .none:
                EmptyView()
            }
        }
        .ignoresSafeArea()
    }
}

/// A charming, deterministic heart field for the Light Pink free preview theme.
/// It stays behind content, but is visible enough to make the theme feel special.
struct LightPinkHeartsBackground: View {
    var body: some View {
        AmbientTimelineView { time in
            heartCanvas(time: time)
        }
    }

    static func animationTime(for currentTime: TimeInterval, startedAt startTime: TimeInterval) -> TimeInterval {
        max(0, currentTime - startTime)
    }

    /// All hearts drawn into ONE Canvas layer: each icon is rasterized just once
    /// (via `symbols`) and then composited per frame with a transform + shadow.
    /// The per-heart shadow filter still costs real GPU time each frame, which is
    /// why `AmbientTimelineView` pausing this field off-screen matters: hidden
    /// tabs (Home/More) must not keep re-drawing it behind the Qibla compass.
    private func heartCanvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            for heart in FloatingHeartFactory.hearts {
                let opacity = heart.opacity(at: time)
                guard opacity > 0.004,
                      let symbol = context.resolveSymbol(id: heart.id) else { continue }

                var layer = context
                layer.opacity = opacity
                layer.addFilter(.shadow(color: Palette.glow.opacity(min(1, opacity * 2.0)),
                                        radius: heart.size * 0.22))
                let position = heart.position(in: size, at: time)
                layer.translateBy(x: position.x, y: position.y)
                layer.rotate(by: .degrees(heart.rotation(at: time)))
                let scale = heart.scale(at: time)
                layer.scaleBy(x: scale, y: scale)
                layer.draw(symbol, at: .zero, anchor: .center)
            }
        } symbols: {
            ForEach(FloatingHeartFactory.hearts) { heart in
                FloatingHeartIcon(heart: heart)
                    .tag(heart.id)
            }
        }
    }
}

private struct FloatingHeartIcon: View {
    let heart: FloatingHeartSpec

    var body: some View {
        Group {
            switch heart.style {
            case .simple:
                Image(systemName: heart.symbol)
                    .font(.system(size: heart.size, weight: .light))
                    .foregroundStyle(heart.usesAccent ? Palette.softAccent : Palette.accent)
            case .sparkly:
                SparklingHeartEmojiIcon(size: heart.size)
            }
        }
        .frame(width: heart.visualSize, height: heart.visualSize)
    }
}

private struct SparklingHeartEmojiIcon: View {
    let size: CGFloat

    var body: some View {
        Text("💖")
            .font(.system(size: size * 1.12))
            .frame(width: size * 1.35, height: size * 1.35)
    }
}

enum FloatingHeartStyle: Equatable {
    case simple
    case sparkly
}

struct FloatingHeartSpec: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let drift: Double
    let twinkleSpeed: Double
    let phase: Double
    let wobble: CGFloat
    let wobbleSpeed: Double
    let rotation: Double
    let rotationDrift: Double
    let symbol: String
    let usesAccent: Bool
    let style: FloatingHeartStyle

    var visualSize: CGFloat {
        switch style {
        case .simple:
            return size
        case .sparkly:
            return size * 1.35
        }
    }

    func verticalFraction(at time: TimeInterval) -> CGFloat {
        var fraction = y - CGFloat((time * drift).truncatingRemainder(dividingBy: 1))
        if fraction < 0 {
            fraction += 1
        }
        return fraction
    }

    func position(in size: CGSize, at time: TimeInterval) -> CGPoint {
        let yFraction = verticalFraction(at: time)
        let x = self.x * size.width + CGFloat(sin(time * wobbleSpeed + phase)) * wobble
        let y = yFraction * size.height
        return CGPoint(x: x, y: y)
    }

    func opacity(at time: TimeInterval) -> Double {
        let yFraction = Double(verticalFraction(at: time))
        let topFade = min(1, max(0, yFraction / 0.07))
        let bottomFade = min(1, max(0, (1 - yFraction) / 0.12))
        let routeFade = min(topFade, bottomFade)
        let twinkle = 0.72 + 0.28 * (0.5 + 0.5 * sin(time * twinkleSpeed + phase))
        return opacity * routeFade * twinkle
    }

    func scale(at time: TimeInterval) -> CGFloat {
        let yFraction = Double(verticalFraction(at: time))
        let topExit = max(0, 1 - yFraction / 0.07)
        return 1 + CGFloat(sin(topExit * .pi) * topExit * 0.12)
    }

    func rotation(at time: TimeInterval) -> Double {
        rotation + sin(time * rotationDrift + phase) * 4
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
    private static let columnCenters: [Double] = [0.07, 0.235, 0.40, 0.565, 0.73, 0.895]

    static let hearts: [FloatingHeartSpec] = {
        var rng = FloatingHeartSeededGenerator(seed: 0xD0AA_1FEE)
        let rowCount = 6

        return (0..<34).map { index in
            let isFeatureHeart = index.isMultiple(of: 7)
            let isSparklyHeart = isFeatureHeart
            let columnIndex = index % columnCenters.count
            let column = columnCenters[columnIndex]
            let rowIndex = index / columnCenters.count
            let xJitter = Double.random(in: -0.010...0.010, using: &rng)
            let columnStagger = Double(columnIndex) * 0.018
            let yJitter = Double.random(in: -0.014...0.014, using: &rng)
            var y = 0.045 + (Double(rowIndex) / Double(rowCount)) * 0.88 + columnStagger + yJitter
            y = y.truncatingRemainder(dividingBy: 1)
            if y < 0 {
                y += 1
            }

            return FloatingHeartSpec(
                id: index,
                x: CGFloat(column + xJitter),
                y: CGFloat(y),
                size: CGFloat(Double.random(in: isFeatureHeart ? 28...40 : 13...29, using: &rng)),
                opacity: Double.random(in: isFeatureHeart ? 0.18...0.26 : 0.09...0.20, using: &rng),
                drift: 0.0062,
                twinkleSpeed: Double.random(in: 0.45...1.25, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng),
                wobble: CGFloat(Double.random(in: 3...6, using: &rng)),
                wobbleSpeed: Double.random(in: 0.16...0.36, using: &rng),
                rotation: Double.random(in: -20...20, using: &rng),
                rotationDrift: Double.random(in: 0.18...0.36, using: &rng),
                symbol: index.isMultiple(of: 4) ? "heart" : "heart.fill",
                usesAccent: index.isMultiple(of: 3),
                style: isSparklyHeart ? .sparkly : .simple
            )
        }
    }()
}
