import SwiftUI
import CoreLocation
import Adhan
import UIKit

/// The Qibla tab: a celestial compass. The gold needle points to the Kaaba;
/// turn the phone until it points straight up at the fixed marker. On a real
/// device the dial tracks the live heading; in the Simulator (no magnetometer)
/// it shows the Qibla relative to North.
struct QiblaView: View {
    @Environment(LocationProvider.self) private var location
    @State private var headingProvider = HeadingProvider()
    @State private var wasAligned = false

    private let kaaba = CLLocation(latitude: 21.4225, longitude: 39.8262)

    // MARK: Derived values

    private var qiblaBearing: Double {
        Qibla(coordinates: Coordinates(latitude: location.active.latitude,
                                       longitude: location.active.longitude)).direction
    }
    private var distanceKm: Double {
        CLLocation(latitude: location.active.latitude, longitude: location.active.longitude)
            .distance(from: kaaba) / 1000
    }
    private var heading: Double { headingProvider.heading ?? 0 }
    /// On-screen angle of the needle (0 = straight up).
    private var relativeQibla: Double { qiblaBearing - heading }
    private var aligned: Bool {
        guard headingProvider.heading != nil else { return false }
        return abs(angleDelta(heading, qiblaBearing)) < 5
    }

    // MARK: Body

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 24) {
                Text("QIBLA")
                    .font(.system(size: 13, weight: .semibold)).tracking(3)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .padding(.top, 20)

                compass(size: 290)
                readout
                statusLine
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { headingProvider.start() }
        .onDisappear { headingProvider.stop() }
        .onChange(of: aligned) { _, now in
            if now && !wasAligned { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            wasAligned = now
        }
    }

    // MARK: Compass

    private func compass(size: CGFloat) -> some View {
        let r = size / 2
        return ZStack {
            Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: size, height: size)
            Circle()
                .stroke((aligned ? Palette.gold : Palette.blue).opacity(aligned ? 0.55 : 0.15),
                        lineWidth: aligned ? 2 : 1)
                .frame(width: size - 20, height: size - 20)
                .shadow(color: aligned ? Palette.gold.opacity(0.4) : .clear, radius: 10)

            // Rotating dial (ticks + cardinals)
            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    let major = i % 9 == 0
                    Capsule()
                        .fill(Color.white.opacity(major ? 0.45 : 0.16))
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
            .rotationEffect(.degrees(-heading))
            .animation(.easeOut(duration: 0.18), value: heading)

            // Qibla needle
            QiblaNeedle()
                .fill(LinearGradient(colors: [Palette.gold, Palette.gold.opacity(0.55)],
                                     startPoint: .top, endPoint: .center))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(relativeQibla))
                .animation(.easeOut(duration: 0.18), value: relativeQibla)
                .shadow(color: Palette.gold.opacity(0.5), radius: 6)

            // Center hub with Kaaba glyph
            ZStack {
                Circle().fill(Palette.appBg).frame(width: 66, height: 66)
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1).frame(width: 66, height: 66)
                VStack(spacing: 1) {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(aligned ? Palette.gold : Palette.blue)
                    Text("\(Int(qiblaBearing.rounded()))°")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Fixed reference marker at the top, pointing down at the dial
            Triangle()
                .fill(aligned ? Palette.gold : .white.opacity(0.7))
                .frame(width: 16, height: 13)
                .rotationEffect(.degrees(180))
                .offset(y: -(r + 6))
        }
        .frame(width: size, height: size)
    }

    private func cardinal(_ text: String, _ angle: Double, _ radius: CGFloat, gold: Bool = false) -> some View {
        Text(text)
            .font(.system(size: gold ? 17 : 13, weight: .semibold))
            .foregroundStyle(gold ? Palette.gold : .white.opacity(0.55))
            .rotationEffect(.degrees(-angle))   // keep upright relative to the dial
            .offset(y: -radius)
            .rotationEffect(.degrees(angle))
    }

    // MARK: Readout + status

    private var readout: some View {
        VStack(spacing: 6) {
            Text("\(Int(qiblaBearing.rounded()))° \(compassPoint(qiblaBearing))")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
            Text("\(formattedDistance) to Makkah")
                .font(.system(size: 14))
                .foregroundStyle(Palette.blue.opacity(0.8))
            Text(location.active.name)
                .font(.system(size: 12))
                .foregroundStyle(Palette.blue.opacity(0.5))
        }
    }

    @ViewBuilder private var statusLine: some View {
        if !headingProvider.available {
            note("Live compass needs a real device.\nShowing Qibla relative to North.")
        } else if aligned {
            Label("Facing the Qibla", systemImage: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.gold)
        } else {
            note("Turn until the gold arrow points up.")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.blue.opacity(0.6))
            .padding(.horizontal, 40)
    }

    // MARK: Helpers

    private var formattedDistance: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let value = f.string(from: NSNumber(value: distanceKm)) ?? "\(Int(distanceKm))"
        return "\(value) km"
    }

    private func compassPoint(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let idx = Int((degrees.truncatingRemainder(dividingBy: 360) + 22.5) / 45)
        return points[(idx % 8 + 8) % 8]
    }

    /// Smallest signed angle from a to b, in -180…180.
    private func angleDelta(_ a: Double, _ b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
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
        let tipY = r.minY + 30
        // shaft: from just below the arrowhead down to the center
        p.addRoundedRect(in: CGRect(x: cx - 1.5, y: tipY + 16, width: 3, height: r.midY - (tipY + 16)),
                         cornerSize: CGSize(width: 1.5, height: 1.5))
        // arrowhead
        p.move(to: CGPoint(x: cx, y: tipY))
        p.addLine(to: CGPoint(x: cx + 12, y: tipY + 20))
        p.addLine(to: CGPoint(x: cx - 12, y: tipY + 20))
        p.closeSubpath()
        return p
    }
}
