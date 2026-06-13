import SwiftUI

/// The Sisters' space: gentle education on salah & wudu, and private period
/// logging that keeps the prayer streak safe during menstruation.
struct SistersView: View {
    @Environment(CycleTracker.self) private var cycle
    @Environment(LocationProvider.self) private var location
    @AppStorage("duhaa.cycle.periodTrackingEnabled") private var periodTrackingEnabled = true
    @AppStorage("duhaa.cycle.periodPredictionEnabled") private var periodPredictionEnabled = true
    @AppStorage("duhaa.cycle.ghuslReminderEnabled") private var ghuslReminderEnabled = true
    @AppStorage("duhaa.cycle.missedFastReminderEnabled") private var missedFastReminderEnabled = false
    @AppStorage("duhaa.cycle.fertileWindowEnabled") private var fertileWindowEnabled = false
    @AppStorage("duhaa.cycle.phaseChangeEnabled") private var phaseChangeEnabled = false

    private var today: String { PrayerTracker.dayKey(Date(), location.active.timeZone) }

    var body: some View {
        // No NavigationStack here — the host (MainTabView or MoreView) provides one,
        // so opening Sisters from "More" gets a proper "‹ More" back button.
        List {
            introSection
            cycleSection
            if periodTrackingEnabled { cycleHelpersSection }
            if !cycle.entries.isEmpty { historySection }
            learnSection
            disclaimerSection
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Sisters")
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
    }

    // MARK: Intro

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("A space for you", systemImage: "leaf.fill")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
                Text("Rest when you need to, learn at your own pace, and know your streak is always safe. 🤍")
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.8))
            }
            .padding(.vertical, 4)
            .listRowBackground(Palette.card)
        }
    }

    // MARK: Cycle

    private var cycleSection: some View {
        Section {
            if !periodTrackingEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Period tracking is off", systemImage: "pause.circle.fill")
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(Palette.gold)
                    Text("You can turn it back on in Settings → Cycle.")
                        .duhaaFont(13)
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card)
            } else if let ongoing = cycle.ongoing {
                VStack(alignment: .leading, spacing: 6) {
                    Label("On your period", systemImage: "drop.fill")
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(Palette.gold)
                    Text("Since \(display(ongoing.start)). Prayer and fasting are lifted now — rest, and your streak stays safe. 🤍")
                        .duhaaFont(13)
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card)

                Button {
                    cycle.endPeriod(today: today)
                    DuhaaHaptics.tap()   // a quiet acknowledgment, deliberately not "success"
                } label: {
                    Label("My period has ended", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.gold)
                }
                .listRowBackground(Palette.card)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No period logged right now.")
                        .duhaaFont(14)
                        .foregroundStyle(.primary.opacity(0.85))
                    if periodPredictionEnabled, let next = cycle.predictedNextStart() {
                        Text("Next one around \(display(next)) — just an estimate from your history.")
                            .duhaaFont(12)
                            .foregroundStyle(Palette.blue.opacity(0.75))
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card)

                Button {
                    cycle.startPeriod(today: today)
                    DuhaaHaptics.tap()
                } label: {
                    Label("Log period start (today)", systemImage: "plus.circle.fill")
                        .foregroundStyle(Palette.gold)
                }
                .listRowBackground(Palette.card)
            }
        } header: {
            Text("Your cycle")
        } footer: {
            Text("Private and stored only on this device. During logged days, Duhaa marks your prayers as excused — your streak is never broken.")
        }
    }

    private var historySection: some View {
        Section("Past entries") {
            ForEach(cycle.entries) { entry in
                HStack {
                    Image(systemName: "drop.fill")
                        .duhaaFont(12).foregroundStyle(Palette.gold.opacity(0.8))
                    Text(rangeText(entry)).duhaaFont(14).foregroundStyle(.primary)
                    Spacer()
                    if entry.end == nil {
                        Text("ongoing").duhaaFont(12, .semibold).foregroundStyle(Palette.gold)
                    }
                }
                .listRowBackground(Palette.card)
            }
            .onDelete { offsets in
                offsets.map { cycle.entries[$0] }.forEach(cycle.delete)
            }
        }
    }

    private var cycleHelpersSection: some View {
        Section("Cycle helpers") {
            if ghuslReminderEnabled {
                helperRow("drop.fill", "Ghusl reminder", ghuslReminderText)
            }

            if missedFastReminderEnabled {
                helperRow("moon.fill", "Missed fast reminder", missedFastText)
            }

            if phaseChangeEnabled {
                helperRow("arrow.triangle.2.circlepath", "Phase change", phaseChangeText)
            }

            if fertileWindowEnabled {
                helperRow("heart.fill", "Fertile window", fertileWindowText)
            }

            if !ghuslReminderEnabled && !missedFastReminderEnabled && !phaseChangeEnabled && !fertileWindowEnabled {
                Text("Turn on helpers in Settings → Cycle.")
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.72))
                    .listRowBackground(Palette.card)
            }
        }
    }

    // MARK: Learn

    private var learnSection: some View {
        Section("Learn — Salah & Wudu") {
            ForEach(SistersContent.topics) { topic in
                NavigationLink {
                    SistersQAView(topic: topic)
                } label: {
                    Label(topic.name, systemImage: topic.icon)
                        .duhaaFont(15)
                }
                .listRowBackground(Palette.card)
            }
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text(SistersContent.disclaimer)
                .duhaaFont(11)
                .foregroundStyle(.secondary)
        }
    }

    private func helperRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .duhaaFont(15, .semibold)
                .foregroundStyle(Palette.gold)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .duhaaFont(14, .semibold)
                    .foregroundStyle(.primary)
                Text(detail)
                    .duhaaFont(12)
                    .foregroundStyle(.primary.opacity(0.72))
            }
        }
        .padding(.vertical, 3)
        .listRowBackground(Palette.card)
    }

    private var ghuslReminderText: String {
        if cycle.ongoing != nil {
            return "When your period ends, mark it here; Duhaa will remind you to make ghusl before returning to prayer."
        }
        if let latest = cycle.entries.first, let end = latest.end {
            return "Last period ended \(display(end)). If you have not made ghusl yet, take care of it before praying."
        }
        return "When you end a logged period, this helper shows the ghusl reminder here."
    }

    private var missedFastText: String {
        if cycle.entries.isEmpty {
            return "Logged period days will help you remember fasting days to make up after Ramadan."
        }
        let excusedDays = cycle.entries.reduce(0) { total, entry in
            total + dayCount(from: entry.start, to: entry.end ?? today)
        }
        return "\(excusedDays) logged excused day\(excusedDays == 1 ? "" : "s"). Use this as a private reminder when making up missed Ramadan fasts."
    }

    private var phaseChangeText: String {
        guard let start = currentCycleStart else {
            return "Log a period start to see simple cycle-day changes here."
        }
        let day = dayCount(from: start, to: today)
        return "Cycle day \(max(day, 1)). This is an estimate from your own logs, not medical advice."
    }

    private var fertileWindowText: String {
        guard periodPredictionEnabled, let next = cycle.predictedNextStart(), let nextDate = Self.parser.date(from: next) else {
            return "Add more cycle history and keep prediction on to estimate this window."
        }
        let start = Self.display.string(from: Calendar(identifier: .gregorian).date(byAdding: .day, value: -19, to: nextDate) ?? nextDate)
        let end = Self.display.string(from: Calendar(identifier: .gregorian).date(byAdding: .day, value: -14, to: nextDate) ?? nextDate)
        return "Estimated around \(start)–\(end), based on your predicted next period."
    }

    private var currentCycleStart: String? {
        if let ongoing = cycle.ongoing { return ongoing.start }
        return cycle.entries.first?.start
    }

    private func dayCount(from startKey: String, to endKey: String) -> Int {
        guard let start = Self.parser.date(from: startKey),
              let end = Self.parser.date(from: endKey) else { return 0 }
        let days = Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 1)
    }

    // MARK: Date helpers

    private func display(_ key: String) -> String {
        guard let date = Self.parser.date(from: key) else { return key }
        return Self.display.string(from: date)
    }

    private func rangeText(_ entry: CycleEntry) -> String {
        if let end = entry.end { return "\(display(entry.start)) – \(display(end))" }
        return "\(display(entry.start)) – now"
    }

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "d MMM"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

/// A topic's Q&A as expandable cards.
struct SistersQAView: View {
    let topic: SistersTopic

    var body: some View {
        List {
            ForEach(topic.items) { item in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.a)
                            .duhaaFont(14)
                            .foregroundStyle(.primary.opacity(0.85))
                        Text(item.source)
                            .duhaaFont(11, italic: true)
                            .foregroundStyle(Palette.blue.opacity(0.7))
                    }
                    .padding(.vertical, 6)
                } label: {
                    Text(item.q)
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(.primary)
                }
                .tint(Palette.gold)
                .listRowBackground(Palette.card)
            }

            // The rulings live on this screen, so the reader sees the caveat
            // here too — not only back on the Sisters page.
            Section {
                Text(SistersContent.disclaimer)
                    .duhaaFont(11)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
