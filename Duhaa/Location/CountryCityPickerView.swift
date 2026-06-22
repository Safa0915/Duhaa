import SwiftUI

/// Step 1 of the offline manual-location flow: pick a country. Pushed from the
/// LocationPickerView; tapping a country drills into its cities (CityPickerView).
/// `onChoose` is called once a city is finally selected, to dismiss the whole sheet.
struct CountryPickerView: View {
    let onChoose: () -> Void

    @State private var countries: [WorldCountry]?
    @State private var query = ""

    private var filtered: [WorldCountry] {
        let all = countries ?? []
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        Group {
            if countries == nil {
                ProgressView().tint(Palette.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { country in
                        NavigationLink {
                            CityPickerView(country: country, onChoose: onChoose)
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.flag).font(.title3)
                                Text(country.name).foregroundStyle(.primary)
                                Spacer()
                                Text("\(country.cities.count)")
                                    .font(.caption)
                                    .foregroundStyle(Palette.blue.opacity(0.6))
                            }
                        }
                    }
                    if filtered.isEmpty {
                        Text("No matching country.").foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                            prompt: "Search countries")
            }
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Country")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if countries == nil { countries = await WorldLocations.loadAsync() }
        }
    }
}

/// Step 2: pick a city within the chosen country. Selecting one sets the manual
/// location (offline) and dismisses the sheet via `onChoose`.
struct CityPickerView: View {
    let country: WorldCountry
    let onChoose: () -> Void

    @Environment(LocationProvider.self) private var location
    @State private var query = ""

    private var filtered: [WorldCity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return country.cities }
        return country.cities.filter {
            $0.n.localizedCaseInsensitiveContains(trimmed)
                || ($0.r?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { city in
                Button {
                    location.choose(city: city, country: country.name)
                    DuhaaHaptics.tap()
                    onChoose()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin")
                            .foregroundStyle(Palette.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.n).foregroundStyle(.primary)
                            if let region = city.r {
                                Text(region)
                                    .font(.caption)
                                    .foregroundStyle(Palette.blue.opacity(0.6))
                            }
                        }
                        Spacer()
                        if location.isActive(city) {
                            Image(systemName: "checkmark").foregroundStyle(Palette.gold)
                        }
                    }
                }
            }
            if filtered.isEmpty {
                Text("No matching city.").foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search cities")
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(country.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
