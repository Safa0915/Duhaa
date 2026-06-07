import SwiftUI
import Observation

/// The resolved colors for one theme. `gold`/`blue` are the warm/cool accents
/// (gold & sky in dark, rose & lavender in Sisters, deeper tones in light).
struct ThemeColors {
    let pageBg: Color
    let appBg: Color
    let gold: Color        // warm accent
    let blue: Color        // cool accent
    let card: Color
    let cardBorder: Color
    let prayerTime: Color
    let colorScheme: ColorScheme
    /// True for the night-sky themes (show stars/glows); false for the light "dawn" theme.
    let isDark: Bool
}

/// The selectable themes (spec: v1 dark; v1.1 adds light + Sisters/rose).
enum AppTheme: String, CaseIterable, Identifiable {
    case dark, light, sisters

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark:    return "Celestial"
        case .light:   return "Dawn (Light)"
        case .sisters: return "Sisters (Rose)"
        }
    }

    var colors: ThemeColors {
        switch self {
        case .dark: // the locked v1 palette
            return ThemeColors(
                pageBg: Color(hex: 0x08111F), appBg: Color(hex: 0x0D1628),
                gold: Color(hex: 0xF0C040), blue: Color(hex: 0x8ECFE8),
                card: Color.white.opacity(0.07), cardBorder: Color.white.opacity(0.13),
                prayerTime: Color.white.opacity(0.8),
                colorScheme: .dark, isDark: true)

        case .sisters: // all-pink celestial (still a night theme)
            return ThemeColors(
                pageBg: Color(hex: 0x140A18), appBg: Color(hex: 0x1E1126),
                gold: Color(hex: 0xF48FB1), blue: Color(hex: 0xCBA6E8),
                card: Color.white.opacity(0.07), cardBorder: Color.white.opacity(0.14),
                prayerTime: Color.white.opacity(0.85),
                colorScheme: .dark, isDark: true)

        case .light: // warm "cream" dawn
            let ink = Color(hex: 0x2A2417)
            return ThemeColors(
                pageBg: Color(hex: 0xE6D8BD), appBg: Color(hex: 0xF3E9D2),
                gold: Color(hex: 0xA9740A), blue: Color(hex: 0x1F5470),
                // Warm ivory cards — lighter than the cream bg so they still lift off it.
                card: Color(hex: 0xFCF6E8).opacity(0.9), cardBorder: Color(hex: 0x6B5A2E).opacity(0.18),
                prayerTime: ink.opacity(0.9),
                colorScheme: .light, isDark: false)
        }
    }
}

/// Holds the selected theme, persists it, and updates the active palette.
@Observable
final class ThemeStore {
    var theme: AppTheme {
        didSet {
            Palette.active = theme.colors
            UserDefaults.standard.set(theme.rawValue, forKey: Self.key)
        }
    }

    @ObservationIgnored private static let key = "duha.theme"

    init() {
        let saved = AppTheme(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .dark
        theme = saved
        Palette.active = saved.colors // didSet doesn't fire during init
    }
}

/// Theme-driven color tokens. Views read these; the active set is swapped when
/// the theme changes (the root re-renders via `.id(theme)`).
enum Palette {
    static var active: ThemeColors = AppTheme.dark.colors

    static var pageBg: Color     { active.pageBg }
    static var appBg: Color      { active.appBg }
    static var gold: Color       { active.gold }
    static var blue: Color       { active.blue }
    static var card: Color       { active.card }
    static var cardBorder: Color { active.cardBorder }
    static var prayerTime: Color { active.prayerTime }

    /// Text/icon color to use on TOP of a gold/accent fill — always dark for contrast.
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
