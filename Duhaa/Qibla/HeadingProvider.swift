import Foundation
import CoreLocation
import Observation

@MainActor
protocol HeadingProviding: AnyObject {
    var available: Bool { get }
    var onHeadingUpdate: ((Double?) -> Void)? { get set }
    func start()
    func stop()
}

/// Streams the device's compass heading for the Qibla screen. Heading needs a
/// magnetometer, so it's only available on real devices (nil in the Simulator).
@Observable
final class HeadingProvider: NSObject, CLLocationManagerDelegate, HeadingProviding {
    /// Current heading in degrees from true north (0…360), or nil if unavailable.
    private(set) var heading: Double?
    /// Whether this device can report a heading at all.
    private(set) var available = true
    @ObservationIgnored var onHeadingUpdate: ((Double?) -> Void)?

    @ObservationIgnored private var manager: CLLocationManager?
    @ObservationIgnored private var didReceiveFirstHeading = false
    @ObservationIgnored private var receivedHeadingCount = 0

    override init() {
        super.init()
        QiblaDiagnostics.event("Qibla heading provider init")
    }

    func start() {
        QiblaDiagnostics.event("Qibla authorization check", "headingAvailable")
        available = CLLocationManager.headingAvailable()
        guard available else { return }
        QiblaDiagnostics.event("Qibla heading updates start")
        makeManager().startUpdatingHeading()
    }

    func stop() {
        guard let manager else { return }
        manager.stopUpdatingHeading()
        QiblaDiagnostics.event("Qibla heading updates stop")
    }

    private func makeManager() -> CLLocationManager {
        if let manager { return manager }

        QiblaDiagnostics.event("Qibla CLLocationManager creation")
        let manager = CLLocationManager()
        manager.delegate = self
        // Stream every heading sample (no 1°-quantized steps); the smooth
        // motion comes from HeadingUpdateGate (rate/noise) + the compass spring.
        manager.headingFilter = kCLHeadingFilterNone
        self.manager = manager
        return manager
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Prefer true north; fall back to magnetic if true isn't resolved yet.
        QiblaDiagnostics.measure("Qibla heading provider update") {
            heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
        onHeadingUpdate?(heading)

        receivedHeadingCount += 1
        if !didReceiveFirstHeading {
            didReceiveFirstHeading = true
            QiblaDiagnostics.event("Qibla first heading update received",
                                   "heading=\(heading ?? -1)")
        } else {
            QiblaDiagnostics.throttledEvent("qibla-heading-provider-update",
                                            interval: 1,
                                            "Qibla heading provider update",
                                            "count=\(receivedHeadingCount), heading=\(heading ?? -1)")
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }
}
