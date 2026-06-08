import SwiftUI

/// Every feature that can live in the tab bar. Add a case here (and in the three
/// switches below) and it automatically becomes a customizable tab — existing
/// users get it appended to the end of their order on next launch.
enum DuhaTab: String, CaseIterable, Identifiable, Codable {
    case prayer, qibla, quran, duas, tasbih

    var id: String { rawValue }

    /// The default order shipped to a brand-new user.
    static let defaultOrder: [DuhaTab] = [.prayer, .qibla, .quran, .duas, .tasbih]

    var title: String {
        switch self {
        case .prayer: "Prayer"
        case .qibla:  "Qibla"
        case .quran:  "Quran"
        case .duas:   "Du'as"
        case .tasbih: "Tasbih"
        }
    }

    var icon: String {
        switch self {
        case .prayer: "moon.stars.fill"
        case .qibla:  "location.north.line.fill"
        case .quran:  "book.closed.fill"
        case .duas:   "hands.sparkles.fill"
        case .tasbih: "circle.hexagongrid.fill"
        }
    }

    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .prayer: PrayerHomeView()
        case .qibla:  QiblaView()
        case .quran:  QuranListView()
        case .duas:   DuasView()
        case .tasbih: TasbihView()
        }
    }
}
