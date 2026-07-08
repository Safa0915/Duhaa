import SwiftUI

/// Gentle falling autumn leaves for the Autumn theme. Each leaf is a hand-drawn
/// `Path` (no emoji), tinted from the *active theme's own* warm tokens — accent,
/// soft accent, secondary text — so they always read as part of the palette and
/// never look pasted on. Everything is composited into ONE Canvas layer (the same
/// cheap approach as the Light Pink hearts and the Chinese Blossom petals), and
/// `AmbientTimelineView` pauses the field entirely while it sits off-screen behind
/// another tab.
///
/// Kept deliberately calm: few leaves, low opacity, slow tumble — present enough to
/// feel like autumn, faint enough never to compete with the content in front of it.
/// Respects Reduce Motion by rendering a single static frame.
struct FloatingLeavesBackground: View {
    var body: some View {
        AmbientTimelineView { time in
            leafCanvas(time: time)
        }
    }

    private func leafCanvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            for leaf in FloatingLeafFactory.leaves {
                let opacity = leaf.opacity(at: time)
                guard opacity > 0.004 else { continue }

                var layer = context
                layer.opacity = opacity
                let position = leaf.position(in: size, at: time)
                layer.translateBy(x: position.x, y: position.y)
                layer.rotate(by: .degrees(leaf.rotation(at: time)))
                layer.scaleBy(x: leaf.size, y: leaf.size)

                // Blade — a tint pulled straight from the active palette so it blends.
                layer.fill(Self.unitLeafPath, with: .color(leaf.tint.color))
                // A faint midrib carved with the page background — just enough to
                // read as a leaf rather than a generic blob, never a hard line.
                layer.stroke(Self.unitVeinPath,
                             with: .color(Palette.appBg.opacity(0.32)),
                             lineWidth: 0.05)
            }
        }
    }

    /// A stylized teardrop leaf, centered at the origin, one unit tall, pointing up.
    /// Widest just above the middle so it tapers gently toward the stem.
    static let unitLeafPath: Path = {
        var p = Path()
        let halfH: CGFloat = 0.5
        let halfW: CGFloat = 0.30
        p.move(to: CGPoint(x: 0, y: -halfH))
        p.addQuadCurve(to: CGPoint(x: 0, y: halfH),
                       control: CGPoint(x: halfW, y: -0.05))
        p.addQuadCurve(to: CGPoint(x: 0, y: -halfH),
                       control: CGPoint(x: -halfW, y: -0.05))
        p.closeSubpath()
        return p
    }()

    /// Midrib running from near the stem toward the tip.
    static let unitVeinPath: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0.45))
        p.addLine(to: CGPoint(x: 0, y: -0.42))
        return p
    }()
}

/// Which active-theme token a leaf borrows, so the field re-tints with the theme.
enum LeafTint: CaseIterable {
    case accent     // burnt amber
    case soft       // warm wheat
    case ember      // tan / secondary

    var color: Color {
        switch self {
        case .accent: return Palette.accent
        case .soft:   return Palette.softAccent
        case .ember:  return Palette.secondaryText
        }
    }
}

struct FloatingLeafSpec: Identifiable {
    let id: Int
    let x: CGFloat            // 0…1 of width
    let y: CGFloat            // 0…1 of height (start)
    let size: CGFloat
    let baseOpacity: Double
    let fallSpeed: Double     // fractions of height per second (downward)
    let sway: CGFloat         // horizontal sway amplitude, points
    let swaySpeed: Double
    let phase: Double
    let baseRotation: Double  // resting tilt, degrees
    let spin: Double          // tumble speed
    let tint: LeafTint

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

    /// A slow tumble plus a gentle rock from the sway, so leaves flutter, not spin.
    func rotation(at time: TimeInterval) -> Double {
        baseRotation + time * spin * 24 + sin(time * swaySpeed + phase) * 10
    }
}

private struct LeafSeededGenerator: RandomNumberGenerator {
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

enum FloatingLeafFactory {
    private static let columnCenters: [Double] = [0.08, 0.26, 0.44, 0.62, 0.79, 0.93]
    private static let tints: [LeafTint] = [.accent, .soft, .ember]

    static let leaves: [FloatingLeafSpec] = {
        var rng = LeafSeededGenerator(seed: 0x1EA0_FA11)
        let rowCount = 4

        return (0..<22).map { index in
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

            return FloatingLeafSpec(
                id: index,
                x: CGFloat(column + xJitter),
                y: CGFloat(y),
                size: CGFloat(Double.random(in: isFeature ? 26...34 : 15...26, using: &rng)),
                baseOpacity: Double.random(in: isFeature ? 0.17...0.24 : 0.09...0.18, using: &rng),
                fallSpeed: Double.random(in: 0.009...0.018, using: &rng),
                sway: CGFloat(Double.random(in: 10...22, using: &rng)),
                swaySpeed: Double.random(in: 0.16...0.34, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng),
                baseRotation: Double.random(in: -40...40, using: &rng),
                spin: Double.random(in: -0.6...0.6, using: &rng),
                tint: tints[index % tints.count]
            )
        }
    }()
}
