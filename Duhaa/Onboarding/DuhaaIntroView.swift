//
//  DuhaaIntroView.swift
//  Duhaa — first-launch cinematic intro
//
//  Surah Ad-Duhaa: night stillness → the breaking of morning brightness → divine reassurance.
//  Ethos: hope, not guilt.
//
//  iOS 17+. SwiftUI only, no third-party packages.
//  Presented at launch from `DuhaaApp` before onboarding: `DuhaaIntroView { /* mark didPlayOpening */ }`.
//
//  Audio sync: the whole sequence is driven by a single `IntroPhase` enum + `IntroTimeline`.
//  `onPhaseChange` fires at each phase boundary so a recitation track can be cued/seeked there.
//  All beat timings live in `IntroTimeline` — retime by editing those values only.
//
//  Imported from the Claude Design project "Duhaa Intro.dc.html".
//

import SwiftUI

// MARK: - Design tokens (locked — the intro is always the dark celestial, regardless of theme)

private enum IntroPalette {
    static let navy = Color(red: 0x0D / 255, green: 0x16 / 255, blue: 0x28 / 255) // #0D1628
    static let gold = Color(red: 0xF0 / 255, green: 0xC0 / 255, blue: 0x40 / 255) // #F0C040
    static let blue = Color(red: 0x8E / 255, green: 0xCF / 255, blue: 0xE8 / 255) // #8ECFE8
}

private extension Font {
    /// Arabic in the bundled Uthmani face (registered at launch via `QuranFont`).
    /// Fixed point size — no Dynamic Type scaling — so the cinematic layout stays locked.
    static func introUthmani(_ size: CGFloat) -> Font {
        Font.custom(QuranFont.family, size: size)
    }
}

// MARK: - Timeline (single source of truth — retime here)

/// Phase boundaries in seconds. A recitation track is synced to these, so each phase
/// is a clearly separable step with its own start time. The four verses of Surah Ad-Duhaa
/// recite in Quranic order. Retime the whole sequence by editing these values only.
struct IntroTimeline {
    // Verse starts are synced to the recitation audio track — each is an audio cue point.
    var verse1Start:   Double = 0.0   // 1. وَالضُّحَىٰ                (full hold 0.4–1.4)
    var verse2Start:   Double = 1.6   // 2. وَاللَّيْلِ إِذَا سَجَىٰ      (1.6–5.3)
    var verse3Start:   Double = 5.3   // 3. مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ (5.3–9.8)
    var verse4Start:   Double = 9.8   // 4. وَلَلْآخِرَةُ خَيْرٌ لَّكَ مِنَ الْأُولَىٰ (9.8–16.2)
    var wordmarkStart: Double = 16.2  // last ayah ends → fade away, wordmark resolves
    var end:           Double = 20.0

    static let `default` = IntroTimeline()

    /// Ordered boundaries used to detect phase transitions for audio cueing.
    var boundaries: [(phase: IntroPhase, time: Double)] {
        [(.verse1, verse1Start),
         (.verse2, verse2Start),
         (.verse3, verse3Start),
         (.verse4, verse4Start),
         (.wordmark, wordmarkStart),
         (.done, end)]
    }

    func phase(at t: Double) -> IntroPhase {
        switch t {
        case ..<verse2Start:   return .verse1
        case ..<verse3Start:   return .verse2
        case ..<verse4Start:   return .verse3
        case ..<wordmarkStart: return .verse4
        case ..<end:           return .wordmark
        default:               return .done
        }
    }
}

enum IntroPhase: Int, Comparable {
    case verse1, verse2, verse3, verse4, wordmark, done
    static func < (l: IntroPhase, r: IntroPhase) -> Bool { l.rawValue < r.rawValue }
}

// MARK: - Public view

struct DuhaaIntroView: View {
    /// Called once the intro finishes or is skipped. Flip your `didPlayOpening` flag here.
    var onComplete: () -> Void = {}
    /// Called at every phase boundary — cue / seek the recitation audio from here.
    var onPhaseChange: (IntroPhase) -> Void = { _ in }

    var timeline: IntroTimeline = .default

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date = .now
    @State private var finished = false

    var body: some View {
        ZStack {
            if reduceMotion {
                ReduceMotionIntro(timeline: timeline)        // static, honors the accessibility setting
                    .onAppear { onPhaseChange(.verse3) }
            } else {
                TimelineView(.animation) { ctx in
                    let t = ctx.date.timeIntervalSince(start)
                    AnimatedIntro(t: t, timeline: timeline)
                        .onChange(of: timeline.phase(at: t)) { _, newPhase in
                            onPhaseChange(newPhase)
                            if newPhase == .done { complete() }
                        }
                }
            }

            SkipButton(action: complete)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, 20)
        }
        .background(IntroPalette.navy.ignoresSafeArea())
        .onAppear { start = .now }
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        onComplete()
    }
}

// MARK: - Animated composition

private struct AnimatedIntro: View {
    let t: Double
    let timeline: IntroTimeline

    /// Eased 0→1 ramp between two times.
    private func ramp(_ a: Double, _ b: Double) -> Double {
        guard b > a else { return t >= b ? 1 : 0 }
        let x = min(max((t - a) / (b - a), 0), 1)
        return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2   // easeInOut
    }

    /// Opacity for a block that fades in over [inS, inE] and out over [outS, outE].
    private func fade(_ inS: Double, _ inE: Double, _ outS: Double, _ outE: Double) -> Double {
        ramp(inS, inE) * (1 - ramp(outS, outE))
    }

    var body: some View {
        let glow = ramp(0.3, 5)   // dawn breaks under the opening oaths

        // four verses, each on-screen exactly during its recited window, crossfading on the audio boundaries
        let v1 = fade(0.0,  0.4,  1.4,  1.8)    // full hold 0.4–1.4 (1.0s, like the others)
        let v2 = fade(1.6,  1.95, 5.0,  5.3)    // 1.6–5.3
        let v3 = fade(5.3,  5.7,  9.5,  9.8)    // 5.3–9.8
        let v4 = fade(9.8,  10.3, 15.4, 16.2)   // 9.8–16.2, then fades after the last ayah ends

        let mark   = fade(16.2, 17.4, 19.6, 20.0)
        let stars  = ramp(0, 0.8) * (1 - 0.3 * ramp(1, 5))
        let screen = 1 - ramp(19.6, 20.0)   // graceful fade out into home

        // the embrace: a slow, living breath of warmth behind the third ayah —
        // "your Lord has not forsaken you." Tied to v3, so it never outlives the verse.
        let breath = 0.5 + 0.5 * sin(t * 1.05)

        ZStack {
            StarField(opacity: stars, drift: t)
            DawnGlow(opacity: glow, swell: 1 + 0.05 * sin(t * 0.6))

            VerseBlock(
                arabic: "وَالضُّحَىٰ",
                translit: "Wad-duhaa",
                line: "By the morning brightness",
                arabicSize: 58
            )
            .opacity(v1).offset(y: (1 - v1) * 16)

            VerseBlock(
                arabic: "وَاللَّيْلِ إِذَا سَجَىٰ",
                translit: "Wal-layli idha sajaa",
                line: "And by the night when it grows still",
                arabicSize: 52
            )
            .opacity(v2).offset(y: (1 - v2) * 16)

            Embrace()
                .opacity(v3 * (0.55 + 0.45 * breath))
                .scaleEffect(1 + 0.10 * breath, anchor: .center)

            VerseBlock(
                arabic: "مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ",
                translit: "Maa wadda'aka rabbuka wa maa qalaa",
                line: "Your Lord has not forsaken you, nor does He hate you.",
                arabicSize: 38
            )
            .opacity(v3).offset(y: (1 - v3) * 16)

            VerseBlock(
                arabic: "وَلَلْآخِرَةُ خَيْرٌ لَّكَ مِنَ الْأُولَىٰ",
                translit: "Wa lal-aakhiratu khayrun laka minal-oolaa",
                line: "And the Hereafter is better for you than the first.",
                arabicSize: 38
            )
            .opacity(v4).offset(y: (1 - v4) * 16)

            Wordmark()
                .opacity(mark)
                .offset(y: (1 - mark) * 14)
        }
        .opacity(screen)
        .ignoresSafeArea()
    }
}

// MARK: - Reduce Motion fallback (static — still shows light, Arabic, reassurance)

private struct ReduceMotionIntro: View {
    let timeline: IntroTimeline
    var body: some View {
        ZStack {
            StarField(opacity: 0.55, drift: 0)
            DawnGlow(opacity: 0.82, swell: 1)
            Embrace().opacity(0.6)   // warmth held behind the reassurance, even at rest
            VerseBlock(
                arabic: "مَا وَدَّعَكَ رَبُّكَ وَمَا قَلَىٰ",
                translit: "Maa wadda'aka rabbuka wa maa qalaa",
                line: "Your Lord has not forsaken you, nor does He hate you.",
                arabicSize: 38
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Pieces

private struct StarField: View {
    let opacity: Double
    let drift: Double

    // Stable field generated once.
    private static let stars: [(CGPoint, CGFloat, Double, Bool)] = {
        var g = SystemRandomNumberGenerator()
        return (0..<54).map { _ in
            (CGPoint(x: .random(in: 0...1, using: &g), y: .random(in: 0...0.64, using: &g)),
             CGFloat.random(in: 1...2.6, using: &g),
             Double.random(in: 0.3...0.9, using: &g),
             Double.random(in: 0...1, using: &g) < 0.18)
        }
    }()

    var body: some View {
        Canvas { ctx, size in
            for (p, r, base, blue) in Self.stars {
                let twinkle = 0.5 + 0.5 * sin(drift * 1.2 + Double(p.x) * 30)
                let rect = CGRect(x: p.x * size.width - r,
                                  y: p.y * size.height - r - drift * 1.4,
                                  width: r * 2, height: r * 2)
                let color = (blue ? IntroPalette.blue : Color.white).opacity(base * (0.4 + 0.6 * twinkle))
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

private struct DawnGlow: View {
    let opacity: Double
    let swell: CGFloat
    var body: some View {
        ZStack {
            // secondary blue horizon wash
            LinearGradient(colors: [IntroPalette.blue.opacity(0.10), .clear],
                           startPoint: .bottom, endPoint: .top)
                .frame(maxHeight: .infinity, alignment: .bottom)

            // primary gold dawn
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: IntroPalette.gold.opacity(0.62), location: 0.0),
                    .init(color: IntroPalette.gold.opacity(0.20), location: 0.38),
                    .init(color: IntroPalette.gold.opacity(0.04), location: 0.62),
                    .init(color: .clear, location: 0.80),
                ]),
                center: .bottom, startRadius: 0, endRadius: 520)
                .scaleEffect(swell, anchor: .bottom)
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

private struct Embrace: View {
    var body: some View {
        RadialGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 1, green: 0.85, blue: 0.57).opacity(0.50), location: 0.0),
                .init(color: IntroPalette.gold.opacity(0.18), location: 0.46),
                .init(color: .clear, location: 0.72),
            ]),
            center: .center, startRadius: 0, endRadius: 300)
            .blur(radius: 3)
            .allowsHitTesting(false)
    }
}

private struct VerseBlock: View {
    let arabic: String
    let translit: String
    let line: String
    let arabicSize: CGFloat

    var body: some View {
        VStack(spacing: 20) {
            Text(arabic)
                .font(.introUthmani(arabicSize))
                .foregroundStyle(IntroPalette.gold)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .shadow(color: IntroPalette.gold.opacity(0.35), radius: 18)
                .environment(\.layoutDirection, .rightToLeft)

            Text(translit.uppercased())
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(IntroPalette.blue)

            Text(line)
                .font(.system(size: 16, weight: .light, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(translit). \(line)")
    }
}

private struct Wordmark: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("ﺿﺤﻰ")
                .font(.introUthmani(80))
                .foregroundStyle(IntroPalette.gold)
                .shadow(color: IntroPalette.gold.opacity(0.4), radius: 24)
            Text("DUHAA")
                .font(.system(size: 22, weight: .light, design: .rounded))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.86))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Duhaa")
    }
}

private struct SkipButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Skip")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.5), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
        }
        .accessibilityLabel("Skip intro")
    }
}

// MARK: - Preview

#Preview {
    DuhaaIntroView(
        onComplete: { print("didPlayOpening = true") },
        onPhaseChange: { phase in print("phase →", phase) }
    )
}
