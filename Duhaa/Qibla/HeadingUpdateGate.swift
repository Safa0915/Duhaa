import Foundation

struct HeadingUpdateDecision: Equatable {
    let shouldEmit: Bool
    let reason: Reason

    enum Reason: Equatable {
        case first
        case accepted
        case invalid
        case duplicate
        case throttled
    }
}

struct HeadingUpdateGate {
    var minimumInterval: TimeInterval
    var minimumDeltaDegrees: Double
    var urgentDeltaDegrees: Double

    private var lastHeading: Double?
    private var lastTimestamp: TimeInterval?

    init(minimumInterval: TimeInterval = 1.0 / 30.0,
         minimumDeltaDegrees: Double = 0.3,
         urgentDeltaDegrees: Double = 4) {
        self.minimumInterval = minimumInterval
        self.minimumDeltaDegrees = minimumDeltaDegrees
        self.urgentDeltaDegrees = urgentDeltaDegrees
    }

    mutating func evaluate(heading: Double?, timestamp: TimeInterval) -> HeadingUpdateDecision {
        guard let heading, heading.isFinite else {
            return HeadingUpdateDecision(shouldEmit: false, reason: .invalid)
        }

        guard let lastHeading, let lastTimestamp else {
            accept(heading: heading, timestamp: timestamp)
            return HeadingUpdateDecision(shouldEmit: true, reason: .first)
        }

        let delta = QiblaAngles.absoluteDelta(from: lastHeading, to: heading)
        if delta < minimumDeltaDegrees {
            return HeadingUpdateDecision(shouldEmit: false, reason: .duplicate)
        }

        let elapsed = timestamp - lastTimestamp
        if elapsed < minimumInterval && delta < urgentDeltaDegrees {
            return HeadingUpdateDecision(shouldEmit: false, reason: .throttled)
        }

        accept(heading: heading, timestamp: timestamp)
        return HeadingUpdateDecision(shouldEmit: true, reason: .accepted)
    }

    mutating func reset() {
        lastHeading = nil
        lastTimestamp = nil
    }

    private mutating func accept(heading: Double, timestamp: TimeInterval) {
        lastHeading = heading
        lastTimestamp = timestamp
    }
}
