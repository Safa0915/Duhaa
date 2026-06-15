import Foundation
import CoreLocation
import MapKit

// MARK: - Seams for testing
//
// These three protocols let the Nearby Mosques view model run without real
// CoreLocation permission, real MapKit search, or actually launching Maps —
// so every state can be unit-tested with fakes. The real conformances below
// stay tiny wrappers; behavior lives in the view model + MosqueSearchService.

/// What the feature needs from a location source (the app's `LocationProvider`).
protocol LocationProviding {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    /// Best-known coordinate, or nil if location couldn't be determined.
    func currentCoordinate() async -> CLLocationCoordinate2D?
}

/// What the feature needs from a mosque search backend.
protocol MosqueSearching {
    /// Throws only when *every* underlying query fails (network/MapKit error).
    /// Returns [] when queries succeed but find nothing (an empty area).
    func searchNearbyMosques(from coordinate: CLLocationCoordinate2D) async throws -> [MosquePlace]
}

/// What the feature needs to open Apple Maps. Never Google.
protocol MapsOpening {
    func openDirections(to mosque: MosquePlace)
    func openInMaps(_ mosque: MosquePlace)
}

enum MosqueSearchError: Error { case allQueriesFailed }

// MARK: - Real implementations

/// The app's existing location service already does the work — just expose it
/// through the protocol so the view model depends on the seam, not the class.
extension LocationProvider: LocationProviding {
    func requestWhenInUseAuthorization() { useCurrentLocation() }
    func currentCoordinate() async -> CLLocationCoordinate2D? {
        // `active` is always a valid (cached or fallback) coordinate.
        CLLocationCoordinate2D(latitude: active.latitude, longitude: active.longitude)
    }
}

/// Opens Apple Maps for directions or a pin. Directions go from the user's
/// current location to the mosque; falls back to a coordinate-only pin.
struct AppleMapsOpener: MapsOpening {
    func openDirections(to mosque: MosquePlace) {
        mapItem(for: mosque).openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    func openInMaps(_ mosque: MosquePlace) {
        mapItem(for: mosque).openInMaps()
    }

    /// Built purely from the coordinate (+ name) — testable, and the
    /// coordinate-only fallback the spec asks for is simply the default path.
    func mapItem(for mosque: MosquePlace) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: mosque.coordinate))
        item.name = mosque.name
        return item
    }
}
