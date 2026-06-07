import SwiftUI

@main
struct DuhaApp: App {
    @State private var location = LocationProvider()
    @State private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            PrayerHomeView()
                .environment(location)
                .environment(settings)
                .task { location.start() }
        }
    }
}
