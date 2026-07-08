import SwiftUI

/// The Prayer home screen — Duhaa's home tab. Shows the current time, the next
/// prayer with a live countdown, today's five prayers, and the night-prayer card,
/// all on the locked celestial design (design/design-1-celestial.html).
struct PrayerHomeView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var settings
    @Environment(PrayerTracker.self) private var tracker
    @Environment(SalahLockController.self) private var salahLock
    @Environment(FeedbackStore.self) private var feedback
    @Environment(QadaFasts.self) private var qada
    @State private var model = PrayerHomeModel()
    @State private var showingLocationPicker = false
    @State private var showingSettings = false
    @State private var showingHighLatitudeSettings = false
    @State private var moonBreath = false
    @State private var toast: String?
    @State private var toastToken = 0
    @State private var welcomeBack: String?
    @State private var verseSheet: VerseRef?
    @State private var showingJourney = false
    @State private var showingMosques = false
    @State private var showingFasting = false
    @State private var showingPrayerTimeDetails = false

    private var isHighLatitude: Bool { abs(location.active.latitude) > 48 }

    var body: some View {
        let d = model.display(for: location.active,
                              config: settings.prayerConfig,
                              hijriOffsetDays: settings.hijriOffsetDays,
                              hijriIsPrimary: settings.hijriIsPrimary,
                              masjid: settings.masjid)

        ZStack {
            CelestialBackground(allowsThemeDecorations: true)

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .duhaaFont(18)
                                .foregroundStyle(Palette.blue.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
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
                                         displayMode: settings.nextPrayerDisplayMode,
                                         timeRemainingCountdown: d.timeRemainingCountdown,
                                         timeRemainingTarget: d.timeRemainingTarget,
                                         timeRemainingProgress: d.timeRemainingProgress,
                                         timeRemainingPrevLabel: d.timeRemainingPrevLabel,
                                         timeRemainingNextLabel: d.timeRemainingNextLabel,
                                         progress: d.progress, prevLabel: d.prevLabel,
                                         nextLabel: d.nextLabel)
                            .padding(.horizontal, 22).padding(.top, 20)

                        if isHighLatitude {
                            HighLatitudeHomeNotice {
                                showingHighLatitudeSettings = true
                            }
                            .padding(.horizontal, 22).padding(.top, 14)
                        }

                        if d.isRamadan {
                            RamadanCard(dayKey: d.dayKey, ramadanDay: d.ramadanDay,
                                        hijriYear: d.hijriYear, suhoor: d.suhoor, iftar: d.iftar,
                                        phase: d.ramadanPhase, countdown: d.ramadanCountdown)
                                .padding(.horizontal, 22).padding(.top, 16)
                        }

                        VerseOfDayCard(ref: VerseOfDay.today()) {
                            verseSheet = VerseOfDay.today()
                        }
                        .padding(.horizontal, 22).padding(.top, 16)

                        PrayersCard(rows: d.rows, masjidName: d.masjidName) { prayer, nowPrayed in
                            if nowPrayed {
                                feedback.recordMeaningfulAction(.prayerMarked)
                                // Lift any active Salah Lock for this prayer — the
                                // reward is for praying, not waiting out the cap.
                                salahLock.markPrayed(prayer.rawValue)
                                showToast(Encouragements.afterPrayerMessage())
                                // The fifth of five gets a little extra warmth.
                                if PrayerCompletionFeedback.shouldPlayPerfectDay(
                                    nowPrayed: nowPrayed,
                                    prayedCount: tracker.count(dayKey: d.dayKey)
                                ) {
                                    DuhaaHaptics.perfectDay()
                                }
                            }
                        }
                        .padding(.horizontal, 22).padding(.top, 16)

                        PrayerTimeDetailsButton {
                            showingPrayerTimeDetails = true
                        }
                        .padding(.horizontal, 22).padding(.top, 14)

                        TodayProgressCard(dayKey: d.dayKey, week: d.week) {
                            showingJourney = true
                        }
                        .padding(.horizontal, 22).padding(.top, 14)

                        let fastKinds = d.isRamadan ? [] :
                            VoluntaryFast.kinds(for: Date(), timeZone: location.active.timeZone,
                                                hijriOffsetDays: settings.hijriOffsetDays)
                        if !d.isRamadan && (!fastKinds.isEmpty || qada.owed > 0) {
                            FastingCard(dayKey: d.dayKey, kinds: fastKinds) {
                                showingFasting = true
                            }
                            .padding(.horizontal, 22).padding(.top, 14)
                        }

                        NightCard(tahajjud: d.tahajjud, islamicMidnight: d.islamicMidnight)
                            .padding(.horizontal, 22).padding(.top, 14)

                        NearbyMosquesButton { showingMosques = true }
                            .padding(.horizontal, 22).padding(.top, 14)
                    } else {
                        emptyState
                            .padding(.horizontal, 22).padding(.top, 28)
                    }
                }
                // The floating tab bar overlays full-screen tab content, so the
                // final prayer rows need enough room to scroll above it.
                .padding(.bottom, 150)
                .duhaaReadableWidth()
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
        .sheet(isPresented: $showingHighLatitudeSettings) {
            NavigationStack { HighLatitudeSettingsView() }
        }
        .sheet(isPresented: $showingJourney) {
            JourneyView()
        }
        .sheet(isPresented: $showingFasting) {
            FastingView()
        }
        .sheet(isPresented: $showingPrayerTimeDetails) {
            PrayerTimeDetailsView()
        }
        .sheet(isPresented: $showingMosques) {
            NearbyMosquesView()
        }
        .sheet(item: $verseSheet) { ref in
            VerseReaderSheet(ref: ref) { verseSheet = nil }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .duhaaFont(14, .medium)
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
                        .duhaaFont(10)
                        .foregroundStyle(Palette.blue.opacity(0.7))
                    Text(d.locationName)
                        .duhaaFont(13, .medium)
                        .foregroundStyle(Palette.blue)
                    Image(systemName: "chevron.down")
                        .duhaaFont(9, .semibold)
                        .foregroundStyle(Palette.blue.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            Text(d.headerDate)
                .duhaaFont(12)
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
                    .duhaaFont(46)
                    .foregroundStyle(Palette.gold)
            }
            .frame(height: 90)
            .onAppear { moonBreath = true }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(d.clock)
                    .duhaaFont(62, .ultraLight)
                    .foregroundStyle(.primary)
                Text(d.period)
                    .duhaaFont(22, .light)
                    .foregroundStyle(.primary.opacity(0.7))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(d.heroDate.uppercased())
                .duhaaFont(13)
                .tracking(0.5)
                .foregroundStyle(Palette.blue.opacity(0.75))
        }
        .padding(.top, 16)
    }

    // MARK: Empty state (extreme latitudes / no solution)

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.zzz")
                .duhaaFont(30)
                .foregroundStyle(Palette.blue.opacity(0.6))
            Text("Prayer times aren't available for this location right now.")
                .duhaaFont(14, .medium)
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.center)
            Text("This can happen at extreme latitudes. Try a nearby city from the location picker above.")
                .duhaaFont(12)
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

private struct VerseReaderSheet: View {
    let ref: VerseRef
    let onDone: () -> Void

    @State private var surah: Surah?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Group {
                if let surah {
                    SurahReaderView(surah: surah, scrollTo: ref.ayah, highlightTarget: true)
                } else if didLoad {
                    ContentUnavailableView("Verse unavailable",
                                           systemImage: "book.closed",
                                           description: Text("Couldn’t open this verse."))
                } else {
                    ProgressView()
                        .tint(Palette.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }.foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .task(id: ref.id) {
            didLoad = false
            surah = await Quran.surahAsync(ref.surah)
            didLoad = true
        }
    }
}

#Preview {
    PrayerHomeView()
        .environment(LocationProvider())
        .environment(SettingsStore())
        .environment(PrayerTracker())
        .environment(SalahLockController())
        .environment(FeedbackStore())
        .environment(QadaFasts())
}

/// A warm, dismissible welcome for someone returning after a gap (spec §5).
private struct WelcomeBackBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sun.haze.fill")
                .duhaaFont(18)
                .foregroundStyle(Palette.gold)
            Text(message)
                .duhaaFont(13, .medium)
                .foregroundStyle(.primary.opacity(0.92))
            Spacer(minLength: 6)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .duhaaFont(11, .bold)
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

private struct HighLatitudeHomeNotice: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .duhaaFont(17, .semibold)
                    .foregroundStyle(Palette.gold)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Verify Fajr & Isha locally")
                        .duhaaFont(14, .semibold)
                        .foregroundStyle(.primary)
                    Text("At this latitude, dawn and night can be approximate. Compare with a trusted local mosque and adjust times if needed.")
                        .duhaaFont(12)
                        .foregroundStyle(Palette.blue.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .duhaaFont(11, .semibold)
                    .foregroundStyle(Palette.blue.opacity(0.55))
                    .padding(.top, 3)
            }
            .padding(14)
            .background(Palette.gold.opacity(0.10))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.gold.opacity(0.32), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("High latitude caution. Verify Fajr and Isha with a trusted local mosque and adjust times if needed.")
    }
}
