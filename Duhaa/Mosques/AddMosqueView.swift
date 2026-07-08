import SwiftUI

/// Form to add (or edit) the user's own masjid when Apple Maps didn't list it.
/// Saves privately on-device via `CustomMosqueStore` — nothing is sent anywhere.
struct AddMosqueView: View {
    let store: CustomMosqueStore
    /// Non-nil when editing an existing saved mosque; nil when adding a new one.
    var editing: CustomMosque?

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var phone = ""
    @State private var website = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Need at least a name and the directions/address to save something useful.
    private var canSave: Bool { !trimmedName.isEmpty && !trimmedAddress.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Mosque name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                }

                Section {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $address)
                            .frame(minHeight: 90)
                            .textInputAutocapitalization(.sentences)

                        if address.isEmpty {
                            Text("Street address, or how to get there")
                                .foregroundStyle(Palette.secondaryText.opacity(0.7))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                } header: {
                    Text("Address or directions")
                } footer: {
                    Text("Used for the Directions button — it opens Apple Maps to this place.")
                }

                Section {
                    TextField("Phone number (optional)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Website (optional)", text: $website)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("Contact")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle(editing == nil ? "Add Mosque" : "Edit Mosque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .onAppear(perform: loadIfEditing)
    }

    private func loadIfEditing() {
        guard let editing else { return }
        name = editing.name
        address = editing.address
        phone = editing.phoneNumber ?? ""
        website = editing.website ?? ""
    }

    private func save() {
        guard canSave else { return }
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWebsite = website.trimmingCharacters(in: .whitespacesAndNewlines)
        let mosque = CustomMosque(
            id: editing?.id ?? UUID(),
            name: trimmedName,
            address: trimmedAddress,
            phoneNumber: trimmedPhone.isEmpty ? nil : trimmedPhone,
            website: trimmedWebsite.isEmpty ? nil : trimmedWebsite
        )
        if editing == nil {
            store.add(mosque)
        } else {
            store.update(mosque)
        }
        DuhaaHaptics.tap()
        dismiss()
    }
}
