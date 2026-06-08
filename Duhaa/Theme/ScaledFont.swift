import SwiftUI

/// A system font whose point size scales with the user's Dynamic Type setting.
/// Drop-in for `.font(.system(size:weight:))` → `.duhaaFont(size, weight)`.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let italic: Bool

    init(size: CGFloat, weight: Font.Weight, italic: Bool) {
        _size = ScaledMetric(wrappedValue: size)
        self.weight = weight
        self.italic = italic
    }

    func body(content: Content) -> some View {
        let font = Font.system(size: size, weight: weight)
        return content.font(italic ? font.italic() : font)
    }
}

extension View {
    /// Dynamic-Type-aware system font (scales relative to the body text style).
    func duhaaFont(_ size: CGFloat, _ weight: Font.Weight = .regular, italic: Bool = false) -> some View {
        modifier(ScaledFont(size: size, weight: weight, italic: italic))
    }
}
