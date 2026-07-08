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
    let onAccent: UInt32
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
    let onAccent: Color
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
    /// Animated decoration drawn behind this theme's content (hearts / blossoms / none).
    let decoration: ThemeDecoration

    var pageBg: Color { secondaryBackground }
    var appBg: Color { background }
    var gold: Color { accent }
    var blue: Color { secondaryAccent }
    var card: Color { cardBackground }
    var cardBorder: Color { border }

    /// Light Pink's rising-hearts field.
    var showsFloatingHearts: Bool { decoration == .hearts }
    /// Chinese Blossom's falling-blossoms field.
    var showsFloatingBlossoms: Bool { decoration == .blossoms }
    /// Autumn's falling-leaves field.
    var showsFloatingLeaves: Bool { decoration == .leaves }
    /// Palestinian's rising tatreez-motif field.
    var showsFloatingTatreez: Bool { decoration == .tatreez }
}

typealias ThemeColors = DuhaaThemePalette

/// An optional animated decoration drawn behind a theme's content.
enum ThemeDecoration: Equatable {
    case none
    case hearts     // Light Pink — gentle rising hearts
    case blossoms   // Chinese Blossom — gentle falling blossoms
    case leaves     // Autumn — gentle falling leaves
    case tatreez    // Palestinian — rising tatreez embroidery motifs
}

/// The selectable themes (Classic is default; Light Pink is a free preview).
enum AppTheme: String, CaseIterable, Identifiable {
    case dark, sisters, ocean, saudi, palestinian, blossom, somali, turkish, autumn, light, lightPink

    static let lightThemes: [AppTheme] = [.light, .lightPink]
    static let darkThemes: [AppTheme] = [.dark, .sisters, .ocean, .saudi, .palestinian, .blossom, .somali, .turkish, .autumn]

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:      return String(localized: "Classic Duhaa")
        case .lightPink: return String(localized: "Light Pink")
        case .light:     return String(localized: "Sky Blue")
        case .sisters:   return String(localized: "Rose")   // theme kept; the Sisters section is parked
        case .ocean:     return String(localized: "Ocean")
        case .saudi:     return String(localized: "Saudi")
        case .palestinian: return String(localized: "Palestinian")
        case .blossom:   return String(localized: "Chinese Blossom")
        case .somali:    return String(localized: "Somali")
        case .turkish:   return String(localized: "Turkish")
        case .autumn:    return String(localized: "Autumn")
        }
    }

    var previewSubtitle: String {
        switch self {
        case .dark:
            return String(localized: "The original celestial palette")
        case .lightPink:
            return String(localized: "Free premium preview")
        case .light:
            return String(localized: "Pale blue · Islamic navy")
        case .sisters:
            return String(localized: "Rose night palette")
        case .ocean:
            return String(localized: "Ocean night palette")
        case .saudi:
            return String(localized: "Emerald green · royal gold")
        case .palestinian:
            return String(localized: "Olive night · tatreez red")
        case .blossom:
            return String(localized: "Moonlit plum · blossom pink")
        case .somali:
            return String(localized: "Sky blue · white star")
        case .turkish:
            return String(localized: "Turkish red · white crescent")
        case .autumn:
            return String(localized: "Amber dusk · falling leaves")
        }
    }

    var previewBadge: String? {
        switch self {
        case .lightPink: return String(localized: "Free preview")
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
                    accent: 0xF0C040, onAccent: 0x10182A, softAccent: 0x8ECFE8,
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
                onAccent: Color(hex: 0x10182A),
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
                decoration: .none)

        case .lightPink:
            let ink = Color(hex: 0x35232A)
            let muted = Color(hex: 0x9A6B80)
            let babyPink = Color(hex: 0xFFA6C8)
            let blushPink = Color(hex: 0xFFC7DA)
            let roseAccent = Color(hex: 0xD979A2)
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0xFFF5F8, secondaryBackground: 0xFFEAF1,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFF0F5,
                    accent: 0xFFA6C8, onAccent: 0x35232A, softAccent: 0xFFC7DA,
                    primaryText: 0x35232A, secondaryText: 0x9A6B80,
                    border: 0xF8C5D4, glow: 0xFFD8E6,
                    success: 0x4F8A67, warning: 0xC87596, destructive: 0xB9475D),
                background: Color(hex: 0xFFF5F8),
                secondaryBackground: Color(hex: 0xFFEAF1),
                cardBackground: Color(hex: 0xFFFFFF),
                elevatedCardBackground: Color(hex: 0xFFF0F5),
                primaryText: ink,
                secondaryText: muted,
                accent: babyPink,
                onAccent: ink,
                softAccent: blushPink,
                border: Color(hex: 0xF8C5D4),
                glow: Color(hex: 0xFFD8E6),
                success: Color(hex: 0x4F8A67),
                warning: Color(hex: 0xC87596),
                destructive: Color(hex: 0xB9475D),
                secondaryAccent: roseAccent,
                prayerTime: ink.opacity(0.9),
                colorScheme: .light,
                isDark: false,
                decoration: .hearts)

        case .sisters: // all-pink celestial (still a night theme)
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x1E1126, secondaryBackground: 0x140A18,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xF48FB1, onAccent: 0x10182A, softAccent: 0xCBA6E8,
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
                onAccent: Color(hex: 0x10182A),
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
                decoration: .none)

        case .ocean: // all-blue celestial — the Rose palette, in blue
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x0A1E3A, secondaryBackground: 0x05101F,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0x5BB4F0, onAccent: 0x10182A, softAccent: 0x9CD2F2,
                    primaryText: 0xFFFFFF, secondaryText: 0x9CD2F2,
                    border: 0xFFFFFF, glow: 0x5BB4F0,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x0A1E3A),
                secondaryBackground: Color(hex: 0x05101F),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0x9CD2F2),
                accent: Color(hex: 0x5BB4F0),
                onAccent: Color(hex: 0x10182A),
                softAccent: Color(hex: 0x9CD2F2),
                border: Color.white.opacity(0.14),
                glow: Color(hex: 0x5BB4F0),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0x9CD2F2),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                decoration: .none)

        case .saudi: // deep emerald night + royal gold — premium, Saudi green & gold
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x06301F, secondaryBackground: 0x021A11,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xE8C36B, onAccent: 0x0A2014, softAccent: 0x9FD8B8,
                    primaryText: 0xFFFFFF, secondaryText: 0x9FD8B8,
                    border: 0xFFFFFF, glow: 0xE8C36B,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x06301F),
                secondaryBackground: Color(hex: 0x021A11),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0x9FD8B8),
                accent: Color(hex: 0xE8C36B),
                onAccent: Color(hex: 0x0A2014),
                softAccent: Color(hex: 0x9FD8B8),
                border: Color.white.opacity(0.13),
                glow: Color(hex: 0xE8C36B),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0x9FD8B8),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                decoration: .none)

        case .palestinian: // olive-grove night + tatreez red — the flag's black/white/green/red, done premium
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x0F1A12, secondaryBackground: 0x081009,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xDE5257, onAccent: 0xFFFFFF, softAccent: 0xBFDDB4,
                    primaryText: 0xFFFFFF, secondaryText: 0xA9C8A5,
                    border: 0xFFFFFF, glow: 0xDE5257,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x0F1A12),
                secondaryBackground: Color(hex: 0x081009),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0xA9C8A5),
                accent: Color(hex: 0xDE5257),
                onAccent: .white,
                softAccent: Color(hex: 0xBFDDB4),
                border: Color.white.opacity(0.13),
                glow: Color(hex: 0xDE5257),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0x9CCE9F),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                decoration: .tatreez)

        case .blossom: // moonlit plum night + blossom pink, with falling blossoms
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x1A0E18, secondaryBackground: 0x110810,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xF4A9C0, onAccent: 0x2A0E1C, softAccent: 0xF1B9CE,
                    primaryText: 0xFFFFFF, secondaryText: 0xD9AEC1,
                    border: 0xFFFFFF, glow: 0xF4A9C0,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x1A0E18),
                secondaryBackground: Color(hex: 0x110810),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0xD9AEC1),
                accent: Color(hex: 0xF4A9C0),
                onAccent: Color(hex: 0x2A0E1C),
                softAccent: Color(hex: 0xF1B9CE),
                border: Color.white.opacity(0.13),
                glow: Color(hex: 0xF4A9C0),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0x8FD3B0),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                decoration: .blossoms)

        case .somali: // Somali-flag sky blue + white star, on a deep azure night
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x0B2C52, secondaryBackground: 0x06182E,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0x4FA3E8, onAccent: 0x08182E, softAccent: 0xD6E8FB,
                    primaryText: 0xFFFFFF, secondaryText: 0xBCD7F4,
                    border: 0xFFFFFF, glow: 0x4FA3E8,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x0B2C52),
                secondaryBackground: Color(hex: 0x06182E),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0xBCD7F4),
                accent: Color(hex: 0x4FA3E8),
                onAccent: Color(hex: 0x08182E),
                softAccent: Color(hex: 0xD6E8FB),
                border: Color.white.opacity(0.14),
                glow: Color(hex: 0x4FA3E8),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0xD6E8FB),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                decoration: .none)

        case .turkish: // Turkish-flag red + white crescent, on a deep crimson night
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x2A0810, secondaryBackground: 0x190509,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xE83A47, onAccent: 0xFFFFFF, softAccent: 0xF3D9DC,
                    primaryText: 0xFFFFFF, secondaryText: 0xE7B9C0,
                    border: 0xFFFFFF, glow: 0xE83A47,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x2A0810),
                secondaryBackground: Color(hex: 0x190509),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0xE7B9C0),
                accent: Color(hex: 0xE83A47),
                onAccent: .white,
                softAccent: Color(hex: 0xF3D9DC),
                border: Color.white.opacity(0.13),
                glow: Color(hex: 0xE83A47),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0xF3D9DC),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                decoration: .none)

        case .autumn: // warm amber-lit autumn night, with gently falling leaves
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0x21140A, secondaryBackground: 0x160C04,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xFFFFFF,
                    accent: 0xE0883A, onAccent: 0x241405, softAccent: 0xE7C083,
                    primaryText: 0xFFFFFF, secondaryText: 0xDDBA8A,
                    border: 0xFFFFFF, glow: 0xE0883A,
                    success: 0x8BD39F, warning: 0xF3C76E, destructive: 0xFF7A93),
                background: Color(hex: 0x21140A),
                secondaryBackground: Color(hex: 0x160C04),
                cardBackground: Color.white.opacity(0.07),
                elevatedCardBackground: Color.white.opacity(0.10),
                primaryText: .white,
                secondaryText: Color(hex: 0xDDBA8A),
                accent: Color(hex: 0xE0883A),
                onAccent: Color(hex: 0x241405),
                softAccent: Color(hex: 0xE7C083),
                border: Color.white.opacity(0.13),
                glow: Color(hex: 0xE0883A),
                success: Color(hex: 0x8BD39F),
                warning: Color(hex: 0xF3C76E),
                destructive: Color(hex: 0xFF7A93),
                secondaryAccent: Color(hex: 0xE7C083),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark,
                isDark: true,
                decoration: .leaves)

        case .light: // B — Sky: pale blue + Islamic navy
            let ink = Color(hex: 0x0C1F3B)
            let steelBlue = Color(hex: 0x44698E)
            let islamicNavy = Color(hex: 0x1154A4)
            return ThemeColors(
                id: self,
                hexes: ThemeColorHexes(
                    background: 0xECF4FD, secondaryBackground: 0xE4EFFB,
                    cardBackground: 0xFFFFFF, elevatedCardBackground: 0xF8FBFF,
                    accent: 0x1154A4, onAccent: 0xFFFFFF, softAccent: 0x2C69B0,
                    primaryText: 0x0C1F3B, secondaryText: 0x44698E,
                    border: 0xC9D8E8, glow: 0x86BDF3,
                    success: 0x236B4E, warning: 0x8A621B, destructive: 0xB14A45),
                background: Color(hex: 0xECF4FD),
                secondaryBackground: Color(hex: 0xE4EFFB),
                cardBackground: Color(hex: 0xFFFFFF),
                elevatedCardBackground: Color(hex: 0xF8FBFF),
                primaryText: ink,
                secondaryText: steelBlue,
                accent: islamicNavy,
                onAccent: .white,
                softAccent: Color(hex: 0x2C69B0),
                border: Color(hex: 0xC9D8E8),
                glow: Color(hex: 0x86BDF3),
                success: Color(hex: 0x236B4E),
                warning: Color(hex: 0x8A621B),
                destructive: Color(hex: 0xB14A45),
                secondaryAccent: steelBlue,
                prayerTime: ink.opacity(0.9),
                colorScheme: .light,
                isDark: false,
                decoration: .none)
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

    /// Text/icon color to use on top of the active accent fill.
    static var onAccent: Color { active.onAccent }
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
