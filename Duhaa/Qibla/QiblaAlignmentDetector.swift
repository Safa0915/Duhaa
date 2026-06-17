import Foundation

enum QiblaAlignmentTransition: Equatable {
    case unchanged
    case entered
    case exited
}

struct QiblaAlignmentUpdate: Equatable {
    let isAligned: Bool
    let absoluteDelta: Double
    let transition: QiblaAlignmentTransition
}

struct QiblaAlignmentDetector {
    var enterThresholdDegrees: Double
    var exitThresholdDegrees: Double
    private(set) var isAligned = false

    init(enterThresholdDegrees: Double = 5,
         exitThresholdDegrees: Double = 7) {
        precondition(enterThresholdDegrees >= 0)
        precondition(exitThresholdDegrees >= enterThresholdDegrees)
        self.enterThresholdDegrees = enterThresholdDegrees
        self.exitThresholdDegrees = exitThresholdDegrees
    }

    mutating func update(heading: Double?, qiblaBearing: Double?) -> QiblaAlignmentUpdate {
        guard let heading,
              let qiblaBearing,
              heading.isFinite,
              qiblaBearing.isFinite else {
            let transition: QiblaAlignmentTransition = isAligned ? .exited : .unchanged
            isAligned = false
            return QiblaAlignmentUpdate(isAligned: false,
                                        absoluteDelta: .infinity,
                                        transition: transition)
        }

        let absoluteDelta = QiblaAngles.absoluteDelta(from: heading, to: qiblaBearing)
        let nextAligned = isAligned
            ? absoluteDelta <= exitThresholdDegrees
            : absoluteDelta <= enterThresholdDegrees

        let transition: QiblaAlignmentTransition
        if nextAligned && !isAligned {
            transition = .entered
        } else if !nextAligned && isAligned {
            transition = .exited
        } else {
            transition = .unchanged
        }

        isAligned = nextAligned
        return QiblaAlignmentUpdate(isAligned: nextAligned,
                                    absoluteDelta: absoluteDelta,
                                    transition: transition)
    }

    mutating func reset() {
        isAligned = false
    }

    static func isAligned(heading: Double,
                          qiblaBearing: Double,
                          thresholdDegrees: Double = 5) -> Bool {
        QiblaAngles.absoluteDelta(from: heading, to: qiblaBearing) <= thresholdDegrees
    }
}
