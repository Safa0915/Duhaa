import Foundation
import CoreLocation
import Observation

/// Drives the Nearby Mosques screen. Holds no CoreLocation manager of its own —
/// it depends on the `LocationProviding` and `MosqueSearching` seams, so every
/// state (permission, loading, empty, error, loaded) is unit-testable with fakes.
@MainActor
@Observable
final class NearbyMosquesViewModel {
    enum State: Equatable {
        case idle
        case permissionNeeded          // notDetermined — show "Allow Location"
        case permissionDenied          // denied/restricted — show "Open Settings"
        case loading
        case loaded([MosquePlace])
        case empty
        case error
    }

    private(set) var state: State = .idle

    private let searcher: MosqueSearching
    /// Coordinate of the last successful search — skips redundant re-searches
    /// when the view opens/closes quickly (in-memory session cache).
    private var lastSearchedKey: String?
    /// Guards against overlapping searches from rapid refresh taps.
    private var isSearching = false

    init(searcher: MosqueSearching = MosqueSearchService()) {
        self.searcher = searcher
    }

    /// Entry point: reads permission, fetches the coordinate, and searches —
    /// the whole flow in one testable call.
    func locateAndSearch(using location: LocationProviding, force: Bool = false) async {
        switch location.authorizationStatus {
        case .notDetermined:
            state = .permissionNeeded
        case .denied, .restricted:
            state = .permissionDenied
        case .authorizedWhenInUse, .authorizedAlways:
            guard let coordinate = await location.currentCoordinate() else {
                state = .error   // location request failed / unavailable / timed out
                return
            }
            await search(around: coordinate, force: force)
        @unknown default:
            state = .permissionNeeded
        }
    }

    /// Searches around a known coordinate. Error on total failure, empty on no
    /// results, loaded otherwise. Caches the coordinate to avoid re-searching.
    func search(around coordinate: CLLocationCoordinate2D, force: Bool = false) async {
        let key = locationKey(coordinate)
        if !force, key == lastSearchedKey, case .loaded = state { return }
        if isSearching { return }   // ignore overlapping refresh taps

        isSearching = true
        defer { isSearching = false }
        state = .loading
        do {
            let results = try await searcher.searchNearbyMosques(from: coordinate)
            lastSearchedKey = key
            state = results.isEmpty ? .empty : .loaded(results)
        } catch {
            state = .error
        }
    }

    private func locationKey(_ c: CLLocationCoordinate2D) -> String {
        "\((c.latitude * 100).rounded() / 100),\((c.longitude * 100).rounded() / 100)"
    }
}
