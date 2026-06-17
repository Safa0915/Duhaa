import SwiftUI

/// Resolves a stored theme id into the app's exact palette (via the shared
/// `Palette.swift`, which is a member of both targets), then adds a few
/// widget-only tuning knobs — background gradients, ring track, motif opacity —
/// so the widgets feel like a natural extension of Duhaa, not a separate skin.
struct WidgetTheme {
    let colors: ThemeColors

    init(id: String) {
        // Mirror ThemeStore's legacy aliasing so old saved values still resolve.
        let theme: AppTheme
        switch id {
        case "classic", "celestial": theme = .dark
        default: theme = AppTheme(rawValue: id) ?? .dark
        }
        colors = theme.colors
    }

    var isDark: Bool { colors.isDark }
    var showsHearts: Bool { colors.showsFloatingHearts }

    var accent: Color { colors.accent }
    var secondaryAccent: Color { colors.secondaryAccent }
    var primaryText: Color { colors.primaryText }
    var secondaryText: Color { colors.secondaryText }
    var success: Color { colors.success }

    /// The widget's container background — a calm vertical wash with a soft accent
    /// glow at the top. Premium, never noisy.
    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [colors.background, colors.secondaryBackground]
                : [colors.background, colors.secondaryBackground],
            startPoint: .top, endPoint: .bottom)
    }

    /// A faint radial glow layered over the gradient (top-trailing), tuned per theme.
    var glowGradient: RadialGradient {
        RadialGradient(
            colors: [colors.glow.opacity(isDark ? 0.22 : 0.30), .clear],
            center: .topTrailing, startRadius: 4, endRadius: 220)
    }

    /// The unfilled portion of a progress ring.
    var ringTrack: Color {
        isDark ? Color.white.opacity(0.12) : colors.accent.opacity(0.16)
    }

    /// Surface for raised pills/cards inside the widget.
    var pillBackground: Color {
        isDark ? Color.white.opacity(0.08) : colors.accent.opacity(0.08)
    }

    var pillBorder: Color {
        isDark ? Color.white.opacity(0.10) : colors.accent.opacity(0.16)
    }

    /// Fill behind a completed prayer pill.
    var completedFill: Color { colors.accent.opacity(isDark ? 0.20 : 0.16) }

    /// Tint for a dimmed (past, unmarked) prayer.
    func dim(_ color: Color, _ amount: Double = 0.5) -> Color { color.opacity(amount) }

    /// Decorative crescent/motif opacity (kept low so text stays the hero).
    var motifOpacity: Double { isDark ? 0.12 : 0.09 }

    /// Faint heart-motif opacity for the Light Pink theme only (static, no spam).
    var heartOpacity: Double { showsHearts ? 0.05 : 0 }

    /// Home-Screen color for a five-state cell, from the theme tokens. (Lock-Screen
    /// accessory widgets ignore this and rely on `PrayerState.monoSymbol` instead.)
    func color(for state: PrayerState) -> Color {
        switch state {
        case .onTime:   return colors.accent
        case .late:     return colors.warning
        case .madeUp:   return colors.success
        case .excused:  return colors.secondaryAccent
        case .upcoming: return ringTrack
        case .missed:   return colors.secondaryText.opacity(0.45)
        }
    }
}
