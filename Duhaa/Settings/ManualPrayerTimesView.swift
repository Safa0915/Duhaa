import SwiftUI

/// Lets the user follow their own fixed timetable instead of the calculated adhān —
/// e.g. the printed calendar from their local mosque. When enabled, these times
/// replace the calculation across the home screen, countdowns and notifications.
/// The first time it's switched on, the fields are seeded from today's calculated
/// times for the active location, so the user starts from accurate values.
struct ManualPrayerTimesView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(LocationProvider.self) private var location

    var body: some View {
        Form {
            Section {
                Toggle("Use my own times", isOn: Binding(
                    get: { store.manualTimes.enabled },
                    set: { isOn in
                        if isOn && !store.manualTimes.configured {
                            fillFromCalculated()
                            store.manualTimes.configured = true
                        }
                        store.manualTimes.enabled = isOn
                        DuhaaHaptics.tick()
                    }))
                    .tint(Palette.gold)
                    .listRowBackground(Palette.card)
            } header: {
                Text("Manual Times")
            } footer: {
                Text("Turn this on to follow your own fixed timetable — like the printed calendar from your local mosque. Your times replace the calculated adhān everywhere, including notifications. The calculation method and time adjustments no longer apply.")
            }

            if store.manualTimes.enabled {
                Section("Your Times") {
                    timeRow("Fajr", \.fajr)
                    timeRow("Sunrise", \.sunrise)
                    timeRow("Dhuhr", \.dhuhr)
                    timeRow("Asr", \.asr)
                    timeRow("Maghrib", \.maghrib)
                    timeRow("Isha", \.isha)
                }

                Section {
                    Button {
                        fillFromCalculated()
                        DuhaaHaptics.success()
                    } label: {
                        Label("Fill from calculated times", systemImage: "wand.and.stars")
                            .foregroundStyle(Palette.blue)
                    }
                    .listRowBackground(Palette.card)
                } footer: {
                    Text("Reset every time to today's calculated value for \(location.active.name), then fine-tune.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(ThemeDecorativeBackground())
        .navigationTitle("My Prayer Times")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
    }

    @ViewBuilder
    private func timeRow(_ name: String,
                         _ keyPath: WritableKeyPath<ManualPrayerTimes, Int>) -> some View {
        HStack {
            Text(name)
                .foregroundStyle(.primary)
            Spacer()
            DatePicker("", selection: dateBinding(keyPath), displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
        .listRowBackground(Palette.card)
    }

    /// Bridges a stored minutes-since-midnight value to the DatePicker's `Date`.
    private func dateBinding(_ keyPath: WritableKeyPath<ManualPrayerTimes, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = store.manualTimes[keyPath: keyPath]
                var comps = DateComponents()
                comps.hour = minutes / 60
                comps.minute = minutes % 60
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                store.manualTimes[keyPath: keyPath] = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }

    /// Seed the manual fields from today's *calculated* times for the active location.
    private func fillFromCalculated() {
        let loc = location.active
        let tz = loc.timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let today = calendar.dateComponents([.year, .month, .day], from: Date())

        var calcConfig = store.prayerConfig
        calcConfig.manual.enabled = false   // compute, don't echo the manual values back

        guard let t = PrayerEngine.times(latitude: loc.latitude,
                                         longitude: loc.longitude,
                                         date: today,
                                         config: calcConfig,
                                         timeZone: tz) else { return }

        func minutes(_ date: Date) -> Int {
            let c = calendar.dateComponents([.hour, .minute], from: date)
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }

        var m = store.manualTimes
        m.fajr = minutes(t.fajr)
        m.sunrise = minutes(t.sunrise)
        m.dhuhr = minutes(t.dhuhr)
        m.asr = minutes(t.asr)
        m.maghrib = minutes(t.maghrib)
        m.isha = minutes(t.isha)
        store.manualTimes = m   // one assignment → one persist
    }
}
