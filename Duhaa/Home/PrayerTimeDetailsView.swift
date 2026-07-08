import SwiftUI

/// A small trust surface for prayer times: explains the inputs behind the current
/// times and gives a one-tap path to adjust or report them.
struct PrayerTimeDetailsView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var settings
    @Environment(FeedbackStore.self) private var feedback
    @Environment(\.dismiss) private var dismiss

    @State private var showingReportComposer = false

    private var isHighLatitude: Bool {
        abs(location.active.latitude) > 48
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    detailRow("Location", location.active.name)
                    detailRow("Timezone", location.active.timeZoneID)
                    detailRow("Source", location.active.isManual ? "Manual city" : "Current location")
                } header: {
                    Text("Place")
                }

                Section {
                    detailRow("Method", settings.method.displayName)
                    detailRow("Asr", settings.madhab.label)
                    detailRow("High latitude rule", "Middle of Night")
                    detailRow("Time adjustments", offsetsSummary)
                } header: {
                    Text("Calculation")
                } footer: {
                    Text("Prayer times are calculated estimates. Compare with a trusted local mosque when precision matters.")
                }

                Section {
                    detailRow("Manual timetable", settings.manualTimes.enabled ? "On" : "Off")
                    detailRow("Local masjid", masjidSummary)
                } header: {
                    Text("Local Overrides")
                } footer: {
                    Text(settings.manualTimes.enabled
                         ? "Your manual timetable replaces calculated adhan times everywhere, including notifications and widgets."
                         : "Manual timetable and local masjid times are optional. Masjid times appear beside calculated adhan times.")
                }

                if isHighLatitude {
                    Section {
                        Label("Fajr and Isha can be approximate at this latitude. Finish suhoor a little early, give Isha a few minutes, and re-check with a trusted local mosque each season.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.gold)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowBackground(Palette.card)
                    } header: {
                        Text("High Latitude Caution")
                    }
                }

                Section {
                    NavigationLink {
                        if settings.manualTimes.enabled {
                            ManualPrayerTimesView()
                        } else {
                            PrayerTimeAdjustmentsView()
                        }
                    } label: {
                        Label(settings.manualTimes.enabled ? "Edit manual timetable" : "Adjust times",
                              systemImage: "clock.badge.fill")
                            .foregroundStyle(Palette.gold)
                    }
                    .listRowBackground(Palette.card)

                    Button {
                        showingReportComposer = true
                    } label: {
                        Label("Report wrong prayer time", systemImage: "bubble.left.and.bubble.right.fill")
                            .foregroundStyle(Palette.blue)
                    }
                    .listRowBackground(Palette.card)
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(ThemeDecorativeBackground())
            .navigationTitle("Prayer Time Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .sheet(isPresented: $showingReportComposer) {
            FeedbackComposerView(
                reason: .manual,
                initialCategory: .prayerTimes,
                initialMessage: reportDraft,
                onClose: { showingReportComposer = false },
                onSubmitted: {
                    feedback.recordFeedbackStarted()
                    showingReportComposer = false
                }
            )
            .presentationDetents([.large])
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(Palette.blue)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .listRowBackground(Palette.card)
    }

    private var offsetsSummary: String {
        let offsets = settings.offsets
        let rows: [(String, Int)] = [
            ("Fajr", offsets.fajr),
            ("Sunrise", offsets.sunrise),
            ("Dhuhr", offsets.dhuhr),
            ("Asr", offsets.asr),
            ("Maghrib", offsets.maghrib),
            ("Isha", offsets.isha)
        ]
        let changed = rows.filter { $0.1 != 0 }
        guard !changed.isEmpty else { return "None" }
        return changed.map { "\($0.0) \(signed($0.1)) min" }.joined(separator: ", ")
    }

    private var masjidSummary: String {
        guard settings.masjid.hasAnyTime else { return "None" }
        let name = settings.masjid.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Times entered" : name
    }

    private var reportDraft: String {
        [
            "I think a prayer time may be wrong. Please check these settings:",
            "",
            "Location: \(location.active.name)",
            "Timezone: \(location.active.timeZoneID)",
            "Location source: \(location.active.isManual ? "Manual city" : "Current location")",
            "Calculation method: \(settings.method.displayName)",
            "Asr method: \(settings.madhab.label)",
            "High latitude caution: \(isHighLatitude ? "Yes" : "No")",
            "Manual timetable: \(settings.manualTimes.enabled ? "On" : "Off")",
            "Time adjustments: \(offsetsSummary)",
            "Local masjid: \(masjidSummary)",
            "",
            "What I expected:",
            "",
            "What Duhaa showed:"
        ].joined(separator: "\n")
    }

    private func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
}

struct PrayerTimeDetailsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "questionmark.circle.fill")
                    .duhaaFont(18, .semibold)
                    .foregroundStyle(Palette.gold)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Why these prayer times?")
                        .duhaaFont(14, .semibold)
                        .foregroundStyle(.primary)
                    Text("See method, location, offsets, and report a wrong time.")
                        .duhaaFont(12)
                        .foregroundStyle(Palette.blue.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .duhaaFont(11, .semibold)
                    .foregroundStyle(Palette.blue.opacity(0.55))
            }
            .padding(14)
            .background(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Why these prayer times? See calculation details or report a wrong prayer time.")
    }
}
