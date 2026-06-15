import SwiftUI

/// One mosque result, in Duhaa's celestial card style. Shows name, distance,
/// address, and only the action buttons the data supports.
struct NearbyMosqueCard: View {
    let mosque: MosquePlace
    /// Injectable so tests can use a fake; the app uses real Apple Maps.
    var maps: MapsOpening = AppleMapsOpener()
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle().fill(Palette.gold.opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: "building.columns.fill")
                        .duhaaFont(15)
                        .foregroundStyle(Palette.gold)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(mosque.name)
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(mosque.displayAddress)
                        .duhaaFont(12.5)
                        .foregroundStyle(.primary.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(mosque.distanceLabel)
                        .duhaaFont(13, .semibold)
                        .foregroundStyle(Palette.blue)
                    if let isOpen = mosque.isOpen {
                        Text(isOpen ? "Open" : "Closed")
                            .duhaaFont(11, .medium)
                            .foregroundStyle(isOpen ? .green : .primary.opacity(0.5))
                    }
                }
            }

            HStack(spacing: 8) {
                actionButton("Directions", icon: "arrow.triangle.turn.up.right.diamond.fill", primary: true) {
                    maps.openDirections(to: mosque)
                }
                if let callURL = mosque.callURL {
                    actionButton("Call", icon: "phone.fill") { openURL(callURL) }
                }
                if let web = mosque.websiteURL {
                    actionButton("Website", icon: "safari.fill") { openURL(web) }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func actionButton(_ title: String, icon: String, primary: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).duhaaFont(11, .semibold)
                Text(title)
                    .duhaaFont(12.5, .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
            }
            .lineLimit(1)
            .foregroundStyle(primary ? Palette.onAccent : Palette.gold)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(primary ? Palette.gold : Palette.gold.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.duhaaPress)
        .accessibilityLabel("\(title), \(mosque.name)")
    }
}

/// A shimmering placeholder shaped like a real mosque card — shown while the
/// search runs, so the loading state previews what's coming (purposeful
/// animation, not a bare spinner).
struct MosqueCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(.skeleton).frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 6) {
                    bar(width: 150, height: 14)
                    bar(width: 200, height: 11)
                    bar(width: 120, height: 11)
                }
                Spacer(minLength: 8)
                bar(width: 38, height: 12)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule().fill(.skeleton).frame(height: 32).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shimmering()
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4).fill(.skeleton).frame(width: width, height: height)
    }
}
