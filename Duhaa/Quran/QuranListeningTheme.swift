import SwiftUI
import UIKit
import Observation

/// A visual ambience for the immersive Quran listening screen ("Now Playing").
/// Independent of the app-wide `AppTheme`: every ambience carries its own
/// complete color set (including explicit text colors) so the player stays
/// readable no matter which app theme is active.
enum QuranListeningTheme: String, CaseIterable, Identifiable {
    case minimalDark
    case nightSky
    case rainWindow
    case desertSunset
    case masjidGlow
    case oceanWaves
    case fireEmbers
    case lightPink

    var id: String { rawValue }

    /// The subtle motion drawn behind the player. Every style renders a still
    /// frame under Reduce Motion (via `AmbientTimelineView`).
    enum Motion: Equatable {
        case none          // Minimal Dark — perfectly still
        case stars         // slow star twinkle
        case rain          // soft streaks sliding down the glass
        case sunsetShimmer // the low sun's glow breathing very slowly
        case lanternGlow   // warm lantern light breathing behind the masjid
        case waves         // slow drifting wave bands
        case embers        // small soft embers rising gently
        case softGlow      // blush glows breathing very slowly
    }

    var displayName: String {
        switch self {
        case .minimalDark:  return String(localized: "Minimal Dark")
        case .nightSky:     return String(localized: "Night Sky")
        case .rainWindow:   return String(localized: "Rain Window")
        case .desertSunset: return String(localized: "Desert Sunset")
        case .masjidGlow:   return String(localized: "Masjid Glow")
        case .oceanWaves:   return String(localized: "Ocean Waves")
        case .fireEmbers:   return String(localized: "Fire Embers")
        case .lightPink:    return String(localized: "Light Pink")
        }
    }

    var shortDescription: String {
        switch self {
        case .minimalDark:  return String(localized: "Nothing but the recitation")
        case .nightSky:     return String(localized: "A still, starlit sky")
        case .rainWindow:   return String(localized: "Soft rain against the glass")
        case .desertSunset: return String(localized: "Warm dusk over quiet dunes")
        case .masjidGlow:   return String(localized: "Lantern light on the masjid")
        case .oceanWaves:   return String(localized: "Slow waves under moonlight")
        case .fireEmbers:   return String(localized: "The warm glow of embers")
        case .lightPink:    return String(localized: "A gentle blush calm")
        }
    }

    var motion: Motion {
        switch self {
        case .minimalDark:  return .none
        case .nightSky:     return .stars
        case .rainWindow:   return .rain
        case .desertSunset: return .sunsetShimmer
        case .masjidGlow:   return .lanternGlow
        case .oceanWaves:   return .waves
        case .fireEmbers:   return .embers
        case .lightPink:    return .softGlow
        }
    }

    // MARK: Source hexes (testable, and shared by SwiftUI + UIKit rendering)

    /// Background gradient stops, top to bottom (2–3 stops).
    var backgroundHexes: [UInt32] {
        switch self {
        case .minimalDark:  return [0x0C1017, 0x05070C]
        case .nightSky:     return [0x0D1B33, 0x040A1A]
        case .rainWindow:   return [0x18222D, 0x0C1218]
        case .desertSunset: return [0x2A1028, 0x6E2A1A, 0x8A3B1E]
        case .masjidGlow:   return [0x0A2A26, 0x041511]
        case .oceanWaves:   return [0x0A3148, 0x041B2C]
        case .fireEmbers:   return [0x221108, 0x120804]
        case .lightPink:    return [0xFFF5F8, 0xFFE4EE]
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .minimalDark:  return 0xF0C040
        case .nightSky:     return 0xF0C040
        case .rainWindow:   return 0x7FB8DE
        case .desertSunset: return 0xF3A44E
        case .masjidGlow:   return 0xE8C36B
        case .oceanWaves:   return 0x5BB4F0
        case .fireEmbers:   return 0xE0883A
        case .lightPink:    return 0xB44A72
        }
    }

    /// Text/icon color used on top of the accent fill (the play button).
    var onAccentHex: UInt32 {
        switch self {
        case .minimalDark:  return 0x10182A
        case .nightSky:     return 0x10182A
        case .rainWindow:   return 0x0B1620
        case .desertSunset: return 0x33150A
        case .masjidGlow:   return 0x0A2014
        case .oceanWaves:   return 0x06263C
        case .fireEmbers:   return 0x241405
        case .lightPink:    return 0xFFFFFF
        }
    }

    var softAccentHex: UInt32 {
        switch self {
        case .minimalDark:  return 0x8ECFE8
        case .nightSky:     return 0x8ECFE8
        case .rainWindow:   return 0xB8CEDE
        case .desertSunset: return 0xF0C9A0
        case .masjidGlow:   return 0x9FD8B8
        case .oceanWaves:   return 0x9CD2F2
        case .fireEmbers:   return 0xE7C083
        case .lightPink:    return 0x86527C
        }
    }

    var preferredTextHex: UInt32 {
        self == .lightPink ? 0x35232A : 0xFFFFFF
    }

    var secondaryTextHex: UInt32 {
        switch self {
        case .minimalDark:  return 0xA9B7C6
        case .nightSky:     return 0x9FB4D8
        case .rainWindow:   return 0xA7BBCB
        case .desertSunset: return 0xE8C4AC
        case .masjidGlow:   return 0xA5CDB8
        case .oceanWaves:   return 0x9CC4DD
        case .fireEmbers:   return 0xD8B490
        case .lightPink:    return 0x7E5265
        }
    }

    // MARK: Resolved colors

    var colorScheme: ColorScheme { self == .lightPink ? .light : .dark }
    var isLight: Bool { colorScheme == .light }

    var gradientColors: [Color] { backgroundHexes.map { Color(hex: $0) } }
    /// Top of the background gradient.
    var primaryColor: Color { Color(hex: backgroundHexes.first ?? 0x000000) }
    /// Bottom of the background gradient.
    var secondaryColor: Color { Color(hex: backgroundHexes.last ?? 0x000000) }
    var accentColor: Color { Color(hex: accentHex) }
    var onAccentColor: Color { Color(hex: onAccentHex) }
    var softAccentColor: Color { Color(hex: softAccentHex) }
    var preferredTextColor: Color { Color(hex: preferredTextHex) }
    var secondaryTextColor: Color { Color(hex: secondaryTextHex) }

    /// Fill and border for the player's control panel card.
    var panelFill: Color {
        isLight ? Color.white.opacity(0.80) : Color.white.opacity(0.07)
    }
    var panelBorder: Color {
        isLight ? Color(hex: 0xE8C3D2) : Color.white.opacity(0.13)
    }

    // MARK: Now Playing artwork (prepared for future MPNowPlayingInfoCenter use)

    /// A generated square artwork in this ambience's palette — no bundled image
    /// assets needed. The app has no Now Playing / background-audio support yet;
    /// when that lands, wrap this in an `MPMediaItemArtwork` and set it on
    /// `MPNowPlayingInfoCenter.default().nowPlayingInfo[MPMediaItemPropertyArtwork]`
    /// so the Lock Screen / Control Center card matches the chosen ambience.
    func nowPlayingArtwork(dimension: CGFloat = 600) -> UIImage {
        let size = CGSize(width: dimension, height: dimension)
        let stops = backgroundHexes
        let accent = accentHex
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()

            let colors = stops.map { UIColor(rgbHex: $0).cgColor } as CFArray
            let locations: [CGFloat] = stops.indices.map {
                stops.count > 1 ? CGFloat($0) / CGFloat(stops.count - 1) : 0
            }
            if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) {
                cg.drawLinearGradient(gradient,
                                      start: .zero,
                                      end: CGPoint(x: 0, y: dimension),
                                      options: [])
            }

            // A soft accent glow in the upper half gives the card gentle depth.
            let glowColors = [UIColor(rgbHex: accent).withAlphaComponent(0.42).cgColor,
                              UIColor(rgbHex: accent).withAlphaComponent(0).cgColor] as CFArray
            if let glow = CGGradient(colorsSpace: space, colors: glowColors, locations: [0, 1]) {
                let center = CGPoint(x: dimension * 0.5, y: dimension * 0.38)
                cg.drawRadialGradient(glow,
                                      startCenter: center, startRadius: 0,
                                      endCenter: center, endRadius: dimension * 0.55,
                                      options: [])
            }

            // A quiet vignette anchors the bottom edge.
            let vignetteAlpha: CGFloat = self.isLight ? 0.06 : 0.30
            let vignette = [UIColor.black.withAlphaComponent(0).cgColor,
                            UIColor.black.withAlphaComponent(vignetteAlpha).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: space, colors: vignette, locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: dimension * 0.55),
                                      end: CGPoint(x: 0, y: dimension),
                                      options: [])
            }
        }
    }
}

/// Holds the chosen listening ambience and persists it, mirroring `ThemeStore`.
@Observable
final class QuranListeningThemeStore {
    static let storageKey = "duhaa.quran.listeningTheme"

    var theme: QuranListeningTheme {
        didSet { defaults.set(theme.rawValue, forKey: Self.storageKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.storageKey) ?? ""
        theme = QuranListeningTheme(rawValue: saved) ?? .minimalDark
    }
}

private extension UIColor {
    convenience init(rgbHex hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
