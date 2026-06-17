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

    func testThemeListOrder() {
        XCTAssertEqual(AppTheme.allCases.map(\.displayName), [
            "Classic Duhaa",
            "Rose",
            "Sky",
            "Light Pink"
        ])
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
        XCTAssertEqual(palette.hexes.accent, 0xFFA6C8)
        XCTAssertEqual(palette.hexes.onAccent, 0x35232A)
        XCTAssertEqual(palette.hexes.softAccent, 0xFFC7DA)
        XCTAssertEqual(palette.hexes.secondaryText, 0x9A6B80)
        XCTAssertEqual(palette.hexes.glow, 0xFFD8E6)
        XCTAssertEqual(palette.hexes.warning, 0xC87596)
        XCTAssertTrue(palette.showsFloatingHearts)
        XCTAssertEqual(AppTheme.lightPink.previewBadge, "Free preview")
        XCTAssertTrue(AppTheme.lightPink.isPremiumPreview)
    }

    func testSkyPaletteUsesSkyTokens() {
        let palette = AppTheme.light.colors

        XCTAssertEqual(palette.id, .light)
        XCTAssertEqual(AppTheme.light.displayName, "Sky")
        XCTAssertEqual(AppTheme.light.previewSubtitle, "Pale blue · Islamic navy")
        XCTAssertEqual(palette.hexes.background, 0xECF4FD)
        XCTAssertEqual(palette.hexes.secondaryBackground, 0xE4EFFB)
        XCTAssertEqual(palette.hexes.cardBackground, 0xFFFFFF)
        XCTAssertEqual(palette.hexes.accent, 0x1154A4)
        XCTAssertEqual(palette.hexes.onAccent, 0xFFFFFF)
        XCTAssertEqual(palette.hexes.softAccent, 0x2C69B0)
        XCTAssertEqual(palette.hexes.primaryText, 0x0C1F3B)
        XCTAssertEqual(palette.hexes.secondaryText, 0x44698E)
        XCTAssertFalse(palette.showsFloatingHearts)
    }

    func testClassicDoesNotUseLightPinkDecorations() {
        let palette = AppTheme.dark.colors

        XCTAssertFalse(palette.showsFloatingHearts)
        XCTAssertFalse(AppTheme.dark.isPremiumPreview)
    }

    func testFloatingHeartSpecsStayLightweightAndSubtle() {
        XCTAssertEqual(FloatingHeartFactory.hearts.count, 34)
        XCTAssertTrue(FloatingHeartFactory.hearts.allSatisfy { $0.opacity <= 0.26 })
        XCTAssertTrue(FloatingHeartFactory.hearts.allSatisfy { $0.drift > 0 })
        XCTAssertTrue(FloatingHeartFactory.hearts.contains { $0.size >= 28 && $0.opacity >= 0.18 })
    }

    func testSparklyHeartsAreSpecialButSparse() {
        let sparklyHearts = FloatingHeartFactory.hearts.filter { $0.style == .sparkly }

        XCTAssertEqual(sparklyHearts.count, 5)
        XCTAssertLessThan(sparklyHearts.count, FloatingHeartFactory.hearts.count)
        XCTAssertTrue(sparklyHearts.allSatisfy { $0.size >= 28 })
        XCTAssertTrue(sparklyHearts.allSatisfy { $0.visualSize > $0.size })
    }

    func testFloatingHeartsStaySeparatedAcrossMotion() {
        let canvas = CGSize(width: 390, height: 844)
        let sampleTimes = stride(from: 0.0, through: 160.0, by: 4.0)

        for time in sampleTimes {
            let positioned = FloatingHeartFactory.hearts.map { heart in
                (heart: heart, point: heart.position(in: canvas, at: time))
            }

            for i in 0..<positioned.count {
                for j in (i + 1)..<positioned.count {
                    let a = positioned[i]
                    let b = positioned[j]
                    let distance = hypot(a.point.x - b.point.x, a.point.y - b.point.y)
                    let minimumDistance = (a.heart.visualSize + b.heart.visualSize) * 0.46

                    XCTAssertGreaterThanOrEqual(
                        distance,
                        minimumDistance,
                        "hearts \(a.heart.id) and \(b.heart.id) overlap at \(time)s"
                    )
                }
            }
        }
    }

    func testLaunchFrameAlreadyHasTopHearts() {
        let canvas = CGSize(width: 390, height: 844)
        let topVisibleHearts = FloatingHeartFactory.hearts.filter { heart in
            let y = heart.position(in: canvas, at: 0).y
            return y >= 0 && y <= canvas.height * 0.38 && heart.opacity(at: 0) >= 0.04
        }

        XCTAssertGreaterThanOrEqual(topVisibleHearts.count, 7)
        XCTAssertTrue(topVisibleHearts.contains { $0.style == .sparkly })
    }

    func testLiveAnimationStartsFromLaunchFrameNotAbsoluteClockTime() {
        XCTAssertEqual(LightPinkHeartsBackground.animationTime(for: 1_000, startedAt: 1_000), 0)
        XCTAssertEqual(LightPinkHeartsBackground.animationTime(for: 1_012.5, startedAt: 1_000), 12.5)
        XCTAssertEqual(LightPinkHeartsBackground.animationTime(for: 999, startedAt: 1_000), 0)
    }

    func testFloatingHeartFieldKeepsTopAreaPopulated() {
        let canvas = CGSize(width: 390, height: 844)
        let sampleTimes = stride(from: 0.0, through: 160.0, by: 4.0)

        for time in sampleTimes {
            let topVisibleHearts = FloatingHeartFactory.hearts.filter { heart in
                let y = heart.position(in: canvas, at: time).y
                return y >= 0 && y <= canvas.height * 0.38 && heart.opacity(at: time) >= 0.04
            }

            XCTAssertGreaterThanOrEqual(
                topVisibleHearts.count,
                7,
                "top area needs several visible hearts at \(time)s"
            )
        }
    }

    func testFloatingHeartsDoNotSitInOnePlace() {
        let canvas = CGSize(width: 390, height: 844)

        for heart in FloatingHeartFactory.hearts {
            let first = heart.position(in: canvas, at: 0)
            let next = heart.position(in: canvas, at: 1)
            let distance = hypot(first.x - next.x, first.y - next.y)

            XCTAssertGreaterThan(
                distance,
                1.5,
                "heart \(heart.id) should drift instead of staying fixed"
            )
        }
    }

    func testFloatingHeartsFadeAtRouteEdges() {
        for heart in FloatingHeartFactory.hearts {
            let topTime = TimeInterval(Double(heart.y) / heart.drift)
            let justAfterWrap = topTime + 0.01

            XCTAssertLessThanOrEqual(heart.opacity(at: topTime), heart.opacity * 0.1)
            XCTAssertLessThanOrEqual(heart.opacity(at: justAfterWrap), heart.opacity * 0.1)
        }
    }
}
