import SwiftUI
import StoreKit

/// The Duhaa+ support catalog — every supporter note in one scrollable list,
/// with the standard account actions (restore, manage, offer codes) below.
/// Deliberately absent: artificial limits. Worship features and the user's own
/// data are never capped in Duhaa, member or not.
struct MembershipBenefitsView: View {
    @Environment(SubscriptionStore.self) private var store

    @State private var showingManageSubscriptions = false
    @State private var showingOfferCodeRedemption = false
    @State private var showingPlans = false

    private struct Benefit: Identifiable {
        let icon: String
        let color: Color
        let title: String
        let detail: String
        var id: String { title }
    }

    private let benefits: [Benefit] = [
        Benefit(icon: "heart.fill", color: .pink,
                title: "Keeps Duhaa Free",
                detail: "Your support helps keep prayer, Quran, du'as, learning, widgets, and tracking open to everyone"),
        Benefit(icon: "hand.raised.fill", color: .teal,
                title: "No Ads, No Tracking",
                detail: "Support lets Duhaa stay privacy-first instead of depending on ads or analytics"),
        Benefit(icon: "book.closed.fill", color: .blue,
                title: "Funds Source Review",
                detail: "Helps cover the careful review needed for religious content before wider release"),
        Benefit(icon: "speaker.wave.2.fill", color: .orange,
                title: "Future Licensed Audio",
                detail: "Helps fund properly licensed notification and recitation improvements later"),
        Benefit(icon: "sparkles", color: .yellow,
                title: "Polish Before Growth",
                detail: "Supports the quiet work: widgets, accessibility, prayer-time confidence, and bug fixes"),
        Benefit(icon: "rosette", color: Palette.gold,
                title: "Our Gratitude",
                detail: "A sincere thank-you and du'a for helping Duhaa remain gentle and sustainable"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                benefitsCard
                actionsCard
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Support Duhaa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Plans") { showingPlans = true }
                    .foregroundStyle(Palette.gold)
            }
        }
        .sheet(isPresented: $showingPlans) { MembershipView() }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .offerCodeRedemption(isPresented: $showingOfferCodeRedemption)
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
    }

    private var benefitsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                if index > 0 {
                    Divider().overlay(Color.primary.opacity(0.08)).padding(.leading, 64)
                }
                benefitRow(benefit)
            }
        }
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func benefitRow(_ benefit: Benefit) -> some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle().fill(benefit.color.opacity(0.9))
                Image(systemName: benefit.icon)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(benefit.title)
                    .duhaaFont(17, .bold)
                    .foregroundStyle(.primary)
                Text(benefit.detail)
                    .duhaaFont(13.5)
                    .foregroundStyle(.primary.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            actionRow("Restore Purchases") {
                Task { await store.restore() }
            }
            Divider().overlay(Color.primary.opacity(0.08)).padding(.leading, 14)
            actionRow("Manage Subscriptions") {
                showingManageSubscriptions = true
            }
            Divider().overlay(Color.primary.opacity(0.08)).padding(.leading, 14)
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.9))
                    Image(systemName: "ticket.fill")
                        .duhaaFont(12, .semibold)
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)
                Text("Redeem Offer Code")
                    .duhaaFont(16, .medium)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .duhaaFont(12, .semibold)
                    .foregroundStyle(.primary.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .onTapGesture { showingOfferCodeRedemption = true }
        }
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func actionRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .duhaaFont(16, .semibold)
                    .foregroundStyle(Palette.gold)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
