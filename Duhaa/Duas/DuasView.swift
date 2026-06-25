import SwiftUI
import UIKit

/// The Du'as tab: occasion-based categories (After Prayer, Morning, Evening, …).
struct DuasView: View {
    @State private var categories: [DuaCategory]?
    @State private var showingDuaRequest = false

    var body: some View {
        Group {
            if let categories {
                // Host provides the NavigationStack (see MainTabView / MoreView).
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        requestSection

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Browse")
                                .duhaaFont(12, .semibold)
                                .foregroundStyle(Palette.blue.opacity(0.65))

                            VStack(spacing: 14) {
                                ForEach(categories) { category in
                                    NavigationLink {
                                        DuaListView(category: category)
                                    } label: {
                                        card(category)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .duhaaReadableWidth()
                }
                .scrollIndicators(.hidden)
            } else {
                ProgressView()
                    .tint(Palette.gold)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Du'as")
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .task {
            guard categories == nil else { return }
            categories = await Duas.loadAsync()
        }
        .sheet(isPresented: $showingDuaRequest) {
            DuaRequestView()
                .presentationDetents([.large])
        }
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Request")
                .duhaaFont(12, .semibold)
                .foregroundStyle(Palette.blue.opacity(0.65))

            Button {
                showingDuaRequest = true
                DuhaaHaptics.tap()
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Palette.gold.opacity(0.14))
                        Image(systemName: "paperplane.fill")
                            .duhaaFont(18, .semibold)
                            .foregroundStyle(Palette.gold)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Submit a du'a request")
                            .duhaaFont(17, .semibold)
                            .foregroundStyle(.primary)
                        Text("Send it directly to Duhaa")
                            .duhaaFont(12)
                            .foregroundStyle(Palette.blue.opacity(0.72))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .duhaaFont(13, .semibold)
                        .foregroundStyle(Palette.blue.opacity(0.5))
                }
                .padding(16)
                .duhaaCardStyle()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Submit a du'a request")
        }
    }

    private func card(_ category: DuaCategory) -> some View {
        HStack(spacing: 14) {
            Image(systemName: category.icon)
                .duhaaFont(20)
                .foregroundStyle(Palette.gold)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .duhaaFont(17, .semibold)
                    .foregroundStyle(.primary)
                Text(category.subtitle ?? "\(category.duas.count) du'as")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .duhaaFont(13, .semibold)
                .foregroundStyle(Palette.blue.opacity(0.5))
        }
        .padding(16)
        .duhaaCardStyle()
    }
}

private struct DuaRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var request = ""
    @State private var contact = ""
    @State private var showingMailError = false

    private let recipientEmail = FeedbackStore.recipientEmail

    private var trimmedRequest: String {
        request.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContact: String {
        contact.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $request)
                            .frame(minHeight: 180)
                            .textInputAutocapitalization(.sentences)

                        if request.isEmpty {
                            Text("Write the du'a request here")
                                .foregroundStyle(Palette.secondaryText.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                } header: {
                    Text("Du'a Request")
                } footer: {
                    Text("Your email app will open so you can review the message before sending.")
                }

                Section {
                    TextField("Name or email (optional)", text: $contact)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                } footer: {
                    Text("Only include what you're comfortable sending by email.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Submit Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendRequest()
                    }
                    .disabled(trimmedRequest.isEmpty)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .alert("Couldn’t open email", isPresented: $showingMailError) {
            Button("Copy Email") {
                UIPasteboard.general.string = recipientEmail
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can email \(recipientEmail) directly. Your draft is still here.")
        }
    }

    private func sendRequest() {
        guard let url = requestURL else { return }
        openURL(url) { accepted in
            if accepted {
                dismiss()
            } else {
                showingMailError = true
            }
        }
    }

    private var requestURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipientEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Duhaa Du'a Request"),
            URLQueryItem(name: "body", value: emailBody)
        ]
        return components.url
    }

    private var emailBody: String {
        var lines = [
            trimmedRequest,
            "",
            "Sent from Duhaa"
        ]

        if !trimmedContact.isEmpty {
            lines.append("Contact: \(trimmedContact)")
        }

        return lines.joined(separator: "\n")
    }
}
