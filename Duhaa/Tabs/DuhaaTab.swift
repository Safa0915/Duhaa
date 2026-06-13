import SwiftUI

/// Every feature that can live in the tab bar. Add a case here (and in the three
/// switches below) and it automatically becomes a customizable tab — existing
/// users get it appended to the end of their order on next launch.
enum DuhaaTab: String, CaseIterable, Identifiable, Codable {
    case prayer, qibla, quran, duas, learn, tasbih, sisters

    var id: String { rawValue }

    /// The default order shipped to a brand-new user.
    static let defaultOrder: [DuhaaTab] = [.prayer, .qibla, .quran, .duas, .learn, .tasbih, .sisters]

    var title: String {
        switch self {
        case .prayer:  "Prayer"
        case .qibla:   "Qibla"
        case .quran:   "Quran"
        case .duas:    "Du'as"
        case .learn:   "Learn"
        case .tasbih:  "Tasbih"
        case .sisters: "Sisters"
        }
    }

    var icon: String {
        switch self {
        case .prayer:  "moon.stars.fill"
        case .qibla:   "location.north.line.fill"
        case .quran:   "book.closed.fill"
        case .duas:    "hands.sparkles.fill"
        case .learn:   "graduationcap.fill"
        case .tasbih:  "circle.hexagongrid.fill"
        case .sisters: "leaf.fill"
        }
    }

    func isAvailable(for profile: UserProfileGender) -> Bool {
        switch self {
        case .sisters:
            profile.showsSistersFeatures
        default:
            true
        }
    }

    /// Full-bleed tabs provide their own top chrome and want no nav bar. The rest
    /// rely on a NavigationStack from their host (MainTabView for direct tabs,
    /// MoreView for overflow) — which also gives them a "‹ More" back button.
    var isFullBleed: Bool {
        switch self {
        case .prayer, .qibla, .tasbih: true
        default: false
        }
    }

    @ViewBuilder
    func makeView() -> some View {
        switch self {
        case .prayer:  PrayerHomeView()
        case .qibla:   QiblaView()
        case .quran:   QuranListView()
        case .duas:    DuasView()
        case .learn:   LearnView()
        case .tasbih:  TasbihView()
        case .sisters: SistersView()
        }
    }
}
