import Foundation
import StoreKit
import Observation

/// The three Duhaa+ supporter tiers — night to morning brightness, mirroring
/// the app's own story. Worship features are never paywalled; these are
/// supporter perks on top of a complete free app.
enum MembershipTier: String, CaseIterable, Identifiable {
    case hilal   // the crescent — first light
    case fajr    // the dawn — most popular
    case duhaa   // the full morning brightness

    var id: String { rawValue }

    /// Higher rank = higher tier of service.
    var rank: Int {
        switch self {
        case .hilal: 1
        case .fajr:  2
        case .duhaa: 3
        }
    }

    var displayName: String {
        switch self {
        case .hilal: "Hilal"
        case .fajr:  "Fajr"
        case .duhaa: "Duhaa"
        }
    }

    var icon: String {
        switch self {
        case .hilal: "moon.fill"
        case .fajr:  "sunrise.fill"
        case .duhaa: "sun.max.fill"
        }
    }

    var tagline: String {
        switch self {
        case .hilal: "The first light of support."
        case .fajr:  "Steady support for Duhaa."
        case .duhaa: "Deeper support for the work."
        }
    }

    var isMostPopular: Bool { self == .fajr }

    var perks: [String] {
        switch self {
        case .hilal:
            ["Keep Duhaa free, forever, for everyone",
             "Help cover Apple, testing, and maintenance costs",
             "Our du'a and gratitude, always"]
        case .fajr:
            ["Everything in Hilal",
             "Help fund privacy-first development with no ads",
             "Support careful source review before wider launch",
             "No worship, Quran, or learning feature is locked"]
        case .duhaa:
            ["Everything in Fajr",
             "Help fund future licensed audio and content work",
             "Support faster polish for widgets, Quran, and prayer tools",
             "A deeper share in keeping Duhaa sustainable"]
        }
    }

    /// Parses a tier out of a product id like "com.duhaa.app.plus.fajr.monthly".
    /// Anchored to the membership prefix — a naive substring match would see
    /// ".duhaa." inside every bundle-prefixed id.
    init?(productID: String) {
        let prefix = "com.duhaa.app.plus."
        guard productID.hasPrefix(prefix),
              let tierComponent = productID.dropFirst(prefix.count).split(separator: ".").first,
              let match = MembershipTier(rawValue: String(tierComponent)) else {
            return nil
        }
        self = match
    }

    func productID(annual: Bool) -> String {
        "com.duhaa.app.plus.\(rawValue).\(annual ? "annual" : "monthly")"
    }
}

/// StoreKit 2 wrapper for the Duhaa+ subscription group. Products come from
/// App Store Connect in production, or from Duhaa.storekit when running
/// through Xcode (the testing-era path — no paid developer account needed).
@Observable
final class SubscriptionStore {
    static let allProductIDs: [String] = MembershipTier.allCases.flatMap {
        [$0.productID(annual: false), $0.productID(annual: true)]
    }

    /// All six products, when the store is reachable (empty otherwise).
    private(set) var products: [Product] = []
    /// The active entitlement, if any.
    private(set) var currentTier: MembershipTier?
    private(set) var currentProductID: String?
    private(set) var purchaseInFlight = false
    private(set) var lastError: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    var isSubscribed: Bool { currentTier != nil }

    /// Called once from the paywall's .task — loads products, reads the current
    /// entitlement, and starts listening for renewals/changes.
    func start() async {
        if products.isEmpty { await loadProducts() }
        await refreshEntitlements()
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                        await self?.refreshEntitlements()
                    }
                }
            }
        }
    }

    func product(for tier: MembershipTier, annual: Bool) -> Product? {
        products.first { $0.id == tier.productID(annual: annual) }
    }

    func purchase(_ product: Product) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        lastError = nil
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
                DuhaaHaptics.success()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "The purchase didn't go through. Nothing was charged."
        }
    }

    func restore() async {
        lastError = nil
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: Internals

    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    private func refreshEntitlements() async {
        var bestTier: MembershipTier?
        var bestProductID: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productType == .autoRenewable,
                  let tier = MembershipTier(productID: transaction.productID) else { continue }
            if bestTier.map({ tier.rank > $0.rank }) ?? true {
                bestTier = tier
                bestProductID = transaction.productID
            }
        }
        currentTier = bestTier
        currentProductID = bestProductID
    }
}
