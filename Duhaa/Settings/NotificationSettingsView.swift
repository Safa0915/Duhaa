import SwiftUI
import UserNotifications

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
                    .onChange(of: notifs.preReminderEnabled) { _, _ in reschedule() }
                if notifs.preReminderEnabled {
                    Stepper(value: $notifs.preReminderMinutes, in: 5...30, step: 5) {
                        HStack {
                            Text("Remind before")
                            Spacer()
                            Text("\(notifs.preReminderMinutes) min").foregroundStyle(Palette.blue)
                        }
                    }
                    .onChange(of: notifs.preReminderMinutes) { _, _ in reschedule() }
                }
            } header: {
                Text("Reminders")
            } footer: {
                Text("Off by default — a reminder for each prayer uses extra notification slots.")
            }

            Section {
                Toggle("Jumu'ah reminder", isOn: $notifs.jumuahReminder)
                    .onChange(of: notifs.jumuahReminder) { _, _ in reschedule() }
            } header: {
                Text("Friday")
            } footer: {
                Text("On Fridays: a gentle morning nudge (ghusl, Surah Al-Kahf) and a Jumu'ah-flavoured midday reminder. 🕌")
            }

            Section {
                Label("Sound plays a soft Duhaa chime. A full Makkah & Madinah adhan recording comes in a later update.",
                      systemImage: "music.note")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            #if DEBUG
            // Dev-only: verify the chime + banner on a real device (simulators
            // don't play custom notification sounds). Lock the phone after tapping.
            Section("Developer") {
                Button {
                    sendTestNotification()
                } label: {
                    Label("Test notification in 5 seconds", systemImage: "bell.and.waves.left.and.right")
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
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

    #if DEBUG
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time for Maghrib 🌆"
        content.body = "This is a test — you should hear the soft Duhaa chime."
        content.sound = UNNotificationSound(named: UNNotificationSoundName(NotificationCopy.soundFileName))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "duhaa.test", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    #endif
}
