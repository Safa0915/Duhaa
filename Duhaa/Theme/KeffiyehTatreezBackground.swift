import SwiftUI

/// The background for the Palestinian theme: the keffiyeh weave read as
/// whisper-faint texture, with two static tatreez cross-stitch bands — like
/// keffiyeh cloth carrying an embroidered chest panel. Fully still except the
/// existing star field behind it, so there is no animation cost at all and
/// nothing for Reduce Motion to do. All tints come from the active theme's own
/// tokens, so the field re-tints automatically if the palette ever changes.
struct KeffiyehTatreezBackground: View {
    var body: some View {
        Canvas { context, size in
            drawKeffiyehLattice(in: context, size: size)
            drawChevronBands(in: context, size: size)
            // The embroidered bands: one behind the hero, one above the tab bar.
            drawCrossStitchBand(in: context, size: size, yTop: 96)
            drawCrossStitchBand(in: context, size: size, yTop: size.height - 214)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Keffiyeh fishnet lattice — two sets of diagonals, barely there.

    private func drawKeffiyehLattice(in context: GraphicsContext, size: CGSize) {
        var ctx = context
        ctx.opacity = 0.032
        let spacing: CGFloat = 22
        let h = size.height
        var x: CGFloat = -h
        while x < size.width + h {
            var down = Path()
            down.move(to: CGPoint(x: x, y: 0))
            down.addLine(to: CGPoint(x: x + h, y: h))
            ctx.stroke(down, with: .color(Palette.primaryText), lineWidth: 1)

            var up = Path()
            up.move(to: CGPoint(x: x + h, y: 0))
            up.addLine(to: CGPoint(x: x, y: h))
            ctx.stroke(up, with: .color(Palette.primaryText), lineWidth: 1)
            x += spacing
        }
    }

    // MARK: Chevron weave rows — three quiet bands across the sky.

    private func drawChevronBands(in context: GraphicsContext, size: CGSize) {
        // (y fraction of height, tint, opacity) — middle band in tatreez red.
        let bands: [(CGFloat, Color, Double)] = [
            (0.17, Palette.softAccent, 0.063),
            (0.49, Palette.accent, 0.056),
            (0.80, Palette.softAccent, 0.063),
        ]
        for (yFraction, tint, opacity) in bands {
            var ctx = context
            ctx.opacity = opacity
            let yBand = yFraction * size.height
            for row in 0..<3 {
                let yBase = yBand + CGFloat(row) * 9
                var path = Path()
                var x: CGFloat = 0
                var step = 0
                while x <= size.width {
                    let y = yBase + (step.isMultiple(of: 2) ? 0 : 5)
                    if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                    x += 8
                    step += 1
                }
                ctx.stroke(path, with: .color(tint), lineWidth: 1.4)
            }
        }
    }

    // MARK: Cross-stitch band — a chain of diamond outlines with red centers,
    // bordered by a dotted sage rule, drawn as little square "stitches".

    private func drawCrossStitchBand(in context: GraphicsContext, size: CGSize, yTop: CGFloat) {
        let cell: CGFloat = 6
        let gap: CGFloat = 1.2
        let rows = 12
        let cols = Int(ceil(size.width / cell))

        for r in 0..<rows {
            for c in 0..<cols {
                var tint: Color?
                var opacity = 0.0
                if r == 0 || r == rows - 1 {
                    if c.isMultiple(of: 2) { tint = Palette.softAccent; opacity = 0.16 }
                } else if (2...9).contains(r) {
                    let d = abs(Double(r) - 5.5) + abs(Double(c % 9) - 4)
                    if d >= 2.4 && d <= 3.6 { tint = Palette.accent; opacity = 0.30 }
                    else if d < 1.2 { tint = Palette.accent; opacity = 0.42 }
                }
                guard let tint else { continue }
                var ctx = context
                ctx.opacity = opacity
                let rect = CGRect(x: CGFloat(c) * cell, y: yTop + CGFloat(r) * cell,
                                  width: cell - gap, height: cell - gap)
                ctx.fill(Path(rect), with: .color(tint))
            }
        }
    }
}
