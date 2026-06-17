import SwiftUI
import Foundation

// MARK: - Background

/// The locked celestial backdrop: dark navy with a warm gold glow up top, a cool
/// blue glow mid-right, and a scattering of faint stars.
struct CelestialBackground: View {
    var allowsThemeDecorations = false

    var body: some View {
        ZStack {
            Palette.appBg
            if allowsThemeDecorations && Palette.active.showsFloatingHearts {
                RadialGradient(colors: [Palette.glow.opacity(0.42), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 340)
                RadialGradient(colors: [Palette.softAccent.opacity(0.28), .clear],
                               center: .bottomTrailing, startRadius: 0, endRadius: 360)
                LightPinkHeartsBackground()
            } else if Palette.active.isDark {
                RadialGradient(colors: [Palette.gold.opacity(0.18), .clear],
                               center: .top, startRadius: 0, endRadius: 320)
                StarField()
            } else {
                // Soft "dawn": a warm glow from the top, a cool hint from below.
                RadialGradient(colors: [Palette.gold.opacity(0.22), .clear],
                               center: .top, startRadius: 0, endRadius: 380)
                RadialGradient(colors: [Palette.blue.opacity(0.10), .clear],
                               center: .bottom, startRadius: 0, endRadius: 320)
            }
        }
        .ignoresSafeArea()
    }
}

/// One star's fixed properties. Position drifts slowly; opacity twinkles.
private struct StarSpec {
    let x: CGFloat            // 0…1 of width
    let y: CGFloat            // 0…1 of height
    let radius: CGFloat
    let baseOpacity: Double
    let twinkleSpeed: Double
    let phase: Double
    let drift: Double         // fractions of height per second (tiny)
    let color: Color
}

/// A tiny deterministic RNG so the star layout stays put across the home
/// screen's per-second redraws (no jumping).
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

private enum StarFactory {
    /// Generated once. Density/brightness biased toward the top (the "sky").
    static let stars: [StarSpec] = {
        var rng = SeededGenerator(seed: 0xD002_DABA)
        return (0..<55).map { _ in
            let y = CGFloat(Double.random(in: 0...1, using: &rng))
            let topFactor = 1.0 - Double(y) * 0.6            // fade lower stars
            let hue = Double.random(in: 0...1, using: &rng)
            let color: Color = hue < 0.7 ? .primary : (hue < 0.86 ? Palette.blue : Palette.gold)
            return StarSpec(
                x: CGFloat(Double.random(in: 0...1, using: &rng)),
                y: y,
                radius: CGFloat(Double.random(in: 0.6...1.7, using: &rng)),
                baseOpacity: Double.random(in: 0.25...0.85, using: &rng) * topFactor,
                twinkleSpeed: Double.random(in: 0.5...2.2, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng),
                drift: Double.random(in: 0.002...0.010, using: &rng),
                color: color
            )
        }
    }()
}

/// A living star field: each star twinkles and drifts slowly upward, with an
/// occasional gold shooting star streaking across the upper sky. Drawn in a
/// Canvas (one GPU layer) and driven by `TimelineView(.animation)`.
private struct StarField: View {
    /// Honour Reduce Motion: render a single still frame (no animation/battery use).
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in render(&context, size, time: 0) }
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        render(&context, size, time: timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func render(_ context: inout GraphicsContext, _ size: CGSize, time t: Double) {
        for star in StarFactory.stars {
            let twinkle = 0.5 + 0.5 * sin(t * star.twinkleSpeed + star.phase)
            context.opacity = star.baseOpacity * (0.3 + 0.7 * twinkle)

            var yFrac = star.y - CGFloat((t * star.drift).truncatingRemainder(dividingBy: 1))
            if yFrac < 0 { yFrac += 1 }
            let c = CGPoint(x: star.x * size.width, y: yFrac * size.height)
            let rect = CGRect(x: c.x - star.radius, y: c.y - star.radius,
                              width: star.radius * 2, height: star.radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(star.color))
        }
        drawShootingStar(in: context, size: size, time: t)
    }

    /// One gold meteor every ~11s, streaking down-right and fading in/out.
    private func drawShootingStar(in context: GraphicsContext, size: CGSize, time: Double) {
        let period = 11.0, duration = 1.1
        let local = time.truncatingRemainder(dividingBy: period)
        guard local < duration else { return }

        let progress = local / duration
        let cycle = floor(time / period)
        var rng = SeededGenerator(seed: UInt64(bitPattern: Int64(cycle)) &* 2654435761)
        let startX = CGFloat(Double.random(in: 0.05...0.55, using: &rng))
        let startY = CGFloat(Double.random(in: 0.04...0.28, using: &rng))
        let angle = Double.random(in: 0.25...0.5, using: &rng)
        let dx = CGFloat(0.35 * cos(angle)), dy = CGFloat(0.35 * sin(angle))

        let head = CGPoint(x: (startX + dx * CGFloat(progress)) * size.width,
                           y: (startY + dy * CGFloat(progress)) * size.height)
        let tailP = CGFloat(max(0, progress - 0.18))
        let tail = CGPoint(x: (startX + dx * tailP) * size.width,
                           y: (startY + dy * tailP) * size.height)

        var path = Path()
        path.move(to: tail)
        path.addLine(to: head)

        var ctx = context
        ctx.opacity = sin(progress * .pi) * 0.9            // ease in then out
        ctx.stroke(path, with: .linearGradient(
            Gradient(colors: [Palette.gold.opacity(0), Palette.gold]),
            startPoint: tail, endPoint: head), lineWidth: 2)
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - 1.6, y: head.y - 1.6, width: 3.2, height: 3.2)),
                 with: .color(.primary))
    }
}

// MARK: - Next-prayer banner

struct NextPrayerBanner: View {
    let nextName: String
    let countdown: String
    let displayMode: NextPrayerDisplayMode
    let timeRemainingCountdown: String
    let timeRemainingTarget: String
    let timeRemainingProgress: Double
    let timeRemainingPrevLabel: String
    let timeRemainingNextLabel: String
    let progress: Double
    let prevLabel: String
    let nextLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Palette.gold)
                        .frame(width: 7, height: 7)
                        .shadow(color: Palette.gold.opacity(0.8), radius: 4)
                    Text(eyebrow)
                        .duhaaFont(12, .medium)
                        .tracking(0.8)
                        .foregroundStyle(Palette.gold.opacity(0.8))
                }
                Spacer()
                headline
                    .duhaaFont(18, .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .multilineTextAlignment(.trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.gold.opacity(0.5), Palette.gold],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * activeProgress))
                        .shadow(color: Palette.gold.opacity(0.4), radius: 4)
                }
            }
            .frame(height: 3)

            HStack {
                Text(activePrevLabel)
                Spacer()
                Text(activeNextLabel)
            }
            .duhaaFont(10)
            .foregroundStyle(Palette.blue.opacity(0.4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            LinearGradient(colors: [Palette.gold.opacity(0.18), Palette.gold.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Palette.gold.opacity(0.15), radius: 12)
    }

    private var eyebrow: String {
        switch displayMode {
        case .nextPrayer: return "NEXT PRAYER"
        case .timeRemaining: return "TIME REMAINING"
        }
    }

    private var headline: Text {
        switch displayMode {
        case .nextPrayer:
            return Text("\(nextName) in ").foregroundStyle(.primary)
                + Text(countdown).foregroundStyle(Palette.gold)
        case .timeRemaining:
            return Text(timeRemainingCountdown).foregroundStyle(Palette.gold)
                + Text(" until \(timeRemainingTarget)").foregroundStyle(.primary)
        }
    }

    private var activeProgress: Double {
        switch displayMode {
        case .nextPrayer: return progress
        case .timeRemaining: return timeRemainingProgress
        }
    }

    private var activePrevLabel: String {
        switch displayMode {
        case .nextPrayer: return prevLabel
        case .timeRemaining: return timeRemainingPrevLabel
        }
    }

    private var activeNextLabel: String {
        switch displayMode {
        case .nextPrayer: return nextLabel
        case .timeRemaining: return timeRemainingNextLabel
        }
    }
}

// MARK: - Prayer list

struct PrayersCard: View {
    let rows: [PrayerRowData]
    /// Fires when a prayer is tapped to mark/unmark; Bool = now prayed.
    let onMark: (Prayer, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRAYER TIMES")
                .duhaaFont(11, .semibold)
                .tracking(1.2)
                .foregroundStyle(Palette.blue.opacity(0.65))
                .padding(.horizontal, 6)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().overlay(Color.primary.opacity(0.09)) }
                    PrayerRowView(row: row, onMark: onMark)
                }
            }
            .duhaaCardStyle(cornerRadius: 20)
        }
    }
}

private struct PrayerRowView: View {
    @Environment(PrayerTracker.self) private var tracker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let row: PrayerRowData
    let onMark: (Prayer, Bool) -> Void

    /// Bumped on each successful mark — drives the one-shot celebration swell.
    @State private var celebration = 0

    private var isNext: Bool { row.state == .next }
    private var isPrayed: Bool { tracker.isMarked(row.prayer, dayKey: row.dayKey) }
    private var canToggleMark: Bool { isPrayed || row.state == .passed }
    /// Softly de-emphasise a passed-and-unmarked prayer — gentle, never a scold.
    private var contentOpacity: Double { isPrayed ? 1 : (row.state == .passed ? 0.5 : 1) }

    var body: some View {
        HStack(spacing: 13) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isNext ? Palette.gold.opacity(0.12) : Color.primary.opacity(0.05))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: row.prayer.icon)
                            .duhaaFont(15)
                            .foregroundStyle(isNext ? Palette.gold : Palette.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.prayer.rawValue)
                            .duhaaFont(15, .medium)
                            .foregroundStyle(.primary)
                        if isNext { nextBadge }
                    }
                    if let sub = row.sub {
                        Text(sub)
                            .duhaaFont(11)
                            .foregroundStyle(Palette.blue.opacity(0.45))
                    }
                }

                Spacer()

                Text(row.time)
                    .duhaaFont(isNext ? 16 : 15, isNext ? .semibold : .medium)
                    .foregroundStyle(isNext ? Palette.gold : Palette.prayerTime)
            }
            .opacity(contentOpacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(row.prayer.rawValue), \(row.time)"
                                + (row.sub.map { ", \($0)" } ?? "")
                                + (isPrayed ? ", prayed" : ""))

            markButton
        }
        // The celebration: the row swells with a soft gold bloom, then settles.
        // Content sits inside 18pt padding, so a 5% swell never hits the card edge.
        .phaseAnimator([false, true], trigger: celebration) { content, swelling in
            content
                .scaleEffect(reduceMotion ? 1 : (swelling ? 1.05 : 1))
                .shadow(color: Palette.gold.opacity(swelling && !reduceMotion ? 0.4 : 0),
                        radius: swelling ? 12 : 0)
        } animation: { swelling in
            swelling ? DuhaaMotion.markSwell : DuhaaMotion.markSettle
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(alignment: .leading) {
            if isNext {
                HStack(spacing: 0) {
                    Rectangle().fill(Palette.gold.opacity(0.7)).frame(width: 3)
                    Palette.gold.opacity(0.06)
                }
            }
        }
    }

    private var markButton: some View {
        Button {
            guard canToggleMark else { return }
            let nowPrayed = tracker.toggle(row.prayer, dayKey: row.dayKey, onTime: row.onTime)
            // A soft touch-down on every toggle…
            DuhaaHaptics.tap()
            if nowPrayed {
                celebration += 1
                // …and a warm success pattern landing with the swell's peak.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    DuhaaHaptics.success()
                }
            }
            onMark(row.prayer, nowPrayed)
        } label: {
            Image(systemName: isPrayed ? "checkmark.circle.fill" : "circle")
                .duhaaFont(22)
                .foregroundStyle(isPrayed ? Palette.gold : Color.primary.opacity(0.22))
                .symbolEffect(.bounce, value: isPrayed)
                // HIG minimum touch target — the glyph alone is only ~22pt.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPrayed ? "\(row.prayer.rawValue) prayed" : "Mark \(row.prayer.rawValue) as prayed")
    }

    private var nextBadge: some View {
        Text("NEXT")
            .duhaaFont(10, .semibold)
            .tracking(0.5)
            .foregroundStyle(Palette.gold)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Palette.gold.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.gold.opacity(0.3), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Night prayer card

struct NightCard: View {
    let tahajjud: String
    let islamicMidnight: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                Text("NIGHT PRAYER")
                    .duhaaFont(11, .semibold)
                    .tracking(1)
                    .foregroundStyle(Palette.blue.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 12)
            .overlay(alignment: .bottom) { Divider().overlay(Color.primary.opacity(0.05)) }

            nightRow(icon: "moon.stars", name: "Tahajjud",
                     sub: "Last third of night", time: tahajjud)
            Divider().overlay(Color.primary.opacity(0.04))
            nightRow(icon: "clock", name: "Islamic Midnight",
                     sub: "Between Maghrib & Fajr", time: islamicMidnight)
        }
        .duhaaGradientCardStyle(
            colors: [Palette.blue.opacity(0.12), Palette.appBg.opacity(0.6)],
            stroke: Palette.blue.opacity(0.22)
        )
    }

    private func nightRow(icon: String, name: String, sub: String, time: String) -> some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Palette.blue.opacity(0.07))
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: icon).duhaaFont(15).foregroundStyle(Palette.blue))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).duhaaFont(14, .medium).foregroundStyle(.primary)
                Text(sub).duhaaFont(11).foregroundStyle(Palette.blue.opacity(0.4))
            }
            Spacer()
            Text(time).duhaaFont(14, .medium).foregroundStyle(Palette.blue.opacity(0.7))
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
    }
}
