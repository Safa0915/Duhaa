import SwiftUI

/// The Qibla tab: a celestial compass. The gold needle points to the Kaaba;
/// turn the phone until it points straight up at the fixed marker. On a real
/// device the dial tracks the live heading; in the Simulator (no magnetometer)
/// it shows the Qibla relative to North.
///
/// The live heading (which fires many updates per second) lives in `QiblaCompass`,
/// not here — so the theme background and the rest of the screen are NOT
/// re-rendered on every heading tick. And the decorated themes' ambient fields
/// (hearts/blossoms/leaves/stars) pause entirely while their tabs sit off-screen
/// (`AmbientTimelineView`), so no hidden tab competes with the compass for frames.
struct QiblaView: View {
    @Environment(LocationProvider.self) private var location

    private var qiblaBearing: Double {
        QiblaBearingCalculator.bearing(from: location.active) ?? 0
    }

    private var distanceKm: Double {
        QiblaBearingCalculator.distanceKm(from: location.active) ?? 0
    }

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 24) {
                Text("QIBLA")
                    .duhaaFont(13, .semibold).tracking(3)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .padding(.top, 20)

                QiblaCompass(qiblaBearing: qiblaBearing,
                             distanceKm: distanceKm,
                             locationName: location.active.name,
                             size: 290)
                Spacer()
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }
}

// MARK: - Compass (owns the live heading in isolation)

/// The rotating compass, readout and status line. It owns the heading stream, so
/// heading updates re-render only this subview — never the parent's background.
private struct QiblaCompass: View {
    let qiblaBearing: Double
    let distanceKm: Double
    let locationName: String
    let size: CGFloat

    @State private var viewModel: QiblaViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// easeOut(0.12) fills the ~100 ms gap between sensor samples while staying
    /// fast at the start of each move (tracks the phone) and slowing near the
    /// target (no "trailing" feel). At 10 Hz the animation completes before the
    /// next sample arrives, so there is no retargeting churn.
    private var trackingAnimation: Animation {
        reduceMotion ? .linear(duration: 0.05) : .easeOut(duration: 0.12)
    }

    init(qiblaBearing: Double, distanceKm: Double, locationName: String, size: CGFloat) {
        self.qiblaBearing = qiblaBearing
        self.distanceKm = distanceKm
        self.locationName = locationName
        self.size = size
        _viewModel = State(initialValue: QiblaViewModel(qiblaBearing: qiblaBearing))
    }

    var body: some View {
        VStack(spacing: 24) {
            compass(size: size)
            VStack(spacing: 12) {
                readout
                if viewModel.hasHeading {
                    headingReadout
                }
            }
            statusLine
        }
        .onAppear {
            viewModel.updateQiblaBearing(qiblaBearing)
            viewModel.screenAppeared()
            DispatchQueue.main.async {
                viewModel.start()
            }
        }
        .onDisappear {
            viewModel.screenDisappeared()
        }
        .onChange(of: qiblaBearing) { _, newValue in
            viewModel.updateQiblaBearing(newValue)
        }
    }

    // MARK: Compass

    private func compass(size: CGFloat) -> some View {
        let r = size / 2
        let state = viewModel.compassState
        return ZStack {
            Circle().stroke(Color.primary.opacity(0.10), lineWidth: 1)
                .frame(width: size, height: size)
            Circle()
                .stroke((state.isAligned ? Palette.gold : Palette.blue).opacity(state.isAligned ? 0.55 : 0.15),
                        lineWidth: state.isAligned ? 2 : 1)
                .frame(width: size - 20, height: size - 20)
                .shadow(color: state.isAligned ? Palette.gold.opacity(0.4) : .clear, radius: 10)

            // Rotating dial (ticks + cardinals)
            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    let major = i % 9 == 0
                    Capsule()
                        .fill(Color.primary.opacity(major ? 0.45 : 0.16))
                        .frame(width: major ? 2 : 1, height: major ? 12 : 6)
                        .offset(y: -(r - 8))
                        .rotationEffect(.degrees(Double(i) * 5))
                }
                cardinal("N", 0, r - 32, gold: true)
                cardinal("E", 90, r - 32)
                cardinal("S", 180, r - 32)
                cardinal("W", 270, r - 32)
            }
            .frame(width: size, height: size)
            // Flatten the 72 ticks + 4 cardinals into one GPU texture so a live
            // heading (which fires many updates per second) just transforms a
            // cached layer instead of re-compositing ~80 views every frame.
            .drawingGroup()
            .rotationEffect(.degrees(-state.continuousHeading))
            .animation(trackingAnimation, value: state.continuousHeading)

            // Qibla needle
            QiblaNeedle()
                .fill(LinearGradient(colors: [Palette.gold, Palette.gold.opacity(0.55)],
                                     startPoint: .top, endPoint: .center))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(state.relativeQibla))
                .animation(trackingAnimation, value: state.relativeQibla)
                .shadow(color: Palette.gold.opacity(0.5), radius: 6)

            // Center hub with Kaaba glyph
            ZStack {
                Circle().fill(Palette.appBg).frame(width: 66, height: 66)
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1).frame(width: 66, height: 66)
                VStack(spacing: 1) {
                    Image(systemName: "cube.fill")
                        .duhaaFont(22)
                        .foregroundStyle(state.isAligned ? Palette.gold : Palette.blue)
                    Text("\(Int(qiblaBearing.rounded()))°")
                        .duhaaFont(11, .medium)
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }

            // Fixed reference marker at the top, pointing down at the dial
            Triangle()
                .fill(state.isAligned ? Palette.gold : .primary.opacity(0.7))
                .frame(width: 16, height: 13)
                .rotationEffect(.degrees(180))
                .offset(y: -(r + 6))
        }
        .frame(width: size, height: size)
    }

    private func cardinal(_ text: String, _ angle: Double, _ radius: CGFloat, gold: Bool = false) -> some View {
        Text(text)
            .duhaaFont(gold ? 17 : 13, .semibold)
            .foregroundStyle(gold ? Palette.gold : .primary.opacity(0.55))
            .rotationEffect(.degrees(-angle))   // keep upright relative to the dial
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
    }

    // MARK: Readout + status

    private var readout: some View {
        VStack(spacing: 6) {
            Text("\(Int(qiblaBearing.rounded()))° \(compassPoint(qiblaBearing))")
                .duhaaFont(24, .semibold)
                .foregroundStyle(.primary)
            Text("\(formattedDistance) to Makkah")
                .duhaaFont(14)
                .foregroundStyle(Palette.blue.opacity(0.8))
            Text(locationName)
                .duhaaFont(12)
                .foregroundStyle(Palette.blue.opacity(0.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Qibla \(Int(qiblaBearing.rounded())) degrees \(compassPoint(qiblaBearing)), \(formattedDistance) to Makkah")
    }

    /// The direction the phone itself is pointing right now, so the user can read
    /// their own bearing and turn it toward the Qibla bearing above. Mirrors the
    /// dial's `continuousHeading`, normalized to 0–359°. Hidden from VoiceOver —
    /// it updates many times per second and the alignment status is the accessible
    /// path — and only shown once a live heading exists (not in the Simulator).
    private var headingReadout: some View {
        let heading = QiblaAngles.normalized(viewModel.continuousHeading)
        let degrees = Int(heading.rounded()) % 360
        return Text("You're facing \(degrees)° \(compassPoint(heading))")
            .duhaaFont(13, .medium)
            .foregroundStyle(Palette.blue.opacity(0.55))
            .accessibilityHidden(true)
    }

    @ViewBuilder private var statusLine: some View {
        if viewModel.startupState == .headingUnavailable {
            note("Live compass needs a real device.\nShowing Qibla relative to North.")
        } else if viewModel.isAligned {
            Label("Facing the Qibla", systemImage: "checkmark.circle.fill")
                .duhaaFont(15, .semibold)
                .foregroundStyle(Palette.gold)
        } else if !viewModel.hasHeading {
            note("Hold your phone flat to calibrate the compass…")
        } else {
            note("Hold your phone flat, then turn until\nthe gold arrow points up.")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .duhaaFont(12)
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.blue.opacity(0.6))
            .padding(.horizontal, 40)
    }

    // MARK: Helpers

    private var formattedDistance: String {
        let value = Int(distanceKm.rounded()).formatted(.number)
        return "\(value) km"
    }

    private func compassPoint(_ degrees: Double) -> String {
        QiblaAngles.compassPoint(degrees)
    }
}

// MARK: - Shapes

/// Upward-pointing triangle.
private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// A needle drawn from the frame's center up to near the top, so rotating the
/// frame swings the tip around the center.
private struct QiblaNeedle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let cx = r.midX
        let tipY = r.minY + 24
        // shaft: from just below the arrowhead down to the center
        p.addRoundedRect(in: CGRect(x: cx - 2.5, y: tipY + 22, width: 5, height: r.midY - (tipY + 22)),
                         cornerSize: CGSize(width: 2.5, height: 2.5))
        // arrowhead — larger so the Qibla direction reads at a glance
        p.move(to: CGPoint(x: cx, y: tipY))
        p.addLine(to: CGPoint(x: cx + 17, y: tipY + 28))
        p.addLine(to: CGPoint(x: cx - 17, y: tipY + 28))
        p.closeSubpath()
        return p
    }
}
