import SwiftUI

/// The full-bleed ambience behind the Quran listening screen: a calm gradient,
/// a per-theme scene (stars / rain / dunes / masjid / waves / embers / glow),
/// and a readability scrim so the player's text always sits on enough contrast.
///
/// Motion rides `AmbientTimelineView`, so it renders a still frame under
/// Reduce Motion and pauses entirely off screen. Every animation is slow and
/// low-alpha — nothing flashes, nothing moves fast.
struct QuranThemedPlayerBackground: View {
    let theme: QuranListeningTheme
    /// True for the picker's mini preview cards: always a still frame, and the
    /// view stays inside its card instead of ignoring the safe area.
    var staticPreview = false

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.gradientColors,
                           startPoint: .top, endPoint: .bottom)

            if staticPreview || theme.motion == .none {
                scene(time: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                AmbientTimelineView(minimumInterval: frameInterval) { time in
                    scene(time: time)
                }
            }

            readabilityScrim
        }
        .ignoresSafeArea(.all, edges: staticPreview ? [] : .all)
    }

    /// Slow scenes redraw slowly — the twinkle/glow themes tick well below the
    /// display rate so an hour of listening doesn't cost an hour of rendering.
    private var frameInterval: Double? {
        switch theme.motion {
        case .none: return nil
        case .stars, .sunsetShimmer, .lanternGlow, .softGlow: return 1.0 / 10.0
        case .rain, .waves, .embers: return 1.0 / 24.0
        }
    }

    @ViewBuilder
    private func scene(time: TimeInterval) -> some View {
        switch theme {
        case .minimalDark:
            minimalScene
        case .nightSky:
            Canvas { context, size in drawStars(context: context, size: size, time: time) }
        case .rainWindow:
            Canvas { context, size in drawRain(context: context, size: size, time: time) }
        case .desertSunset:
            Canvas { context, size in drawSunset(context: context, size: size, time: time) }
        case .masjidGlow:
            Canvas { context, size in drawMasjid(context: context, size: size, time: time) }
        case .oceanWaves:
            Canvas { context, size in drawWaves(context: context, size: size, time: time) }
        case .fireEmbers:
            Canvas { context, size in drawEmbers(context: context, size: size, time: time) }
        case .lightPink:
            Canvas { context, size in drawBlushGlow(context: context, size: size, time: time) }
        }
    }

    /// Keeps the player legible over every scene without flattening it.
    private var readabilityScrim: some View {
        LinearGradient(
            colors: theme.isLight
                ? [Color.white.opacity(0.10), .clear, Color.white.opacity(0.22)]
                : [Color.black.opacity(0.18), .clear, Color.black.opacity(0.32)],
            startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    // MARK: Minimal Dark — a single still gold breath at the top

    private var minimalScene: some View {
        RadialGradient(colors: [theme.accentColor.opacity(0.12), .clear],
                       center: .top, startRadius: 8, endRadius: 420)
    }

    // MARK: Night Sky

    private func drawStars(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // Moonlight from the top, like the reader's existing celestial glow.
        fillRadialGlow(context, size: size,
                       center: CGPoint(x: size.width * 0.5, y: -size.height * 0.05),
                       radius: size.height * 0.5,
                       color: theme.accentColor, alpha: 0.10)

        for index in 0..<46 {
            let x = unitRandom(index, 11) * size.width
            let y = unitRandom(index, 23) * size.height * 0.78
            let radius = 0.7 + unitRandom(index, 37) * 1.5
            let baseAlpha = 0.22 + unitRandom(index, 51) * 0.5
            // Gentle sinusoidal twinkle — slow, never a flash.
            let twinkle = 0.65 + 0.35 * sin(time * (0.25 + unitRandom(index, 67) * 0.5)
                                            + unitRandom(index, 83) * .pi * 2)
            let color = index % 5 == 0 ? theme.accentColor : Color.white
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(color.opacity(baseAlpha * twinkle)))
        }
    }

    // MARK: Rain Window

    private func drawRain(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // A cool sheen on the "glass".
        fillRadialGlow(context, size: size,
                       center: CGPoint(x: size.width * 0.7, y: size.height * 0.12),
                       radius: size.height * 0.45,
                       color: theme.softAccentColor, alpha: 0.08)

        for index in 0..<26 {
            let x = unitRandom(index, 13) * size.width
            let length = 26 + unitRandom(index, 29) * 40
            let speed = 34 + unitRandom(index, 41) * 46   // slow drizzle, pt/s
            let travel = size.height + length
            let y = (unitRandom(index, 59) * travel + time * speed)
                .truncatingRemainder(dividingBy: travel) - length
            let alpha = 0.08 + unitRandom(index, 71) * 0.12
            let streak = Path(roundedRect: CGRect(x: x, y: y, width: 1.4, height: length),
                              cornerRadius: 0.7)
            context.fill(streak, with: .color(theme.softAccentColor.opacity(alpha)))
        }
    }

    // MARK: Desert Sunset

    private func drawSunset(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // The low sun: a wide warm glow with a brighter core, breathing slowly.
        let sunCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.60)
        let breath = 0.9 + 0.1 * sin(time * 0.22)
        fillRadialGlow(context, size: size, center: sunCenter,
                       radius: size.width * 0.55,
                       color: theme.accentColor, alpha: 0.38 * breath)
        fillRadialGlow(context, size: size, center: sunCenter,
                       radius: size.width * 0.18,
                       color: Color(hex: 0xFFD9A0), alpha: 0.42 * breath)

        // Two layered dunes in near-silhouette.
        var back = Path()
        back.move(to: CGPoint(x: 0, y: size.height * 0.74))
        back.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.80),
                          control: CGPoint(x: size.width * 0.42, y: size.height * 0.64))
        back.addLine(to: CGPoint(x: size.width, y: size.height))
        back.addLine(to: CGPoint(x: 0, y: size.height))
        back.closeSubpath()
        context.fill(back, with: .color(Color(hex: 0x3A1512).opacity(0.85)))

        var front = Path()
        front.move(to: CGPoint(x: 0, y: size.height * 0.86))
        front.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.90),
                           control: CGPoint(x: size.width * 0.68, y: size.height * 0.78))
        front.addLine(to: CGPoint(x: size.width, y: size.height))
        front.addLine(to: CGPoint(x: 0, y: size.height))
        front.closeSubpath()
        context.fill(front, with: .color(Color(hex: 0x230A0C).opacity(0.92)))
    }

    // MARK: Masjid Glow

    private func drawMasjid(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let groundY = size.height * 0.90
        let breath = 0.9 + 0.1 * sin(time * 0.3)

        // Warm lantern light rising behind the silhouette.
        fillRadialGlow(context, size: size,
                       center: CGPoint(x: size.width * 0.5, y: groundY),
                       radius: size.width * 0.62,
                       color: theme.accentColor, alpha: 0.30 * breath)

        let silhouette = Color(hex: 0x03110D)
        var scene = Path()

        // Ground line.
        scene.addRect(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY))

        // Prayer-hall block under the dome.
        let hallWidth = size.width * 0.42
        let hallHeight = size.height * 0.045
        scene.addRect(CGRect(x: size.width * 0.5 - hallWidth / 2, y: groundY - hallHeight,
                             width: hallWidth, height: hallHeight))

        // Central dome with a small finial.
        let domeRadius = size.width * 0.13
        let domeCenter = CGPoint(x: size.width * 0.5, y: groundY - hallHeight)
        scene.move(to: CGPoint(x: domeCenter.x - domeRadius, y: domeCenter.y))
        scene.addArc(center: domeCenter, radius: domeRadius,
                     startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        scene.closeSubpath()
        scene.addRect(CGRect(x: domeCenter.x - 1.2, y: domeCenter.y - domeRadius - size.height * 0.020,
                             width: 2.4, height: size.height * 0.020))
        let finial = CGRect(x: domeCenter.x - 2.6, y: domeCenter.y - domeRadius - size.height * 0.020 - 5.2,
                            width: 5.2, height: 5.2)
        scene.addEllipse(in: finial)

        // Two slim minarets, each capped with its own small dome and spire.
        for minaretX in [size.width * 0.20, size.width * 0.80] {
            let minaretWidth = size.width * 0.030
            let minaretHeight = size.height * 0.135
            let topY = groundY - minaretHeight
            scene.addRect(CGRect(x: minaretX - minaretWidth / 2, y: topY,
                                 width: minaretWidth, height: minaretHeight))
            let capRadius = minaretWidth * 0.85
            scene.move(to: CGPoint(x: minaretX - capRadius, y: topY))
            scene.addArc(center: CGPoint(x: minaretX, y: topY), radius: capRadius,
                         startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            scene.closeSubpath()
            scene.addRect(CGRect(x: minaretX - 0.9, y: topY - capRadius - size.height * 0.012,
                                 width: 1.8, height: size.height * 0.012))
        }

        context.fill(scene, with: .color(silhouette))
    }

    // MARK: Ocean Waves

    private func drawWaves(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // Moonlight on the water.
        fillRadialGlow(context, size: size,
                       center: CGPoint(x: size.width * 0.5, y: size.height * 0.06),
                       radius: size.height * 0.42,
                       color: theme.softAccentColor, alpha: 0.10)

        let bands: [(baseline: CGFloat, amplitude: CGFloat, wavelength: CGFloat, speed: Double, alpha: Double)] = [
            (0.70, 9,  0.95, 0.16, 0.10),
            (0.78, 12, 0.75, -0.12, 0.14),
            (0.86, 14, 0.60, 0.09, 0.18)
        ]
        for band in bands {
            let path = wavePath(in: size,
                                baseline: size.height * band.baseline,
                                amplitude: band.amplitude,
                                wavelength: size.width * band.wavelength,
                                phase: time * band.speed * 2 * .pi)
            context.fill(path, with: .color(theme.softAccentColor.opacity(band.alpha)))
        }
    }

    private func wavePath(in size: CGSize, baseline: CGFloat, amplitude: CGFloat,
                          wavelength: CGFloat, phase: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseline + amplitude * sin(phase)))
        var x: CGFloat = 0
        while x <= size.width {
            let y = baseline + amplitude * sin((x / wavelength) * 2 * .pi + phase)
            path.addLine(to: CGPoint(x: x, y: y))
            x += 8
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    // MARK: Fire Embers — cozy firelight, deliberately soft and warm

    private func drawEmbers(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // The fire itself stays out of frame below; only its light reaches up.
        fillRadialGlow(context, size: size,
                       center: CGPoint(x: size.width * 0.5, y: size.height * 1.06),
                       radius: size.width * 0.85,
                       color: theme.accentColor, alpha: 0.30 + 0.04 * sin(time * 0.4))

        for index in 0..<16 {
            let speed = 12 + unitRandom(index, 17) * 14      // gentle rise, pt/s
            let travel = size.height * 0.72
            let progress = ((unitRandom(index, 31) * travel + time * speed)
                .truncatingRemainder(dividingBy: travel)) / travel
            let y = size.height - progress * travel
            let sway = sin(time * (0.3 + unitRandom(index, 43) * 0.4)
                           + unitRandom(index, 61) * .pi * 2) * 14
            let x = unitRandom(index, 7) * size.width + sway
            let radius = 1.3 + unitRandom(index, 73) * 1.9
            // Embers fade in near the fire and out as they cool — never blink.
            let alpha = (0.10 + unitRandom(index, 89) * 0.25) * sin(.pi * progress)
            let color = index % 3 == 0 ? theme.softAccentColor : theme.accentColor
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .color(color.opacity(alpha)))
        }
    }

    // MARK: Light Pink

    private func drawBlushGlow(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let breath = 0.9 + 0.1 * sin(time * 0.18)
        fillRadialGlow(context, size: size,
                       center: CGPoint(x: size.width * 0.18, y: size.height * 0.10),
                       radius: size.width * 0.7,
                       color: Color(hex: 0xFFC7DA), alpha: 0.45 * breath)
        fillRadialGlow(context, size: size,
                       center: CGPoint(x: size.width * 0.88, y: size.height * 0.85),
                       radius: size.width * 0.75,
                       color: Color(hex: 0xF7D4E4), alpha: 0.50 * (1.8 - breath))
    }

    // MARK: Shared helpers

    private func fillRadialGlow(_ context: GraphicsContext, size: CGSize,
                                center: CGPoint, radius: CGFloat,
                                color: Color, alpha: Double) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect),
                     with: .radialGradient(
                        Gradient(colors: [color.opacity(alpha), color.opacity(0)]),
                        center: center, startRadius: 0, endRadius: radius))
    }

    /// Deterministic 0...1 value per (seed, salt), so scene layouts are stable
    /// across frames and identical in the Reduce Motion still.
    private func unitRandom(_ seed: Int, _ salt: Int) -> Double {
        var n = UInt64(bitPattern: Int64(seed)) &* 374_761_393 &+ UInt64(bitPattern: Int64(salt)) &* 668_265_263
        n = (n ^ (n >> 13)) &* 1_274_126_177
        return Double((n ^ (n >> 16)) & 0xFFFF) / Double(0xFFFF)
    }
}
