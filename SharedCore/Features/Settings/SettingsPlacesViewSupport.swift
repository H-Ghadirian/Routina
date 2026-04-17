import Foundation

extension SettingsPlacesState {
    var overviewSubtitle: String {
        switch savedPlaces.count {
        case 0:
            return "Save locations for place-based routines"
        case 1:
            return "1 saved place"
        default:
            return "\(savedPlaces.count) saved places"
        }
    }

    var hasDuplicateDraftName: Bool {
        guard let normalizedDraftName = RoutinePlace.normalizedName(placeDraftName) else {
            return false
        }

        return savedPlaces.contains { place in
            RoutinePlace.normalizedName(place.name) == normalizedDraftName
        }
    }

    var saveValidationMessage: String? {
        guard hasDuplicateDraftName else { return nil }
        return "A place with this name already exists."
    }

    var isSaveDisabled: Bool {
        isPlaceOperationInProgress || hasDuplicateDraftName
    }

    var deleteConfirmationMessage: String {
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

    var selectionButtonTitle: String {
        placeDraftCoordinate == nil ? "Choose Location on Map" : "Edit Location on Map"
    }

    var draftSelectionSummary: String {
        guard let coordinate = placeDraftCoordinate else {
            if lastKnownLocationCoordinate != nil {
                return "No location selected yet. The map will open near your current location."
            }
            return "No location selected yet. Open the map and tap where this place should be centered."
        }

        return "Selected center: \(coordinate.formattedForPlaceSelection) • \(Int(placeDraftRadiusMeters)) m radius"
    }

    var locationHelpText: String {
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

extension RoutinePlaceSummary {
    var settingsSubtitle: String {
        let linkedText = linkedRoutineCount == 1
            ? "1 linked routine"
            : "\(linkedRoutineCount) linked routines"
        return "\(Int(radiusMeters)) m radius • \(linkedText)"
    }
}

extension LocationCoordinate {
    var formattedForPlaceSelection: String {
        let latitude = latitude.formatted(.number.precision(.fractionLength(4)))
        let longitude = longitude.formatted(.number.precision(.fractionLength(4)))
        return "\(latitude), \(longitude)"
    }
}
