import SwiftUI
import StoreKit
import UIKit

/// Settings keeps Duhaa's existing working controls, but presents them in a
/// fuller sectioned structure: identity, appearance, prayer, Quran, cycle,
/// privacy, support, and about.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(LocationProvider.self) private var location
    @Environment(ThemeStore.self) private var themeStore
    @Environment(InsightsStore.self) private var insights
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    @AppStorage("duhaa.profile.name") private var profileName = ""
    @AppStorage("duhaa.quran.reciter") private var quranReciterID = Reciters.defaultID
    @AppStorage("duhaa.quran.showTranslation") private var quranShowTranslation = true
    @AppStorage(AdhanSoundPreference.key) private var adhanSoundRaw = AdhanSoundPreference.duhaaChime.rawValue

    @State private var showingLocationPicker = false
    @State private var showingMembership = false
    @Environment(SubscriptionStore.self) private var subscriptions

    private var displayName: String {
        let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Duhaa friend" : trimmed
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                appearanceSection
                prayerSection
                quranSection
                privacySection
                languageSection
                helpSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(ThemeDecorativeBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.gold)
                }
            }
            .sheet(isPresented: $showingMembership) {
                MembershipView()
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView()
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }

    // MARK: Sections

    private var profileSection: some View {
        Section {
            NavigationLink {
                ProfileSettingsView()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Palette.gold.opacity(0.18))
                            .frame(width: 48, height: 48)
                        Text(String(displayName.prefix(1)).uppercased())
                            .duhaaFont(20, .bold)
                            .foregroundStyle(Palette.gold)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .duhaaFont(17, .semibold)
                            .foregroundStyle(.primary)
                        Text("Local profile · no account required")
                            .duhaaFont(12)
                            .foregroundStyle(Palette.blue.opacity(0.72))
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Palette.card)

            HStack(spacing: 12) {
                Button {
                    showingMembership = true
                } label: {
                    statusCard(icon: subscriptions.currentTier?.icon ?? "moon.stars",
                               title: subscriptions.currentTier.map { "Duhaa+ \($0.displayName)" } ?? "Duhaa+",
                               detail: subscriptions.isSubscribed ? "Active — jazakum Allahu khairan" : "Nurture the ummah")
                }
                .buttonStyle(.duhaaPress)
                statusCard(icon: "arrow.triangle.2.circlepath", title: version, detail: "Installed")
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)

            NavigationLink {
                MembershipBenefitsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rosette")
                        .duhaaFont(17)
                        .foregroundStyle(Palette.gold)
                    Text("Membership Benefits")
                        .duhaaFont(16, .medium)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Palette.card)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            NavigationLink {
                ThemeSettingsView()
            } label: {
                settingsRow("Theme", icon: "paintbrush.fill", color: Palette.gold, value: themeStore.theme.displayName)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                CustomizeTabsView()
            } label: {
                settingsRow("Customize Tabs", icon: "square.grid.2x2.fill", color: Palette.blue)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                NotificationSettingsView()
            } label: {
                settingsRow("Notifications", icon: "bell.badge.fill", color: Palette.blue)
            }
            .listRowBackground(Palette.card)
        }
    }

    private var prayerSection: some View {
        Section("Prayer") {
            NavigationLink {
                CalculationMethodSettingsView()
            } label: {
                settingsRow("Calculation Method", icon: "calendar.badge.clock", color: Palette.blue, value: store.method.shortName)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                AsrMethodSettingsView()
            } label: {
                settingsRow("Madhab", icon: "book.closed.fill", color: Palette.gold, value: store.madhab.shortName)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                HighLatitudeSettingsView()
            } label: {
                settingsRow("High Latitude Rule", icon: "globe.europe.africa.fill", color: Palette.blue, value: "Middle of Night")
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                PrayerTimeAdjustmentsView()
            } label: {
                settingsRow("Time Adjustments", icon: "clock.badge.fill", color: Palette.gold, value: offsetsSummary)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                HijriDateSettingsView()
            } label: {
                settingsRow("Hijri Date", icon: "moonphase.waxing.crescent", color: Palette.blue, value: hijriSummary)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                PrayerInsightsSettingsView()
            } label: {
                settingsRow("Prayer Insights", icon: "chart.line.uptrend.xyaxis", color: Palette.gold, value: insights.enabled ? "On" : "Off")
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                SiriShortcutsSettingsView()
            } label: {
                settingsRow("Siri Shortcuts", icon: "sparkles", color: Palette.blue)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                AdhanSoundSettingsView()
            } label: {
                settingsRow("Adhan Sound", icon: "speaker.wave.2.fill", color: Palette.gold, value: adhanSoundLabel)
            }
            .listRowBackground(Palette.card)

            Button {
                showingLocationPicker = true
            } label: {
                settingsRow("Location", icon: "location.fill", color: Palette.blue, value: location.active.name)
            }
            .buttonStyle(.duhaaPress)
            .listRowBackground(Palette.card)
        }
    }

    private var quranSection: some View {
        Section("Quran") {
            NavigationLink {
                QuranPreferencesView()
            } label: {
                settingsRow("Quran Preferences", icon: "book.closed.fill", color: Palette.gold)
            }
            .listRowBackground(Palette.card)

            Toggle(isOn: $quranShowTranslation) {
                settingsRow("Show Translation", icon: "text.alignleft", color: Palette.blue)
            }
            .tint(Palette.gold)
            .listRowBackground(Palette.card)
        }
    }

    private var privacySection: some View {
        Section("Privacy & Data") {
            NavigationLink {
                DataExportPreviewView(title: "Backup & Transfer",
                                      intro: "Duhaa does not sync data to a server. For now, backup and transfer means making a local JSON export you can save or send to yourself.")
            } label: {
                settingsRow("Backup & Transfer", icon: "archivebox.fill", color: Palette.blue, value: "Local export")
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                DataExportPreviewView()
            } label: {
                settingsRow("Export My Data", icon: "square.and.arrow.up.fill", color: Palette.gold)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                DeleteLocalDataView()
            } label: {
                settingsRow("Delete All Local Data", icon: "trash.fill", color: .orange)
            }
            .listRowBackground(Palette.card)
        }
    }

    private var languageSection: some View {
        Section {
            Button {
                openAppSettings()
            } label: {
                settingsRow("App Language", icon: "globe", color: Palette.blue, value: Locale.current.localizedString(forIdentifier: Locale.current.identifier))
            }
            .buttonStyle(.duhaaPress)
            .listRowBackground(Palette.card)
        } header: {
            Text("Language")
        } footer: {
            Text("iOS manages per-app language from the system Settings app.")
        }
    }

    private var helpSection: some View {
        // Subscription management & offer codes live in Membership Benefits —
        // real StoreKit sheets, not website links to a domain we don't own.
        Section("Help & Support") {
            Button {
                requestReview()
            } label: {
                settingsRow("Rate the App", icon: "star.fill", color: Palette.gold)
            }
            .buttonStyle(.duhaaPress)
            .listRowBackground(Palette.card)

            ShareLink(item: "Duhaa — a gentle prayer app built on hope, not guilt.") {
                settingsRow("Share the App", icon: "square.and.arrow.up.fill", color: Palette.blue)
            }
            .tint(.primary)   // keep the title white like its neighbours, not accent-gold
            .listRowBackground(Palette.card)

            Button {
                reportBug()
            } label: {
                settingsRow("Report a Bug", icon: "ladybug.fill", color: .orange)
            }
            .buttonStyle(.duhaaPress)
            .listRowBackground(Palette.card)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                WhatsNewView()
            } label: {
                settingsRow("What's New", icon: "sparkles", color: Palette.gold)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                AboutView()
            } label: {
                settingsRow("About & Acknowledgements", icon: "info.circle.fill", color: Palette.blue)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                LegalDocumentView(document: .privacy)
            } label: {
                settingsRow("Privacy Policy", icon: "hand.raised.fill", color: Palette.blue)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                LegalDocumentView(document: .terms)
            } label: {
                settingsRow("Terms of Service", icon: "doc.text.fill", color: Palette.gold)
            }
            .listRowBackground(Palette.card)
        }
    }

    // MARK: Row helpers

    private func statusCard(icon: String, title: String, detail: String) -> some View {
        // Fixed height + a Spacer means the icon pins to the top and the title /
        // caption pin to the bottom — so the two cards line up exactly even when
        // one is wrapped in a Button and the other isn't.
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .duhaaFont(18, .semibold)
                .foregroundStyle(Palette.gold)
            Spacer(minLength: 10)
            Text(title)
                .duhaaFont(20, .bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .duhaaFont(12)
                .foregroundStyle(.primary.opacity(0.64))
                .lineLimit(1)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(16)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func settingsRow(_ title: String, icon: String, color: Color, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon, color: color)
            Text(title)
                .duhaaFont(16, .semibold)
                .foregroundStyle(.primary)
            Spacer(minLength: 10)
            if let value, !value.isEmpty {
                Text(value)
                    .duhaaFont(14, .medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var offsetsSummary: String {
        let values = store.offsets
        let offsets = [values.fajr, values.dhuhr, values.asr, values.maghrib, values.isha]
        let changed = offsets.filter { $0 != 0 }.count
        return changed == 0 ? "None" : "\(changed) changed"
    }

    private var hijriSummary: String {
        store.hijriOffsetDays == 0 ? (store.hijriIsPrimary ? "Primary" : "Secondary") : signed(store.hijriOffsetDays)
    }

    private var quranReciterLabel: String {
        Reciters.byID(quranReciterID)?.name ?? "Alafasy"
    }

    private var adhanSoundLabel: String {
        AdhanSoundPreference(rawValue: adhanSoundRaw)?.label ?? AdhanSoundPreference.duhaaChime.label
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func reportBug() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "safaburak0915@gmail.com"   // the real, monitored inbox
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Duhaa Bug Report")
        ]
        if let url = components.url {
            openURL(url)
        }
    }
}

private struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 30, height: 30)
            Image(systemName: systemName)
                .duhaaFont(13, .semibold)
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }
}

private extension CalcMethod {
    var shortName: String {
        switch self {
        case .muslimWorldLeague: "MWL"
        case .northAmerica: "ISNA"
        case .egyptian: "Egyptian"
        case .ummAlQura: "Umm al-Qura"
        case .karachi: "Karachi"
        case .dubai: "Dubai"
        case .qatar: "Qatar"
        case .kuwait: "Kuwait"
        case .singapore: "Singapore"
        case .tehran: "Tehran"
        case .turkey: "Turkey"
        case .moonsighting: "Moonsighting"
        }
    }
}

private extension AsrMadhab {
    var shortName: String {
        self == .hanafi ? "Hanafi" : "Standard"
    }
}
