import SwiftUI

/// "Support Duhaa" — a gentle, never-pushy invitation to back the app.
/// In the Ad-Duhaa spirit: an offer, with a warm "and if you can't, that's okay."
struct SupportView: View {
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero

                Text("Duhaa is made by one person, kept free, with no ads and nothing locked away. Your support keeps it alive and helps it grow.")
                    .duhaaFont(15)
                    .foregroundStyle(.primary.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    perk("heart.fill", "Keeps Duhaa free & ad-free", "For everyone, forever.")
                    divider
                    perk("sparkles", "Funds new features", "Quran audio, more du'as, and more to come.")
                    divider
                    perk("apple.logo", "Covers the running costs", "Like Apple's yearly developer fee.")
                }
                .background(Palette.card)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                Button {
                    openURL(SupportLinks.checkout)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                        Text("Support on Website")
                    }
                    .duhaaFont(16, .semibold)
                    .foregroundStyle(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Palette.gold, Palette.gold.opacity(0.82)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Palette.gold.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(.plain)

                ShareLink(item: "Duhaa — a gentle prayer app built on hope, not guilt.") {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Share Duhaa")
                    }
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    requestReview()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                        Text("Rate Duhaa")
                    }
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Text("Support opens Duhaa's website and is handled there with Stripe. Core worship, Quran, and learning features stay free.")
                    .duhaaFont(12)
                    .foregroundStyle(.primary.opacity(0.66))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Text("And if you can't right now, that's completely okay — a quiet du'a for this work means just as much. 🤍")
                    .duhaaFont(13)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Support Duhaa")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Palette.gold.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: 60))
                .frame(width: 130, height: 130)
            Image(systemName: "heart.fill")
                .duhaaFont(46)
                .foregroundStyle(Palette.gold)
                .shadow(color: Palette.gold.opacity(0.5), radius: 14)
        }
        .frame(height: 120)
        .padding(.top, 8)
    }

    private func perk(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .duhaaFont(18)
                .foregroundStyle(Palette.gold)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).duhaaFont(15, .semibold).foregroundStyle(.primary)
                Text(subtitle).duhaaFont(12).foregroundStyle(Palette.blue.opacity(0.75))
            }
            Spacer()
        }
        .padding(16)
    }

    private var divider: some View {
        Divider().overlay(Color.primary.opacity(0.06)).padding(.leading, 16)
    }
}

enum SupportLinks {
    static let checkout = URL(string: "https://duhaa.app/support?source=ios_app")!
    static let billing = URL(string: "https://duhaa.app/billing?source=ios_app")!
    static let redeem = URL(string: "https://duhaa.app/redeem?source=ios_app")!
}
