import SwiftUI

/// Settings → Appearance → App Icon. A calm gallery of home-screen icons the
/// user can switch between. Tapping one applies it immediately (iOS shows its
/// own confirmation alert) and marks it with a gold ring + checkmark.
struct AppIconPickerView: View {
    @Environment(AppIconStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 18)]

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                intro

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(AppIconOption.all) { option in
                        AppIconCell(option: option,
                                    isSelected: store.current.id == option.id) {
                            store.select(option)
                        }
                    }
                }

                if !store.supported {
                    footnote("Your device can't change the app icon right now.")
                } else if let error = store.lastError {
                    footnote(error)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .duhaaReadableWidth()
        }
        .scrollIndicators(.hidden)
        .background(ThemeDecorativeBackground())
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Palette.gold)
        .preferredColorScheme(Palette.active.colorScheme)
    }

    private var intro: some View {
        Text("Choose how Duhaa looks on your home screen. Each option keeps the same crescent-and-stars mark in a different palette.")
            .duhaaFont(14, .medium)
            .foregroundStyle(Palette.secondaryText.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .duhaaFont(13, .medium)
            .foregroundStyle(Palette.secondaryText.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}

private struct AppIconCell: View {
    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    // iOS masks app icons with a continuous "squircle"; ~22% of the side
    // approximates it for the in-app preview.
    private let side: CGFloat = 92
    private var cornerRadius: CGFloat { side * 0.2237 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 11) {
                ZStack(alignment: .bottomTrailing) {
                    Image(option.previewAsset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(isSelected ? Palette.gold : Palette.cardBorder.opacity(0.55),
                                        lineWidth: isSelected ? 3 : 1)
                        )
                        .shadow(color: .black.opacity(isSelected ? 0.28 : 0.16),
                                radius: isSelected ? 9 : 5, y: 3)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(Palette.gold)
                            .background(Circle().fill(Palette.appBg).padding(2))
                            .offset(x: 7, y: 7)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                VStack(spacing: 2) {
                    Text(option.title)
                        .duhaaFont(15, .semibold)
                        .foregroundStyle(isSelected ? Palette.gold : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(option.subtitle)
                        .duhaaFont(12, .medium)
                        .foregroundStyle(Palette.secondaryText.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.duhaaPress)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(option.title), \(option.subtitle)")
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint(isSelected ? "" : "Double tap to use this icon")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
