import UIKit

@MainActor
protocol QiblaHapticControlling: AnyObject {
    func prepareAlignmentHaptic()
    func playAlignedOnce()
}

@MainActor
final class QiblaHapticController: QiblaHapticControlling {
    private var generator: UINotificationFeedbackGenerator?

    func prepareAlignmentHaptic() {
        if generator == nil {
            generator = UINotificationFeedbackGenerator()
            QiblaDiagnostics.event("Qibla haptic generator created")
        }
        generator?.prepare()
        QiblaDiagnostics.event("Qibla haptic generator prepared")
    }

    func playAlignedOnce() {
        if generator == nil {
            prepareAlignmentHaptic()
        }
        generator?.notificationOccurred(.success)
        QiblaDiagnostics.event("Qibla haptic fired")
        generator?.prepare()
        QiblaDiagnostics.event("Qibla haptic generator prepared", "after fire")
    }
}
