import SwiftUI

/// The locked celestial palette (DUHA_SPEC.md §6). Do not change these values —
/// every screen pulls its colors from here so the look stays consistent.
enum Palette {
    static let pageBg     = Color(hex: 0x08111F) // outermost
    static let appBg      = Color(hex: 0x0D1628) // main background (dark navy)
    static let gold       = Color(hex: 0xF0C040) // highlights, active prayer, moon
    static let blue       = Color(hex: 0x8ECFE8) // location, dates, labels, night card
    static let card       = Color.white.opacity(0.07)
    static let cardBorder = Color.white.opacity(0.13)
    static let prayerTime = Color.white.opacity(0.8)
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
