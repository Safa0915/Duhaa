import Foundation

#if DEBUG
import os.signpost

struct FirstUseSignpostToken {
    let id: OSSignpostID
}

enum FirstUseDiagnostics {
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

    static func begin(_ name: StaticString, _ details: String = "") -> FirstUseSignpostToken {
        let id = OSSignpostID(log: log)
        os_signpost(.begin, log: log, name: name, signpostID: id, "%{public}@", details as NSString)
        return FirstUseSignpostToken(id: id)
    }

    static func end(_ name: StaticString, token: FirstUseSignpostToken, _ details: String = "") {
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
struct FirstUseSignpostToken {}

enum FirstUseDiagnostics {
    static func event(_ name: StaticString, _ details: String = "") {}
    static func throttledEvent(_ key: String,
                               interval: TimeInterval,
                               _ name: StaticString,
                               _ details: @autoclosure () -> String = "") {}
    static func begin(_ name: StaticString, _ details: String = "") -> FirstUseSignpostToken {
        FirstUseSignpostToken()
    }
    static func end(_ name: StaticString, token: FirstUseSignpostToken, _ details: String = "") {}
    static func measure<T>(_ name: StaticString,
                           _ details: String = "",
                           _ work: () throws -> T) rethrows -> T {
        try work()
    }
}
#endif
