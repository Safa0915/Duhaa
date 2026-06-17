import Foundation
import Observation

struct QiblaHeadingProcessingResult: Equatable {
    let accepted: Bool
    let transition: QiblaAlignmentTransition
    let reason: HeadingUpdateDecision.Reason
}

struct QiblaCompassState: Equatable {
    var continuousHeading = 0.0
    var hasHeading = false
    var isAligned = false
    var relativeQibla = 0.0
    var alignmentAnimationToken = 0
    var startupState: QiblaStartupState = .idle
}

enum QiblaStartupState: Equatable {
    case idle
    case calibrating
    case headingUnavailable
    case ready
}

@MainActor
@Observable
final class QiblaViewModel {
    private(set) var compassState = QiblaCompassState()
    private(set) var latestHeading: Double?

    var continuousHeading: Double { compassState.continuousHeading }
    var hasHeading: Bool { compassState.hasHeading }
    var isAligned: Bool { compassState.isAligned }
    var relativeQibla: Double { compassState.relativeQibla }
    var alignmentAnimationToken: Int { compassState.alignmentAnimationToken }
    var startupState: QiblaStartupState { compassState.startupState }

    @ObservationIgnored private let hapticController: QiblaHapticControlling
    @ObservationIgnored private let headingProvider: HeadingProviding
    @ObservationIgnored private var alignmentDetector: QiblaAlignmentDetector
    @ObservationIgnored private var headingGate: HeadingUpdateGate
    @ObservationIgnored private var qiblaBearing: Double
    @ObservationIgnored private(set) var performanceReport = QiblaPerformanceReport()
    @ObservationIgnored private var didStart = false

    init(qiblaBearing: Double,
         hapticController: QiblaHapticControlling? = nil,
         headingProvider: HeadingProviding? = nil,
         alignmentDetector: QiblaAlignmentDetector = QiblaAlignmentDetector(),
         headingGate: HeadingUpdateGate = HeadingUpdateGate()) {
        QiblaDiagnostics.event("Qibla view model init start")
        self.qiblaBearing = QiblaAngles.normalized(qiblaBearing)
        self.hapticController = hapticController ?? QiblaHapticController()
        self.headingProvider = headingProvider ?? HeadingProvider()
        self.alignmentDetector = alignmentDetector
        self.headingGate = headingGate
        compassState.relativeQibla = self.qiblaBearing
        QiblaDiagnostics.event("Qibla view model init end")
    }

    func screenAppeared() {
        QiblaDiagnostics.event("Qibla view appear")
        if compassState.startupState == .idle {
            compassState.startupState = .calibrating
        }
        QiblaDiagnostics.event("Qibla first frame placeholder visible", "\(startupState)")
    }

    func screenDisappeared() {
        stop()
        #if DEBUG
        let report = QiblaPerformanceDiagnostics.report(merging: performanceReport)
        QiblaDiagnostics.event("Qibla performance report", report.summary)
        #endif
    }

    func start() {
        guard !didStart else {
            QiblaDiagnostics.event("Qibla start ignored", "already-started")
            return
        }
        didStart = true
        compassState.startupState = .calibrating
        QiblaDiagnostics.event("Qibla first async startup begins")

        headingProvider.onHeadingUpdate = { [weak self] heading in
            self?.handleHeading(heading)
        }
        headingProvider.start()
        if !headingProvider.available {
            compassState.startupState = .headingUnavailable
        }

        QiblaDiagnostics.event("Qibla haptic prepare")
        hapticController.prepareAlignmentHaptic()
    }

    func stop() {
        guard didStart else { return }
        headingProvider.stop()
        headingProvider.onHeadingUpdate = nil
        headingGate.reset()
        didStart = false
    }

    func updateQiblaBearing(_ newBearing: Double) {
        guard newBearing.isFinite else { return }
        qiblaBearing = QiblaAngles.normalized(newBearing)
        let update = alignmentDetector.update(heading: hasHeading ? continuousHeading : nil,
                                              qiblaBearing: qiblaBearing)
        applyAlignment(update) { state in
            state.relativeQibla = self.qiblaBearing - state.continuousHeading
        }
    }

    @discardableResult
    func handleHeading(_ heading: Double?, timestamp: TimeInterval = Date.timeIntervalSinceReferenceDate) -> QiblaHeadingProcessingResult {
        performanceReport.headingUpdatesReceived += 1
        let decision = headingGate.evaluate(heading: heading, timestamp: timestamp)

        guard decision.shouldEmit, let heading else {
            performanceReport.headingUpdatesDropped += 1
            QiblaDiagnostics.throttledEvent("qibla-heading-dropped",
                                            interval: 1,
                                            "Qibla heading update dropped",
                                            "reason=\(decision.reason)")
            return QiblaHeadingProcessingResult(accepted: false,
                                                transition: .unchanged,
                                                reason: decision.reason)
        }

        let startedAt = Date.timeIntervalSinceReferenceDate
        let transition = QiblaDiagnostics.measure("Qibla heading update",
                                                  "heading=\(heading)") {
            processAcceptedHeading(heading)
        }
        let duration = Date.timeIntervalSinceReferenceDate - startedAt
        performanceReport.longestHeadingUpdate = max(performanceReport.longestHeadingUpdate, duration)
        performanceReport.longestMainThreadUpdate = max(performanceReport.longestMainThreadUpdate, duration)
        performanceReport.headingUpdatesEmitted += 1

        QiblaDiagnostics.throttledEvent("qibla-heading-duration",
                                        interval: 1,
                                        "Qibla heading update duration",
                                        "durationMs=\(String(format: "%.3f", duration * 1_000))")

        return QiblaHeadingProcessingResult(accepted: true,
                                            transition: transition,
                                            reason: decision.reason)
    }

    private func processAcceptedHeading(_ heading: Double) -> QiblaAlignmentTransition {
        latestHeading = QiblaAngles.normalized(heading)

        let delta = QiblaAngles.delta(from: continuousHeading, to: heading)
        // Adaptive low-pass filter: heavy smoothing for sensor noise (small deltas),
        // full pass-through for deliberate fast rotation (≥4°/sample ≈ 40°/s).
        let absDelta = abs(delta)
        let alpha = absDelta >= 4.0 ? 1.0 : 0.2 + 0.8 * (absDelta / 4.0)
        let nextHeading = continuousHeading + delta * alpha
        let alignmentUpdate = alignmentDetector.update(heading: nextHeading,
                                                       qiblaBearing: qiblaBearing)

        applyAlignment(alignmentUpdate) { state in
            state.continuousHeading = nextHeading
            state.hasHeading = true
            state.startupState = .ready
            state.relativeQibla = self.qiblaBearing - nextHeading
        }

        performanceReport.uiStateUpdates += 1
        if performanceReport.uiStateUpdates == 1 {
            QiblaDiagnostics.event("Qibla first compass UI update")
        }

        return alignmentUpdate.transition
    }

    private func applyAlignment(_ update: QiblaAlignmentUpdate,
                                updateState: ((inout QiblaCompassState) -> Void)? = nil) {
        var nextState = compassState
        updateState?(&nextState)
        nextState.isAligned = update.isAligned

        switch update.transition {
        case .entered:
            performanceReport.alignmentEnterEvents += 1
            performanceReport.hapticFires += 1
            nextState.alignmentAnimationToken += 1
            QiblaDiagnostics.event("Qibla alignment entered",
                                   "delta=\(String(format: "%.2f", update.absoluteDelta))")
            QiblaDiagnostics.event("Qibla alignment animation started")
            hapticController.playAlignedOnce()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 240_000_000)
                QiblaDiagnostics.event("Qibla alignment animation ended")
            }
        case .exited:
            performanceReport.alignmentExitEvents += 1
            QiblaDiagnostics.event("Qibla alignment exited",
                                   "delta=\(String(format: "%.2f", update.absoluteDelta))")
        case .unchanged:
            break
        }

        compassState = nextState
    }
}
