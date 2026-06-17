import XCTest
@testable import Duhaa

final class QiblaPerformanceTests: XCTestCase {
    func testPerformanceQiblaBearingCalculationRepeated() {
        measure {
            for _ in 0..<10_000 {
                _ = QiblaBearingCalculator.bearing(latitude: 40.7128,
                                                   longitude: -74.0060,
                                                   instrumented: false)
            }
        }
    }

    func testPerformanceAlignmentDetectionRepeated() {
        measure {
            var detector = QiblaAlignmentDetector()
            for index in 0..<100_000 {
                _ = detector.update(heading: Double(index % 360), qiblaBearing: 120)
            }
        }
    }

    func testPerformanceHeadingGateRepeated() {
        measure {
            var gate = HeadingUpdateGate()
            for index in 0..<100_000 {
                _ = gate.evaluate(heading: Double(index % 360),
                                  timestamp: Double(index) * 0.02)
            }
        }
    }

    @MainActor
    func testViewModelRestartsHeadingProviderAfterScreenDisappears() {
        let haptics = FakePerformanceQiblaHapticController()
        let headingProvider = FakePerformanceHeadingProvider()
        let viewModel = QiblaViewModel(qiblaBearing: 120,
                                       hapticController: haptics,
                                       headingProvider: headingProvider)

        viewModel.screenAppeared()
        viewModel.start()
        viewModel.screenDisappeared()
        viewModel.screenAppeared()
        viewModel.start()

        XCTAssertEqual(headingProvider.startCount, 2)
        XCTAssertEqual(headingProvider.stopCount, 1)
        XCTAssertNotNil(headingProvider.onHeadingUpdate)
    }

    @MainActor
    func testViewModelAcceptsFirstHeadingAfterRestart() {
        let haptics = FakePerformanceQiblaHapticController()
        let headingProvider = FakePerformanceHeadingProvider()
        let viewModel = QiblaViewModel(qiblaBearing: 120,
                                       hapticController: haptics,
                                       headingProvider: headingProvider,
                                       headingGate: HeadingUpdateGate(minimumInterval: 10,
                                                                      minimumDeltaDegrees: 0.3,
                                                                      urgentDeltaDegrees: 4))

        viewModel.start()
        let first = viewModel.handleHeading(10, timestamp: 1)
        viewModel.stop()
        viewModel.start()
        let restartedFirst = viewModel.handleHeading(10.1, timestamp: 1.01)

        XCTAssertEqual(first.reason, .first)
        XCTAssertTrue(first.accepted)
        XCTAssertEqual(restartedFirst.reason, .first)
        XCTAssertTrue(restartedFirst.accepted)
    }

    @MainActor
    func testPerformanceViewModelStartupWithFakeHeadingProvider() {
        measure {
            let haptics = FakePerformanceQiblaHapticController()
            let headingProvider = FakePerformanceHeadingProvider()
            let viewModel = QiblaViewModel(qiblaBearing: 120,
                                           hapticController: haptics,
                                           headingProvider: headingProvider)

            viewModel.screenAppeared()
            viewModel.start()
        }
    }

    @MainActor
    func testPerformanceHapticEnterLogicWithMockHaptics() {
        measure {
            let haptics = FakePerformanceQiblaHapticController()
            let viewModel = QiblaViewModel(
                qiblaBearing: 120,
                hapticController: haptics,
                headingGate: HeadingUpdateGate(minimumInterval: 0,
                                               minimumDeltaDegrees: 0,
                                               urgentDeltaDegrees: 4)
            )

            for index in 0..<5_000 {
                let heading = index.isMultiple(of: 250) ? 100.0 : 120.0
                viewModel.handleHeading(heading, timestamp: Double(index) * 0.1)
            }
        }
    }

    @MainActor
    func testPerformanceViewModelHandlingHeadingBurst() {
        let headings = (0..<5_000).map { index in
            120 + sin(Double(index) / 18.0) * 8
        }

        measure {
            let haptics = FakePerformanceQiblaHapticController()
            let viewModel = QiblaViewModel(
                qiblaBearing: 120,
                hapticController: haptics,
                headingGate: HeadingUpdateGate(minimumInterval: 0,
                                               minimumDeltaDegrees: 0,
                                               urgentDeltaDegrees: 4)
            )

            for (index, heading) in headings.enumerated() {
                viewModel.handleHeading(heading, timestamp: Double(index) * 0.1)
            }
        }
    }
}

@MainActor
private final class FakePerformanceQiblaHapticController: QiblaHapticControlling {
    func prepareAlignmentHaptic() {}
    func playAlignedOnce() {}
}

@MainActor
private final class FakePerformanceHeadingProvider: HeadingProviding {
    var available = true
    var onHeadingUpdate: ((Double?) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }
}
