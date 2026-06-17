import SwiftUI
import UserNotifications

@main
struct DuhaaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var location = LocationProvider()
    @State private var settings = SettingsStore()
    @State private var notifications = NotificationSettings()
    @State private var tracker = PrayerTracker()
    @State private var theme = ThemeStore()
    @State private var quranBookmarks = QuranBookmarks()
    @State private var tabSettings = TabSettings()
    @State private var fastingTracker = FastingTracker()
    @State private var insightsStore = InsightsStore()
    @State private var subscriptions = SubscriptionStore()
    @State private var didRunInitialNotificationSchedule = false
    @State private var lastAppNotificationReschedule: Date?
    @State private var showingNotificationOptIn = false
    @AppStorage("duhaa.hasOnboarded") private var hasOnboarded = false
    @AppStorage("duhaa.shortcut.targetTab") private var shortcutTargetTab = ""
    @AppStorage("duhaa.notifications.didShowOptIn") private var didShowNotificationOptIn = false

    private let notificationRescheduleCooldown: TimeInterval = 30

    init() { QuranFont.register() }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    MainTabView()
                } else {
                    OnboardingView { hasOnboarded = true }
                }
            }
            .environment(location)
            .environment(settings)
            .environment(notifications)
            .environment(tracker)
            .environment(theme)
            .environment(quranBookmarks)
            .environment(tabSettings)
            .environment(fastingTracker)
            .environment(insightsStore)
            .environment(subscriptions)
            .id(theme.theme) // rebuild the tree so the new palette takes effect everywhere
            // Drive the app-wide accent from the LIVE theme. Without this, any
            // control that falls back to the default accent uses the static gold
            // AccentColor asset (Assets.xcassets) — which can't follow the theme,
            // so it would show gold even in Light Pink. This keeps the tint true.
            .tint(Palette.gold)
            .onAppear {
                FirstUseDiagnostics.event("App root view visible")
            }
            .task(id: hasOnboarded) {
                // Start location + notification scheduling only once we're past onboarding.
                guard hasOnboarded else { return }
                FirstUseDiagnostics.event("App launch finished", "hasOnboarded=true")
                AppDataWarmup.start()
                location.start()
                rescheduleNotifications()
                updateWidgetSnapshot()
                didRunInitialNotificationSchedule = true
                await presentNotificationOptInIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active && hasOnboarded && didRunInitialNotificationSchedule else { return }
                // Re-fill the rolling notification window on every app open (spec §8).
                rescheduleNotifications()
                // Widget → app: pull any prayers checked off from the widget while
                // we were away, then refresh the widget's own times snapshot.
                tracker.reloadFromStore()
                updateWidgetSnapshot()
            }
            // Keep the widget's times + theme in step with the live app state.
            .onChange(of: location.active) { _, _ in updateWidgetSnapshot() }
            .onChange(of: theme.theme) { _, _ in updateWidgetSnapshot() }
            .onChange(of: settings.prayerConfig) { _, _ in updateWidgetSnapshot() }
            // Daily Du'a widget tap → open the Du'as tab (reuses the shortcut path).
            .onOpenURL { url in
                guard url.scheme == "duhaa", url.host == "dua" else { return }
                shortcutTargetTab = DuhaaTab.duas.rawValue
            }
            .sheet(isPresented: $showingNotificationOptIn) {
                NotificationOptInView(
                    onEnable: enableNotificationsFromOptIn,
                    onNotNow: dismissNotificationOptIn
                )
                .presentationDetents([.medium])
            }
        }
    }

    /// Recompute the shared widget times payload from the current location, prayer
    /// settings, and theme, so home-screen widgets stay accurate without the app.
    private func updateWidgetSnapshot() {
        guard hasOnboarded else { return }
        WidgetSnapshotWriter.update(location: location.active,
                                    config: settings.prayerConfig,
                                    themeID: theme.theme.rawValue,
                                    hijriOffsetDays: settings.hijriOffsetDays)
    }

    private func rescheduleNotifications(force: Bool = false) {
        let now = Date()
        if !force,
           let lastAppNotificationReschedule,
           now.timeIntervalSince(lastAppNotificationReschedule) < notificationRescheduleCooldown {
            return
        }
        lastAppNotificationReschedule = now
        NotificationScheduler.reschedule(location: location.active,
                                         config: settings.prayerConfig,
                                         notifs: notifications)
    }

    @MainActor
    private func presentNotificationOptInIfNeeded() async {
        guard !didShowNotificationOptIn else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        showingNotificationOptIn = true
    }

    private func enableNotificationsFromOptIn() {
        didShowNotificationOptIn = true
        showingNotificationOptIn = false
        Task {
            await NotificationScheduler.requestAuthorization()
            rescheduleNotifications(force: true)
        }
    }

    private func dismissNotificationOptIn() {
        didShowNotificationOptIn = true
        showingNotificationOptIn = false
    }
}
