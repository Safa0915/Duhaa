import SwiftUI
import UIKit

/// Lets the user add their local masjid's jamāʿah (iqāmah) times. Each prayer is
/// optional — "Add" to set a time, the ✕ to clear it. Stored as wall-clock times,
/// shown beside the calculated adhān times on the home screen. Times can be copied
/// or shared and pasted, so two people at one masjid only enter them once.
struct MasjidTimesView: View {
    @Environment(SettingsStore.self) private var store

    @State private var justCopied = false
    @State private var pendingPaste: MasjidTimetable?
    @State private var showPasteFailed = false

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                TextField("Masjid name (optional)", text: $store.masjid.name)
                    .listRowBackground(Palette.card)
            } header: {
                Text("Your Masjid")
            } footer: {
                Text("Add your mosque's jamāʿah times. They appear beside the calculated adhān times on the home screen. Leave any prayer off if you don't want it. Remember to update them when your masjid changes its schedule.")
            }

            Section("Jamāʿah Times") {
                timeRow("Fajr", \.fajr, default: 5 * 60 + 30)
                timeRow("Dhuhr", \.dhuhr, default: 13 * 60 + 30)
                timeRow("Asr", \.asr, default: 17 * 60)
                timeRow("Maghrib", \.maghrib, default: 19 * 60)
                timeRow("Isha", \.isha, default: 20 * 60 + 30)
            }

            Section {
                timeRow("Jumuʿah", \.jumuah, default: 13 * 60 + 30)
            } header: {
                Text("Friday")
            } footer: {
                Text("Shown in place of Dhuhr on Fridays.")
            }

            Section {
                if store.masjid.hasAnyTime {
                    Button {
                        UIPasteboard.general.string = store.masjid.shareText()
                        DuhaaHaptics.tick()
                        justCopied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            justCopied = false
                        }
                    } label: {
                        Label(justCopied ? "Copied" : "Copy times",
                              systemImage: justCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundStyle(justCopied ? Palette.success : Palette.blue)
                    }
                    .listRowBackground(Palette.card)

                    ShareLink(item: store.masjid.shareText()) {
                        Label("Share times…", systemImage: "square.and.arrow.up")
                            .foregroundStyle(Palette.blue)
                    }
                    .listRowBackground(Palette.card)
                }

                Button {
                    handlePaste()
                } label: {
                    Label("Paste times", systemImage: "doc.on.clipboard")
                        .foregroundStyle(Palette.blue)
                }
                .listRowBackground(Palette.card)
            } header: {
                Text("Share")
            } footer: {
                Text("Copy your masjid's times to send to someone, or paste times a fellow worshipper shared with you.")
            }

            if store.masjid.hasAnyTime {
                Section {
                    Button(role: .destructive) {
                        store.masjid = MasjidTimetable(name: store.masjid.name)
                    } label: {
                        Text("Clear all times")
                    }
                    .listRowBackground(Palette.card)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .duhaaReadableWidth()
        .background(ThemeDecorativeBackground())
        .navigationTitle("Local Masjid")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
        .alert("Replace your masjid times?",
               isPresented: Binding(get: { pendingPaste != nil },
                                    set: { if !$0 { pendingPaste = nil } })) {
            Button("Replace", role: .destructive) {
                if let parsed = pendingPaste { apply(parsed) }
                pendingPaste = nil
            }
            Button("Cancel", role: .cancel) { pendingPaste = nil }
        } message: {
            Text("This overwrites the times you've entered with the ones on your clipboard.")
        }
        .alert("No times found", isPresented: $showPasteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your clipboard doesn't contain masjid times Duhaa can read. Copy a timetable shared from Duhaa, then try again.")
        }
    }

    /// Read the clipboard, parse it, and either apply it or — if the user already has
    /// times — ask before replacing them.
    private func handlePaste() {
        guard let text = UIPasteboard.general.string,
              let parsed = MasjidTimetable.parse(text) else {
            DuhaaHaptics.tick()
            showPasteFailed = true
            return
        }
        if store.masjid.hasAnyTime {
            pendingPaste = parsed
        } else {
            apply(parsed)
        }
    }

    private func apply(_ timetable: MasjidTimetable) {
        store.masjid = timetable
        DuhaaHaptics.success()
    }

    @ViewBuilder
    private func timeRow(_ name: String,
                         _ keyPath: WritableKeyPath<MasjidTimetable, Int?>,
                         default fallback: Int) -> some View {
        let isSet = store.masjid[keyPath: keyPath] != nil
        HStack {
            Text(name)
                .foregroundStyle(.primary)
            Spacer()
            if isSet {
                DatePicker("", selection: dateBinding(keyPath), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Button {
                    store.masjid[keyPath: keyPath] = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(name) jamāʿah time")
            } else {
                Button("Add") {
                    store.masjid[keyPath: keyPath] = fallback
                }
                .foregroundStyle(Palette.blue)
            }
        }
        .listRowBackground(Palette.card)
    }

    /// Bridges a stored minutes-since-midnight value to the DatePicker's `Date`.
    private func dateBinding(_ keyPath: WritableKeyPath<MasjidTimetable, Int?>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = store.masjid[keyPath: keyPath] ?? 0
                var comps = DateComponents()
                comps.hour = minutes / 60
                comps.minute = minutes % 60
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                store.masjid[keyPath: keyPath] = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }
}
