import Foundation
import CoreLocation
import Observation

/// Owns Duhaa's location: GPS auto-detect (While-Using), reverse-geocoding to a
/// city name + time zone, offline caching, and manual city search/override.
///
/// Created once at app launch and shared via the SwiftUI environment.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    /// The location currently driving prayer times. Always valid (cached or fallback).
    private(set) var active: ActiveLocation

    /// Latest authorization status, for the picker UI.
    private(set) var authorizationStatus: CLAuthorizationStatus

    /// True while a GPS fix is in flight (drives a spinner in the picker).
    private(set) var isLocating = false

    /// User-facing problem, if any (denied permission, geocode failure…).
    private(set) var errorMessage: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let geocoder = CLGeocoder()
    @ObservationIgnored private let cacheKey = "duhaa.activeLocation.v1"
    /// Set when the user asked for current location before permission resolved.
    @ObservationIgnored private var fetchWhenAuthorized = false

    override init() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(ActiveLocation.self, from: data) {
            active = cached
        } else {
            active = .fallback
        }
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer // city-level is plenty
    }

    // MARK: Launch

    /// Called once on launch. Respects a manual choice; otherwise asks permission
    /// on first run and fetches a fix once allowed. Stays silent if denied (the
    /// cached/fallback location keeps working — the user can use the picker).
    func start() {
        guard !active.isManual else { return }
        switch authorizationStatus {
        case .notDetermined:
            fetchWhenAuthorized = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestFix()
        default:
            break
        }
    }

    // MARK: GPS

    /// "Use current location" — asks permission if needed, then fetches a fix.
    func useCurrentLocation() {
        errorMessage = nil
        switch authorizationStatus {
        case .notDetermined:
            fetchWhenAuthorized = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestFix()
        case .denied, .restricted:
            errorMessage = "Location is off for Duhaa. Turn it on in Settings, or search for your city below."
        @unknown default:
            break
        }
    }

    private func requestFix() {
        isLocating = true
        manager.requestLocation() // one-shot
    }

    // MARK: Manual city search

    /// Forward-geocode a query into tappable city suggestions (needs network).
    func searchCities(_ query: String, completion: @escaping ([CitySuggestion]) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { completion([]); return }
        geocoder.geocodeAddressString(trimmed) { placemarks, _ in
            let suggestions: [CitySuggestion] = (placemarks ?? []).compactMap { p in
                guard let loc = p.location else { return nil }
                return CitySuggestion(
                    name: Self.displayName(for: p),
                    latitude: loc.coordinate.latitude,
                    longitude: loc.coordinate.longitude,
                    timeZoneID: p.timeZone?.identifier ?? TimeZone.current.identifier
                )
            }
            completion(suggestions)
        }
    }

    /// Apply a manually-chosen city and remember it.
    func choose(_ city: CitySuggestion) {
        errorMessage = nil
        setActive(ActiveLocation(name: city.name,
                                 latitude: city.latitude, longitude: city.longitude,
                                 timeZoneID: city.timeZoneID, isManual: true))
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        let allowed = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        if allowed && fetchWhenAuthorized {
            fetchWhenAuthorized = false
            requestFix()
        } else if authorizationStatus == .denied {
            fetchWhenAuthorized = false
            errorMessage = "Location is off for Duhaa. Turn it on in Settings, or search for your city below."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        errorMessage = "Couldn't get your location. Try again, or search for your city."
    }

    // MARK: Helpers

    /// Reverse-geocode a fix into name + time zone, then make it active.
    /// If offline (geocode fails) we still keep the coordinates and fall back to
    /// the device's current time zone — you're physically there, so it matches.
    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            self.isLocating = false
            let placemark = placemarks?.first
            let name = placemark.map(Self.displayName(for:)) ?? "Current Location"
            let tz = placemark?.timeZone?.identifier ?? TimeZone.current.identifier
            self.setActive(ActiveLocation(name: name,
                                          latitude: location.coordinate.latitude,
                                          longitude: location.coordinate.longitude,
                                          timeZoneID: tz, isManual: false))
        }
    }

    private func setActive(_ location: ActiveLocation) {
        active = location
        if let data = try? JSONEncoder().encode(location) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    /// "City, Country" where possible, gracefully degrading.
    private static func displayName(for placemark: CLPlacemark) -> String {
        let city = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.name
        let country = placemark.isoCountryCode ?? placemark.country
        return [city, country].compactMap { $0 }.joined(separator: ", ")
    }
}
