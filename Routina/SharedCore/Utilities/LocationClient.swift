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
    static let noop = LocationClient(
        snapshot: { _ in
            LocationSnapshot(authorizationStatus: .notDetermined)
        }
    )
}
