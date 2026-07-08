import SwiftUI

/// First-launch onboarding (spec §7): Welcome → Location → Method/Madhab.
/// No account, no email, under a minute. Calls `onFinish` to enter the app.
/// DuhaaApp gates this behind the first-launch opening moment.
struct OnboardingView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var settings
    @Environment(InsightsStore.self) private var insights
    let onFinish: () -> Void

    @State private var step = 0
    @State private var showingCitySearch = false

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 0) {
                GeometryReader { proxy in
                    ScrollView {
                        Group {
                            switch step {
                            case 0:  welcome
                            case 1:  locationStep
                            case 2:  methodStep
                            default: insightsStep
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                        .transition(.opacity)
                        .id(step)
                    }
                    .scrollIndicators(.hidden)
                }

                stepDots
                continueButton
            }
            .padding(.bottom, 30)
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .sheet(isPresented: $showingCitySearch) { LocationPickerView() }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.gold.opacity(0.35), .clear],
                                         center: .center, startRadius: 0, endRadius: 75))
                    .frame(width: 150, height: 150)
                Image(systemName: "moon.stars.fill")
                    .duhaaFont(58)
                    .foregroundStyle(Palette.gold)
            }
            Text("ضحى")
                .duhaaFont(60)
                .foregroundStyle(Palette.gold)
            Text("Welcome to Duhaa")
                .duhaaFont(26, .semibold)
                .foregroundStyle(.primary)
            Text("Duhaa means “the morning brightness.”\nA gentle return to prayer — built on hope, never guilt.")
                .duhaaFont(15)
                .foregroundStyle(Palette.blue.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 44)
            Spacer()
        }
    }

    private var locationStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .duhaaFont(54)
                .foregroundStyle(Palette.blue)
            Text("Where are you?")
                .duhaaFont(24, .semibold)
                .foregroundStyle(.primary)
            Text("So Duhaa can show accurate prayer times for your place.")
                .duhaaFont(14)
                .foregroundStyle(Palette.blue.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)

            HStack(spacing: 8) {
                Image(systemName: location.active.isManual ? "mappin.circle.fill" : "location.fill")
                    .foregroundStyle(Palette.gold)
                Text(location.active.name).foregroundStyle(.primary)
                if location.isLocating { ProgressView().tint(Palette.gold).scaleEffect(0.8) }
            }
            .duhaaFont(14, .medium)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Palette.card).clipShape(Capsule())
            .padding(.top, 4)

            VStack(spacing: 12) {
                pillButton("Use My Location", "location.fill", color: Palette.gold) {
                    location.useCurrentLocation()
                }
                pillButton("Search for a city", "magnifyingglass", color: Palette.blue) {
                    showingCitySearch = true
                }
            }
            .padding(.horizontal, 44).padding(.top, 8)
            Spacer()
        }
    }

    private var methodStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "slider.horizontal.3")
                .duhaaFont(46)
                .foregroundStyle(Palette.gold)
            Text("Calculation")
                .duhaaFont(24, .semibold)
                .foregroundStyle(.primary)
            Text("You can change these anytime in Settings.")
                .duhaaFont(13)
                .foregroundStyle(Palette.blue.opacity(0.7))

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("METHOD")
                Menu {
                    Picker("Method", selection: methodBinding) {
                        ForEach(CalcMethod.allCases) { Text($0.displayName).tag($0) }
                    }
                } label: {
                    HStack {
                        Text(settings.method.displayName).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .duhaaFont(12).foregroundStyle(Palette.blue)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                fieldLabel("ASR (AFTERNOON)").padding(.top, 8)
                Picker("Asr", selection: madhabBinding) {
                    ForEach(AsrMadhab.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 32).padding(.top, 6)
            Spacer()
        }
    }

    // MARK: Pieces

    private var insightsStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .duhaaFont(46)
                .foregroundStyle(Palette.gold)
            Text("See your progress?")
                .duhaaFont(24, .semibold)
                .foregroundStyle(.primary)
            Text("Duhaa can gently show how many prayers you've kept on time, prayed late, or missed — a quiet mirror to help you grow. It only ever encourages, never shames.")
                .duhaaFont(14)
                .foregroundStyle(Palette.blue.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 36)

            Toggle(isOn: insightsBinding) {
                Text("Show prayer insights")
                    .duhaaFont(15, .medium)
                    .foregroundStyle(.primary)
            }
            .tint(Palette.gold)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 36).padding(.top, 6)

            Text("Off by default · change it anytime in Settings.")
                .duhaaFont(12)
                .foregroundStyle(Palette.blue.opacity(0.6))
            Spacer()
        }
    }

    private var insightsBinding: Binding<Bool> {
        Binding(
            get: { insights.enabled },
            set: { insights.setEnabled($0, today: PrayerTracker.dayKey(Date(), location.active.timeZone)) }
        )
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Palette.gold : Color.primary.opacity(0.2))
                    .frame(width: i == step ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.3), value: step)
        .padding(.bottom, 20)
    }

    private var continueButton: some View {
        Button {
            if step < 3 {
                withAnimation { step += 1 }
            } else {
                DuhaaHaptics.success()   // crossing the threshold into the app
                onFinish()
            }
        } label: {
            Text(step < 3 ? "Continue" : "Get Started")
                .duhaaFont(17, .semibold)
                .foregroundStyle(Palette.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Palette.gold)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 32)
    }

    private func pillButton(_ title: String, _ icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .duhaaFont(15, .medium)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .duhaaFont(11, .semibold).tracking(1)
            .foregroundStyle(Palette.blue.opacity(0.6))
    }

    private var methodBinding: Binding<CalcMethod> {
        Binding(get: { settings.method }, set: { settings.method = $0 })
    }
    private var madhabBinding: Binding<AsrMadhab> {
        Binding(get: { settings.madhab }, set: { settings.madhab = $0 })
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environment(LocationProvider())
        .environment(SettingsStore())
        .environment(InsightsStore())
}
