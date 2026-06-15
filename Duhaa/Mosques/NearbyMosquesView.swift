import SwiftUI
import CoreLocation
import UIKit

/// Nearby Mosques — finds masjids around the user with Apple MapKit only.
/// Reuses the app's existing `LocationProvider` for permission + coordinate
/// (no second location manager, no background tracking, no analytics).
struct NearbyMosquesView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = NearbyMosquesViewModel()

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.active.latitude,
                               longitude: location.active.longitude)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.appBg.ignoresSafeArea()
                content
            }
            .navigationTitle("Nearby Mosques")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if case .loaded = model.state {
                        Button { Task { await model.search(around: coordinate, force: true) } } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .foregroundStyle(Palette.gold)
                        .accessibilityLabel("Refresh")
                    }
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .task { await model.locateAndSearch(using: location) }
        .onChange(of: location.authorizationStatus) { _, _ in
            Task { await model.locateAndSearch(using: location) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            loadingSkeletons
        case .permissionNeeded:
            permissionNeeded
        case .permissionDenied:
            stateView(icon: "location.slash.fill",
                      title: "Location permission is off",
                      message: "Turn it on to find nearby mosques.",
                      button: ("Open Settings", openAppSettings))
        case .empty:
            stateView(icon: "building.columns",
                      title: "No nearby mosques found",
                      message: "Try refreshing or expanding your search.",
                      button: ("Refresh", { Task { await model.search(around: coordinate, force: true) } }))
        case .error:
            stateView(icon: "exclamationmark.triangle.fill",
                      title: "Couldn't load nearby mosques",
                      button: ("Try Again", { Task { await model.search(around: coordinate, force: true) } }))
        case .loaded(let mosques):
            results(mosques)
        }
    }

    /// The loading state — shimmering skeleton cards that preview the real list,
    /// with a quiet caption. Calmer and more premium than a centered spinner.
    private var loadingSkeletons: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Finding nearby mosques…")
                    .duhaaFont(13)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)
                ForEach(0..<5, id: \.self) { _ in MosqueCardSkeleton() }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(true)
        .accessibilityLabel("Finding nearby mosques")
    }

    private func results(_ mosques: [MosquePlace]) -> some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(mosques) { NearbyMosqueCard(mosque: $0) }
                Text("Used only to show nearby mosques and prayer times.")
                    .duhaaFont(11)
                    .foregroundStyle(Palette.blue.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6).padding(.bottom, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
    }

    private var permissionNeeded: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .duhaaFont(52)
                .foregroundStyle(Palette.gold)
            Text("Find mosques around you")
                .duhaaFont(22, .semibold)
                .foregroundStyle(.primary)
            Text("Duhaa uses your location to find nearby mosques and calculate prayer times. Your location is not sold or used for ads.")
                .duhaaFont(14)
                .foregroundStyle(.primary.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)
            Button {
                location.useCurrentLocation()   // triggers the system When-In-Use prompt
            } label: {
                Text("Allow Location")
                    .duhaaFont(16, .semibold)
                    .foregroundStyle(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Palette.gold, in: Capsule())
            }
            .buttonStyle(.duhaaPress)
            .padding(.horizontal, 36)
            Spacer()
        }
    }

    private func stateView(icon: String, title: String, message: String? = nil,
                           spinner: Bool = false,
                           button: (String, () -> Void)? = nil) -> some View {
        VStack(spacing: 14) {
            Spacer()
            if spinner {
                ProgressView().controlSize(.large).tint(Palette.gold)
            }
            Image(systemName: icon)
                .duhaaFont(40)
                .foregroundStyle(Palette.gold.opacity(0.85))
            Text(title)
                .duhaaFont(18, .semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .duhaaFont(13.5)
                    .foregroundStyle(.primary.opacity(0.62))
                    .multilineTextAlignment(.center)
            }
            if let (label, action) = button {
                Button(action: action) {
                    Text(label)
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 26).padding(.vertical, 12)
                        .background(Palette.gold, in: Capsule())
                }
                .buttonStyle(.duhaaPress)
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 36)
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

/// The entry point on the Prayer home — a calm celestial card that opens the
/// Nearby Mosques sheet.
struct NearbyMosquesButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Palette.gold.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "building.columns.fill")
                        .duhaaFont(17)
                        .foregroundStyle(Palette.gold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nearby Mosques")
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(.primary)
                    Text("Find masjids around you")
                        .duhaaFont(12.5)
                        .foregroundStyle(Palette.blue.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(Palette.blue.opacity(0.5))
            }
            .padding(16)
            .background(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.duhaaPress)
        .accessibilityLabel("Nearby Mosques. Find masjids around you.")
    }
}
