import Foundation
import SwiftData

struct CloudUsageEstimate: Equatable, Sendable {
    var taskCount: Int
    var logCount: Int
    var placeCount: Int
    var imageCount: Int
    var taskPayloadBytes: Int64
    var logPayloadBytes: Int64
    var placePayloadBytes: Int64
    var imagePayloadBytes: Int64

    static let zero = CloudUsageEstimate(
        taskCount: 0,
        logCount: 0,
        placeCount: 0,
        imageCount: 0,
        taskPayloadBytes: 0,
        logPayloadBytes: 0,
        placePayloadBytes: 0,
        imagePayloadBytes: 0
    )

    var totalPayloadBytes: Int64 {
        taskPayloadBytes + logPayloadBytes + placePayloadBytes + imagePayloadBytes
    }

    var totalRecordCount: Int {
        taskCount + logCount + placeCount
    }

    @MainActor
    static func estimate(in context: ModelContext) throws -> CloudUsageEstimate {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let encoder = JSONEncoder()

        let taskPayloadBytes = tasks.reduce(into: Int64.zero) { total, task in
            total += encodedByteCount(TaskPayload(task: task), encoder: encoder)
        }
        let logPayloadBytes = logs.reduce(into: Int64.zero) { total, log in
            total += encodedByteCount(LogPayload(log: log), encoder: encoder)
        }
        let placePayloadBytes = places.reduce(into: Int64.zero) { total, place in
            total += encodedByteCount(PlacePayload(place: place), encoder: encoder)
        }
        let imagePayloadBytes = tasks.reduce(into: Int64.zero) { total, task in
            total += Int64(task.imageData?.count ?? 0)
        }

        return CloudUsageEstimate(
            taskCount: tasks.count,
            logCount: logs.count,
            placeCount: places.count,
            imageCount: tasks.reduce(into: 0) { count, task in
                if task.imageData?.isEmpty == false {
                    count += 1
                }
            },
            taskPayloadBytes: taskPayloadBytes,
            logPayloadBytes: logPayloadBytes,
            placePayloadBytes: placePayloadBytes,
            imagePayloadBytes: imagePayloadBytes
        )
    }

    private static func encodedByteCount<T: Encodable>(_ value: T, encoder: JSONEncoder) -> Int64 {
        Int64((try? encoder.encode(value).count) ?? 0)
    }

    private struct TaskPayload: Encodable {
        var id: UUID
        var name: String?
        var emoji: String?
        var notes: String?
        var link: String?
        var deadline: Date?
        var priorityRawValue: String
        var importanceRawValue: String
        var urgencyRawValue: String
        var hasImage: Bool
        var placeID: UUID?
        var tagsStorage: String
        var stepsStorage: String
        var checklistItemsStorage: String
        var completedChecklistItemIDsStorage: String
        var relationshipsStorage: String
        var scheduleModeRawValue: String
        var recurrenceRuleStorage: String
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var pinnedAt: Date?
        var completedStepCount: Int16
        var sequenceStartedAt: Date?

        init(task: RoutineTask) {
            id = task.id
            name = task.name
            emoji = task.emoji
            notes = task.notes
            link = task.link
            deadline = task.deadline
            priorityRawValue = task.priorityRawValue
            importanceRawValue = task.importanceRawValue
            urgencyRawValue = task.urgencyRawValue
            hasImage = task.hasImage
            placeID = task.placeID
            tagsStorage = task.tagsStorage
            stepsStorage = task.stepsStorage
            checklistItemsStorage = task.checklistItemsStorage
            completedChecklistItemIDsStorage = task.completedChecklistItemIDsStorage
            relationshipsStorage = task.relationshipsStorage
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceRuleStorage = task.recurrenceRuleStorage
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            scheduleAnchor = task.scheduleAnchor
            pausedAt = task.pausedAt
            pinnedAt = task.pinnedAt
            completedStepCount = task.completedStepCount
            sequenceStartedAt = task.sequenceStartedAt
        }
    }

    private struct LogPayload: Encodable {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID

        init(log: RoutineLog) {
            id = log.id
            timestamp = log.timestamp
            taskID = log.taskID
        }
    }

    private struct PlacePayload: Encodable {
        var id: UUID
        var name: String
        var latitude: Double
        var longitude: Double
        var radiusMeters: Double
        var createdAt: Date

        init(place: RoutinePlace) {
            id = place.id
            name = place.name
            latitude = place.latitude
            longitude = place.longitude
            radiusMeters = place.radiusMeters
            createdAt = place.createdAt
        }
    }
}

extension SettingsFeatureState {
    var cloudUsageTotalText: String {
        ByteCountFormatter.string(fromByteCount: cloud.cloudUsageEstimate.totalPayloadBytes, countStyle: .file)
    }

    var cloudUsageTaskPayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloud.cloudUsageEstimate.taskPayloadBytes, countStyle: .file)
    }

    var cloudUsageLogPayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloud.cloudUsageEstimate.logPayloadBytes, countStyle: .file)
    }

    var cloudUsagePlacePayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloud.cloudUsageEstimate.placePayloadBytes, countStyle: .file)
    }

    var cloudUsageImagePayloadText: String {
        ByteCountFormatter.string(fromByteCount: cloud.cloudUsageEstimate.imagePayloadBytes, countStyle: .file)
    }

    var cloudUsageSummaryText: String {
        switch (cloud.cloudUsageEstimate.totalRecordCount, cloud.cloudUsageEstimate.imageCount) {
        case (0, 0):
            return cloud.cloudSyncAvailable
                ? "No Routina data is estimated to be using iCloud yet."
                : "No Routina data is available to estimate yet."
        case let (recordCount, 0):
            return "\(recordCount) synced records are included in this estimate."
        case let (recordCount, imageCount):
            return "\(recordCount) synced records and \(imageCount) image\(imageCount == 1 ? "" : "s") are included in this estimate."
        }
    }

    var cloudUsageFootnoteText: String {
        "Estimate based on local Routina data. Actual iCloud storage can be higher because CloudKit adds its own metadata and history."
    }

    var notificationsOverviewSubtitle: String {
        if notifications.notificationsEnabled {
            let time = notifications.notificationReminderTime.formatted(date: .omitted, time: .shortened)
            return "Daily reminder at \(time)"
        }
        if notifications.systemSettingsNotificationsEnabled == false {
            return "Disabled in System Settings"
        }
        return "Routine reminders are turned off"
    }

    var placesOverviewSubtitle: String {
        switch places.savedPlaces.count {
        case 0:
            return "Save locations for place-based routines"
        case 1:
            return "1 saved place"
        default:
            return "\(places.savedPlaces.count) saved places"
        }
    }

    var appearanceOverviewSubtitle: String {
        "Icon: \(appearance.selectedAppIcon.title) • List: \(appearance.routineListSectioningMode.summaryText) • Tags: \(appearance.tagCounterDisplayMode.summaryText)"
    }

    var cloudOverviewSubtitle: String {
        if cloud.isCloudSyncInProgress {
            return "Syncing with iCloud"
        }
        if cloud.isCloudDataResetInProgress {
            return "Deleting iCloud data"
        }
        if !cloud.cloudStatusMessage.isEmpty {
            return cloud.cloudStatusMessage
        }
        if !cloud.cloudSyncAvailable {
            return "Unavailable in this build"
        }
        return "Sync routines across devices"
    }

    var backupOverviewSubtitle: String {
        if dataTransfer.isDataTransferInProgress {
            return "Importing or exporting JSON"
        }
        if !dataTransfer.dataTransferStatusMessage.isEmpty {
            return dataTransfer.dataTransferStatusMessage
        }
        return "Export or import your routine data"
    }

    var aboutOverviewSubtitle: String {
        if diagnostics.isDebugSectionVisible {
            return "Version \(diagnostics.appVersion) • Diagnostics unlocked"
        }
        if diagnostics.appVersion.isEmpty {
            return "App details"
        }
        return "Version \(diagnostics.appVersion)"
    }

    var hasDuplicatePlaceDraftName: Bool {
        guard let normalizedDraftName = RoutinePlace.normalizedName(places.placeDraftName) else {
            return false
        }

        return places.savedPlaces.contains { place in
            RoutinePlace.normalizedName(place.name) == normalizedDraftName
        }
    }

    var savePlaceValidationMessage: String? {
        guard hasDuplicatePlaceDraftName else { return nil }
        return "A place with this name already exists."
    }

    var isSavePlaceDisabled: Bool {
        places.isPlaceOperationInProgress || hasDuplicatePlaceDraftName
    }

    var syncStatusText: String {
        if cloud.isCloudDataResetInProgress {
            return "Deleting iCloud data..."
        }
        if cloud.isCloudSyncInProgress {
            return "Syncing..."
        }
        if !cloud.cloudStatusMessage.isEmpty {
            return cloud.cloudStatusMessage
        }
        if !cloud.cloudSyncAvailable {
            return "iCloud sync is disabled in this build."
        }
        return "Ready to sync."
    }

    var dataTransferStatusText: String {
        if dataTransfer.isDataTransferInProgress {
            return "Processing JSON file..."
        }
        if !dataTransfer.dataTransferStatusMessage.isEmpty {
            return dataTransfer.dataTransferStatusMessage
        }
        return "Export or import all routine data as JSON."
    }

    var tagsOverviewSubtitle: String {
        switch tags.savedTags.count {
        case 0:
            return "Review and manage tags across routines"
        case 1:
            return "1 saved tag"
        default:
            return "\(tags.savedTags.count) saved tags"
        }
    }

    var deletePlaceConfirmationMessage: String {
        guard let place = places.placePendingDeletion else {
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
        guard let tag = tags.tagPendingDeletion else {
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
            !tags.isTagOperationInProgress,
            let cleanedTagName = RoutineTag.cleaned(tags.tagRenameDraft)
        else {
            return true
        }

        guard let pendingTag = tags.tagPendingRename else { return false }
        return cleanedTagName == pendingTag.name
    }

    var placeSelectionButtonTitle: String {
        places.placeDraftCoordinate == nil ? "Choose Location on Map" : "Edit Location on Map"
    }

    var placeDraftSelectionSummary: String {
        guard let coordinate = places.placeDraftCoordinate else {
            if places.lastKnownLocationCoordinate != nil {
                return "No location selected yet. The map will open near your current location."
            }
            return "No location selected yet. Open the map and tap where this place should be centered."
        }

        return "Selected center: \(coordinate.formattedForPlaceSelection) • \(Int(places.placeDraftRadiusMeters)) m radius"
    }

    var placeLocationHelpText: String {
        switch places.locationAuthorizationStatus {
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
        appearance.routineListSectioningMode.subtitle
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
