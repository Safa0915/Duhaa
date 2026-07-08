import SwiftUI

/// Gentle falling cherry/plum blossoms for the Chinese Blossom theme. Every petal is
/// drawn into ONE Canvas layer — the 🌸 emoji is rasterized just once (via `symbols`)
/// and composited per frame with a transform — and `AmbientTimelineView` pauses the
/// field entirely while it sits off-screen behind another tab (the same approach as
/// the Light Pink hearts). Respects Reduce Motion by rendering a single static frame.
struct FloatingBlossomsBackground: View {
    var body: some View {
        AmbientTimelineView { time in
            blossomCanvas(time: time)
        }
    }

    private func blossomCanvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            for blossom in FloatingBlossomFactory.blossoms {
                let opacity = blossom.opacity(at: time)
                guard opacity > 0.004,
                      let symbol = context.resolveSymbol(id: blossom.id) else { continue }

                var layer = context
                layer.opacity = opacity
                let position = blossom.position(in: size, at: time)
                layer.translateBy(x: position.x, y: position.y)
                layer.rotate(by: .degrees(blossom.rotation(at: time)))
                let scale = blossom.scale(at: time)
                layer.scaleBy(x: scale, y: scale)
                layer.draw(symbol, at: .zero, anchor: .center)
            }
        } symbols: {
            ForEach(FloatingBlossomFactory.blossoms) { blossom in
                Text(blossom.emoji)
                    .font(.system(size: blossom.size))
                    .tag(blossom.id)
            }
        }
    }
}

struct FloatingBlossomSpec: Identifiable {
    let id: Int
    let x: CGFloat            // 0…1 of width
    let y: CGFloat            // 0…1 of height (start)
    let size: CGFloat
    let baseOpacity: Double
    let fallSpeed: Double     // fractions of height per second (downward)
    let sway: CGFloat         // horizontal sway amplitude, points
    let swaySpeed: Double
    let phase: Double
    let spin: Double          // rotation speed
    let emoji: String

    /// Falls downward, wrapping back to the top once it leaves the bottom.
    func verticalFraction(at time: TimeInterval) -> CGFloat {
        var fraction = y + CGFloat((time * fallSpeed).truncatingRemainder(dividingBy: 1))
        if fraction > 1 {
            fraction -= 1
        }
        return fraction
    }

    func position(in size: CGSize, at time: TimeInterval) -> CGPoint {
        let yFraction = verticalFraction(at: time)
        let x = self.x * size.width + CGFloat(sin(time * swaySpeed + phase)) * sway
        let y = yFraction * size.height
        return CGPoint(x: x, y: y)
    }

    func opacity(at time: TimeInterval) -> Double {
        let yFraction = Double(verticalFraction(at: time))
        let topFade = min(1, max(0, yFraction / 0.08))
        let bottomFade = min(1, max(0, (1 - yFraction) / 0.12))
        return baseOpacity * min(topFade, bottomFade)
    }

    func scale(at time: TimeInterval) -> CGFloat {
        1 + CGFloat(sin(time * 0.6 + phase)) * 0.05
    }

    func rotation(at time: TimeInterval) -> Double {
        time * spin * 36 + phase * 28
    }
}

private struct BlossomSeededGenerator: RandomNumberGenerator {
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

enum FloatingBlossomFactory {
    private static let columnCenters: [Double] = [0.08, 0.26, 0.44, 0.62, 0.79, 0.93]

    static let blossoms: [FloatingBlossomSpec] = {
        var rng = BlossomSeededGenerator(seed: 0xB105_50EE)
        let rowCount = 5

        return (0..<28).map { index in
            let isFeature = index.isMultiple(of: 6)
            let columnIndex = index % columnCenters.count
            let column = columnCenters[columnIndex]
            let rowIndex = index / columnCenters.count
            let xJitter = Double.random(in: -0.012...0.012, using: &rng)
            let columnStagger = Double(columnIndex) * 0.02
            let yJitter = Double.random(in: -0.016...0.016, using: &rng)
            var y = 0.04 + (Double(rowIndex) / Double(rowCount)) * 0.9 + columnStagger + yJitter
            y = y.truncatingRemainder(dividingBy: 1)
            if y < 0 {
                y += 1
            }

            return FloatingBlossomSpec(
                id: index,
                x: CGFloat(column + xJitter),
                y: CGFloat(y),
                size: CGFloat(Double.random(in: isFeature ? 26...34 : 14...26, using: &rng)),
                baseOpacity: Double.random(in: isFeature ? 0.20...0.30 : 0.12...0.22, using: &rng),
                fallSpeed: Double.random(in: 0.010...0.020, using: &rng),
                sway: CGFloat(Double.random(in: 8...18, using: &rng)),
                swaySpeed: Double.random(in: 0.18...0.40, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng),
                spin: Double.random(in: -0.5...0.5, using: &rng),
                emoji: "🌸"
            )
        }
    }()
}
