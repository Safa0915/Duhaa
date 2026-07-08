import XCTest
import UIKit
@testable import Duhaa

final class QuranListeningThemeTests: XCTestCase {

    // MARK: Theme catalogue

    func testExactThemeList() {
        // The eight shipped ambiences, in picker order. Adding/removing one is
        // a product decision — update this list deliberately.
        XCTAssertEqual(QuranListeningTheme.allCases.map(\.rawValue), [
            "minimalDark",
            "nightSky",
            "rainWindow",
            "desertSunset",
            "masjidGlow",
            "oceanWaves",
            "fireEmbers",
            "lightPink"
        ])
    }

    func testDisplayNamesAreUniqueAndNonEmpty() {
        let names = QuranListeningTheme.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertFalse(names.contains(where: \.isEmpty))
    }

    func testShortDescriptionsAreNonEmpty() {
        for theme in QuranListeningTheme.allCases {
            XCTAssertFalse(theme.shortDescription.isEmpty, "\(theme.rawValue) has no description")
        }
    }

    func testBackgroundGradientsHaveAtLeastTwoStops() {
        for theme in QuranListeningTheme.allCases {
            XCTAssertGreaterThanOrEqual(theme.backgroundHexes.count, 2, theme.rawValue)
        }
    }

    func testOnlyLightPinkIsLight() {
        for theme in QuranListeningTheme.allCases {
            XCTAssertEqual(theme.isLight, theme == .lightPink, theme.rawValue)
        }
    }

    // MARK: Readability (WCAG contrast against every background stop)

    func testPrimaryAndSecondaryTextMeetContrastOnAllBackgrounds() {
        for theme in QuranListeningTheme.allCases {
            for background in theme.backgroundHexes {
                assertContrast(theme.preferredTextHex, background, atLeast: 4.5,
                               "\(theme.rawValue) primary text on \(hexString(background))")
                assertContrast(theme.secondaryTextHex, background, atLeast: 4.5,
                               "\(theme.rawValue) secondary text on \(hexString(background))")
                assertContrast(theme.softAccentHex, background, atLeast: 4.5,
                               "\(theme.rawValue) soft accent on \(hexString(background))")
                // Accent doubles as icon/tint color — the 3:1 non-text standard.
                assertContrast(theme.accentHex, background, atLeast: 3.0,
                               "\(theme.rawValue) accent on \(hexString(background))")
            }
            assertContrast(theme.onAccentHex, theme.accentHex, atLeast: 3.0,
                           "\(theme.rawValue) onAccent on accent")
        }
    }

    // MARK: Persistence

    private func freshDefaults(_ function: String = #function) -> UserDefaults {
        let suite = "QuranListeningThemeTests.\(function)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testStorageKeyIsStable() {
        XCTAssertEqual(QuranListeningThemeStore.storageKey, "duhaa.quran.listeningTheme")
    }

    func testDefaultThemeIsMinimalDark() {
        let store = QuranListeningThemeStore(defaults: freshDefaults())
        XCTAssertEqual(store.theme, .minimalDark)
    }

    func testSelectionPersistsAcrossStores() {
        let defaults = freshDefaults()
        let store = QuranListeningThemeStore(defaults: defaults)
        store.theme = .rainWindow

        let reloaded = QuranListeningThemeStore(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .rainWindow)
    }

    func testUnknownStoredValueFallsBackToDefault() {
        let defaults = freshDefaults()
        defaults.set("lavaFlow", forKey: QuranListeningThemeStore.storageKey)

        let store = QuranListeningThemeStore(defaults: defaults)
        XCTAssertEqual(store.theme, .minimalDark)
    }

    // MARK: Now Playing artwork (prepared for future lock-screen metadata)

    func testEveryThemeGeneratesArtworkAtRequestedSize() {
        for theme in QuranListeningTheme.allCases {
            let artwork = theme.nowPlayingArtwork(dimension: 300)
            XCTAssertEqual(artwork.size, CGSize(width: 300, height: 300), theme.rawValue)
        }
    }

    // MARK: Contrast helpers (WCAG 2.1 relative luminance)

    private func assertContrast(_ foreground: UInt32, _ background: UInt32,
                                atLeast minimum: Double, _ message: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        let ratio = contrastRatio(foreground, background)
        XCTAssertGreaterThanOrEqual(ratio, minimum,
                                    "\(message): \(String(format: "%.2f", ratio)) < \(minimum)",
                                    file: file, line: line)
    }

    private func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func relativeLuminance(_ hex: UInt32) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let r = linear(Double((hex >> 16) & 0xFF) / 255)
        let g = linear(Double((hex >> 8) & 0xFF) / 255)
        let b = linear(Double(hex & 0xFF) / 255)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private func hexString(_ hex: UInt32) -> String {
        String(format: "#%06X", hex)
    }
}
