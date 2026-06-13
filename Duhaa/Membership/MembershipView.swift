import SwiftUI
import StoreKit

/// The Duhaa+ paywall. Selecting a tier repaints the header (name, tagline,
/// perks) — one sheet tells each tier's story. Monthly/Annual toggle, three
/// plan cards, a state-aware CTA, and Restore. Worship is never paywalled;
/// this is a supporter membership on top of a complete free app.
struct MembershipView: View {
    @Environment(SubscriptionStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: MembershipTier = .fajr
    @State private var annual = false

    private var selectedProduct: Product? {
        store.product(for: selectedTier, annual: annual)
    }

    private var isCurrentSelection: Bool {
        store.currentProductID == selectedTier.productID(annual: annual)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.appBg.ignoresSafeArea()
            // The tier header glow — gold dawn fading into the night background.
            LinearGradient(colors: [Palette.gold.opacity(0.38), Palette.gold.opacity(0.10), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 360)
                .ignoresSafeArea(edges: .top)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    tierHeader
                    perkList
                    periodToggle.padding(.top, 6)
                    planCards
                    renewalCaption
                    ctaButton
                    restoreButton
                    if store.products.isEmpty { storeUnavailableNote }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .task {
            await store.start()
            if let tier = store.currentTier { selectedTier = tier }
            if store.currentProductID?.hasSuffix(".annual") == true { annual = true }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTier)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Palette.card)
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.cardBorder, lineWidth: 1))
                Image(systemName: "moon.stars.fill")
                    .duhaaFont(20)
                    .foregroundStyle(Palette.gold)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .duhaaFont(14, .semibold)
                    .foregroundStyle(.primary.opacity(0.8))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .accessibilityLabel("Close")
        }
        .padding(.top, 8)
    }

    // MARK: Header

    private var tierHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(selectedTier.displayName)
                    .duhaaFont(44, .bold)
                    .foregroundStyle(.primary.opacity(0.92))
                Image(systemName: selectedTier.icon)
                    .duhaaFont(26)
                    .foregroundStyle(Palette.gold)
            }
            Text(selectedTier.tagline)
                .duhaaFont(18)
                .foregroundStyle(.primary.opacity(0.75))
        }
        .accessibilityElement(children: .combine)
    }

    private var perkList: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(selectedTier.perks, id: \.self) { perk in
                HStack(alignment: .top, spacing: 11) {
                    ZStack {
                        Circle().fill(Palette.gold.opacity(0.95)).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .duhaaFont(11, .bold)
                            .foregroundStyle(Palette.onAccent)
                    }
                    Text(perk)
                        .duhaaFont(16)
                        .foregroundStyle(.primary.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: Billing period

    private var periodToggle: some View {
        HStack(spacing: 0) {
            periodButton("Monthly", isAnnual: false)
            periodButton("Annual", isAnnual: true)
        }
        .padding(3)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
        .overlay(Capsule().stroke(Palette.cardBorder, lineWidth: 1))
    }

    private func periodButton(_ title: String, isAnnual: Bool) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { annual = isAnnual }
        } label: {
            Text(title)
                .duhaaFont(14, .semibold)
                .foregroundStyle(annual == isAnnual ? Palette.onAccent : .primary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(annual == isAnnual ? Palette.gold : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Plan cards

    private var planCards: some View {
        VStack(spacing: 12) {
            ForEach(MembershipTier.allCases) { tier in
                planCard(tier)
            }
        }
    }

    private func planCard(_ tier: MembershipTier) -> some View {
        let selected = tier == selectedTier
        let price = store.product(for: tier, annual: annual)?.displayPrice
            ?? fallbackPrice(tier)
        return Button {
            selectedTier = tier
            DuhaaHaptics.tick()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Image(systemName: tier.icon)
                            .duhaaFont(14)
                            .foregroundStyle(Palette.gold)
                        Text(tier.displayName)
                            .duhaaFont(19, .bold)
                            .foregroundStyle(.primary)
                        if tier.isMostPopular {
                            Text("MOST POPULAR")
                                .duhaaFont(11, .bold).tracking(0.6)
                                .foregroundStyle(Palette.blue)
                        }
                    }
                    Text("\(price)/\(annual ? "yr" : "mo")")
                        .duhaaFont(24, .bold)
                        .foregroundStyle(.primary)
                }
                Spacer()
                ZStack {
                    if selected {
                        Circle().fill(Palette.gold).frame(width: 26, height: 26)
                        Image(systemName: "checkmark")
                            .duhaaFont(12, .bold)
                            .foregroundStyle(Palette.onAccent)
                    } else {
                        Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1.6)
                            .frame(width: 26, height: 26)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(selected ? Palette.gold.opacity(0.10) : Palette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(selected ? Palette.gold.opacity(0.8) : Palette.cardBorder,
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.duhaaPress)
        .accessibilityLabel("\(tier.displayName), \(price) per \(annual ? "year" : "month")\(tier.isMostPopular ? ", most popular" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Shown only when the App Store is unreachable (e.g. launched outside Xcode
    /// during the testing era) so the layout still reads correctly.
    private func fallbackPrice(_ tier: MembershipTier) -> String {
        switch (tier, annual) {
        case (.hilal, false): "$1.99"
        case (.hilal, true):  "$19.99"
        case (.fajr, false):  "$2.99"
        case (.fajr, true):   "$29.99"
        case (.duhaa, false): "$3.99"
        case (.duhaa, true):  "$39.99"
        }
    }

    // MARK: CTA + captions

    private var renewalCaption: some View {
        VStack(spacing: 3) {
            Text("\(selectedProduct?.displayPrice ?? fallbackPrice(selectedTier))/\(annual ? "yr" : "mo")")
                .duhaaFont(14, .semibold)
                .foregroundStyle(.primary.opacity(0.85))
            Text("Auto-renews at \(selectedProduct?.displayPrice ?? fallbackPrice(selectedTier))/\(annual ? "yr" : "mo"). Cancel anytime.")
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var ctaButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await store.purchase(product) }
        } label: {
            Group {
                if store.purchaseInFlight {
                    ProgressView().tint(Palette.onAccent)
                } else {
                    Text(ctaTitle)
                        .duhaaFont(18, .semibold)
                }
            }
            .foregroundStyle(isCurrentSelection ? Color.primary.opacity(0.45) : Palette.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(isCurrentSelection ? Color.primary.opacity(0.08) : Palette.gold, in: Capsule())
        }
        .buttonStyle(.duhaaPress)
        .disabled(isCurrentSelection || selectedProduct == nil || store.purchaseInFlight)

    }

    private var ctaTitle: String {
        if isCurrentSelection { return "Your current plan" }
        if store.isSubscribed { return "Switch to \(selectedTier.displayName)" }
        return "Continue with \(selectedTier.displayName)"
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restore() }
        } label: {
            Text("Restore Purchases")
                .duhaaFont(15, .medium)
                .foregroundStyle(.primary.opacity(0.7))
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 2)
    }

    private var storeUnavailableNote: some View {
        Text("Plans load when the App Store is reachable. During testing, run Duhaa from Xcode to try purchases.")
            .duhaaFont(12)
            .foregroundStyle(Palette.blue.opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }
}
