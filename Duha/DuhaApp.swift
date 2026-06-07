import SwiftUI

@main
struct DuhaApp: App {
    @State private var location = LocationProvider()

    var body: some Scene {
        WindowGroup {
            PrayerHomeView()
                .environment(location)
                .task { location.start() }
        }
    }
}
