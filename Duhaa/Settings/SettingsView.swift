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
    @Environment(SalahLockController.self) private var salahLock
    @Environment(FeedbackStore.self) private var feedback
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    @AppStorage("duhaa.profile.name") private var profileName = ""
    @AppStorage("duhaa.quran.showTranslation") private var quranShowTranslation = true
    @AppStorage(AdhanSoundPreference.key) private var adhanSoundRaw = AdhanSoundPreference.duhaaChime.rawValue

    @State private var showingLocationPicker = false
    @State private var showingMembership = false
    @State private var showingProfileSettings = false
    @State private var showingMembershipBenefits = false
    @State private var feedbackDraft: FeedbackDraft?
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
            ZStack {
                ThemeDecorativeBackground()

                VStack(spacing: 0) {
                    settingsHeader
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

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
                }
                .duhaaReadableWidth()
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showingProfileSettings) {
                ProfileSettingsView()
            }
            .navigationDestination(isPresented: $showingMembershipBenefits) {
                MembershipBenefitsView()
            }
            .sheet(isPresented: $showingMembership) {
                MembershipView()
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView()
            }
            .sheet(item: $feedbackDraft) { draft in
                FeedbackComposerView(
                    reason: draft.reason,
                    initialCategory: draft.category,
                    onClose: { feedbackDraft = nil },
                    onSubmitted: {
                        feedback.recordFeedbackStarted()
                        feedbackDraft = nil
                    }
                )
                .presentationDetents([.large])
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }

    // MARK: Sections

    private var settingsHeader: some View {
        ZStack {
            Text("settings")
                .duhaaFont(28, .bold)
                .foregroundStyle(.primary)
                .lineLimit(1)

            HStack {
                Spacer()
                Button("done") { dismiss() }
                    .duhaaFont(20, .bold)
                    .foregroundStyle(Palette.blue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(settingsHeaderButtonFill, in: Capsule())
                    .overlay(Capsule().stroke(Palette.cardBorder.opacity(0.7), lineWidth: 1))
                    .buttonStyle(.plain)
            }
        }
        .frame(height: 58)
        .accessibilityElement(children: .contain)
    }

    private var profileSection: some View {
        Section {
            VStack(spacing: 18) {
                Button {
                    showingProfileSettings = true
                } label: {
                    profileHeroCard
                }
                .buttonStyle(.duhaaPress)

                HStack(alignment: .top, spacing: 12) {
                    Button {
                        showingMembership = true
                    } label: {
                        topMetricCard(icon: "checkmark.seal.fill",
                                      iconFill: settingsPink,
                                      title: "duhaa+",
                                      value: subscriptions.isSubscribed ? "active" : "support",
                                      detail: "Nurture\nthe ummah")
                    }
                    .buttonStyle(.duhaaPress)
                    .frame(maxWidth: .infinity)

                    topMetricCard(icon: "gearshape.fill",
                                  iconFill: settingsBlue,
                                  title: "update",
                                  value: version,
                                  detail: "keep your app\nalways up to date")
                    .frame(maxWidth: .infinity)
                }

                Button {
                    showingMembershipBenefits = true
                } label: {
                    membershipBenefitsCard
                }
                .buttonStyle(.duhaaPress)
            }
            .listRowInsets(EdgeInsets(top: 18, leading: 0, bottom: 18, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
                ManualPrayerTimesView()
            } label: {
                settingsRow("My Prayer Times", icon: "clock.fill", color: Palette.gold, value: store.manualTimes.enabled ? "On" : "Off")
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                AsrMethodSettingsView()
            } label: {
                settingsRow("Madhab", icon: "book.closed.fill", color: Palette.gold, value: store.madhab.shortName)
            }
            .listRowBackground(Palette.card)

            NavigationLink {
                PrayerDisplaySettingsView()
            } label: {
                settingsRow("Home Display", icon: "timer", color: Palette.blue, value: store.nextPrayerDisplayMode.label)
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
                MasjidTimesView()
            } label: {
                settingsRow("Local Masjid", icon: "building.columns.fill", color: Palette.gold, value: masjidSummary)
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
                SalahLockView()
            } label: {
                settingsRow("Salah Lock", icon: "lock.fill", color: Palette.gold, value: salahLock.isArmed ? "On" : "Off")
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

            Button {
                feedbackDraft = FeedbackDraft(reason: .manual, category: .general)
            } label: {
                settingsRow("Send Feedback", icon: "bubble.left.and.bubble.right.fill", color: Palette.blue)
            }
            .buttonStyle(.duhaaPress)
            .listRowBackground(Palette.card)

            ShareLink(item: "Duhaa — a gentle prayer app built on hope, not guilt.") {
                settingsRow("Share the App", icon: "square.and.arrow.up.fill", color: Palette.blue)
            }
            .tint(.primary)   // keep the title white like its neighbours, not accent-gold
            .listRowBackground(Palette.card)

            Button {
                feedbackDraft = FeedbackDraft(reason: .bug, category: .bug)
            } label: {
                settingsRow("Report a Bug", icon: "ladybug.fill", color: .orange)
            }
            .buttonStyle(.duhaaPress)
            .listRowBackground(Palette.card)

            NavigationLink {
                FeedbackPromptSettingsView()
            } label: {
                settingsRow("Feedback Prompts",
                            icon: feedback.automaticPromptsEnabled ? "bell.badge.fill" : "bell.slash.fill",
                            color: Palette.gold,
                            value: feedback.automaticPromptsEnabled ? "On" : "Off")
            }
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

    private var profileHeroCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(settingsAvatarFill)
                    .frame(width: 66, height: 66)
                Text(String(displayName.prefix(1)).uppercased())
                    .duhaaFont(30, .medium)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .duhaaFont(24, .bold)
                    .foregroundStyle(settingsPink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("tap to edit your profile")
                    .duhaaFont(18, .semibold)
                    .foregroundStyle(settingsMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .duhaaFont(23, .bold)
                .foregroundStyle(settingsMutedText.opacity(0.62))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(settingsCardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile, \(displayName), tap to edit your profile")
    }

    private func topMetricCard(icon: String, iconFill: Color, title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(iconFill)
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .duhaaFont(21, .bold)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

                Text(title)
                    .duhaaFont(18, .bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 14)

            Text(value)
                .duhaaFont(24, .bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(detail)
                .duhaaFont(13, .semibold)
                .foregroundStyle(settingsMutedText)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 162, alignment: .leading)
        .padding(16)
        .background(settingsCardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var membershipBenefitsCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(settingsPink)
                    .frame(width: 54, height: 54)
                Image(systemName: "rosette")
                    .duhaaFont(30, .bold)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text("membership benefits")
                .duhaaFont(24, .semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .duhaaFont(23, .bold)
                .foregroundStyle(settingsMutedText.opacity(0.62))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(settingsCardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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

    private var masjidSummary: String {
        guard store.masjid.hasAnyTime else { return "Off" }
        let name = store.masjid.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "On" : name
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

    private var settingsCardFill: Color {
        Palette.active.isDark ? Color.white.opacity(0.105) : Palette.card
    }

    private var settingsHeaderButtonFill: Color {
        Palette.active.isDark ? Color.black.opacity(0.22) : Palette.elevatedCardBackground
    }

    private var settingsMutedText: Color {
        Palette.active.isDark ? Color.white.opacity(0.46) : Palette.secondaryText.opacity(0.78)
    }

    private var settingsPink: Color {
        Palette.active.isDark ? Color(hex: 0xF14F78) : Palette.gold
    }

    private var settingsBlue: Color {
        Palette.active.isDark ? Color(hex: 0x1DA1FF) : Palette.blue
    }

    private var settingsAvatarFill: Color {
        Palette.active.isDark ? Color(hex: 0xAF42C7) : Palette.gold
    }
}

private struct FeedbackDraft: Identifiable {
    let id = UUID()
    let reason: FeedbackPromptReason
    let category: FeedbackCategory
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
