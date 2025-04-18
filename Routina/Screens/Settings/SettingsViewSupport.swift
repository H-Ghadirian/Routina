import Foundation

enum RoutineListSectioningMode: String, CaseIterable, Equatable, Identifiable {
    case status
    case deadlineDate

    static let defaultValue: Self = .status

    var id: Self { self }

    var title: String {
        switch self {
        case .status:
            return "Status"
        case .deadlineDate:
            return "Deadline Date"
        }
    }

    var subtitle: String {
        switch self {
        case .status:
            return "Shows Due Soon, On Track, and Done Today."
        case .deadlineDate:
            return "Keeps Due Soon, then groups the rest by deadline date."
        }
    }

    var summaryText: String {
        switch self {
        case .status:
            return "Status"
        case .deadlineDate:
            return "Deadline Date"
        }
    }
}

extension SettingsFeature.State {
    var hasDuplicatePlaceDraftName: Bool {
        guard let normalizedDraftName = RoutinePlace.normalizedName(placeDraftName) else {
            return false
        }

        return savedPlaces.contains { place in
            RoutinePlace.normalizedName(place.name) == normalizedDraftName
        }
    }

    var savePlaceValidationMessage: String? {
        guard hasDuplicatePlaceDraftName else { return nil }
        return "A place with this name already exists."
    }

    var isSavePlaceDisabled: Bool {
        isPlaceOperationInProgress || hasDuplicatePlaceDraftName
    }

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

    var tagsOverviewSubtitle: String {
        switch savedTags.count {
        case 0:
            return "Review and manage tags across routines"
        case 1:
            return "1 saved tag"
        default:
            return "\(savedTags.count) saved tags"
        }
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

    var deleteTagConfirmationMessage: String {
        guard let tag = tagPendingDeletion else {
            return "This will remove the tag from every routine that uses it."
        }

        let linkedRoutinesText: String
        if tag.linkedRoutineCount == 1 {
            linkedRoutinesText = "1 routine will lose it"
        } else {
            linkedRoutinesText = "\(tag.linkedRoutineCount) routines will lose it"
        }

        return "Delete \(tag.name)? This cannot be undone, and \(linkedRoutinesText)."
    }

    var isSaveTagRenameDisabled: Bool {
        guard
            !isTagOperationInProgress,
            let cleanedTagName = RoutineTag.cleaned(tagRenameDraft)
        else {
            return true
        }

        guard let pendingTag = tagPendingRename else { return false }
        return cleanedTagName == pendingTag.name
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

    var routineListSectioningSubtitle: String {
        routineListSectioningMode.subtitle
    }
}

func settingsPlaceSubtitle(for place: RoutinePlaceSummary) -> String {
    let linkedText = place.linkedRoutineCount == 1
        ? "1 linked routine"
        : "\(place.linkedRoutineCount) linked routines"
    return "\(Int(place.radiusMeters)) m radius • \(linkedText)"
}

func settingsTagSubtitle(for tag: RoutineTagSummary) -> String {
    tag.linkedRoutineCount == 1
        ? "Used by 1 routine"
        : "Used by \(tag.linkedRoutineCount) routines"
}

extension LocationCoordinate {
    var formattedForPlaceSelection: String {
        let latitude = latitude.formatted(.number.precision(.fractionLength(4)))
        let longitude = longitude.formatted(.number.precision(.fractionLength(4)))
        return "\(latitude), \(longitude)"
    }
}
