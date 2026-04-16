import Foundation

struct SettingsPlaceSaveRequest: Equatable {
    var cleanedName: String
    var coordinate: LocationCoordinate
    var radiusMeters: Double
}

struct SettingsPlaceDeletionRequest: Equatable {
    var placeID: UUID
}

enum SettingsPlaceEditor {
    static func setDeleteConfirmation(
        _ isPresented: Bool,
        state: inout SettingsPlacesState
    ) {
        state.isDeletePlaceConfirmationPresented = isPresented
        if !isPresented {
            state.placePendingDeletion = nil
        }
    }

    static func loadedPlaces(
        _ places: [RoutinePlaceSummary],
        state: inout SettingsPlacesState
    ) {
        state.savedPlaces = places
        if let pendingPlace = state.placePendingDeletion,
           let updatedPlace = places.first(where: { $0.id == pendingPlace.id }) {
            state.placePendingDeletion = updatedPlace
        }
    }

    static func applyLocationSnapshot(
        _ snapshot: LocationSnapshot,
        state: inout SettingsPlacesState
    ) {
        state.locationAuthorizationStatus = snapshot.authorizationStatus
        if let coordinate = snapshot.coordinate {
            state.lastKnownLocationCoordinate = coordinate
        }
    }

    static func updateDraftName(
        _ name: String,
        state: inout SettingsPlacesState
    ) {
        state.placeDraftName = name
        state.placeStatusMessage = ""
    }

    static func updateDraftCoordinate(
        _ coordinate: LocationCoordinate?,
        state: inout SettingsPlacesState
    ) {
        state.placeDraftCoordinate = coordinate
        state.placeStatusMessage = ""
    }

    static func updateDraftRadius(
        _ radius: Double,
        state: inout SettingsPlacesState
    ) {
        state.placeDraftRadiusMeters = min(max(radius, 25), 2_000)
        state.placeStatusMessage = ""
    }

    static func beginDelete(
        placeID: UUID,
        state: inout SettingsPlacesState
    ) -> Bool {
        guard !state.isPlaceOperationInProgress,
              let place = state.savedPlaces.first(where: { $0.id == placeID }) else {
            return false
        }

        state.placePendingDeletion = place
        state.isDeletePlaceConfirmationPresented = true
        return true
    }

    // Centralize draft validation before kicking off persistence effects.
    static func prepareSave(
        state: inout SettingsPlacesState
    ) -> SettingsPlaceSaveRequest? {
        guard let cleanedName = RoutinePlace.cleanedName(state.placeDraftName) else {
            state.placeStatusMessage = "Enter a place name first."
            return nil
        }
        guard let coordinate = state.placeDraftCoordinate else {
            state.placeStatusMessage = "Choose a location on the map first."
            return nil
        }
        guard !state.isPlaceOperationInProgress else {
            return nil
        }

        state.isPlaceOperationInProgress = true
        state.placeStatusMessage = ""
        return SettingsPlaceSaveRequest(
            cleanedName: cleanedName,
            coordinate: coordinate,
            radiusMeters: state.placeDraftRadiusMeters
        )
    }

    static func prepareDeleteConfirmation(
        state: inout SettingsPlacesState
    ) -> SettingsPlaceDeletionRequest? {
        guard !state.isPlaceOperationInProgress,
              let pendingPlace = state.placePendingDeletion else {
            return nil
        }

        state.isDeletePlaceConfirmationPresented = false
        state.placePendingDeletion = nil
        state.isPlaceOperationInProgress = true
        state.placeStatusMessage = ""
        return SettingsPlaceDeletionRequest(placeID: pendingPlace.id)
    }

    static func finishOperation(
        success: Bool,
        message: String,
        state: inout SettingsPlacesState
    ) {
        state.isPlaceOperationInProgress = false
        state.placeStatusMessage = message
        if success {
            state.placeDraftName = ""
            state.placeDraftCoordinate = nil
        }
    }
}
