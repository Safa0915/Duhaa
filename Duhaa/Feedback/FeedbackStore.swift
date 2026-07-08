import Foundation
import Observation

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case general
    case prayerTimes
    case quran
    case duas
    case widgets
    case bug
    case idea

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "General"
        case .prayerTimes: return "Prayer times"
        case .quran: return "Quran"
        case .duas: return "Du'as"
        case .widgets: return "Widgets"
        case .bug: return "Bug"
        case .idea: return "Idea"
        }
    }

    var triageKey: String {
        switch self {
        case .general: return "general"
        case .prayerTimes: return "prayer-times"
        case .quran: return "quran"
        case .duas: return "duas"
        case .widgets: return "widgets"
        case .bug: return "bug"
        case .idea: return "idea"
        }
    }
}

enum FeedbackPromptReason: String, Codable, Equatable {
    case appOpen
    case prayerMarked
    case quranRead
    case manual
    case bug

    var promptTitle: String {
        switch self {
        case .appOpen:
            return "How is Duhaa feeling so far?"
        case .prayerMarked:
            return "Can Duhaa feel better?"
        case .quranRead:
            return "Help shape the Quran experience"
        case .manual:
            return "Send feedback"
        case .bug:
            return "Report a bug"
        }
    }

    var promptMessage: String {
        switch self {
        case .appOpen:
            return "A quick note from you can help make the app calmer, clearer, and more useful."
        case .prayerMarked:
            return "If anything felt confusing, beautiful, or missing, you can tell me directly."
        case .quranRead:
            return "Your notes help me polish reading, audio, tafsir, and navigation before more people use it."
        case .manual:
            return "Tell me what worked, what felt off, or what you wish Duhaa had."
        case .bug:
            return "Tell me what broke and what you were doing right before it happened."
        }
    }

    var triageKind: String {
        switch self {
        case .bug:
            return "bug"
        default:
            return "feedback"
        }
    }
}

struct FeedbackDiagnostics: Equatable {
    let appVersion: String
    let buildNumber: String
    let device: String
    let systemName: String
    let systemVersion: String

    var appDisplay: String {
        "\(appVersion) (\(buildNumber))"
    }

    var systemDisplay: String {
        "\(systemName) \(systemVersion)"
    }
}

struct FeedbackEmailDraft: Equatable {
    let recipient: String
    let subject: String
    let body: String

    static func make(reason: FeedbackPromptReason,
                     category: FeedbackCategory,
                     message: String,
                     contact: String,
                     diagnostics: FeedbackDiagnostics?) -> FeedbackEmailDraft {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionToken = diagnostics.map { "v\($0.appVersion) b\($0.buildNumber)" } ?? "no-diagnostics"
        let subjectPrefix = reason == .bug ? "Duhaa Bug Report" : "Duhaa Feedback"

        var lines = [
            trimmedMessage,
            "",
            "---",
            "Duhaa Feedback Metadata",
            "Type: \(reason.triageKind)",
            "Topic: \(category.label)",
            "Area: \(category.triageKey)",
            "Reason: \(reason.rawValue)"
        ]

        if trimmedContact.isEmpty {
            lines.append("Contact: Not provided")
        } else {
            lines.append("Contact: \(trimmedContact)")
        }

        if let diagnostics {
            lines.append("App: \(diagnostics.appDisplay)")
            lines.append("Device: \(diagnostics.device)")
            lines.append("System: \(diagnostics.systemDisplay)")
        } else {
            lines.append("Diagnostics: Not included by user")
        }

        lines.append("Triage: area=\(category.triageKey); severity=untriaged; source=in-app-email")
        lines.append("Privacy: No prayer data is attached.")

        return FeedbackEmailDraft(
            recipient: FeedbackStore.recipientEmail,
            subject: "\(subjectPrefix) [\(category.triageKey)] [\(versionToken)]",
            body: lines.joined(separator: "\n")
        )
    }
}

@Observable
final class FeedbackStore {
    enum Presentation: Equatable, Identifiable {
        case prompt(FeedbackPromptReason)
        case composer(FeedbackPromptReason)

        var id: String {
            switch self {
            case .prompt(let reason): return "prompt-\(reason.rawValue)"
            case .composer(let reason): return "composer-\(reason.rawValue)"
            }
        }
    }

    static let recipientEmail = "duhaaapp@gmail.com"

    var presentation: Presentation?

    private(set) var automaticPromptsDisabled: Bool

    var automaticPromptsEnabled: Bool { !automaticPromptsDisabled }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let promptCooldown: TimeInterval
    @ObservationIgnored private let maxAutomaticPrompts: Int

    init(defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init,
         promptCooldown: TimeInterval = 4 * 24 * 60 * 60,
         maxAutomaticPrompts: Int = 4) {
        self.defaults = defaults
        self.now = now
        self.promptCooldown = promptCooldown
        self.maxAutomaticPrompts = maxAutomaticPrompts
        automaticPromptsDisabled = defaults.bool(forKey: Key.automaticPromptsDisabled)
    }

    func recordAppOpen() {
        let count = increment(Key.appOpenCount)
        guard count == 2 || (count > 2 && (count - 2).isMultiple(of: 8)) else { return }
        presentAutomaticPrompt(reason: .appOpen)
    }

    func recordMeaningfulAction(_ reason: FeedbackPromptReason) {
        guard reason != .manual && reason != .bug else { return }
        let count = increment(Key.meaningfulActionCount)
        switch count {
        case 3, 10, 25:
            presentAutomaticPrompt(reason: reason)
        default:
            return
        }
    }

    func presentComposer(reason: FeedbackPromptReason) {
        presentation = .composer(reason)
    }

    func startFeedbackFromPrompt(reason: FeedbackPromptReason) {
        presentation = .composer(reason)
    }

    func dismissPrompt() {
        presentation = nil
    }

    func closePresentation() {
        presentation = nil
    }

    func disableAutomaticPrompts() {
        automaticPromptsDisabled = true
        defaults.set(true, forKey: Key.automaticPromptsDisabled)
        presentation = nil
    }

    func setAutomaticPromptsEnabled(_ enabled: Bool) {
        automaticPromptsDisabled = !enabled
        defaults.set(!enabled, forKey: Key.automaticPromptsDisabled)
    }

    func recordFeedbackStarted() {
        defaults.set(now(), forKey: Key.lastFeedbackStarted)
        presentation = nil
    }

    // MARK: Internals

    private func presentAutomaticPrompt(reason: FeedbackPromptReason) {
        guard canPresentAutomaticPrompt else { return }
        defaults.set(promptCount + 1, forKey: Key.promptCount)
        defaults.set(now(), forKey: Key.lastPromptDate)
        presentation = .prompt(reason)
    }

    private var canPresentAutomaticPrompt: Bool {
        guard !automaticPromptsDisabled, presentation == nil else { return false }
        guard promptCount < maxAutomaticPrompts else { return false }
        guard let lastPrompt = defaults.object(forKey: Key.lastPromptDate) as? Date else { return true }
        return now().timeIntervalSince(lastPrompt) >= promptCooldown
    }

    private var promptCount: Int {
        defaults.integer(forKey: Key.promptCount)
    }

    @discardableResult
    private func increment(_ key: String) -> Int {
        let next = defaults.integer(forKey: key) + 1
        defaults.set(next, forKey: key)
        return next
    }

    private enum Key {
        static let automaticPromptsDisabled = "duhaa.feedback.automaticPromptsDisabled"
        static let appOpenCount = "duhaa.feedback.appOpenCount"
        static let meaningfulActionCount = "duhaa.feedback.meaningfulActionCount"
        static let promptCount = "duhaa.feedback.promptCount"
        static let lastPromptDate = "duhaa.feedback.lastPromptDate"
        static let lastFeedbackStarted = "duhaa.feedback.lastFeedbackStarted"
    }
}
