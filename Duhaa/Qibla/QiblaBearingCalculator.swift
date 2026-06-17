import Adhan
import CoreLocation
import Foundation

enum QiblaAngles {
    static func normalized(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }

    /// Smallest signed angle from `from` to `to`, in -180...180 degrees.
    static func delta(from: Double, to: Double) -> Double {
        guard from.isFinite, to.isFinite else { return 0 }
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    static func absoluteDelta(from: Double, to: Double) -> Double {
        abs(delta(from: from, to: to))
    }

    static func compassPoint(_ degrees: Double) -> String {
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let normalizedDegrees = normalized(degrees)
        let index = Int((normalizedDegrees + 22.5) / 45)
        return points[index % points.count]
    }
}

struct QiblaBearingCalculator {
    static let kaabaCoordinate = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    static func bearing(from location: ActiveLocation, instrumented: Bool = true) -> Double? {
        bearing(latitude: location.latitude, longitude: location.longitude, instrumented: instrumented)
    }

    static func bearing(latitude: Double, longitude: Double, instrumented: Bool = true) -> Double? {
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)),
              latitude.isFinite,
              longitude.isFinite else {
            return nil
        }

        let calculation = {
            QiblaAngles.normalized(
                Qibla(coordinates: Coordinates(latitude: latitude, longitude: longitude)).direction
            )
        }

        guard instrumented else { return calculation() }

        let startedAt = Date.timeIntervalSinceReferenceDate
        return QiblaDiagnostics.measure("Qibla bearing calculation",
                                        "lat=\(latitude), lon=\(longitude)") {
            let bearing = calculation()
            QiblaPerformanceDiagnostics.recordBearingCalculation(
                duration: Date.timeIntervalSinceReferenceDate - startedAt
            )
            return bearing
        }
    }

    static func distanceKm(from location: ActiveLocation) -> Double? {
        distanceKm(latitude: location.latitude, longitude: location.longitude)
    }

    static func distanceKm(latitude: Double, longitude: Double) -> Double? {
        guard CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude)),
              latitude.isFinite,
              longitude.isFinite else {
            return nil
        }

        let current = CLLocation(latitude: latitude, longitude: longitude)
        let kaaba = CLLocation(latitude: kaabaCoordinate.latitude, longitude: kaabaCoordinate.longitude)
        return current.distance(from: kaaba) / 1_000
    }
}
