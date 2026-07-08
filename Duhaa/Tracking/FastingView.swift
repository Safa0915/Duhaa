import SwiftUI

/// The Fasting screen — voluntary (Sunnah) fasts and make-up (qaḍāʾ) fasts in one
/// gentle, count-only place. Surfaced from the home's Fasting card and Settings.
/// It only ever celebrates what's done; nothing here scolds.
struct FastingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FastingTracker.self) private var fasting
    @Environment(QadaFasts.self) private var qada
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var settings

    @AppStorage("duhaa.fasting.remindMonThu") private var remindMonThu = false

    private var tz: TimeZone { location.active.timeZone }
    private var offset: Int { settings.hijriOffsetDays }
    private var todayKey: String { PrayerTracker.dayKey(Date(), tz) }

    private var todaysKinds: [VoluntaryFastKind] {
        VoluntaryFast.kinds(for: Date(), timeZone: tz, hijriOffsetDays: offset)
    }

    private var upcoming: [VoluntaryFastDay] {
        VoluntaryFast.upcoming(days: 16, timeZone: tz, hijriOffsetDays: offset)
            .filter { $0.dayKey != todayKey }   // today is shown in its own card
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    todayCard
                    upcomingCard
                    reminderCard
                    qadaCard
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Fasting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
    }

    // MARK: Today

    private var todayCard: some View {
        let recommended = !todaysKinds.isEmpty
        let fastedToday = fasting.isFasted(todayKey)
        return VStack(alignment: .leading, spacing: 12) {
            Label("TODAY", systemImage: "sun.max")
                .duhaaFont(11, .semibold).tracking(1.2)
                .foregroundStyle(Palette.gold)

            if recommended {
                Text(todaysKinds.first?.title ?? "Sunnah fast")
                    .duhaaFont(18, .semibold).foregroundStyle(.primary)
                Text(todaysKinds.first?.reason ?? "")
                    .duhaaFont(13).foregroundStyle(Palette.blue.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No Sunnah fast today")
                    .duhaaFont(16, .medium).foregroundStyle(.primary)
                Text("You can still log a fast any day you keep one.")
                    .duhaaFont(13).foregroundStyle(Palette.blue.opacity(0.8))
            }

            Button {
                fasting.toggle(todayKey)
                DuhaaHaptics.tap()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: fastedToday ? "checkmark.circle.fill" : "circle")
                        .duhaaFont(20)
                        .foregroundStyle(fastedToday ? Palette.gold : Color.primary.opacity(0.3))
                        .symbolEffect(.bounce, value: fastedToday)
                    Text(fastedToday ? "Fasting logged today — taqabbal Allah 🤍" : "I'm fasting today")
                        .duhaaFont(14, .medium).foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    // MARK: Upcoming recommended days

    @ViewBuilder private var upcomingCard: some View {
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("UPCOMING SUNNAH FASTS", systemImage: "calendar")
                    .duhaaFont(11, .semibold).tracking(1.2)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                ForEach(upcoming) { day in
                    HStack(spacing: 12) {
                        Image(systemName: day.primaryKind.icon)
                            .duhaaFont(15).foregroundStyle(Palette.gold.opacity(0.9)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weekdayLine(day.date))
                                .duhaaFont(14, .medium).foregroundStyle(.primary)
                            Text(hijriLine(day.date) + " · " + label(for: day.kinds))
                                .duhaaFont(11).foregroundStyle(Palette.blue.opacity(0.7))
                        }
                        Spacer()
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: Reminders

    private var reminderCard: some View {
        Toggle(isOn: Binding(
            get: { remindMonThu },
            set: { newValue in
                remindMonThu = newValue
                FastingReminders.reschedule(enabled: newValue)
            })) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Monday & Thursday reminders")
                    .duhaaFont(15, .medium).foregroundStyle(.primary)
                Text("A gentle nudge on Sunnah fast mornings.")
                    .duhaaFont(12).foregroundStyle(Palette.blue.opacity(0.7))
            }
        }
        .tint(Palette.gold)
        .cardStyle()
    }

    // MARK: Make-up (qada) fasts

    private var qadaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("MAKE-UP FASTS", systemImage: "arrow.uturn.backward.circle")
                .duhaaFont(11, .semibold).tracking(1.2)
                .foregroundStyle(Palette.gold)
            Text("Days to make up, e.g. from Ramadan. Set how many you owe, then check them off.")
                .duhaaFont(12).foregroundStyle(Palette.blue.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Text("Owed").duhaaFont(15, .medium).foregroundStyle(.primary)
                Spacer()
                Text("\(qada.owed)")
                    .duhaaFont(17, .bold).foregroundStyle(Palette.gold)
                    .monospacedDigit()
                    .frame(minWidth: 28, alignment: .trailing)
                Stepper("Owed fasts", value: Binding(get: { qada.owed }, set: { qada.setOwed($0) }),
                        in: 0...365)
                    .labelsHidden()
                    .fixedSize()
            }

            Button {
                qada.logMakeUp()
                DuhaaHaptics.tap()
            } label: {
                Text("I made up a fast")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(qada.owed > 0 ? Palette.onAccent : Color.primary.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(qada.owed > 0 ? Palette.gold : Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(qada.owed == 0)

            if qada.completed > 0 {
                HStack {
                    Text("Made up so far: \(qada.completed) 🤍")
                        .duhaaFont(12).foregroundStyle(Palette.blue.opacity(0.8))
                    Spacer()
                    Button("Undo") { qada.undoMakeUp() }
                        .duhaaFont(12, .medium).foregroundStyle(Palette.gold)
                        .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private var footer: some View {
        Text("Duhaa counts only the fasts you keep — never what you've missed. 🤍")
            .duhaaFont(12)
            .foregroundStyle(Palette.blue.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.top, 4)
    }

    // MARK: Formatting

    private func weekdayLine(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = tz
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private func hijriLine(_ date: Date) -> String {
        HijriCalendar.string(date, timeZone: tz, offsetDays: offset, format: "d MMM") + " AH"
    }

    private func label(for kinds: [VoluntaryFastKind]) -> String {
        kinds.map { kind in
            switch kind {
            case .monday:   return "Monday"
            case .thursday: return "Thursday"
            case .whiteDay: return "White day"
            }
        }.joined(separator: " · ")
    }
}

private extension View {
    /// The shared rounded card chrome used across the Fasting screen.
    func cardStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
