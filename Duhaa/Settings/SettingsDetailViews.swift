import Foundation
import SwiftUI
import UserNotifications

struct ProfileSettingsView: View {
    @AppStorage("duhaa.profile.name") private var profileName = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $profileName)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Local Profile")
            } footer: {
                Text("This stays on your device — no account required.")
            }
        }
        .settingsDetailStyle(title: "Identity")
    }
}

struct ThemeSettingsView: View {
    @Environment(ThemeStore.self) private var themeStore

    var body: some View {
        Form {
            Section {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        guard themeStore.theme != theme else { return }
                        themeStore.theme = theme
                        DuhaaHaptics.tick()
                    } label: {
                        ThemeOptionRow(theme: theme, isSelected: themeStore.theme == theme)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Palette.card)
                }
            } header: {
                Text("Appearance")
            } footer: {
                Text("Light Pink is a free premium preview - a taste of future premium themes. No subscription is required.")
            }
        }
        .settingsDetailStyle(title: "Appearance")
    }
}

private struct ThemeOptionRow: View {
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 13) {
            ThemeSwatches(theme: theme)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(theme.displayName)
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(.primary)
                    if let badge = theme.previewBadge {
                        Text(badge)
                            .duhaaFont(10.5, .bold)
                            .foregroundStyle(theme.colors.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(theme.colors.accent, in: Capsule())
                    }
                }

                Text(theme.previewSubtitle)
                    .duhaaFont(12.5)
                    .foregroundStyle(Palette.secondaryText.opacity(0.84))
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .duhaaFont(20, .semibold)
                .foregroundStyle(isSelected ? Palette.gold : Palette.secondaryText.opacity(0.38))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(theme.displayName), \(theme.previewSubtitle)\(isSelected ? ", selected" : "")")
    }
}

private struct ThemeSwatches: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: -4) {
            let swatches = theme.previewSwatches
            ForEach(Array(swatches.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(theme.colors.border.opacity(0.85), lineWidth: 1))
            }
        }
        .frame(width: 58, alignment: .leading)
        .accessibilityHidden(true)
    }
}

struct CalculationMethodSettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Picker("Method", selection: $store.method) {
                    ForEach(CalcMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Calculation Method")
            } footer: {
                Text("Changing this recomputes prayer times immediately.")
            }
        }
        .settingsDetailStyle(title: "Calculation Method")
    }
}

struct AsrMethodSettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Picker("Asr method", selection: $store.madhab) {
                    ForEach(AsrMadhab.allCases) { madhab in
                        Text(madhab.label).tag(madhab)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Asr Method")
            } footer: {
                Text("Hanafi calculates Asr later, when an object's shadow is twice its length.")
            }
        }
        .settingsDetailStyle(title: "Madhab")
    }
}

struct PrayerDisplaySettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Picker("Home display", selection: $store.nextPrayerDisplayMode) {
                    ForEach(NextPrayerDisplayMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Home Display")
            } footer: {
                Text("Choose whether the home banner leads with the next prayer name or the time remaining until it begins.")
            }
        }
        .settingsDetailStyle(title: "Home Display")
    }
}

struct HighLatitudeSettingsView: View {
    @Environment(LocationProvider.self) private var location

    private var isHighLatitude: Bool { abs(location.active.latitude) > 48 }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Rule")
                    Spacer()
                    Text("Middle of Night")
                        .foregroundStyle(Palette.blue)
                }
                .listRowBackground(Palette.card)

                if isHighLatitude {
                    precaution("sunrise", "Dawn is hard to pin down exactly here. To be safe, finish suhoor a little early — and don't rush to pray the moment Fajr begins.")
                    precaution("moon.stars", "Isha's start is approximate here. Give it a few minutes before you pray.")
                    NavigationLink {
                        PrayerTimeAdjustmentsView()
                    } label: {
                        Label("Adjust Fajr & Isha Times", systemImage: "clock.badge.fill")
                            .foregroundStyle(Palette.gold)
                    }
                    .listRowBackground(Palette.card)
                    precaution("calendar.badge.clock", "Daylight shifts fast at this latitude — re-check these offsets each season.")
                } else {
                    Text("Your saved location is not currently in Duhaa's high-latitude caution zone.")
                        .duhaaFont(13)
                        .foregroundStyle(.primary.opacity(0.72))
                        .listRowBackground(Palette.card)
                }
            } header: {
                Text("High-Latitude Handling")
            } footer: {
                Text("This is a v1 stopgap. High-latitude Fajr and Isha remain a known research debt, so Duhaa does not present them as uniquely authoritative. Compare with a trusted local mosque when unsure.")
            }
        }
        .settingsDetailStyle(title: "High Latitude")
    }

    private func precaution(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Palette.blue)
                .frame(width: 20)
            Text(text)
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.82))
        }
        .listRowBackground(Palette.card)
    }
}

struct PrayerTimeAdjustmentsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                offsetStepper("Fajr", value: $store.offsets.fajr)
                offsetStepper("Dhuhr", value: $store.offsets.dhuhr)
                offsetStepper("Asr", value: $store.offsets.asr)
                offsetStepper("Maghrib", value: $store.offsets.maghrib)
                offsetStepper("Isha", value: $store.offsets.isha)
            } header: {
                Text("Adjust Prayer Times")
            } footer: {
                Text("Fine-tune any prayer to match your trusted local mosque. Larger adjustments are available for high-latitude Fajr and Isha differences.")
            }
        }
        .settingsDetailStyle(title: "Time Adjustments")
    }

    private func offsetStepper(_ name: String, value: Binding<Int>) -> some View {
        Stepper(value: value, in: -120...120, step: 5) {
            HStack {
                Text(name)
                Spacer()
                Text("\(signed(value.wrappedValue)) min")
                    .foregroundStyle(value.wrappedValue == 0 ? .secondary : Palette.blue)
            }
        }
        .listRowBackground(Palette.card)
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}

struct HijriDateSettingsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
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
                    .tint(Palette.gold)
            } header: {
                Text("Hijri Date")
            } footer: {
                Text("Nudge ±1–2 days to match your local moon sighting. Both dates are always shown.")
            }
        }
        .settingsDetailStyle(title: "Hijri Date")
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}

struct PrayerInsightsSettingsView: View {
    @Environment(InsightsStore.self) private var insights
    @Environment(LocationProvider.self) private var location

    var body: some View {
        Form {
            Section {
                Toggle(isOn: insightsBinding) {
                    Label("Prayer insights", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tint(Palette.gold)
                .listRowBackground(Palette.card)
            } footer: {
                Text("Shows how many prayers you've kept on time, prayed late, or missed in your Journey — a gentle nudge to grow. Turning it on starts fresh from today.")
            }
        }
        .settingsDetailStyle(title: "Prayer Insights")
    }

    private var insightsBinding: Binding<Bool> {
        Binding(
            get: { insights.enabled },
            set: { insights.setEnabled($0, today: PrayerTracker.dayKey(Date(), location.active.timeZone)) }
        )
    }
}

struct SiriShortcutsSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                shortcut("Prayer Times", "Open Duhaa directly to the Prayer tab.", "moon.stars.fill")
                shortcut("Quran", "Open Duhaa directly to Quran.", "book.closed.fill")
                shortcut("Qibla", "Open Duhaa directly to Qibla.", "location.north.line.fill")
            } header: {
                Text("Available Shortcuts")
            } footer: {
                Text("These are registered with the iOS Shortcuts app and can be used from Siri.")
            }

            Section {
                Button {
                    if let url = URL(string: "shortcuts://") {
                        openURL(url)
                    }
                } label: {
                    Label("Open Shortcuts App", systemImage: "sparkles")
                        .foregroundStyle(Palette.gold)
                }
                .listRowBackground(Palette.card)
            }
        }
        .settingsDetailStyle(title: "Siri Shortcuts")
    }

    private func shortcut(_ title: String, _ detail: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .duhaaFont(16, .semibold)
                .foregroundStyle(Palette.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .duhaaFont(15, .semibold)
                Text(detail)
                    .duhaaFont(12)
                    .foregroundStyle(.primary.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Palette.card)
    }
}

struct AdhanSoundSettingsView: View {
    @Environment(NotificationSettings.self) private var notifs
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var calc
    @AppStorage(AdhanSoundPreference.key) private var soundRaw = AdhanSoundPreference.duhaaChime.rawValue
    @State private var testMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("Sound", selection: soundBinding) {
                    ForEach(AdhanSoundPreference.allCases) { preference in
                        Text(preference.label).tag(preference)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .listRowBackground(Palette.card)
            } header: {
                Text("Adhan Notification Sound")
            } footer: {
                Text(currentSound.detail)
            }

            Section {
                Button {
                    sendTestNotification()
                } label: {
                    Label("Test Sound in 5 Seconds", systemImage: "bell.and.waves.left.and.right")
                        .foregroundStyle(Palette.gold)
                }
                .listRowBackground(Palette.card)

                if let testMessage {
                    Text(testMessage)
                        .duhaaFont(12)
                        .foregroundStyle(Palette.blue.opacity(0.82))
                        .listRowBackground(Palette.card)
                }
            } footer: {
                Text("Changing this reschedules upcoming prayer notifications immediately.")
            }
        }
        .settingsDetailStyle(title: "Adhan Sound")
    }

    private var currentSound: AdhanSoundPreference {
        AdhanSoundPreference(rawValue: soundRaw) ?? .duhaaChime
    }

    private var soundBinding: Binding<AdhanSoundPreference> {
        Binding(
            get: { currentSound },
            set: { preference in
                soundRaw = preference.rawValue
                reschedule()
                DuhaaHaptics.tick()
            }
        )
    }

    private func reschedule() {
        NotificationScheduler.reschedule(location: location.active,
                                         config: calc.prayerConfig,
                                         notifs: notifs)
    }

    private func sendTestNotification() {
        Task {
            let granted = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            guard granted == true else {
                await MainActor.run { testMessage = "Notification permission is off." }
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Duhaa sound test"
            content.body = "This is how your adhan notifications will sound."
            content.sound = notificationSound(for: currentSound)

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(identifier: "duhaa.sound.test", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
            await MainActor.run { testMessage = "Scheduled. Lock the phone or wait for the banner." }
        }
    }

    private func notificationSound(for preference: AdhanSoundPreference) -> UNNotificationSound {
        switch preference {
        case .duhaaChime:
            UNNotificationSound(named: UNNotificationSoundName(NotificationCopy.soundFileName))
        case .systemDefault:
            .default
        }
    }
}

struct QuranPreferencesView: View {
    @AppStorage("duhaa.quran.readerFont") private var readerFont = "kfgqpc"
    @AppStorage("duhaa.quran.reciter") private var reciterID = Reciters.defaultID
    @AppStorage("duhaa.quran.arabicSize") private var arabicSize = 28.0
    @AppStorage("duhaa.quran.showTranslation") private var showTranslation = true
    @AppStorage("duhaa.quran.tajweedColoring") private var tajweedColoring = false
    @AppStorage("duhaa.quran.audioCacheBudgetMB") private var audioCacheBudgetMB = 0
    @Environment(QuranOfflineLibrary.self) private var offline
    @State private var showingReciterPicker = false
    @State private var offlineBytes: Int64 = 0

    var body: some View {
        Form {
            Section {
                Button { showingReciterPicker = true } label: {
                    HStack(spacing: 12) {
                        if let reciter = Reciters.byID(reciterID) {
                            ReciterAvatar(reciter: reciter, size: 32)
                        }
                        Text("Reciter").foregroundStyle(.primary)
                        Spacer()
                        Text(Reciters.byID(reciterID)?.name ?? "Choose")
                            .foregroundStyle(Palette.blue)
                            .lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .sheet(isPresented: $showingReciterPicker) {
                    ReciterPickerView(selection: $reciterID)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("Arabic size")
                        Spacer()
                        Text("\(Int(arabicSize)) pt")
                            .foregroundStyle(Palette.blue)
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundStyle(.secondary)
                        Slider(value: $arabicSize, in: 22...40, step: 2)
                            .tint(Palette.gold)
                            .accessibilityLabel("Arabic size")
                            .accessibilityValue("\(Int(arabicSize)) points")
                        Image(systemName: "textformat.size.larger")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Show translation", isOn: $showTranslation)
                    .tint(Palette.gold)

                Picker("Reader font", selection: $readerFont) {
                    Text("KFGQPC HAFS").tag("kfgqpc")
                    Text("System Arabic").tag("systemArabic")
                }

                Toggle("Tajweed coloring", isOn: $tajweedColoring)
                    .tint(Palette.gold)
            } header: {
                Text("Reader")
            } footer: {
                Text("Reciter, Arabic size, translation visibility, reader font, and mark coloring update the Quran reader immediately.")
            }

            Section {
                HStack {
                    Text("Translation")
                    Spacer()
                    Text("ClearQuran English")
                        .foregroundStyle(Palette.blue)
                }
            } footer: {
                Text("More translations need licensing review before shipping — they'll appear here when cleared.")
            }

            Section {
                Picker("Cache budget", selection: $audioCacheBudgetMB) {
                    Text("Off").tag(0)
                    Text("100 MB").tag(100)
                    Text("250 MB").tag(250)
                    Text("500 MB").tag(500)
                }
                .onChange(of: audioCacheBudgetMB) { _, budget in
                    if budget == 0 { QuranAudioCache.clear() }
                    DuhaaHaptics.tick()
                }
            } header: {
                Text("Audio")
            } footer: {
                Text("When enabled, played Quran audio is cached locally up to this budget. Off clears the cache.")
            }

            Section {
                HStack {
                    Text("Downloaded recitations")
                    Spacer()
                    Text(offlineBytes > 0
                         ? ByteCountFormatter.string(fromByteCount: offlineBytes, countStyle: .file)
                         : "None")
                        .foregroundStyle(Palette.blue)
                }
                if offlineBytes > 0 {
                    Button(role: .destructive) {
                        offline.clearAll()
                        offlineBytes = 0
                        DuhaaHaptics.tick()
                    } label: {
                        Text("Remove all downloads")
                    }
                }
            } header: {
                Text("Offline")
            } footer: {
                Text("Download a surah from the Listen player (the headphones button) to keep it for offline playback. Downloads stay until you remove them.")
            }
        }
        .onAppear { offlineBytes = offline.totalBytes() }
        .settingsDetailStyle(title: "Quran")
    }
}

struct DataExportPreviewView: View {
    var title = "Export My Data"
    var intro = "Create a readable JSON export of Duhaa's local settings and on-device data keys."

    @State private var exportURL: URL?
    @State private var exportError: String?

    var body: some View {
        Form {
            Section {
                Label("Local JSON export", systemImage: "square.and.arrow.up")
                    .listRowBackground(Palette.card)
                Text(intro)
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.72))
                    .listRowBackground(Palette.card)
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share Export File", systemImage: "square.and.arrow.up.fill")
                            .foregroundStyle(Palette.gold)
                    }
                    .listRowBackground(Palette.card)
                }

                Button {
                    prepareExport()
                } label: {
                    Label(exportURL == nil ? "Prepare Export" : "Refresh Export",
                          systemImage: "arrow.clockwise.circle.fill")
                }
                .listRowBackground(Palette.card)

                if let exportError {
                    Text(exportError)
                        .duhaaFont(12)
                        .foregroundStyle(.red.opacity(0.85))
                        .listRowBackground(Palette.card)
                }
            } header: {
                Text("Export")
            } footer: {
                Text("\(DuhaaDataExporter.exportedKeyCount) local Duhaa keys are ready to export. The file stays on this device until you share or save it.")
            }
        }
        .settingsDetailStyle(title: title)
        .task {
            if exportURL == nil { prepareExport() }
        }
    }

    private func prepareExport() {
        do {
            exportURL = try DuhaaDataExporter.makeExportFile()
            exportError = nil
            DuhaaHaptics.tick()
        } catch {
            exportURL = nil
            exportError = error.localizedDescription
        }
    }
}

struct DeleteLocalDataView: View {
    @State private var showingConfirmation = false
    @State private var deletionMessage: String?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("This only clears this device", systemImage: "trash.fill")
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(.orange)
                    Text("It removes Duhaa's local preferences, prayer marks, Quran bookmarks, tab layout, and onboarding flag from UserDefaults.")
                        .duhaaFont(13)
                        .foregroundStyle(.primary.opacity(0.74))
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card)

                Button(role: .destructive) {
                    showingConfirmation = true
                } label: {
                    Label("Delete Local Data", systemImage: "trash.fill")
                }
                .listRowBackground(Palette.card)

                if let deletionMessage {
                    Text(deletionMessage)
                        .duhaaFont(12)
                        .foregroundStyle(Palette.blue.opacity(0.8))
                        .listRowBackground(Palette.card)
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("This does not delete anything in iCloud or Apple purchase history. Export first if you may want a backup.")
            }
        }
        .settingsDetailStyle(title: "Delete Local Data")
        .confirmationDialog("Delete all local Duhaa data?",
                            isPresented: $showingConfirmation,
                            titleVisibility: .visible) {
            Button("Delete Local Data", role: .destructive) {
                let removed = DuhaaDataExporter.deleteLocalData()
                deletionMessage = "Deleted \(removed) local keys. Restart Duhaa to reload every screen from defaults."
                DuhaaHaptics.tap()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone inside the app.")
        }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument

    var body: some View {
        Form {
            ForEach(document.sections) { section in
                Section(section.title) {
                    Text(section.body)
                        .duhaaFont(13)
                        .foregroundStyle(.primary.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowBackground(Palette.card)
                }
            }
        }
        .settingsDetailStyle(title: document.title)
    }
}

enum LegalDocument {
    case privacy
    case terms

    var title: String {
        switch self {
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Service"
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .privacy:
            [
                LegalSection("Local First", "Duhaa is designed to work without an account. Your prayer marks, Quran bookmarks, and settings are stored on this device unless you choose to export them."),
                LegalSection("Location", "Prayer times need a location. Duhaa stores your selected location locally and uses it to calculate times on device. City search, current-location naming, and nearby mosque search use Apple's location and MapKit services; Duhaa does not sell your location or use it for ads."),
                LegalSection("Notifications", "Prayer reminders are scheduled through iOS notifications. You can turn them off per prayer or from system Settings at any time."),
                LegalSection("Support", "If you email a bug report or support request, your message is handled by your mail app and whatever details you choose to include."),
                LegalSection("Your Controls", "Export My Data creates a local JSON file. Delete All Local Data removes Duhaa's local keys from this device.")
            ]
        case .terms:
            [
                LegalSection("Purpose", "Duhaa is a worship companion built on hope, not guilt. It provides prayer reminders, Quran reading tools, and educational material."),
                LegalSection("Prayer Times", "Prayer times are calculated estimates. Verify local mosque times when precision matters, especially in high-latitude locations where Fajr and Isha remain a known caution area."),
                LegalSection("Religious Content", "Learning content is provided for review and study. If a ruling or source looks wrong, report it so it can be checked before release."),
                LegalSection("Purchases", "Any support flow is voluntary. Core worship, Quran, and learning features are not paywalled."),
                LegalSection("No Warranty", "Use Duhaa as a helpful tool, not as the sole authority for religious or legal decisions.")
            ]
        }
    }
}

struct LegalSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String

    init(_ title: String, _ body: String) {
        self.title = title
        self.body = body
    }
}

enum DuhaaDataExporter {
    private struct DefaultsSuite {
        let label: String
        let defaults: UserDefaults
        let keys: [String]
    }

    static var exportedKeyCount: Int {
        defaultSuites().reduce(0) { $0 + exportableDefaults(from: $1).count }
    }

    static func makeExportFile(now: Date = Date(), appVersion: String = appVersion) throws -> URL {
        let payload = exportPayload(now: now, appVersion: appVersion)
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("duhaa-data-export", conformingTo: .json)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportPayload(now: Date = Date(), appVersion: String = appVersion) -> [String: Any] {
        exportPayload(now: now, appVersion: appVersion, suites: defaultSuites())
    }

    static func exportPayload(now: Date = Date(), appVersion: String = appVersion, standard: UserDefaults, appGroup: UserDefaults) -> [String: Any] {
        exportPayload(now: now,
                      appVersion: appVersion,
                      suites: [DefaultsSuite(label: "standard", defaults: standard, keys: standardKeys),
                               DefaultsSuite(label: "appGroup", defaults: appGroup, keys: appGroupKeys)])
    }

    @discardableResult
    static func deleteLocalData() -> Int {
        deleteLocalData(from: defaultSuites())
    }

    @discardableResult
    static func deleteLocalData(standard: UserDefaults, appGroup: UserDefaults) -> Int {
        deleteLocalData(from: [DefaultsSuite(label: "standard", defaults: standard, keys: standardKeys),
                               DefaultsSuite(label: "appGroup", defaults: appGroup, keys: appGroupKeys)])
    }

    private static func exportPayload(now: Date, appVersion: String, suites: [DefaultsSuite]) -> [String: Any] {
        let settings = suites.reduce(into: [String: Any]()) { result, suite in
            result[suite.label] = exportableDefaults(from: suite)
        }
        return [
            "app": "Duhaa",
            "appVersion": appVersion,
            "exportedAt": ISO8601DateFormatter().string(from: now),
            "format": "duhaa.local.userdefaults.v2",
            "settings": settings
        ]
    }

    private static func deleteLocalData(from suites: [DefaultsSuite]) -> Int {
        suites.reduce(0) { total, suite in
            let existingKeys = suite.keys.filter { suite.defaults.object(forKey: $0) != nil }
            existingKeys.forEach { suite.defaults.removeObject(forKey: $0) }
            suite.defaults.synchronize()
            return total + existingKeys.count
        }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private static func defaultSuites() -> [DefaultsSuite] {
        [DefaultsSuite(label: "standard", defaults: .standard, keys: standardKeys),
         DefaultsSuite(label: "appGroup", defaults: .duhaaShared, keys: appGroupKeys)]
    }

    private static func exportableDefaults(from suite: DefaultsSuite) -> [String: Any] {
        suite.keys.sorted().reduce(into: [String: Any]()) { result, key in
            guard let value = suite.defaults.object(forKey: key) else { return }
            result[key] = jsonSafeValue(value)
        }
    }

    private static let standardKeys = [
        "duhaa.activeLocation.v1",
        "duhaa.fasting.days",
        "duhaa.hasOnboarded",
        "duhaa.insights.enabled",
        "duhaa.insights.startDay",
        "duhaa.notif.adhanSound",
        "duhaa.notif.jumuah",
        "duhaa.notif.modes",
        "duhaa.notif.reminderMinutes",
        "duhaa.notif.reminderOn",
        "duhaa.notifications.didShowOptIn",
        "duhaa.profile.gender",
        "duhaa.profile.name",
        "duhaa.quran.arabicSize",
        "duhaa.quran.audioCacheBudgetMB",
        "duhaa.quran.bookmarks",
        "duhaa.quran.lastAyah",
        "duhaa.quran.lastSurah",
        "duhaa.quran.readerFont",
        "duhaa.quran.reciter",
        "duhaa.quran.showTranslation",
        "duhaa.quran.tajweedColoring",
        "duhaa.settings.hijriIsPrimary",
        "duhaa.settings.hijriOffsetDays",
        "duhaa.settings.madhab",
        "duhaa.settings.method",
        "duhaa.settings.nextPrayerDisplayMode",
        "duhaa.settings.offsets",
        "duhaa.shortcut.targetTab",
        "duhaa.tabs.hidden",
        "duhaa.tabs.order",
        "duhaa.tasbih.adhkar.completed",
        "duhaa.tasbih.adhkar.count",
        "duhaa.tasbih.adhkar.phase",
        "duhaa.tasbih.adhkar.total",
        "duhaa.tasbih.custom.count",
        "duhaa.tasbih.mode",
        "duhaa.tasbih.target",
        "duhaa.theme"
    ]

    private static let appGroupKeys = [
        "duhaa.shared.migratedTrackerV1",
        "duhaa.theme",
        "duhaa.tracker.lastOpened",
        "duhaa.tracker.lateMarks",
        "duhaa.tracker.marks",
        "duhaa.widget.timesPayload.v1"
    ]

    private static func jsonSafeValue(_ value: Any) -> Any {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let data as Data:
            return [
                "encoding": "base64",
                "value": data.base64EncodedString()
            ]
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let url as URL:
            return url.absoluteString
        case let array as [Any]:
            return array.map(jsonSafeValue)
        case let dictionary as [String: Any]:
            return dictionary.mapValues(jsonSafeValue)
        case Optional<Any>.none:
            return NSNull()
        default:
            return String(describing: value)
        }
    }
}

struct WhatsNewView: View {
    var body: some View {
        Form {
            Section {
                change("Learn", "Added the offline Learn section with step-by-step guides and inline evidence.")
                change("Settings", "Expanded settings into a fuller structure while keeping the existing prayer controls.")
            }
        }
        .settingsDetailStyle(title: "What's New")
    }

    private func change(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .duhaaFont(15, .semibold)
            Text(detail)
                .duhaaFont(13)
                .foregroundStyle(.primary.opacity(0.72))
        }
        .padding(.vertical, 2)
        .listRowBackground(Palette.card)
    }
}

private extension View {
    func settingsDetailStyle(title: String) -> some View {
        self
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(ThemeDecorativeBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .tint(Palette.gold)
            .preferredColorScheme(Palette.active.colorScheme)
    }
}
