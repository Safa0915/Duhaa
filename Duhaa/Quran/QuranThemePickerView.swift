import SwiftUI

/// A sheet of listening-ambience cards for the Quran player. Each card is a
/// still miniature of its ambience; tapping one selects and persists it, and
/// both the player behind the sheet and the sheet itself re-tint immediately.
///
/// Every color here is explicit (from the ambience, never `.primary`/Palette):
/// the player forces its own color scheme while open, so this sheet must stay
/// readable in any app theme × ambience combination.
struct QuranThemePickerView: View {
    let store: QuranListeningThemeStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    var body: some View {
        let current = store.theme
        VStack(spacing: 0) {
            header(current)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(QuranListeningTheme.allCases) { theme in
                        Button {
                            store.theme = theme
                            DuhaaHaptics.tap()
                        } label: {
                            QuranThemePreviewCard(theme: theme,
                                                  isSelected: current == theme,
                                                  captionColor: current.secondaryTextColor,
                                                  restingBorder: current.preferredTextColor.opacity(0.14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Text("Ambience only changes this listening screen — your app theme stays as it is.")
                    .duhaaFont(12)
                    .foregroundStyle(current.secondaryTextColor.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(
            LinearGradient(colors: current.gradientColors,
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: current)
        .presentationDragIndicator(.visible)
    }

    private func header(_ current: QuranListeningTheme) -> some View {
        HStack {
            Text("Listening Ambience")
                .duhaaFont(17, .bold)
                .foregroundStyle(current.preferredTextColor)
            Spacer()
            Button("Done") { dismiss() }
                .duhaaFont(15, .semibold)
                .foregroundStyle(current.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }
}

/// One ambience card: the miniature scene with the theme's name inside it and
/// its one-line description underneath.
struct QuranThemePreviewCard: View {
    let theme: QuranListeningTheme
    let isSelected: Bool
    /// Caption + resting-border colors come from the *current* ambience so
    /// they read well against the sheet's background.
    let captionColor: Color
    let restingBorder: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomLeading) {
                QuranThemedPlayerBackground(theme: theme, staticPreview: true)

                // A tiny play button hints that this themes the player.
                Circle()
                    .fill(theme.accentColor)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.onAccentColor)
                            .offset(x: 1)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(theme.displayName)
                    .duhaaFont(12.5, .semibold)
                    .foregroundStyle(theme.preferredTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .duhaaFont(16, .semibold)
                        .foregroundStyle(theme.accentColor)
                        .background(Circle().fill(theme.isLight ? Color.white : Color.black.opacity(0.55)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topTrailing)
                        .padding(7)
                }
            }
            .frame(height: 118)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? theme.accentColor : restingBorder,
                            lineWidth: isSelected ? 2 : 1)
            )

            Text(theme.shortDescription)
                .duhaaFont(11)
                .foregroundStyle(captionColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.displayName), \(theme.shortDescription)\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
