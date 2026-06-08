import SwiftUI

/// The Prayer home screen — Duha's home tab. Shows the current time, the next
/// prayer with a live countdown, today's five prayers, and the night-prayer card,
/// all on the locked celestial design (design/design-1-celestial.html).
struct PrayerHomeView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var settings
    @Environment(PrayerTracker.self) private var tracker
    @State private var model = PrayerHomeModel()
    @State private var showingLocationPicker = false
    @State private var showingSettings = false
    @State private var moonBreath = false
    @State private var toast: String?
    @State private var toastToken = 0
    @State private var welcomeBack: String?
    @State private var verseSheet: VerseRef?
    @State private var showingJourney = false

    var body: some View {
        let d = model.display(for: location.active,
                              config: settings.prayerConfig,
                              hijriOffsetDays: settings.hijriOffsetDays,
                              hijriIsPrimary: settings.hijriIsPrimary)

        ZStack {
            CelestialBackground()

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .duhaFont(18)
                                .foregroundStyle(Palette.blue.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 4)

                    header(d)
                    hero(d)

                    if let welcomeBack {
                        WelcomeBackBanner(message: welcomeBack) {
                            withAnimation { self.welcomeBack = nil }
                        }
                        .padding(.horizontal, 22).padding(.top, 16)
                    }

                    if d.hasData {
                        NextPrayerBanner(nextName: d.nextName, countdown: d.countdown,
                                         progress: d.progress, prevLabel: d.prevLabel,
                                         nextLabel: d.nextLabel)
                            .padding(.horizontal, 22).padding(.top, 20)

                        VerseOfDayCard(ref: VerseOfDay.today()) {
                            verseSheet = VerseOfDay.today()
                        }
                        .padding(.horizontal, 22).padding(.top, 16)

                        PrayersCard(rows: d.rows, dayKey: d.dayKey,
                                    sunrise: d.sunrise, sunrisePassed: d.sunrisePassed) { _, nowPrayed in
                            if nowPrayed { showToast(Encouragements.afterPrayerMessage()) }
                        }
                        .padding(.horizontal, 22).padding(.top, 16)

                        TodayProgressCard(dayKey: d.dayKey, week: d.week) {
                            showingJourney = true
                        }
                        .padding(.horizontal, 22).padding(.top, 14)

                        NightCard(tahajjud: d.tahajjud, islamicMidnight: d.islamicMidnight)
                            .padding(.horizontal, 22).padding(.top, 14)
                    } else {
                        emptyState
                            .padding(.horizontal, 22).padding(.top, 28)
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingJourney) {
            JourneyView()
        }
        .sheet(item: $verseSheet) { ref in
            if let surah = Quran.surah(ref.surah) {
                NavigationStack {
                    SurahReaderView(surah: surah, scrollTo: ref.ayah)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { verseSheet = nil }.foregroundStyle(Palette.gold)
                            }
                        }
                }
                .preferredColorScheme(Palette.active.colorScheme)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .duhaFont(14, .medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.gold.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 14)
                    .padding(.horizontal, 30).padding(.bottom, 46)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: toast)
        .task { evaluateWelcomeBack() }
    }

    // MARK: Marking + welcome-back

    private func showToast(_ message: String) {
        toast = message
        toastToken += 1
        let token = toastToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            if toastToken == token { withAnimation { toast = nil } }
        }
    }

    private func evaluateWelcomeBack() {
        let todayKey = PrayerTracker.dayKey(Date(), location.active.timeZone)
        if let gap = tracker.recordOpen(today: todayKey), gap >= 2 {
            welcomeBack = Encouragements.welcomeBackMessage()
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
                        .duhaFont(10)
                        .foregroundStyle(Palette.blue.opacity(0.7))
                    Text(d.locationName)
                        .duhaFont(13, .medium)
                        .foregroundStyle(Palette.blue)
                    Image(systemName: "chevron.down")
                        .duhaFont(9, .semibold)
                        .foregroundStyle(Palette.blue.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            Text(d.headerDate)
                .duhaFont(12)
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
                    .scaleEffect(moonBreath ? 1.06 : 0.92)
                    .opacity(moonBreath ? 1.0 : 0.72)
                    .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: moonBreath)
                Image(systemName: "moon.stars.fill")
                    .duhaFont(46)
                    .foregroundStyle(Palette.gold)
            }
            .frame(height: 90)
            .onAppear { moonBreath = true }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(d.clock)
                    .duhaFont(62, .ultraLight)
                    .foregroundStyle(.primary)
                Text(d.period)
                    .duhaFont(22, .light)
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(d.heroDate.uppercased())
                .duhaFont(13)
                .tracking(0.5)
                .foregroundStyle(Palette.blue.opacity(0.75))
        }
        .padding(.top, 16)
    }

    // MARK: Empty state (extreme latitudes / no solution)

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.zzz")
                .duhaFont(30)
                .foregroundStyle(Palette.blue.opacity(0.6))
            Text("Prayer times aren't available for this location right now.")
                .duhaFont(14, .medium)
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.center)
            Text("This can happen at extreme latitudes. Try a nearby city from the location picker above.")
                .duhaFont(12)
                .foregroundStyle(Palette.blue.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    PrayerHomeView()
        .environment(LocationProvider())
        .environment(SettingsStore())
        .environment(PrayerTracker())
}

/// A warm, dismissible welcome for someone returning after a gap (spec §5).
private struct WelcomeBackBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.haze.fill")
                .duhaFont(18)
                .foregroundStyle(Palette.gold)
            Text(message)
                .duhaFont(13, .medium)
                .foregroundStyle(.primary.opacity(0.92))
            Spacer(minLength: 6)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .duhaFont(11, .bold)
                    .foregroundStyle(Palette.blue.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            LinearGradient(colors: [Palette.gold.opacity(0.16), Palette.gold.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.gold.opacity(0.3), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
