import SwiftUI
import FamilyControls

/// Settings screen for **Salah Lock** — opt-in app blocking around each prayer,
/// framed gently: a quiet space to pray, lifted the instant the prayer is logged.
///
/// Mirrors the rest of Settings (Form + `settingsDetailStyle`). When Screen Time
/// isn't authorized yet, only the master row + the access prompt show; the app
/// picker and timing appear once permission is granted.
struct SalahLockView: View {
    @Environment(SalahLockController.self) private var lock
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @State private var pickerSelection = FamilyActivitySelection()
    @State private var showingPicker = false

    var body: some View {
        Form {
            masterSection
            accessSection
            if lock.isAuthorized {
                appsSection
                windowSection
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(ThemeDecorativeBackground())
        .navigationTitle("Salah Lock")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
        .familyActivityPicker(isPresented: $showingPicker, selection: $pickerSelection)
        .onChange(of: pickerSelection) { _, newValue in
            lock.updateSelection(newValue)
        }
        .onAppear {
            pickerSelection = lock.selection
            lock.refreshAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { lock.refreshAuthorization() }
        }
    }

    // MARK: Master toggle

    private var masterSection: some View {
        Section {
            Toggle(isOn: enabledBinding) {
                HStack(spacing: 12) {
                    SettingsLockIcon(systemName: "lock.fill", color: Palette.gold)
                    Text("Salah Lock")
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(.primary)
                }
            }
            .tint(Palette.gold)
            .listRowBackground(Palette.card)
        } footer: {
            Text("Salah Lock gently pauses the apps you choose when a prayer comes in — and lifts the moment you mark that prayer prayed. A quiet space to turn to Allah, never a punishment.")
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { lock.isEnabled },
            set: { newValue in
                guard newValue else { lock.setEnabled(false); return }
                if lock.isAuthorized {
                    lock.setEnabled(true)
                } else {
                    Task {
                        await lock.requestAuthorization()
                        if lock.isAuthorized { lock.setEnabled(true) }
                    }
                }
            }
        )
    }

    // MARK: Screen Time access

    private var accessSection: some View {
        Section {
            HStack(spacing: 12) {
                SettingsLockIcon(systemName: "hourglass", color: Palette.blue)
                Text("Screen Time Access")
                    .duhaaFont(16, .semibold)
                    .foregroundStyle(.primary)
                Spacer(minLength: 10)
                Text(statusText)
                    .duhaaFont(14, .medium)
                    .foregroundStyle(statusColor)
            }
            .listRowBackground(Palette.card)

            if !lock.isAuthorized {
                Button(action: handleAccessTap) {
                    HStack(spacing: 12) {
                        SettingsLockIcon(systemName: "checkmark.shield.fill", color: Palette.success)
                        Text(lock.authorizationStatus == .denied ? "Open Screen Time Settings" : "Allow Screen Time Access")
                            .duhaaFont(16, .semibold)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 10)
                        Image(systemName: "chevron.right")
                            .duhaaFont(13, .bold)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.duhaaPress)
                .listRowBackground(Palette.card)
            }
        } footer: {
            Text("Duhaa needs Screen Time permission to pause apps during prayer windows. Your app choices and schedule stay on your device — Duhaa has no servers and no analytics.")
        }
    }

    private var statusText: String {
        switch lock.authorizationStatus {
        case .approved: return "Allowed"
        case .denied:   return "Not allowed"
        default:        return "Not set"
        }
    }

    private var statusColor: Color {
        switch lock.authorizationStatus {
        case .approved: return Palette.success
        case .denied:   return Palette.warning
        default:        return .secondary
        }
    }

    private func handleAccessTap() {
        if lock.authorizationStatus == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        } else {
            Task { await lock.requestAuthorization() }
        }
    }

    // MARK: Apps to block

    private var appsSection: some View {
        Section {
            Button { showingPicker = true } label: {
                HStack(spacing: 12) {
                    SettingsLockIcon(systemName: "apps.iphone", color: Palette.gold)
                    Text("Apps to Pause")
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 10)
                    Text(lock.selectedCount == 0 ? "None chosen" : "\(lock.selectedCount) selected")
                        .duhaaFont(14, .medium)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .duhaaFont(13, .bold)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.duhaaPress)
            .listRowBackground(Palette.card)
        } header: {
            Text("Apps to Pause")
        } footer: {
            Text("Pick the apps and categories that pull you away. They'll be paused during prayer windows only — everything else stays open.")
        }
    }

    // MARK: Window length

    private var windowSection: some View {
        Section {
            Stepper(value: capBinding, in: SalahLock.minCapMinutes...SalahLock.maxCapMinutes, step: 5) {
                HStack(spacing: 12) {
                    SettingsLockIcon(systemName: "timer", color: Palette.blue)
                    Text("Lift after at most")
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 10)
                    Text("\(lock.capMinutes) min")
                        .duhaaFont(14, .medium)
                        .foregroundStyle(Palette.gold)
                }
            }
            .listRowBackground(Palette.card)
        } header: {
            Text("How Long")
        } footer: {
            Text("The lock lifts as soon as you mark the prayer prayed. This is only a safety cap, so it never holds longer than you'd want — and praying early (before the adhan) means it won't lock at all.")
        }
    }

    private var capBinding: Binding<Int> {
        Binding(get: { lock.capMinutes }, set: { lock.capMinutes = $0 })
    }
}

/// Small rounded icon chip, matching the Settings list rows.
private struct SettingsLockIcon: View {
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
