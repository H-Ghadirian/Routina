import ComposableArchitecture
import Foundation
import SwiftData

enum SettingsPlaceActionHandler {
    static func setDeletePlaceConfirmation(
        _ isPresented: Bool,
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        SettingsPlaceEditor.setDeleteConfirmation(isPresented, state: &state)
        return .none
    }

    static func placesLoaded(
        _ places: [RoutinePlaceSummary],
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        SettingsPlaceEditor.loadedPlaces(places, state: &state)
        return .none
    }

    static func locationSnapshotUpdated(
        _ snapshot: LocationSnapshot,
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        SettingsPlaceEditor.applyLocationSnapshot(snapshot, state: &state)
        return .none
    }

    static func placeDraftNameChanged(
        _ name: String,
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        SettingsPlaceEditor.updateDraftName(name, state: &state)
        return .none
    }

    static func placeDraftCoordinateChanged(
        _ coordinate: LocationCoordinate?,
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        SettingsPlaceEditor.updateDraftCoordinate(coordinate, state: &state)
        return .none
    }

    static func placeDraftRadiusChanged(
        _ radius: Double,
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        SettingsPlaceEditor.updateDraftRadius(radius, state: &state)
        return .none
    }

    static func savePlaceTapped(
        state: inout SettingsPlacesState,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard let request = SettingsPlaceEditor.prepareSave(state: &state) else {
            return .none
        }
        return SettingsPlaceExecution.save(request, modelContext: modelContext)
    }

    static func deletePlaceTapped(
        _ placeID: UUID,
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsPlaceEditor.beginDelete(placeID: placeID, state: &state) else {
            return .none
        }
        return .none
    }

    static func deletePlaceConfirmed(
        state: inout SettingsPlacesState,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard let request = SettingsPlaceEditor.prepareDeleteConfirmation(state: &state) else {
            return .none
        }
        return SettingsPlaceExecution.delete(request, modelContext: modelContext)
    }

    static func placeOperationFinished(
        success: Bool,
        message: String,
        state: inout SettingsPlacesState
    ) -> Effect<SettingsFeature.Action> {
        SettingsPlaceEditor.finishOperation(
            success: success,
            message: message,
            state: &state
        )
        return .none
    }
}
