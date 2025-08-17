import CoreLocation
import Foundation

struct LocationCoordinate: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
}

enum LocationAuthorizationStatus: Equatable, Sendable {
    case disabled
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways

    var isAuthorized: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .disabled, .notDetermined, .restricted, .denied:
            return false
        }
    }

    var needsSettingsChange: Bool {
        switch self {
        case .denied, .restricted:
            return true
        case .disabled, .notDetermined, .authorizedWhenInUse, .authorizedAlways:
            return false
        }
    }
}

struct LocationSnapshot: Equatable, Sendable {
    var authorizationStatus: LocationAuthorizationStatus
    var coordinate: LocationCoordinate?
    var horizontalAccuracy: Double?
    var timestamp: Date?

    var canDeterminePresence: Bool {
        authorizationStatus.isAuthorized && coordinate != nil
    }
}

struct LocationClient: Sendable {
    var snapshot: @MainActor @Sendable (_ requestAuthorizationIfNeeded: Bool) async -> LocationSnapshot
}

extension LocationClient {
    static let live = LocationClient(
        snapshot: { requestAuthorizationIfNeeded in
            await OneShotLocationProvider().fetchSnapshot(
                requestAuthorizationIfNeeded: requestAuthorizationIfNeeded
            )
        }
    )
}

@MainActor
private final class OneShotLocationProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    private enum Timeout {
        static let authorizationNanoseconds: UInt64 = 30_000_000_000
        static let locationNanoseconds: UInt64 = 15_000_000_000
    }

    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func fetchSnapshot(requestAuthorizationIfNeeded: Bool) async -> LocationSnapshot {
#if os(macOS)
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
#else
        var authorizationStatus = manager.authorizationStatus
        if requestAuthorizationIfNeeded && authorizationStatus == .notDetermined {
            authorizationStatus = await awaitAuthorizationDecision()
        }

        if authorizationStatus == .notDetermined {
            return snapshot(authorizationStatus: .notDetermined)
        }

        guard await areLocationServicesEnabled() else {
            return snapshot(authorizationStatus: .disabled)
        }

        let mappedAuthorization = mapAuthorizationStatus(authorizationStatus)
        guard mappedAuthorization.isAuthorized else {
            return snapshot(authorizationStatus: mappedAuthorization)
        }

        let location = await awaitCurrentLocation()
#endif
        return snapshot(authorizationStatus: mappedAuthorization, location: location)
    }

    private func awaitAuthorizationDecision() async -> CLAuthorizationStatus {
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

    private func awaitCurrentLocation() async -> CLLocation? {
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

    private func areLocationServicesEnabled() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: CLLocationManager.locationServicesEnabled())
            }
        }
    }

    private func snapshot(
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

    private func mapAuthorizationStatus(_ status: CLAuthorizationStatus) -> LocationAuthorizationStatus {
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
