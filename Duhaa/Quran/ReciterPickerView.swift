import SwiftUI

/// A circular reciter avatar: the Quran.com profile photo when it loads, with a
/// themed gold/blue monogram as the placeholder + offline fallback.
struct ReciterAvatar: View {
    let reciter: Reciter
    var size: CGFloat = 84

    var body: some View {
        Group {
            if let url = reciter.imageURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        monogram // .empty (loading) and .failure both fall back
                    }
                }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var monogram: some View {
        ZStack {
            Circle().fill(
                LinearGradient(colors: [Palette.gold.opacity(0.38), Palette.blue.opacity(0.28)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            Text(reciter.initials)
                .duhaaFont(size * 0.34, .semibold)
                .foregroundStyle(.primary)
        }
    }
}

/// A scrollable gallery of reciters shown as photos — tap one to select it.
/// Presented as a sheet from the Quran reader and from Settings.
struct ReciterPickerView: View {
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 18)]

    private var filtered: [Reciter] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Reciters.all }
        return Reciters.all.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(filtered) { reciter in
                            Button {
                                selection = reciter.id
                                dismiss()
                            } label: {
                                cell(reciter)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .scrollIndicators(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Reciter")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search reciters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(Palette.gold)
                }
            }
        }
    }

    private func cell(_ reciter: Reciter) -> some View {
        let isSelected = reciter.id == selection
        return VStack(spacing: 9) {
            ReciterAvatar(reciter: reciter, size: 84)
                .overlay(
                    Circle().stroke(isSelected ? Palette.gold : Palette.blue.opacity(0.18),
                                    lineWidth: isSelected ? 3 : 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Palette.gold)
                            .background(Circle().fill(Palette.appBg))
                    }
                }
            Text(reciter.name)
                .duhaaFont(12, isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Palette.gold : .primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        // Top-align so avatars stay on one line across a row even when names
        // wrap to different numbers of lines.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reciter.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
