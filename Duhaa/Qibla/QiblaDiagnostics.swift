import Foundation

#if DEBUG
import os.signpost

struct QiblaSignpostToken {
    let id: OSSignpostID
}

enum QiblaDiagnostics {
    private static let log = OSLog(subsystem: "com.duhaa.app", category: .pointsOfInterest)
    private static let throttleLock = NSLock()
    private static var lastLogTimes: [String: TimeInterval] = [:]

    static func event(_ name: StaticString, _ details: String = "") {
        os_signpost(.event, log: log, name: name, "%{public}@", details as NSString)
    }

    static func throttledEvent(_ key: String,
                               interval: TimeInterval,
                               _ name: StaticString,
                               _ details: @autoclosure () -> String = "") {
        let now = Date.timeIntervalSinceReferenceDate
        throttleLock.lock()
        let shouldLog = now - (lastLogTimes[key] ?? -.infinity) >= interval
        if shouldLog {
            lastLogTimes[key] = now
        }
        throttleLock.unlock()

        if shouldLog {
            event(name, details())
        }
    }

    static func begin(_ name: StaticString, _ details: String = "") -> QiblaSignpostToken {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id, "%{public}@", details as NSString)
        return QiblaSignpostToken(id: id)
    }

    static func end(_ name: StaticString, token: QiblaSignpostToken, _ details: String = "") {
        os_signpost(.end, log: log, name: name, signpostID: token.id, "%{public}@", details as NSString)
    }

    static func measure<T>(_ name: StaticString,
                           _ details: String = "",
                           _ work: () throws -> T) rethrows -> T {
        let token = begin(name, details)
        defer { end(name, token: token) }
        return try work()
    }
}
#else
struct QiblaSignpostToken {}

enum QiblaDiagnostics {
    static func event(_ name: StaticString, _ details: String = "") {}
    static func throttledEvent(_ key: String,
                               interval: TimeInterval,
                               _ name: StaticString,
                               _ details: @autoclosure () -> String = "") {}
    static func begin(_ name: StaticString, _ details: String = "") -> QiblaSignpostToken {
        QiblaSignpostToken()
    }
    static func end(_ name: StaticString, token: QiblaSignpostToken, _ details: String = "") {}
    static func measure<T>(_ name: StaticString,
                           _ details: String = "",
                           _ work: () throws -> T) rethrows -> T {
        try work()
    }
}
#endif

struct QiblaPerformanceReport: Equatable {
    var headingUpdatesReceived = 0
    var headingUpdatesEmitted = 0
    var headingUpdatesDropped = 0
    var uiStateUpdates = 0
    var alignmentEnterEvents = 0
    var alignmentExitEvents = 0
    var hapticFires = 0
    var longestBearingCalculation: TimeInterval = 0
    var longestHeadingUpdate: TimeInterval = 0
    var longestMainThreadUpdate: TimeInterval = 0

    var summary: String {
        [
            "heading received: \(headingUpdatesReceived)",
            "heading emitted: \(headingUpdatesEmitted)",
            "heading dropped: \(headingUpdatesDropped)",
            "ui updates: \(uiStateUpdates)",
            "alignment enters: \(alignmentEnterEvents)",
            "alignment exits: \(alignmentExitEvents)",
            "haptic fires: \(hapticFires)",
            "max bearing: \(Self.ms(longestBearingCalculation))",
            "max heading: \(Self.ms(longestHeadingUpdate))",
            "max main update: \(Self.ms(longestMainThreadUpdate))"
        ].joined(separator: " · ")
    }

    private static func ms(_ interval: TimeInterval) -> String {
        String(format: "%.3fms", interval * 1_000)
    }
}

#if DEBUG
enum QiblaPerformanceDiagnostics {
    private static let lock = NSLock()
    private static var globalReport = QiblaPerformanceReport()

    static func recordBearingCalculation(duration: TimeInterval) {
        lock.lock()
        globalReport.longestBearingCalculation = max(globalReport.longestBearingCalculation, duration)
        lock.unlock()
    }

    static func report(merging localReport: QiblaPerformanceReport) -> QiblaPerformanceReport {
        lock.lock()
        let global = globalReport
        lock.unlock()

        var report = localReport
        report.longestBearingCalculation = max(report.longestBearingCalculation,
                                               global.longestBearingCalculation)
        return report
    }
}
#else
enum QiblaPerformanceDiagnostics {
    static func recordBearingCalculation(duration: TimeInterval) {}
    static func report(merging localReport: QiblaPerformanceReport) -> QiblaPerformanceReport {
        localReport
    }
}
#endif
