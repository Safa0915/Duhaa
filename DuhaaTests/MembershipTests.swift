import XCTest
import StoreKit
import StoreKitTest
@testable import Duhaa

/// Covers the Duhaa+ tier model and — when the scheme's StoreKit configuration
/// is active — that all six products actually load from Duhaa.storekit.
final class MembershipTests: XCTestCase {

    func testTierRanksAscendNightToMorning() {
        XCTAssertLessThan(MembershipTier.hilal.rank, MembershipTier.fajr.rank)
        XCTAssertLessThan(MembershipTier.fajr.rank, MembershipTier.duhaa.rank)
    }

    func testProductIDsRoundTrip() {
        for tier in MembershipTier.allCases {
            for annual in [false, true] {
                let id = tier.productID(annual: annual)
                XCTAssertEqual(MembershipTier(productID: id), tier, id)
                XCTAssertTrue(id.hasPrefix("com.duhaa.app.plus."), id)
                XCTAssertTrue(id.hasSuffix(annual ? ".annual" : ".monthly"), id)
            }
        }
        XCTAssertNil(MembershipTier(productID: "com.duhaa.app.unrelated"))
    }

    func testSixProductIDsExist() {
        XCTAssertEqual(SubscriptionStore.allProductIDs.count, 6)
        XCTAssertEqual(Set(SubscriptionStore.allProductIDs).count, 6)
    }

    func testEveryTierHasContent() {
        for tier in MembershipTier.allCases {
            XCTAssertFalse(tier.perks.isEmpty, tier.rawValue)
            XCTAssertFalse(tier.tagline.isEmpty, tier.rawValue)
            XCTAssertFalse(tier.displayName.isEmpty, tier.rawValue)
        }
        XCTAssertEqual(MembershipTier.allCases.filter(\.isMostPopular).count, 1)
    }

    /// Spins up a local StoreKit test session from the bundled Duhaa.storekit
    /// (no Apple account, no scheme dependency) and validates the full pipeline:
    /// all six products load, a purchase entitles the right tier, and switching
    /// tiers upgrades the entitlement.
    func testFullPurchasePipelineAgainstBundledConfiguration() async throws {
        let url = try XCTUnwrap(
            Bundle(for: SubscriptionStore.self).url(forResource: "Duhaa", withExtension: "storekit"),
            "Duhaa.storekit must be bundled with the app"
        )
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true

        let products = try await Product.products(for: SubscriptionStore.allProductIDs)
        // SKTestSession needs the full Xcode toolchain as the SYSTEM default
        // (`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`).
        // When the host points at CommandLineTools, the testing daemon can't
        // start — skip honestly rather than failing the whole suite.
        try XCTSkipIf(products.isEmpty,
                      "StoreKit test infrastructure unavailable — run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` once, then this test goes live")
        XCTAssertEqual(products.count, 6, "Expected all six Duhaa+ products from Duhaa.storekit")
        for product in products {
            XCTAssertEqual(product.type, .autoRenewable, product.id)
        }

        let store = SubscriptionStore()
        await store.start()
        XCTAssertNil(store.currentTier, "fresh session should have no entitlement")

        let fajr = try XCTUnwrap(store.product(for: .fajr, annual: false))
        await store.purchase(fajr)
        XCTAssertEqual(store.currentTier, .fajr)
        XCTAssertEqual(store.currentProductID, "com.duhaa.app.plus.fajr.monthly")

        // Upgrading within the group replaces the entitlement.
        let duhaa = try XCTUnwrap(store.product(for: .duhaa, annual: true))
        await store.purchase(duhaa)
        XCTAssertEqual(store.currentTier, .duhaa)

        session.clearTransactions()
    }
}
