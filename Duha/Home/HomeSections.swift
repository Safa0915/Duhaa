import SwiftUI

// MARK: - Background

/// The locked celestial backdrop: dark navy with a warm gold glow up top, a cool
/// blue glow mid-right, and a scattering of faint stars.
struct CelestialBackground: View {
    var body: some View {
        ZStack {
            Palette.appBg
            RadialGradient(colors: [Palette.gold.opacity(0.18), .clear],
                           center: .top, startRadius: 0, endRadius: 320)
            RadialGradient(colors: [Palette.blue.opacity(0.12), .clear],
                           center: .init(x: 0.95, y: 0.32), startRadius: 0, endRadius: 260)
            StarField()
        }
        .ignoresSafeArea()
    }
}

/// A subtle, fixed scatter of stars across the upper portion of the screen.
private struct StarField: View {
    // (xFraction, yFraction, radius, opacity, color)
    private let stars: [(Double, Double, Double, Double, Color)] = [
        (0.11, 0.10, 1.0, 0.6, Palette.blue), (0.22, 0.07, 0.7, 0.5, Palette.gold),
        (0.33, 0.11, 1.2, 0.3, .white),       (0.79, 0.08, 0.8, 0.5, Palette.blue),
        (0.90, 0.12, 1.0, 0.3, .white),       (0.85, 0.16, 0.6, 0.4, Palette.gold),
        (0.15, 0.19, 0.7, 0.25, .white),      (0.95, 0.20, 0.8, 0.4, Palette.blue),
        (0.05, 0.24, 1.0, 0.2, .white),       (0.44, 0.06, 0.6, 0.35, Palette.gold),
        (0.56, 0.09, 0.5, 0.3, .white),       (0.68, 0.05, 0.9, 0.45, Palette.blue),
    ]

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(stars.enumerated()), id: \.offset) { _, s in
                Circle()
                    .fill(s.4)
                    .frame(width: s.2 * 2, height: s.2 * 2)
                    .opacity(s.3)
                    .position(x: geo.size.width * s.0, y: geo.size.height * s.1)
            }
        }
    }
}

// MARK: - Next-prayer banner

struct NextPrayerBanner: View {
    let nextName: String
    let countdown: String
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
                    Text("NEXT PRAYER")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.8)
                        .foregroundStyle(Palette.gold.opacity(0.8))
                }
                Spacer()
                (Text("\(nextName) in ").foregroundStyle(.white)
                 + Text(countdown).foregroundStyle(Palette.gold))
                    .font(.system(size: 18, weight: .semibold))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.gold.opacity(0.5), Palette.gold],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * progress))
                        .shadow(color: Palette.gold.opacity(0.4), radius: 4)
                }
            }
            .frame(height: 3)

            HStack {
                Text(prevLabel)
                Spacer()
                Text(nextLabel)
            }
            .font(.system(size: 10))
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
}

// MARK: - Prayer list

struct PrayersCard: View {
    let rows: [PrayerRowData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRAYER TIMES")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.blue.opacity(0.65))
                .padding(.horizontal, 6)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { Divider().overlay(Color.white.opacity(0.09)) }
                    PrayerRowView(row: row)
                }
            }
            .background(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct PrayerRowView: View {
    let row: PrayerRowData

    private var isNext: Bool { row.state == .next }

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 10)
                .fill(isNext ? Palette.gold.opacity(0.12) : Color.white.opacity(0.05))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: row.prayer.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(isNext ? Palette.gold : Palette.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(row.prayer.rawValue)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                if let sub = row.sub {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.blue.opacity(0.45))
                }
            }

            Spacer()

            Text(row.time)
                .font(.system(size: isNext ? 16 : 15, weight: isNext ? .semibold : .medium))
                .foregroundStyle(isNext ? Palette.gold : Palette.prayerTime)

            if isNext {
                Text("NEXT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Palette.gold.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.gold.opacity(0.3), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
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
        .opacity(row.state == .passed ? 0.38 : 1)
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
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.blue.opacity(0.7))
                Text("NIGHT PRAYER")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Palette.blue.opacity(0.5))
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 12)
            .overlay(alignment: .bottom) { Divider().overlay(Color.white.opacity(0.05)) }

            nightRow(icon: "moon.stars", name: "Tahajjud",
                     sub: "Last third of night", time: tahajjud)
            Divider().overlay(Color.white.opacity(0.04))
            nightRow(icon: "clock", name: "Islamic Midnight",
                     sub: "Between Maghrib & Fajr", time: islamicMidnight)
        }
        .background(
            LinearGradient(colors: [Palette.blue.opacity(0.12), Palette.appBg.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.blue.opacity(0.22), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func nightRow(icon: String, name: String, sub: String, time: String) -> some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Palette.blue.opacity(0.07))
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Palette.blue))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                Text(sub).font(.system(size: 11)).foregroundStyle(Palette.blue.opacity(0.4))
            }
            Spacer()
            Text(time).font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.blue.opacity(0.7))
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
    }
}
