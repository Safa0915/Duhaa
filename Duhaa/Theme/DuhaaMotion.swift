import SwiftUI

/// Small native SwiftUI motion primitives inspired by Motion's gesture patterns.
/// Kept local so Duhaa stays dependency-free and list-heavy screens stay fast.
enum DuhaaMotion {
    static let pressSpring = Animation.spring(response: 0.18, dampingFraction: 0.9)

    /// The "prayer marked" celebration: a quick swell with a touch of overshoot…
    static let markSwell = Animation.spring(response: 0.24, dampingFraction: 0.55)
    /// …then a calm, slightly slower settle back to rest.
    static let markSettle = Animation.spring(response: 0.4, dampingFraction: 0.85)
}

struct DuhaaPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(DuhaaMotion.pressSpring, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DuhaaPressButtonStyle {
    static var duhaaPress: DuhaaPressButtonStyle { DuhaaPressButtonStyle() }
}
