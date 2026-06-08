import SwiftUI

/// Root tab bar. v1 ships Prayer + Qibla; Quran, Duas and a Settings tab arrive
/// later (Settings is reachable from the Prayer screen's gear for now).
struct MainTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            PrayerHomeView()
                .tag(0)
                .tabItem { Label("Prayer", systemImage: "moon.stars.fill") }

            QiblaView()
                .tag(1)
                .tabItem { Label("Qibla", systemImage: "location.north.line.fill") }

            QuranListView()
                .tag(2)
                .tabItem { Label("Quran", systemImage: "book.closed.fill") }

            DuasView()
                .tag(3)
                .tabItem { Label("Du'as", systemImage: "hands.sparkles.fill") }

            TasbihView()
                .tag(4)
                .tabItem { Label("Tasbih", systemImage: "circle.hexagongrid.fill") }
        }
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
    }
}
