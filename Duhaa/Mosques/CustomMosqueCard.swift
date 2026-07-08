import SwiftUI

/// One mosque the user added themselves, in Duhaa's celestial card style.
/// Mirrors `NearbyMosqueCard` (Directions / Call / Website) and adds an overflow
/// menu to edit or remove it. Only shows the buttons the saved data supports.
struct CustomMosqueCard: View {
    let mosque: CustomMosque
    var onEdit: () -> Void
    var onDelete: () -> Void
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
                    Text(mosque.displayName)
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
                    Text("Added by you")
                        .duhaaFont(11, .medium)
                        .foregroundStyle(Palette.blue.opacity(0.8))
                    Menu {
                        Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { onDelete() } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .duhaaFont(15, .semibold)
                            .foregroundStyle(Palette.blue.opacity(0.7))
                            .frame(width: 32, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More options for \(mosque.displayName)")
                }
            }

            HStack(spacing: 8) {
                if let directions = mosque.directionsURL {
                    actionButton("Directions", icon: "arrow.triangle.turn.up.right.diamond.fill", primary: true) {
                        openURL(directions)
                    }
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
        .duhaaCardStyle()
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: {
                Label("Remove", systemImage: "trash")
            }
        }
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
        .accessibilityLabel("\(title), \(mosque.displayName)")
    }
}
