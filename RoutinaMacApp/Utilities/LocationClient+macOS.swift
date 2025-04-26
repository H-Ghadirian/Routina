import CoreLocation

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
