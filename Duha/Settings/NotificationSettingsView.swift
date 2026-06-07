import SwiftUI

/// Per-prayer notification controls (spec §8). Changing anything reschedules the
/// rolling window immediately.
struct NotificationSettingsView: View {
    @Environment(NotificationSettings.self) private var notifs
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var calc

    var body: some View {
        @Bindable var notifs = notifs

        Form {
            Section {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    Picker(prayer.rawValue, selection: modeBinding(prayer)) {
                        ForEach(PrayerNotificationMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
            } header: {
                Text("Per Prayer")
            } footer: {
                Text("Adhan plays a sound · Silent shows a banner only · Off sends nothing.")
            }

            Section {
                Toggle("Pre-prayer reminder", isOn: $notifs.preReminderEnabled)
                    .onChange(of: notifs.preReminderEnabled) { reschedule() }
                if notifs.preReminderEnabled {
                    Stepper(value: $notifs.preReminderMinutes, in: 5...30, step: 5) {
                        HStack {
                            Text("Remind before")
                            Spacer()
                            Text("\(notifs.preReminderMinutes) min").foregroundStyle(Palette.blue)
                        }
                    }
                    .onChange(of: notifs.preReminderMinutes) { reschedule() }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Off by default — a reminder for each prayer uses extra notification slots.")
            }

            Section {
                Label("Adhan currently uses the default tone. Bundled Makkah & Madinah recordings come in a later update.",
                      systemImage: "music.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func modeBinding(_ prayer: Prayer) -> Binding<PrayerNotificationMode> {
        Binding(
            get: { notifs.mode(for: prayer) },
            set: { notifs.setMode($0, for: prayer); reschedule() }
        )
    }

    private func reschedule() {
        NotificationScheduler.reschedule(location: location.active,
                                         config: calc.prayerConfig,
                                         notifs: notifs)
    }
}
