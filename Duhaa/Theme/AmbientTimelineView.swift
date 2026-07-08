import SwiftUI

/// Drives the ambient theme decorations (star field, hearts, blossoms, leaves)
/// from one shared clock, with two rules each field used to re-implement:
///
/// 1. **Reduce Motion** renders a single still frame (time 0) — no animation,
///    no battery use.
/// 2. **Off screen = paused.** A `TimelineView(.animation)` keeps firing even
///    while its tab sits hidden behind another tab, and more than one decorated
///    tab can be alive at once (Home and More both draw the theme field). That
///    unseen churn competed with the Qibla compass for frame time on decorated
///    themes, so the schedule pauses whenever the view leaves the screen.
///
/// `content` receives the seconds elapsed since the view first appeared.
struct AmbientTimelineView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationStart = Date.timeIntervalSinceReferenceDate
    @State private var isOnScreen = false

    private let minimumInterval: Double?
    private let content: (TimeInterval) -> Content

    /// `minimumInterval` caps the redraw rate for slow ambiences (a 10th of a
    /// second is plenty for a twinkle); nil keeps the display-rate default.
    init(minimumInterval: Double? = nil,
         @ViewBuilder content: @escaping (TimeInterval) -> Content) {
        self.minimumInterval = minimumInterval
        self.content = content
    }

    var body: some View {
        Group {
            if reduceMotion {
                content(0)
            } else {
                TimelineView(.animation(minimumInterval: minimumInterval, paused: !isOnScreen)) { timeline in
                    content(max(0, timeline.date.timeIntervalSinceReferenceDate - animationStart))
                }
            }
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
