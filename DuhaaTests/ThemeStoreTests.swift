import XCTest
@testable import Duhaa

final class ThemeStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.theme.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        Palette.active = AppTheme.dark.colors
        super.tearDown()
    }

    func testFreshDefaultsToClassicDuhaa() {
        let store = ThemeStore(defaults: defaults)

        XCTAssertEqual(store.theme, .dark)
        XCTAssertEqual(store.theme.displayName, "Classic Duhaa")
        XCTAssertEqual(Palette.active.id, .dark)
    }

    func testLightPinkCanBeSelectedAndPersists() {
        let store = ThemeStore(defaults: defaults)

        store.theme = .lightPink

        XCTAssertEqual(store.theme, .lightPink)
        XCTAssertEqual(defaults.string(forKey: ThemeStore.key), AppTheme.lightPink.rawValue)
        XCTAssertEqual(Palette.active.id, .lightPink)

        let reloaded = ThemeStore(defaults: defaults)
        XCTAssertEqual(reloaded.theme, .lightPink)
    }

    func testLightPinkPaletteUsesPreviewTokens() {
        let palette = AppTheme.lightPink.colors

        XCTAssertEqual(palette.id, .lightPink)
        XCTAssertEqual(palette.hexes.background, 0xFFF5F8)
        XCTAssertEqual(palette.hexes.secondaryBackground, 0xFFEAF1)
        XCTAssertEqual(palette.hexes.accent, 0xFF8FB3)
        XCTAssertEqual(palette.hexes.softAccent, 0xFFD1DF)
        XCTAssertTrue(palette.showsFloatingHearts)
        XCTAssertEqual(AppTheme.lightPink.previewBadge, "Free preview")
        XCTAssertTrue(AppTheme.lightPink.isPremiumPreview)
    }

    func testClassicDoesNotUseLightPinkDecorations() {
        let palette = AppTheme.dark.colors

        XCTAssertFalse(palette.showsFloatingHearts)
        XCTAssertFalse(AppTheme.dark.isPremiumPreview)
    }

    func testFloatingHeartSpecsStayLightweightAndSubtle() {
        let hearts = FloatingHeartFactory.hearts
        XCTAssertEqual(hearts.count, 16, "sparse field")
        XCTAssertTrue(hearts.allSatisfy { $0.opacity <= 0.12 }, "hearts must stay subtle (<= 0.12)")
        XCTAssertTrue(hearts.allSatisfy { $0.size <= 30 }, "hearts stay small-to-medium")
    }

    func testHeartsHugTheSideGuttersNotTheReadingColumn() {
        // Nothing should drift through the central reading column (0.20...0.80).
        XCTAssertTrue(FloatingHeartFactory.hearts.allSatisfy { $0.x <= 0.20 || $0.x >= 0.80 },
                      "hearts must hug the side gutters to keep text clear")
    }

    func testHeartProgressIsBoundedIncludingReduceMotionPath() {
        for heart in FloatingHeartFactory.hearts {
            let still = heart.progress(at: 0)              // Reduce Motion path uses time 0
            XCTAssertTrue(still >= 0 && still < 1, "progress out of range at rest: \(still)")
            let moving = heart.progress(at: 12_345.678)
            XCTAssertTrue(moving >= 0 && moving < 1, "progress out of range while moving: \(moving)")
        }
    }

    func testDecorationGateRespectsThemeAndPerScreenOptOut() {
        // Classic never shows hearts, even if a screen allows decorations.
        XCTAssertFalse(ThemeDecorativeBackground.showsHearts(allowsHearts: true, palette: AppTheme.dark.colors))
        // Light Pink shows hearts by default…
        XCTAssertTrue(ThemeDecorativeBackground.showsHearts(allowsHearts: true, palette: AppTheme.lightPink.colors))
        // …but a reading-heavy screen can suppress them.
        XCTAssertFalse(ThemeDecorativeBackground.showsHearts(allowsHearts: false, palette: AppTheme.lightPink.colors))
    }
}
