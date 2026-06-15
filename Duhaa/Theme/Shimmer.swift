import SwiftUI

/// A calm gold shimmer sweep for skeleton placeholders — the "animated
/// placeholder" pattern, reimagined in Duhaa's celestial palette. Purposeful:
/// it signals "your content is on its way" while previewing its shape, instead
/// of a bare spinner. Honors Reduce Motion (falls back to a still placeholder).
private struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Palette.gold.opacity(0.28), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.7)
                        .offset(x: phase * geo.size.width * 1.6)
                        .blendMode(.plusLighter)
                    }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Applies the soft gold loading shimmer. Use on skeleton placeholder shapes.
    func shimmering() -> some View { modifier(Shimmer()) }
}

/// A neutral placeholder fill for skeleton shapes (adapts to light/dark themes).
extension ShapeStyle where Self == Color {
    static var skeleton: Color { Color.primary.opacity(0.08) }
}
