import CoreHaptics
import UIKit

/// One vocabulary of touch feedback for the whole app. Haptics in Duhaa are
/// reserved for moments of meaning — marking, completing, aligning, logging —
/// never plain navigation, so the celebratory ones keep their weight.
enum DuhaaHaptics {
    private static var engine: CHHapticEngine?
    private static var engineStopWorkItem: DispatchWorkItem?

    /// Soft, quiet acknowledgment: logging, toggling, bookmarking.
    static func tap() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Selection tick: pickers whose change is meaningful (theme).
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// The warm two-stage success: completing something that matters.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Light tactile beat: tasbih counting.
    static func count() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Firmer thud: reset-style actions.
    static func reset() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// The "all five today" flourish — an echo after the row's own success,
    /// spaced so it reads as celebration, not error buzz.
    static func perfectDay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
                playPerfectDayPattern()
            } else {
                perfectDayFallback()
            }
        }
    }

    /// The winning feeling: three rising steps (drumroll) over a low rumble,
    /// then a crisp full-strength hit, an echoing second beat, and a soft
    /// afterglow that melts away. Mark → success → beat → rise → TA-DA.
    private static func playPerfectDayPattern() {
        do {
            let engine = try preparedEngine()
            let events = [
                // The rise — three quick steps, each stronger than the last.
                event(.hapticTransient, at: 0.00, intensity: 0.55, sharpness: 0.30),
                event(.hapticTransient, at: 0.12, intensity: 0.75, sharpness: 0.45),
                event(.hapticTransient, at: 0.24, intensity: 0.95, sharpness: 0.60),
                // Low rumble underneath the rise — anticipation.
                event(.hapticContinuous, at: 0.10, duration: 0.36, intensity: 0.32, sharpness: 0.10),
                // The win: a crisp full hit, then a rounder echoing second beat.
                event(.hapticTransient, at: 0.56, intensity: 1.00, sharpness: 0.95),
                event(.hapticTransient, at: 0.68, intensity: 1.00, sharpness: 0.45),
                // Afterglow that the curve below fades to nothing.
                event(.hapticContinuous, at: 0.68, duration: 0.38, intensity: 0.45, sharpness: 0.08)
            ]
            // Decay envelope for the afterglow (1.0 before the win, melting to 0 after).
            let fade = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0.68, value: 1.0),
                    .init(relativeTime: 1.06, value: 0.0)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: events, parameterCurves: [fade])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            scheduleEngineStop()
        } catch {
            perfectDayFallback()
        }
    }

    private static func perfectDayFallback() {
        // No CoreHaptics? The original double-success still feels like a win.
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private static func preparedEngine() throws -> CHHapticEngine {
        if engine == nil {
            let newEngine = try CHHapticEngine()
            newEngine.stoppedHandler = { _ in
                DispatchQueue.main.async { engine = nil }
            }
            newEngine.resetHandler = {
                DispatchQueue.main.async { try? engine?.start() }
            }
            engine = newEngine
        }
        try engine?.start()
        return engine!
    }

    private static func event(_ type: CHHapticEvent.EventType,
                              at time: TimeInterval,
                              duration: TimeInterval = 0,
                              intensity: Float,
                              sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: type,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time,
            duration: duration
        )
    }

    private static func scheduleEngineStop() {
        engineStopWorkItem?.cancel()
        let work = DispatchWorkItem {
            engine?.stop(completionHandler: nil)
            engine = nil
        }
        engineStopWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}
