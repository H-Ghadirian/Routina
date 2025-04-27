import CoreLocation

extension OneShotLocationProvider {
    func fetchPlatformSnapshot(requestAuthorizationIfNeeded: Bool) async -> LocationSnapshot {
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
        return snapshot(authorizationStatus: mappedAuthorization, location: location)
    }
}
