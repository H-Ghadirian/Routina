import CoreLocation
import Foundation

@MainActor
final class OneShotLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    enum Timeout {
        static let authorizationNanoseconds: UInt64 = 30_000_000_000
        static let locationNanoseconds: UInt64 = 15_000_000_000
    }

    let manager = CLLocationManager()
    var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fetchSnapshot(requestAuthorizationIfNeeded: Bool) async -> LocationSnapshot {
        await fetchPlatformSnapshot(requestAuthorizationIfNeeded: requestAuthorizationIfNeeded)
    }

    func awaitAuthorizationDecision() async -> CLAuthorizationStatus {
        if manager.authorizationStatus != .notDetermined {
            return manager.authorizationStatus
        }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: Timeout.authorizationNanoseconds)
                guard let self, let continuation = self.authorizationContinuation else { return }
                self.authorizationContinuation = nil
                continuation.resume(returning: self.manager.authorizationStatus)
            }
        }
    }

    func awaitCurrentLocation() async -> CLLocation? {
        if let location = manager.location {
            return location
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: Timeout.locationNanoseconds)
                guard let self, let continuation = self.locationContinuation else { return }
                self.locationContinuation = nil
                continuation.resume(returning: self.manager.location)
            }
        }
    }

    func areLocationServicesEnabled() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: CLLocationManager.locationServicesEnabled())
            }
        }
    }

    func snapshot(
        authorizationStatus: LocationAuthorizationStatus,
        location: CLLocation? = nil
    ) -> LocationSnapshot {
        LocationSnapshot(
            authorizationStatus: authorizationStatus,
            coordinate: location.map {
                LocationCoordinate(
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude
                )
            },
            horizontalAccuracy: location?.horizontalAccuracy,
            timestamp: location?.timestamp
        )
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: status)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: locations.last ?? manager.location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: manager.location)
    }

    func mapAuthorizationStatus(_ status: CLAuthorizationStatus) -> LocationAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedAlways:
            return .authorizedAlways
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        @unknown default:
            return .denied
        }
    }
}

extension OneShotLocationProvider {
    func fetchPlatformSnapshot(requestAuthorizationIfNeeded: Bool) async -> LocationSnapshot {
        let initialAuthorization = manager.authorizationStatus
        if initialAuthorization == .notDetermined && !requestAuthorizationIfNeeded {
            return snapshot(authorizationStatus: .notDetermined)
        }

        guard await areLocationServicesEnabled() else {
            return snapshot(authorizationStatus: .disabled)
        }

        let initialMappedAuthorization = mapAuthorizationStatus(initialAuthorization)
        if initialAuthorization != .notDetermined && !initialMappedAuthorization.isAuthorized {
            return snapshot(authorizationStatus: initialMappedAuthorization)
        }

        let location = await awaitCurrentLocation()
        let mappedAuthorization = mapAuthorizationStatus(manager.authorizationStatus)
        guard mappedAuthorization.isAuthorized else {
            return snapshot(authorizationStatus: mappedAuthorization)
        }

        return snapshot(authorizationStatus: mappedAuthorization, location: location)
    }
}
