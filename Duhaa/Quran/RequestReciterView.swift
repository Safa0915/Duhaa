import SwiftUI
import UIKit

/// Pure value type that builds the reciter-request email (subject + body +
/// `mailto:` URL). SwiftUI/UIKit-free so it's unit-testable.
struct ReciterRequest {
    var name = ""
    var detail = ""
    var contact = ""

    private func trim(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The reciter's name is the one required field.
    var isValid: Bool { !trim(name).isEmpty }

    var subject: String {
        let name = trim(name)
        let headline = name.isEmpty ? "Duhaa Reciter Request" : "Duhaa Reciter Request: \(name)"
        return String(headline.prefix(120))
    }

    var body: String {
        var lines = [
            "Assalamu alaikum,",
            "",
            "I'd like to request a reciter to add to Duhaa.",
            ""
        ]
        lines.append("Reciter: \(trim(name))")
        if !trim(detail).isEmpty {
            lines.append("")
            lines.append("Details (style, recording, link): \(trim(detail))")
        }
        if !trim(contact).isEmpty {
            lines.append("")
            lines.append("Contact: \(trim(contact))")
        }
        lines.append("")
        lines.append("Sent from Duhaa")
        return lines.joined(separator: "\n")
    }

    func mailtoURL(to recipient: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

/// Lets anyone email the developer a reciter they'd love to see added. Opens the
/// user's mail app (mailto) pre-filled to `duhaaapp@gmail.com`. The reciter name
/// is required before Send enables.
struct RequestReciterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Pre-fill the name (e.g. from a no-results search in the picker).
    var prefilledName: String = ""

    @State private var draft = ReciterRequest()
    @State private var showingMailError = false

    private let recipientEmail = FeedbackStore.recipientEmail

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reciter's name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Reciter")
                } footer: {
                    Text("Required — whose recitation would you like to listen to?")
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $draft.detail)
                            .frame(minHeight: 80)
                            .textInputAutocapitalization(.sentences)

                        if draft.detail.isEmpty {
                            Text("Style, a link, or anything that helps (optional)")
                                .foregroundStyle(Palette.secondaryText.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }

                    TextField("Your name or email (optional)", text: $draft.contact)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                } header: {
                    Text("Details")
                } footer: {
                    Text("Your email app opens with everything filled in, so you can review it before sending to \(recipientEmail).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Request a Reciter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }.disabled(!draft.isValid)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .onAppear {
            if draft.name.isEmpty { draft.name = prefilledName }
        }
        .alert("Couldn’t open email", isPresented: $showingMailError) {
            Button("Copy Email") { UIPasteboard.general.string = recipientEmail }
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can email \(recipientEmail) directly. Your draft is still here.")
        }
    }

    private func send() {
        guard draft.isValid, let url = draft.mailtoURL(to: recipientEmail) else { return }
        openURL(url) { accepted in
            if accepted { dismiss() } else { showingMailError = true }
        }
    }
}
