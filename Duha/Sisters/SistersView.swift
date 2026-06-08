import SwiftUI

/// The Sisters' space: gentle education on salah & wudu, and private period
/// logging that keeps the prayer streak safe during menstruation.
struct SistersView: View {
    @Environment(CycleTracker.self) private var cycle
    @Environment(LocationProvider.self) private var location

    private var today: String { PrayerTracker.dayKey(Date(), location.active.timeZone) }

    var body: some View {
        NavigationStack {
            List {
                introSection
                cycleSection
                if !cycle.entries.isEmpty { historySection }
                learnSection
                disclaimerSection
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Sisters")
            .tint(Palette.gold)
        }
        .preferredColorScheme(Palette.active.colorScheme)
    }

    // MARK: Intro

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("A space for you", systemImage: "leaf.fill")
                    .duhaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
                Text("Rest when you need to, learn at your own pace, and know your streak is always safe. 🤍")
                    .duhaFont(13)
                    .foregroundStyle(.primary.opacity(0.8))
            }
            .padding(.vertical, 4)
            .listRowBackground(Palette.card)
        }
    }

    // MARK: Cycle

    private var cycleSection: some View {
        Section {
            if let ongoing = cycle.ongoing {
                VStack(alignment: .leading, spacing: 6) {
                    Label("On your period", systemImage: "drop.fill")
                        .duhaFont(15, .semibold)
                        .foregroundStyle(Palette.gold)
                    Text("Since \(display(ongoing.start)). Prayer and fasting are lifted now — rest, and your streak stays safe. 🤍")
                        .duhaFont(13)
                        .foregroundStyle(.primary.opacity(0.8))
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card)

                Button {
                    cycle.endPeriod(today: today)
                } label: {
                    Label("My period has ended", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.gold)
                }
                .listRowBackground(Palette.card)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No period logged right now.")
                        .duhaFont(14)
                        .foregroundStyle(.primary.opacity(0.85))
                    if let next = cycle.predictedNextStart() {
                        Text("Next one around \(display(next)) — just an estimate from your history.")
                            .duhaFont(12)
                            .foregroundStyle(Palette.blue.opacity(0.75))
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card)

                Button {
                    cycle.startPeriod(today: today)
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
                        .duhaFont(12).foregroundStyle(Palette.gold.opacity(0.8))
                    Text(rangeText(entry)).duhaFont(14).foregroundStyle(.primary)
                    Spacer()
                    if entry.end == nil {
                        Text("ongoing").duhaFont(12, .semibold).foregroundStyle(Palette.gold)
                    }
                }
                .listRowBackground(Palette.card)
            }
            .onDelete { offsets in
                offsets.map { cycle.entries[$0] }.forEach(cycle.delete)
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
                        .duhaFont(15)
                }
                .listRowBackground(Palette.card)
            }
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text(SistersContent.disclaimer)
                .duhaFont(11)
                .foregroundStyle(.secondary)
        }
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
                            .duhaFont(14)
                            .foregroundStyle(.primary.opacity(0.85))
                        Text(item.source)
                            .duhaFont(11, italic: true)
                            .foregroundStyle(Palette.blue.opacity(0.7))
                    }
                    .padding(.vertical, 6)
                } label: {
                    Text(item.q)
                        .duhaFont(15, .semibold)
                        .foregroundStyle(.primary)
                }
                .tint(Palette.gold)
                .listRowBackground(Palette.card)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
