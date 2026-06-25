import SwiftUI

extension View {
    /// Keep scrollable content in a centered, readable column on wide screens
    /// (iPad / large windows) instead of letting it stretch edge-to-edge. On
    /// iPhone this is a no-op — the screen is already narrower than the cap, so the
    /// locked phone design is untouched.
    ///
    /// Apply to the content *inside* a `ScrollView`/`List`/`Form`, not to the
    /// full-bleed background, so backgrounds still fill the whole screen.
    func duhaaReadableWidth(_ maxWidth: CGFloat = 700) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
