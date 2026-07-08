import XCTest
@testable import Duhaa

@MainActor
private final class FakeQiblaHapticController: QiblaHapticControlling {
    private(set) var prepareCount = 0
    private(set) var fireCount = 0

    func prepareAlignmentHaptic() {
        prepareCount += 1
    }

    func playAlignedOnce() {
        fireCount += 1
    }
}

@MainActor
private final class FakeHeadingProvider: HeadingProviding {
    var available: Bool
    var onHeadingUpdate: ((Double?) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(available: Bool = true) {
        self.available = available
    }

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }

    func emit(_ heading: Double?) {
        onHeadingUpdate?(heading)
    }
}

final class QiblaAlignmentTests: XCTestCase {
    func testExactAlignmentReturnsAligned() {
        XCTAssertTrue(QiblaAlignmentDetector.isAligned(heading: 120, qiblaBearing: 120))
    }

    func testSlightlyInsideThresholdReturnsAligned() {
        XCTAssertTrue(QiblaAlignmentDetector.isAligned(heading: 115.1, qiblaBearing: 120))
    }

    func testSlightlyOutsideThresholdReturnsNotAligned() {
        XCTAssertFalse(QiblaAlignmentDetector.isAligned(heading: 114.9, qiblaBearing: 120))
    }

    func testWraparoundHeading359Qibla1ReturnsAligned() {
        XCTAssertTrue(QiblaAlignmentDetector.isAligned(heading: 359, qiblaBearing: 1))
        XCTAssertEqual(QiblaAngles.absoluteDelta(from: 359, to: 1), 2, accuracy: 0.0001)
    }

    func testWraparoundHeading1Qibla359ReturnsAligned() {
        XCTAssertTrue(QiblaAlignmentDetector.isAligned(heading: 1, qiblaBearing: 359))
        XCTAssertEqual(QiblaAngles.absoluteDelta(from: 1, to: 359), 2, accuracy: 0.0001)
    }

    func testAlignmentEnterEventFiresOnceWhenCrossingIntoThreshold() {
        var detector = QiblaAlignmentDetector()

        XCTAssertEqual(detector.update(heading: 100, qiblaBearing: 120).transition, .unchanged)
        XCTAssertEqual(detector.update(heading: 116, qiblaBearing: 120).transition, .entered)
        XCTAssertEqual(detector.update(heading: 119, qiblaBearing: 120).transition, .unchanged)
    }

    func testAlignmentDoesNotFireRepeatedlyWhileStayingInsideThreshold() {
        var detector = QiblaAlignmentDetector()
        let headings = [116.0, 118.0, 119.5, 120.0, 121.0, 123.5]
        let transitions = headings.map { detector.update(heading: $0, qiblaBearing: 120).transition }

        XCTAssertEqual(transitions.filter { $0 == .entered }.count, 1)
        XCTAssertEqual(transitions.filter { $0 == .exited }.count, 0)
        XCTAssertTrue(detector.isAligned)
    }

    func testAlignmentExitResetsOnlyAfterLeavingExitThreshold() {
        var detector = QiblaAlignmentDetector(enterThresholdDegrees: 5, exitThresholdDegrees: 7)

        XCTAssertEqual(detector.update(heading: 120, qiblaBearing: 120).transition, .entered)
        XCTAssertEqual(detector.update(heading: 126.8, qiblaBearing: 120).transition, .unchanged)
        XCTAssertTrue(detector.isAligned)
        XCTAssertEqual(detector.update(heading: 127.2, qiblaBearing: 120).transition, .exited)
        XCTAssertFalse(detector.isAligned)
    }

    func testJitterNearThresholdDoesNotSpamEnterExitEvents() {
        var detector = QiblaAlignmentDetector(enterThresholdDegrees: 5, exitThresholdDegrees: 7)
        let headings = [120.0, 124.8, 125.2, 126.5, 124.9, 126.9, 123.5]
        let transitions = headings.map { detector.update(heading: $0, qiblaBearing: 120).transition }

        XCTAssertEqual(transitions.filter { $0 == .entered }.count, 1)
        XCTAssertEqual(transitions.filter { $0 == .exited }.count, 0)
        XCTAssertTrue(detector.isAligned)
    }

    func testHeadingUpdatesAreDedupedAndThrottled() {
        var gate = HeadingUpdateGate(minimumInterval: 0.1,
                                     minimumDeltaDegrees: 0.5,
                                     urgentDeltaDegrees: 4)

        XCTAssertEqual(gate.evaluate(heading: 100, timestamp: 0).reason, .first)
        XCTAssertEqual(gate.evaluate(heading: 100.2, timestamp: 1).reason, .duplicate)
        XCTAssertEqual(gate.evaluate(heading: 101, timestamp: 0.01).reason, .throttled)
        XCTAssertEqual(gate.evaluate(heading: 101, timestamp: 0.11).reason, .accepted)
    }

    func testQiblaBearingCalculationIsDeterministicForKnownCoordinates() {
        let newYorkBearing = QiblaBearingCalculator.bearing(latitude: 40.7128, longitude: -74.0060)

        XCTAssertEqual(newYorkBearing ?? -1, 58.4817, accuracy: 0.01)
    }

    func testInvalidLocationDoesNotCrash() {
        XCTAssertNil(QiblaBearingCalculator.bearing(latitude: .nan, longitude: -74.0060))
        XCTAssertNil(QiblaBearingCalculator.bearing(latitude: 95, longitude: -74.0060))
        XCTAssertNil(QiblaBearingCalculator.distanceKm(latitude: 40.7128, longitude: -181))
    }

    func testMissingHeadingDoesNotCrash() {
        var detector = QiblaAlignmentDetector()

        let update = detector.update(heading: nil, qiblaBearing: 120)

        XCTAssertFalse(update.isAligned)
        XCTAssertEqual(update.transition, .unchanged)
    }

    @MainActor
    func testViewModelMissingHeadingDoesNotCrash() {
        let haptics = FakeQiblaHapticController()
        let viewModel = QiblaViewModel(qiblaBearing: 120, hapticController: haptics)

        let result = viewModel.handleHeading(nil, timestamp: 0)

        XCTAssertFalse(result.accepted)
        XCTAssertEqual(result.reason, .invalid)
        XCTAssertEqual(haptics.fireCount, 0)
    }

    @MainActor
    func testViewModelInitDoesNotStartHeadingOrPrepareHaptic() {
        let haptics = FakeQiblaHapticController()
        let headingProvider = FakeHeadingProvider()
        _ = QiblaViewModel(qiblaBearing: 120,
                           hapticController: haptics,
                           headingProvider: headingProvider)

        XCTAssertEqual(headingProvider.startCount, 0)
        XCTAssertEqual(haptics.prepareCount, 0)
    }

    @MainActor
    func testViewModelStartIsIdempotentAndStartsHeadingOnce() {
        let haptics = FakeQiblaHapticController()
        let headingProvider = FakeHeadingProvider()
        let viewModel = QiblaViewModel(qiblaBearing: 120,
                                       hapticController: haptics,
                                       headingProvider: headingProvider)

        viewModel.start()
        viewModel.start()
        viewModel.start()

        XCTAssertEqual(haptics.prepareCount, 1)
        XCTAssertEqual(headingProvider.startCount, 1)
        XCTAssertEqual(haptics.fireCount, 0)
    }

    @MainActor
    func testQiblaCanShowCalibratingStateBeforeFirstHeading() {
        let haptics = FakeQiblaHapticController()
        let headingProvider = FakeHeadingProvider()
        let viewModel = QiblaViewModel(qiblaBearing: 120,
                                       hapticController: haptics,
                                       headingProvider: headingProvider)

        viewModel.screenAppeared()

        XCTAssertEqual(viewModel.startupState, .calibrating)
        XCTAssertFalse(viewModel.hasHeading)
        XCTAssertFalse(viewModel.isAligned)
    }

    @MainActor
    func testNoAlignmentHapticBeforeValidHeading() {
        let haptics = FakeQiblaHapticController()
        let headingProvider = FakeHeadingProvider()
        let viewModel = QiblaViewModel(qiblaBearing: 120,
                                       hapticController: haptics,
                                       headingProvider: headingProvider)

        viewModel.start()

        XCTAssertEqual(haptics.prepareCount, 1)
        XCTAssertEqual(haptics.fireCount, 0)
        XCTAssertFalse(viewModel.hasHeading)
    }

    @MainActor
    func testSimulatedHeadingBurstFiresHapticAndAnimationOncePerEntry() {
        let haptics = FakeQiblaHapticController()
        let headingProvider = FakeHeadingProvider()
        let viewModel = QiblaViewModel(
            qiblaBearing: 120,
            hapticController: haptics,
            headingProvider: headingProvider,
            headingGate: HeadingUpdateGate(minimumInterval: 0,
                                           minimumDeltaDegrees: 0,
                                           urgentDeltaDegrees: 4)
        )
        let burst = [
            80.0, 95.0, 110.0, 115.2, // enters
            116.0, 119.0, 120.0, 121.0, 123.5, 124.9, 126.8, // jitter/stays aligned
            132.5 // exits after hysteresis
        ]

        for (index, heading) in burst.enumerated() {
            viewModel.handleHeading(heading, timestamp: Double(index) * 0.2)
        }

        XCTAssertEqual(haptics.fireCount, 1)
        XCTAssertEqual(viewModel.alignmentAnimationToken, 1)
        XCTAssertEqual(viewModel.performanceReport.alignmentEnterEvents, 1)
        XCTAssertEqual(viewModel.performanceReport.alignmentExitEvents, 1)
        XCTAssertEqual(viewModel.performanceReport.headingUpdatesEmitted, burst.count)
        XCTAssertLessThanOrEqual(viewModel.performanceReport.uiStateUpdates, burst.count)
        XCTAssertFalse(viewModel.isAligned)
    }
}
