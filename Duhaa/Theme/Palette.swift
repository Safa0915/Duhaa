import SwiftUI
import Observation

/// Testable source colors for a theme. SwiftUI `Color` is intentionally opaque,
/// so this keeps the design tokens easy to assert without changing rendering.
struct ThemeColorHexes: Equatable {
    let background: UInt32
    let secondaryBackground: UInt32
    let cardBackground: UInt32
    let elevatedCardBackground: UInt32
    let accent: UInt32
    let softAccent: UInt32
    let primaryText: UInt32
    let secondaryText: UInt32
    let border: UInt32
    let glow: UInt32
    let success: UInt32
    let warning: UInt32
    let destructive: UInt32
}

/// The resolved colors for one theme. The explicit token names are the forward-
/// looking theme system; the old `gold`/`blue` aliases keep existing views stable.
struct DuhaaThemePalette {
    let id: AppTheme
    let hexes: ThemeColorHexes
    let background: Color
    let secondaryBackground: Color
    let cardBackground: Color
    let elevatedCardBackground: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let softAccent: Color
    let border: Color
    let glow: Color
    let success: Color
    let warning: Color
    let destructive: Color
    let secondaryAccent: Color
    let prayerTime: Color
    let colorScheme: ColorScheme
    /// True for the night-sky themes (show stars/glows); false for light themes.
    let isDark: Bool
    let showsFloatingHearts: Bool

    var pageBg: Color { secondaryBackground }
    var appBg: Color { background }
    var gold: Color { accent }
    var blue: Color { secondaryAccent }
    var card: Color { cardBackground }
    var cardBorder: Color { border }
}

typealias ThemeColors = DuhaaThemePalette

/// The selectable themes (Classic is default; Light Pink is a free preview).
enum AppTheme: String, CaseIterable, Identifiable {
    case dark, lightPink, light, sisters

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:      return "Classic Duhaa"
        case .lightPink: return "Light Pink"
        case .light:     return "Dawn (Light)"
        case .sisters:   return "Rose"   // theme kept; the Sisters section is parked
        }
    }

    var previewSubtitle: String {
        switch self {
        case .dark:
            return "The original celestial palette"
        case .lightPink:
            return "Free premium preview"
        case .light:
            return "Warm morning light"
        case .sisters:
            return "Rose night palette"
        }
    }

    var previewBadge: String? {
        switch self {
        case .lightPink: return "Free preview"
        default: return nil
        }
    }

    var previewSwatches: [Color] {
        let c = colors
        return [c.background, c.cardBackground, c.accent, c.secondaryAccent]
    }

    var isPremiumPreview: Bool {
        self == .lightPink
    }

    var colors: ThemeColors {
        switch self {
        case .dark: // the locked v1 palette
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x0D1628, secondaryBackground: 0x08111F,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xF0C040, softAccent: 0x8ECFE8,
                    primaryText: 0xFFFFFF, secondaryText: 0x8ECFE8,
                    border: 0xFFFFFF, glow: 0xF0C040,
                    success: 0x7BCB8F, warning: 0xF0C040, destructive: 0xFF7A7A),
                background: Color(hex: 0x0D1628),
                secondaryBackground: Color(hex: 0x08111F),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0x8ECFE8),
                accent: Color(hex: 0xF0C040),
                softAccent: Color(hex: 0x8ECFE8),
                border: Color.white.opacity(0.13),
                glow: Color(hex: 0xF0C040),
                success: Color(hex: 0x7BCB8F),
                warning: Color(hex: 0xF0C040),
                destructive: Color(hex: 0xFF7A7A),
                secondaryAccent: Color(hex: 0x8ECFE8),
                prayerTime: Color.white.opacity(0.8),
                colorScheme: .dark,
                isDark: true,
                showsFloatingHearts: false)

        case .lightPink:
            let ink = Color(hex: 0x35232A)
            let muted = Color(hex: 0x7A5A66)
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0xFFF5F8, secondaryBackground: 0xFFEAF1,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFF0F5,
                    accent: 0xFF8FB3, softAccent: 0xFFD1DF,
                    primaryText: 0x35232A, secondaryText: 0x7A5A66,
                    border: 0xF7BFD0, glow: 0xFFC2D6,
                    success: 0x4F8A67, warning: 0xA86B21, destructive: 0xB9475D),
                background: Color(hex: 0xFFF5F8),
                secondaryBackground: Color(hex: 0xFFEAF1),
                cardBackground: Color(hex: 0xFFFFFF),
                elevatedCardBackground: Color(hex: 0xFFF0F5),
                primaryText: ink,
                secondaryText: muted,
                accent: Color(hex: 0xFF8FB3),
                softAccent: Color(hex: 0xFFD1DF),
                border: Color(hex: 0xF7BFD0),
                glow: Color(hex: 0xFFC2D6),
                success: Color(hex: 0x4F8A67),
                warning: Color(hex: 0xA86B21),
                destructive: Color(hex: 0xB9475D),
                secondaryAccent: muted,
                prayerTime: ink.opacity(0.9),
                colorScheme: .light,
                isDark: false,
                showsFloatingHearts: true)

        case .sisters: // all-pink celestial (still a night theme)
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x1E1126, secondaryBackground: 0x140A18,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xF48FB1, softAccent: 0xCBA6E8,
                    primaryText: 0xFFFFFF, secondaryText: 0xCBA6E8,
                    border: 0xFFFFFF, glow: 0xF48FB1,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x1E1126),
                secondaryBackground: Color(hex: 0x140A18),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0xCBA6E8),
                accent: Color(hex: 0xF48FB1),
                softAccent: Color(hex: 0xCBA6E8),
                border: Color.white.opacity(0.14),
                glow: Color(hex: 0xF48FB1),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0xCBA6E8),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                showsFloatingHearts: false)

        case .light: // warm, golden "honey cream" dawn
            let ink = Color(hex: 0x2A2412)
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0xF4E7C6, secondaryBackground: 0xE7D3A2,
                    cardBackground: 0xFCF3D9, elevatedCardBackground: 0xFFF7E5,
                    accent: 0x9C6A06, softAccent: 0xEBC978,
                    primaryText: 0x2A2412, secondaryText: 0x1F5470,
                    border: 0x7A6526, glow: 0xD89A16,
                    success: 0x4F7E4D, warning: 0x9C6A06, destructive: 0xA84835),
                background: Color(hex: 0xF4E7C6),
                secondaryBackground: Color(hex: 0xE7D3A2),
                // Warm golden-ivory cards, a touch lighter than the honey bg.
                cardBackground: Color(hex: 0xFCF3D9).opacity(0.92),
                elevatedCardBackground: Color(hex: 0xFFF7E5),
                primaryText: ink,
                secondaryText: Color(hex: 0x1F5470),
                accent: Color(hex: 0x9C6A06),
                softAccent: Color(hex: 0xEBC978),
                border: Color(hex: 0x7A6526).opacity(0.20),
                glow: Color(hex: 0xD89A16),
                success: Color(hex: 0x4F7E4D),
                warning: Color(hex: 0x9C6A06),
                destructive: Color(hex: 0xA84835),
                secondaryAccent: Color(hex: 0x1F5470),
                prayerTime: ink.opacity(0.9),
                colorScheme: .light,
                isDark: false,
                showsFloatingHearts: false)
        }
    }
}

/// Holds the selected theme, persists it, and updates the active palette.
@Observable
final class ThemeStore {
    var theme: AppTheme {
        didSet {
            Palette.active = theme.colors
            defaults.set(theme.rawValue, forKey: Self.key)
        }
    }

    @ObservationIgnored static let key = "duhaa.theme"
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = Self.savedTheme(from: defaults.string(forKey: Self.key))
        theme = saved
        Palette.active = saved.colors // didSet does not fire during init
    }

    private static func savedTheme(from rawValue: String?) -> AppTheme {
        switch rawValue {
        case "classic", "celestial":
            return .dark
        default:
            return AppTheme(rawValue: rawValue ?? "") ?? .dark
        }
    }
}

/// Theme-driven color tokens. Views read these; the active set is swapped when
/// the theme changes (the root re-renders via `.id(theme)`).
enum Palette {
    static var active: ThemeColors = AppTheme.dark.colors

    static var background: Color { active.background }
    static var secondaryBackground: Color { active.secondaryBackground }
    static var cardBackground: Color { active.cardBackground }
    static var elevatedCardBackground: Color { active.elevatedCardBackground }
    static var primaryText: Color { active.primaryText }
    static var secondaryText: Color { active.secondaryText }
    static var accent: Color { active.accent }
    static var softAccent: Color { active.softAccent }
    static var border: Color { active.border }
    static var glow: Color { active.glow }
    static var success: Color { active.success }
    static var warning: Color { active.warning }
    static var destructive: Color { active.destructive }

    static var pageBg: Color     { active.pageBg }
    static var appBg: Color      { active.appBg }
    static var gold: Color       { active.gold }
    static var blue: Color       { active.blue }
    static var card: Color       { active.card }
    static var cardBorder: Color { active.cardBorder }
    static var prayerTime: Color { active.prayerTime }

    /// Text/icon color to use on TOP of a gold/accent fill - always dark for contrast.
    static let onAccent = Color(hex: 0x10182A)
}

extension Color {
    /// Build a color from a 0xRRGGBB literal, e.g. `Color(hex: 0xF0C040)`.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
