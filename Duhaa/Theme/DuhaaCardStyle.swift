import SwiftUI

struct DuhaaCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color
    let stroke: Color
    let lineWidth: CGFloat
    let shadowColor: Color?
    let shadowRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(stroke, lineWidth: lineWidth))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadowColor ?? .clear, radius: shadowRadius)
    }
}

struct DuhaaGradientCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let colors: [Color]
    let stroke: Color
    let lineWidth: CGFloat
    let shadowColor: Color?
    let shadowRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(stroke, lineWidth: lineWidth))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: shadowColor ?? .clear, radius: shadowRadius)
    }
}

extension View {
    func duhaaCardStyle(
        cornerRadius: CGFloat = 18,
        fill: Color = Palette.card,
        stroke: Color = Palette.cardBorder,
        lineWidth: CGFloat = 1,
        shadowColor: Color? = nil,
        shadowRadius: CGFloat = 0
    ) -> some View {
        modifier(DuhaaCardStyle(
            cornerRadius: cornerRadius,
            fill: fill,
            stroke: stroke,
            lineWidth: lineWidth,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius
        ))
    }

    func duhaaGradientCardStyle(
        cornerRadius: CGFloat = 20,
        colors: [Color],
        stroke: Color,
        lineWidth: CGFloat = 1,
        shadowColor: Color? = nil,
        shadowRadius: CGFloat = 0
    ) -> some View {
        modifier(DuhaaGradientCardStyle(
            cornerRadius: cornerRadius,
            colors: colors,
            stroke: stroke,
            lineWidth: lineWidth,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius
        ))
    }
}
