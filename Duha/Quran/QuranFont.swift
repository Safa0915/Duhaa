import SwiftUI
import CoreText

/// The bundled KFGQPC HAFS Uthmanic Script font — designed for Quranic Uthmani
/// text, so it places every harakah/dagger-alif correctly (the system Arabic
/// font does not). Registered once at launch; used for all Quran Arabic.
enum QuranFont {
    static let family = "KFGQPC HAFS Uthmanic Script"

    static func register() {
        guard let url = Bundle.main.url(forResource: "UthmanicHafs1Ver18", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// The Uthmani font at a given point size (falls back to the system font if
    /// registration ever fails).
    static func uthmani(_ size: CGFloat) -> Font { .custom(family, size: size, relativeTo: .body) }
}
