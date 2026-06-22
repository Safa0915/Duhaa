import SwiftUI
import UIKit

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case general
    case prayerTimes
    case quran
    case widgets
    case bug
    case idea

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .prayerTimes: return "Prayer times"
        case .quran: return "Quran"
        case .widgets: return "Widgets"
        case .bug: return "Bug"
        case .idea: return "Idea"
        }
    }
}

struct FeedbackPromptView: View {
    let reason: FeedbackPromptReason
    let onGiveFeedback: () -> Void
    let onNotNow: () -> Void
    let onNeverAskAgain: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Palette.secondaryText.opacity(0.25))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            ZStack {
                Circle()
                    .fill(Palette.gold.opacity(0.18))
                    .frame(width: 62, height: 62)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .duhaaFont(26, .semibold)
                    .foregroundStyle(Palette.gold)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text(reason.promptTitle)
                    .duhaaFont(24, .bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(reason.promptMessage)
                    .duhaaFont(14)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button(action: onGiveFeedback) {
                    Label("Give feedback", systemImage: "paperplane.fill")
                        .duhaaFont(16, .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.onAccent)
                .background(Palette.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button(action: onNotNow) {
                    Text("Not now")
                        .duhaaFont(15, .semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.blue)

                Button(action: onNeverAskAgain) {
                    Text("Don’t ask again")
                        .duhaaFont(13, .medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondaryText)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.background.ignoresSafeArea())
        .preferredColorScheme(Palette.active.colorScheme)
    }
}

struct FeedbackComposerView: View {
    let reason: FeedbackPromptReason
    let initialCategory: FeedbackCategory
    let onClose: () -> Void
    let onSubmitted: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var category: FeedbackCategory
    @State private var message = ""
    @State private var contact = ""
    @State private var includeDiagnostics = true
    @State private var showingMailError = false

    init(reason: FeedbackPromptReason,
         initialCategory: FeedbackCategory = .general,
         onClose: @escaping () -> Void,
         onSubmitted: @escaping () -> Void) {
        self.reason = reason
        self.initialCategory = initialCategory
        self.onClose = onClose
        self.onSubmitted = onSubmitted
        _category = State(initialValue: initialCategory)
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContact: String {
        contact.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Topic", selection: $category) {
                        ForEach(FeedbackCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Palette.gold)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                            .textInputAutocapitalization(.sentences)

                        if message.isEmpty {
                            Text("What should feel better in Duhaa?")
                                .foregroundStyle(Palette.secondaryText.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("This opens your email app with the message filled in, so you can review it before sending.")
                }

                Section {
                    TextField("Email or name (optional)", text: $contact)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    Toggle("Include app and device details", isOn: $includeDiagnostics)
                        .tint(Palette.gold)
                } footer: {
                    Text("Device details help debug issues. Your prayer data is not attached.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(reason == .bug ? "Report a Bug" : "Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendFeedback()
                    }
                    .disabled(trimmedMessage.isEmpty)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .alert("Couldn’t open email", isPresented: $showingMailError) {
            Button("Copy Email") {
                UIPasteboard.general.string = FeedbackStore.recipientEmail
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can email \(FeedbackStore.recipientEmail) directly. Your draft is still here.")
        }
    }

    private func sendFeedback() {
        guard let url = feedbackURL else { return }
        openURL(url) { accepted in
            if accepted {
                onSubmitted()
            } else {
                showingMailError = true
            }
        }
    }

    private var feedbackURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = FeedbackStore.recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: emailBody)
        ]
        return components.url
    }

    private var subject: String {
        switch reason {
        case .bug:
            return "Duhaa Bug Report"
        default:
            return "Duhaa Feedback - \(category.label)"
        }
    }

    private var emailBody: String {
        var lines = [
            trimmedMessage,
            "",
            "Topic: \(category.label)"
        ]

        if !trimmedContact.isEmpty {
            lines.append("Contact: \(trimmedContact)")
        }

        if includeDiagnostics {
            lines.append("")
            lines.append("App: \(appVersion) (\(buildNumber))")
            lines.append("Device: \(UIDevice.current.model)")
            lines.append("System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        }

        return lines.joined(separator: "\n")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

struct FeedbackPromptSettingsView: View {
    @Environment(FeedbackStore.self) private var feedback

    var body: some View {
        Form {
            Section {
                Toggle("Occasional prompts", isOn: automaticPromptsBinding)
                    .tint(Palette.gold)
                    .listRowBackground(Palette.card)
            } footer: {
                Text("Duhaa may gently ask for feedback after a few app opens or meaningful actions. Turning this off never removes the manual feedback button.")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .background(ThemeDecorativeBackground())
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
    }

    private var automaticPromptsBinding: Binding<Bool> {
        Binding(
            get: { feedback.automaticPromptsEnabled },
            set: { feedback.setAutomaticPromptsEnabled($0) }
        )
    }
}

private struct FeedbackPresentationModifier: ViewModifier {
    let feedback: FeedbackStore

    private var presentation: Binding<FeedbackStore.Presentation?> {
        Binding(
            get: { feedback.presentation },
            set: { feedback.presentation = $0 }
        )
    }

    func body(content: Content) -> some View {
        content
            .sheet(item: presentation) { presentation in
                switch presentation {
                case .prompt(let reason):
                    FeedbackPromptView(
                        reason: reason,
                        onGiveFeedback: { feedback.startFeedbackFromPrompt(reason: reason) },
                        onNotNow: { feedback.dismissPrompt() },
                        onNeverAskAgain: { feedback.disableAutomaticPrompts() }
                    )
                    .presentationDetents([.medium])
                case .composer(let reason):
                    FeedbackComposerView(
                        reason: reason,
                        initialCategory: category(for: reason),
                        onClose: { feedback.closePresentation() },
                        onSubmitted: { feedback.recordFeedbackStarted() }
                    )
                    .presentationDetents([.large])
                }
            }
    }

    private func category(for reason: FeedbackPromptReason) -> FeedbackCategory {
        switch reason {
        case .appOpen, .manual:
            return .general
        case .prayerMarked:
            return .prayerTimes
        case .quranRead:
            return .quran
        case .bug:
            return .bug
        }
    }
}

extension View {
    func feedbackPresentation(_ feedback: FeedbackStore) -> some View {
        modifier(FeedbackPresentationModifier(feedback: feedback))
    }
}
