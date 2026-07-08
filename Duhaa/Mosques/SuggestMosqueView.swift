import SwiftUI
import UIKit

/// Pure value type that builds the mosque-suggestion email (subject + body +
/// `mailto:` URL). Kept free of SwiftUI/UIKit so it's unit-testable.
struct MosqueSuggestion {
    var name = ""
    var address = ""
    var phone = ""
    var website = ""
    var notes = ""
    var contact = ""

    private func trim(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The directions/address is the one required field — the dev needs at least
    /// a location to find and add the mosque.
    var isValid: Bool { !trim(address).isEmpty }

    /// Gmail-friendly headline, e.g. "Duhaa Mosque Suggestion: Masjid An-Noor".
    /// Falls back to the address when no name was given.
    var subject: String {
        let name = trim(name)
        let detail = name.isEmpty ? trim(address) : name
        let headline = detail.isEmpty ? "Duhaa Mosque Suggestion"
                                      : "Duhaa Mosque Suggestion: \(detail)"
        return String(headline.prefix(120))
    }

    var body: String {
        var lines = [
            "Assalamu alaikum,",
            "",
            "I'd like to suggest a mosque to add to Duhaa.",
            ""
        ]
        if !trim(name).isEmpty { lines.append("Name: \(trim(name))") }
        lines.append("Directions / address: \(trim(address))")
        if !trim(phone).isEmpty { lines.append("Phone: \(trim(phone))") }
        if !trim(website).isEmpty { lines.append("Website: \(trim(website))") }
        if !trim(notes).isEmpty {
            lines.append("")
            lines.append("Notes: \(trim(notes))")
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

/// Form that lets anyone email the developer a mosque to add to Duhaa. Opens the
/// user's mail app (mailto) pre-filled, going to `duhaaapp@gmail.com` with a
/// clear subject. The directions field is required before Send enables.
struct SuggestMosqueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var draft = MosqueSuggestion()
    @State private var showingMailError = false

    private let recipientEmail = FeedbackStore.recipientEmail

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Mosque name (optional)", text: $draft.name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $draft.address)
                            .frame(minHeight: 90)
                            .textInputAutocapitalization(.sentences)

                        if draft.address.isEmpty {
                            Text("Street address, or how to get there")
                                .foregroundStyle(Palette.secondaryText.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                } header: {
                    Text("Directions or address")
                } footer: {
                    Text("Required — at minimum, tell us where the mosque is so it can be found.")
                }

                Section {
                    TextField("Phone number (optional)", text: $draft.phone)
                        .keyboardType(.phonePad)
                    TextField("Website (optional)", text: $draft.website)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("Contact")
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $draft.notes)
                            .frame(minHeight: 70)
                            .textInputAutocapitalization(.sentences)

                        if draft.notes.isEmpty {
                            Text("Anything else we should know (optional)")
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
                    Text("Notes")
                } footer: {
                    Text("Your email app opens with everything filled in, so you can review it before sending to \(recipientEmail).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Suggest a Mosque")
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
