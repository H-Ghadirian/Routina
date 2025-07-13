import Foundation

extension SettingsFeature.State {
    var syncStatusText: String {
        if isCloudDataResetInProgress {
            return "Deleting iCloud data..."
        }
        if isCloudSyncInProgress {
            return "Syncing..."
        }
        if !cloudStatusMessage.isEmpty {
            return cloudStatusMessage
        }
        if !cloudSyncAvailable {
            return "iCloud sync is disabled in this build."
        }
        return "Ready to sync."
    }

    var dataTransferStatusText: String {
        if isDataTransferInProgress {
            return "Processing JSON file..."
        }
        if !dataTransferStatusMessage.isEmpty {
            return dataTransferStatusMessage
        }
        return "Export or import all routine data as JSON."
    }

    var deletePlaceConfirmationMessage: String {
        guard let place = placePendingDeletion else {
            return "This will remove the place."
        }

        let linkedRoutinesText: String
        if place.linkedRoutineCount == 1 {
            linkedRoutinesText = "1 linked routine will be unlinked"
        } else {
            linkedRoutinesText = "\(place.linkedRoutineCount) linked routines will be unlinked"
        }

        return "Delete \(place.name)? This cannot be undone, and \(linkedRoutinesText)."
    }

    var placeSelectionButtonTitle: String {
        placeDraftCoordinate == nil ? "Choose Location on Map" : "Edit Location on Map"
    }

    var placeDraftSelectionSummary: String {
        guard let coordinate = placeDraftCoordinate else {
            if lastKnownLocationCoordinate != nil {
                return "No location selected yet. The map will open near your current location."
            }
            return "No location selected yet. Open the map and tap where this place should be centered."
        }

        return "Selected center: \(coordinate.formattedForPlaceSelection) • \(Int(placeDraftRadiusMeters)) m radius"
    }

    var placeLocationHelpText: String {
        switch locationAuthorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "Choose a point on the map and adjust the radius. Routina will show place-based routines when you are inside that circle."
        case .notDetermined:
            return "Choose a point on the map and adjust the radius. Allow location access later so Routina can tell when you are inside the saved circle."
        case .disabled:
            return "Location services are disabled on this device. You can still save places, but Routina will not know when you are inside them."
        case .restricted, .denied:
            return "Location access is off. You can still save places, but place-linked routines stay visible until you enable location again."
        }
    }
}

func settingsPlaceSubtitle(for place: RoutinePlaceSummary) -> String {
    let linkedText = place.linkedRoutineCount == 1
        ? "1 linked routine"
        : "\(place.linkedRoutineCount) linked routines"
    return "\(Int(place.radiusMeters)) m radius • \(linkedText)"
}
