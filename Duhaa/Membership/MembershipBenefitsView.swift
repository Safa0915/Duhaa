import SwiftUI
import StoreKit

/// The Duhaa+ benefits catalog — every supporter perk in one scrollable list,
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
        Benefit(icon: "arrow.down.circle.fill", color: .teal,
                title: "Offline Quran Audio",
                detail: "Download surahs for offline listening"),
        Benefit(icon: "music.mic", color: .orange,
                title: "Expanded Reciter Library",
                detail: "More renowned voices for your recitation"),
        Benefit(icon: "speaker.wave.2.fill", color: .blue,
                title: "Custom Adhan Voices",
                detail: "A library of adhan voices for your prayer notifications"),
        Benefit(icon: "paintpalette.fill", color: .purple,
                title: "Tajweed-Colored Mushaf",
                detail: "Color-coded tajweed rules for proper recitation"),
        Benefit(icon: "chart.line.uptrend.xyaxis", color: .pink,
                title: "Cycle Analytics",
                detail: "Charts and gentle insights in the Sisters' space"),
        Benefit(icon: "doc.text.fill", color: .red,
                title: "Medical Export",
                detail: "Your cycle history as a PDF for healthcare providers"),
        Benefit(icon: "sparkles", color: .yellow,
                title: "Early Access",
                detail: "Try new features before everyone else"),
        Benefit(icon: "rosette", color: Palette.gold,
                title: "Founding Supporter",
                detail: "Your name in About, and our lasting du'a"),
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
        .navigationTitle("Membership Benefits")
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
            actionRow("Manage Subscription") {
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
