import SwiftUI

/// First-launch onboarding (spec §7): Welcome → Location → Method/Madhab.
/// No account, no email, under a minute. Calls `onFinish` to enter the app.
/// (Later, the Duha cinematic in Slice 10 will play before this.)
struct OnboardingView: View {
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var settings
    let onFinish: () -> Void

    @State private var step = 0
    @State private var showingCitySearch = false

    var body: some View {
        ZStack {
            CelestialBackground()

            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0:  welcome
                    case 1:  locationStep
                    default: methodStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .id(step)

                stepDots
                continueButton
            }
            .padding(.bottom, 30)
        }
        .preferredColorScheme(.dark)
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
                    .font(.system(size: 58))
                    .foregroundStyle(Palette.gold)
            }
            Text("ضحى")
                .font(.system(size: 60))
                .foregroundStyle(Palette.gold)
            Text("Welcome to Duha")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
            Text("Duha means “the morning brightness.”\nA gentle return to prayer — built on hope, never guilt.")
                .font(.system(size: 15))
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
                .font(.system(size: 54))
                .foregroundStyle(Palette.blue)
            Text("Where are you?")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
            Text("So Duha can show accurate prayer times for your place.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.blue.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)

            HStack(spacing: 8) {
                Image(systemName: location.active.isManual ? "mappin.circle.fill" : "location.fill")
                    .foregroundStyle(Palette.gold)
                Text(location.active.name).foregroundStyle(.white)
                if location.isLocating { ProgressView().tint(Palette.gold).scaleEffect(0.8) }
            }
            .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 46))
                .foregroundStyle(Palette.gold)
            Text("Calculation")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
            Text("You can change these anytime in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.blue.opacity(0.7))

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("METHOD")
                Menu {
                    Picker("Method", selection: methodBinding) {
                        ForEach(CalcMethod.allCases) { Text($0.displayName).tag($0) }
                    }
                } label: {
                    HStack {
                        Text(settings.method.displayName).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12)).foregroundStyle(Palette.blue)
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

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Palette.gold : Color.white.opacity(0.2))
                    .frame(width: i == step ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.3), value: step)
        .padding(.bottom, 20)
    }

    private var continueButton: some View {
        Button {
            if step < 2 { withAnimation { step += 1 } } else { onFinish() }
        } label: {
            Text(step < 2 ? "Continue" : "Get Started")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.appBg)
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold)).tracking(1)
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
}
