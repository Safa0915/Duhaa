import XCTest
@testable import Duhaa

/// Covers the customizable tab bar: defaults, the merge-in of newly-shipped tabs,
/// the bar/More split, hide/show, and reset.
final class TabSettingsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.tabs.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFreshUsesDefaultOrder() {
        let tabs = TabSettings(defaults: defaults)
        XCTAssertEqual(tabs.order, DuhaaTab.defaultOrder)
        XCTAssertTrue(tabs.hidden.isEmpty)
    }

    func testMergesInNewlyShippedTabs() {
        // Simulate an older user who only had the first three tabs saved.
        defaults.set([DuhaaTab.prayer, .qibla, .quran].map(\.rawValue), forKey: "duhaa.tabs.order")
        let tabs = TabSettings(defaults: defaults)
        // The saved three stay first; everything else is appended (nothing disappears).
        XCTAssertEqual(Array(tabs.order.prefix(3)), [.prayer, .qibla, .quran])
        for t in DuhaaTab.allCases { XCTAssertTrue(tabs.order.contains(t)) }
    }

    func testBarAndMoreSplitWhenOverflowing() {
        let tabs = TabSettings(defaults: defaults)   // 6 tabs by default
        XCTAssertGreaterThan(tabs.enabled.count, TabSettings.maxBarSlots)
        XCTAssertEqual(tabs.barTabs.count, TabSettings.maxBarSlots - 1)   // last slot is "More"
        XCTAssertFalse(tabs.moreTabs.isEmpty)
        XCTAssertEqual(tabs.barTabs.count + tabs.moreTabs.count, tabs.enabled.count)
    }

    func testHidingEnoughRemovesTheMoreOverflow() {
        let tabs = TabSettings(defaults: defaults)
        tabs.toggleHidden(.sisters)
        tabs.toggleHidden(.tasbih)    // down to 5 enabled -> all fit, no More
        XCTAssertEqual(tabs.enabled.count, 5)
        XCTAssertEqual(tabs.barTabs.count, 5)
        XCTAssertTrue(tabs.moreTabs.isEmpty)
        XCTAssertEqual(tabs.placement(of: .sisters), .hidden)
        XCTAssertEqual(tabs.placement(of: .tasbih), .hidden)
    }

    func testBrotherProfileDoesNotSeeSistersTab() {
        let tabs = TabSettings(defaults: defaults)
        XCTAssertTrue(tabs.enabled.contains(.sisters))
        XCTAssertFalse(tabs.enabled(for: .brother).contains(.sisters))
        XCTAssertFalse(tabs.barTabs(for: .brother).contains(.sisters))
        XCTAssertFalse(tabs.moreTabs(for: .brother).contains(.sisters))
        XCTAssertEqual(tabs.placement(of: .sisters, for: .brother), .hidden)
    }

    func testSisterProfileCanSeeSistersTab() {
        let tabs = TabSettings(defaults: defaults)
        XCTAssertTrue(tabs.enabled(for: .sister).contains(.sisters))
    }

    func testCannotHideTheLastVisibleTab() {
        let tabs = TabSettings(defaults: defaults)
        for t in DuhaaTab.allCases where t != .prayer { tabs.toggleHidden(t) }
        XCTAssertEqual(tabs.enabled, [.prayer])
        tabs.toggleHidden(.prayer)   // refused — must keep at least one
        XCTAssertEqual(tabs.enabled, [.prayer])
    }

    func testReorderPersists() {
        let tabs = TabSettings(defaults: defaults)
        tabs.move(from: IndexSet(integer: tabs.order.count - 1), to: 0)   // move last to front
        let reloaded = TabSettings(defaults: defaults)
        XCTAssertEqual(reloaded.order.first, tabs.order.first)
    }

    func testResetRestoresDefault() {
        let tabs = TabSettings(defaults: defaults)
        tabs.toggleHidden(.tasbih)
        tabs.move(from: IndexSet(integer: 0), to: 3)
        tabs.resetToDefault()
        XCTAssertEqual(tabs.order, DuhaaTab.defaultOrder)
        XCTAssertTrue(tabs.hidden.isEmpty)
    }
}
