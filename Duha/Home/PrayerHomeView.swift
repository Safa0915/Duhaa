import SwiftUI

/// The Prayer home screen — Duha's home tab. Shows the current time, the next
/// prayer with a live countdown, today's five prayers, and the night-prayer card,
/// all on the locked celestial design (design/design-1-celestial.html).
struct PrayerHomeView: View {
    @Environment(LocationProvider.self) private var location
    @State private var model = PrayerHomeModel()
    @State private var showingLocationPicker = false

    var body: some View {
        let d = model.display(for: location.active)

        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(spacing: 0) {
                    header(d)
                    hero(d)

                    if d.hasData {
                        NextPrayerBanner(nextName: d.nextName, countdown: d.countdown,
                                         progress: d.progress, prevLabel: d.prevLabel,
                                         nextLabel: d.nextLabel)
                            .padding(.horizontal, 22).padding(.top, 20)

                        PrayersCard(rows: d.rows)
                            .padding(.horizontal, 22).padding(.top, 16)

                        NightCard(tahajjud: d.tahajjud, islamicMidnight: d.islamicMidnight)
                            .padding(.horizontal, 22).padding(.top, 14)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView()
        }
    }

    // MARK: Header — location + Hijri date

    private func header(_ d: HomeDisplay) -> some View {
        VStack(spacing: 6) {
            Button {
                showingLocationPicker = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.blue.opacity(0.7))
                    Text(d.locationName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.blue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.blue.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            Text(d.hijri)
                .font(.system(size: 12))
                .foregroundStyle(Palette.blue.opacity(0.75))
        }
        .padding(.top, 12)
    }

    // MARK: Hero — moon, big clock, date

    private func hero(_ d: HomeDisplay) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.gold.opacity(0.35), .clear],
                                         center: .center, startRadius: 0, endRadius: 55))
                    .frame(width: 110, height: 110)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Palette.gold)
            }
            .frame(height: 90)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(d.clock)
                    .font(.system(size: 62, weight: .ultraLight))
                    .foregroundStyle(.white)
                Text(d.period)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(d.gregorian.uppercased())
                .font(.system(size: 13))
                .tracking(0.5)
                .foregroundStyle(Palette.blue.opacity(0.75))
        }
        .padding(.top, 16)
    }
}

#Preview {
    PrayerHomeView()
        .environment(LocationProvider())
}
