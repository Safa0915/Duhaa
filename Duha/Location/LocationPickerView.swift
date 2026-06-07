import SwiftUI
import UIKit

/// Sheet for choosing where Duha computes prayer times: use the current GPS
/// location, or search for a city by hand. Reached by tapping the header.
struct LocationPickerView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [CitySuggestion] = []
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.appBg.ignoresSafeArea()
                list
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var list: some View {
        List {
            Section {
                Button {
                    location.useCurrentLocation()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill").foregroundStyle(Palette.gold)
                        Text("Use Current Location").foregroundStyle(.white)
                        Spacer()
                        if location.isLocating { ProgressView().tint(Palette.gold) }
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: location.active.isManual ? "mappin.circle.fill" : "location.circle.fill")
                        .foregroundStyle(Palette.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(location.active.name).foregroundStyle(.white)
                        Text(location.active.isManual ? "Selected city" : "Current location")
                            .font(.caption).foregroundStyle(Palette.blue.opacity(0.6))
                    }
                }

                if let error = location.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                    if location.authorizationStatus == .denied {
                        Button("Open Settings") { openSettings() }
                            .foregroundStyle(Palette.gold)
                    }
                }
            } header: {
                Text("Your Location")
            }

            if !results.isEmpty {
                Section("Search Results") {
                    ForEach(results) { city in
                        Button {
                            location.choose(city)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin").foregroundStyle(Palette.blue)
                                Text(city.name).foregroundStyle(.white)
                            }
                        }
                    }
                }
            } else if query.count >= 2 && !searching {
                Section {
                    Text("No matches. Try a different spelling.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search for a city")
        .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
    }

    /// Debounce typing, then forward-geocode the query into suggestions.
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { results = []; searching = false; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            if Task.isCancelled { return }
            searching = true
            location.searchCities(trimmed) { found in
                results = found
                searching = false
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
