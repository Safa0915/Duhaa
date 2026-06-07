import SwiftUI

/// The Settings screen. Changing anything here persists and the home screen
/// recomputes live (spec §4, §12, §13). Reached from the gear on the home screen.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(LocationProvider.self) private var location
    @Environment(\.dismiss) private var dismiss

    /// High latitudes (≈ above 48°) get the gentle Fajr/Isha precaution copy.
    private var isHighLatitude: Bool { abs(location.active.latitude) > 48 }

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }

                Section("Calculation Method") {
                    Picker("Method", selection: $store.method) {
                        ForEach(CalcMethod.allCases) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Picker("Asr method", selection: $store.madhab) {
                        ForEach(AsrMadhab.allCases) { madhab in
                            Text(madhab.label).tag(madhab)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Asr (Afternoon Prayer)")
                } footer: {
                    Text("Hanafi calculates Asr later, when an object's shadow is twice its length.")
                }

                Section {
                    Stepper(value: $store.hijriOffsetDays, in: -2...2) {
                        HStack {
                            Text("Adjust days")
                            Spacer()
                            Text(signed(store.hijriOffsetDays))
                                .foregroundStyle(Palette.blue)
                        }
                    }
                    Toggle("Show Hijri as the primary date", isOn: $store.hijriIsPrimary)
                } header: {
                    Text("Hijri Date")
                } footer: {
                    Text("Nudge ±1–2 days to match your local moon sighting. Both dates are always shown.")
                }

                Section {
                    offsetStepper("Fajr", value: $store.offsets.fajr)
                    offsetStepper("Dhuhr", value: $store.offsets.dhuhr)
                    offsetStepper("Asr", value: $store.offsets.asr)
                    offsetStepper("Maghrib", value: $store.offsets.maghrib)
                    offsetStepper("Isha", value: $store.offsets.isha)
                } header: {
                    Text("Adjust Prayer Times")
                } footer: {
                    Text("Fine-tune any prayer by a few minutes to match your local mosque.")
                }

                if isHighLatitude {
                    highLatitudeSection
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: High-latitude precaution (spec §13)

    private var highLatitudeSection: some View {
        Section {
            precaution("sunrise", "Dawn is hard to pin down exactly here. To be safe, finish suhoor a little early — and don't rush to pray the moment Fajr begins.")
            precaution("moon.stars", "Isha's start is approximate here. Give it a few minutes before you pray.")
            precaution("calendar.badge.clock", "Daylight shifts fast at this latitude — re-check these offsets each season.")
        } header: {
            Label("High-latitude note — \(location.active.name)", systemImage: "exclamationmark.triangle")
                .foregroundStyle(Palette.gold)
        } footer: {
            Text("Pray each one on time — that's the heart of it.")
                .foregroundStyle(Palette.blue)
        }
    }

    private func precaution(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(Palette.blue).frame(width: 20)
            Text(text).font(.footnote).foregroundStyle(.white.opacity(0.85))
        }
    }

    // MARK: Helpers

    private func offsetStepper(_ name: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: -30...30) {
            HStack {
                Text(name)
                Spacer()
                Text("\(signed(value.wrappedValue)) min")
                    .foregroundStyle(value.wrappedValue == 0 ? .secondary : Palette.blue)
            }
        }
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}
