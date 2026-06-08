import Foundation
import CoreLocation
import Observation

/// Streams the device's compass heading for the Qibla screen. Heading needs a
/// magnetometer, so it's only available on real devices (nil in the Simulator).
@Observable
final class HeadingProvider: NSObject, CLLocationManagerDelegate {
    /// Current heading in degrees from true north (0…360), or nil if unavailable.
    private(set) var heading: Double?
    /// Whether this device can report a heading at all.
    let available: Bool

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        available = CLLocationManager.headingAvailable()
        super.init()
        manager.delegate = self
        manager.headingFilter = 1 // degrees
    }

    func start() {
        guard available else { return }
        manager.startUpdatingHeading()
    }

    func stop() { manager.stopUpdatingHeading() }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Prefer true north; fall back to magnetic if true isn't resolved yet.
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }
}
