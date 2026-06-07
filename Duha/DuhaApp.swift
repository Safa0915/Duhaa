import SwiftUI

@main
struct DuhaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var location = LocationProvider()
    @State private var settings = SettingsStore()
    @State private var notifications = NotificationSettings()

    var body: some Scene {
        WindowGroup {
            PrayerHomeView()
                .environment(location)
                .environment(settings)
                .environment(notifications)
                .task {
                    location.start()
                    await NotificationScheduler.requestAuthorization()
                    rescheduleNotifications()
                }
                .onChange(of: scenePhase) { _, phase in
                    // Re-fill the rolling notification window on every app open (spec §8).
                    if phase == .active { rescheduleNotifications() }
                }
        }
    }

    private func rescheduleNotifications() {
        NotificationScheduler.reschedule(location: location.active,
                                         config: settings.prayerConfig,
                                         notifs: notifications)
    }
}
