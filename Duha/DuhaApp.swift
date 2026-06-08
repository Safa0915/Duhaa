import SwiftUI

@main
struct DuhaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var location = LocationProvider()
    @State private var settings = SettingsStore()
    @State private var notifications = NotificationSettings()
    @State private var tracker = PrayerTracker()
    @State private var theme = ThemeStore()
    @State private var quranBookmarks = QuranBookmarks()
    @State private var tabSettings = TabSettings()
    @State private var cycleTracker = CycleTracker()
    @AppStorage("duha.hasOnboarded") private var hasOnboarded = false

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
            .environment(cycleTracker)
            .id(theme.theme) // rebuild the tree so the new palette takes effect everywhere
            .task(id: hasOnboarded) {
                // Start location + notifications only once we're past onboarding.
                guard hasOnboarded else { return }
                location.start()
                await NotificationScheduler.requestAuthorization()
                rescheduleNotifications()
            }
            .onChange(of: scenePhase) { _, phase in
                // Re-fill the rolling notification window on every app open (spec §8).
                if phase == .active && hasOnboarded { rescheduleNotifications() }
            }
        }
    }

    private func rescheduleNotifications() {
        NotificationScheduler.reschedule(location: location.active,
                                         config: settings.prayerConfig,
                                         notifs: notifications)
    }
}
