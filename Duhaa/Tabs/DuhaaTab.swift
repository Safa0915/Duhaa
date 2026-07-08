import SwiftUI

/// Every feature that can live in the tab bar. Add a case here (and in the three
/// switches below) and it automatically becomes a customizable tab — existing
/// users get it appended to the end of their order on next launch.
enum DuhaaTab: String, CaseIterable, Identifiable, Codable {
    // NOTE: `.sisters` (the women's cycle space) is parked — removed for now,
    // restorable via `git revert` of the cycle-removal commit.
    case prayer, qibla, quran, duas, learn, tasbih

    var id: String { rawValue }

    /// The default order shipped to a brand-new user.
    static let defaultOrder: [DuhaaTab] = [.prayer, .qibla, .quran, .duas, .learn, .tasbih]

    var title: String {
        switch self {
        case .prayer:  String(localized: "Prayer")
        case .qibla:   String(localized: "Qibla")
        case .quran:   String(localized: "Quran")
        case .duas:    String(localized: "Du'as")
        case .learn:   String(localized: "Learn")
        case .tasbih:  String(localized: "Tasbih")
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
        }
    }

    /// All current tabs are available to everyone. (Gender gating returns with
    /// the parked Sisters tab.)
    func isAvailable(for profile: UserProfileGender) -> Bool { true }

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
        }
    }
}
