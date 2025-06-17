import CloudKit
import ComposableArchitecture
import SwiftData
import SwiftUI
import UserNotifications

@Reducer
struct SettingsFeature {
    typealias State = SettingsFeatureState

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case routineListSectioningModeChanged(RoutineListSectioningMode)
        case tagCounterDisplayModeChanged(TagCounterDisplayMode)
        case notificationAuthorizationFinished(Bool)
        case notificationReminderTimeChanged(Date)
        case openAppSettingsTapped
        case onAppear
        case tagManagerAppeared
        case onAppBecameActive
        case contactUsTapped
        case aboutSectionLongPressed
        case systemNotificationPermissionChecked(Bool)
        case cloudDiagnosticsUpdated
        case cloudUsageEstimateLoaded(CloudUsageEstimate)
        case syncNowTapped
        case setCloudDataResetConfirmation(Bool)
        case resetCloudDataConfirmed
        case setDeletePlaceConfirmation(Bool)
        case setDeleteTagConfirmation(Bool)
        case setTagRenameSheet(Bool)
        case placesLoaded([RoutinePlaceSummary])
        case tagsLoaded([RoutineTagSummary])
        case locationSnapshotUpdated(LocationSnapshot)
        case placeDraftNameChanged(String)
        case tagRenameDraftChanged(String)
        case placeDraftCoordinateChanged(LocationCoordinate?)
        case placeDraftRadiusChanged(Double)
        case savePlaceTapped
        case renameTagTapped(String)
        case saveTagRenameTapped
        case deletePlaceTapped(UUID)
        case deleteTagTapped(String)
        case deletePlaceConfirmed
        case deleteTagConfirmed
        case placeOperationFinished(success: Bool, message: String)
        case tagOperationFinished(success: Bool, message: String)
        case exportRoutineDataTapped
        case importRoutineDataTapped
        case appIconSelected(AppIconOption)
        case resetTemporaryViewStateTapped
        case appIconChangeFinished(requestedOption: AppIconOption, errorMessage: String?)
        case routineDataTransferFinished(success: Bool, message: String)
        case cloudSyncFinished(success: Bool, message: String)
        case cloudDataResetFinished(success: Bool, message: String)
    }

    @Dependency(\.modelContext) var modelContext
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.appIconClient) var appIconClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.appInfoClient) var appInfoClient
    @Dependency(\.urlOpenerClient) var urlOpenerClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.routineDataTransferClient) var routineDataTransferClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .routineListSectioningModeChanged(mode):
                state.appearance.routineListSectioningMode = mode
                appSettingsClient.setRoutineListSectioningMode(mode)
                return .none

            case let .tagCounterDisplayModeChanged(mode):
                state.appearance.tagCounterDisplayMode = mode
                appSettingsClient.setTagCounterDisplayMode(mode)
                return .none

            case .resetTemporaryViewStateTapped:
                appSettingsClient.resetTemporaryViewState()
                state.appearance.hasTemporaryViewStateToReset = false
                state.appearance.temporaryViewStateStatusMessage = "Saved filters and temporary selections were reset."
                return .none

            case .toggleNotifications(let isOn):
                guard isOn else {
                    state.notifications.notificationsEnabled = false
                    appSettingsClient.setNotificationsEnabled(false)
                    return .run { _ in
                        await self.notificationClient.cancelAll()
                    }
                }

                return .run { send in
                    let granted = await self.notificationClient.requestAuthorizationIfNeeded()
                    await send(.notificationAuthorizationFinished(granted))
                }

            case .notificationAuthorizationFinished(let isGranted):
                state.notifications.notificationsEnabled = isGranted
                state.notifications.systemSettingsNotificationsEnabled = isGranted
                appSettingsClient.setNotificationsEnabled(isGranted)

                guard isGranted else { return .none }
                return .run { @MainActor _ in
                    try? await self.rescheduleNotificationsIfNeeded(in: self.modelContext())
                }

            case .notificationReminderTimeChanged(let reminderTime):
                state.notifications.notificationReminderTime = reminderTime
                appSettingsClient.setNotificationReminderTime(reminderTime)

                guard state.notifications.notificationsEnabled else { return .none }
                return .run { @MainActor _ in
                    try? await self.rescheduleNotificationsIfNeeded(in: self.modelContext())
                }

            case .openAppSettingsTapped:
                if let url = urlOpenerClient.notificationSettingsURL() {
                    return .run { @MainActor _ in
                        self.urlOpenerClient.open(url)
                    }
                }
                return .none

            case .onAppear:
                state.diagnostics.appVersion = appInfoClient.versionString()
                state.diagnostics.dataModeDescription = appInfoClient.dataModeDescription()
                state.diagnostics.iCloudContainerDescription = appInfoClient.cloudContainerDescription()
                state.cloud.cloudSyncAvailable = appInfoClient.isCloudSyncEnabled()
                state.notifications.notificationsEnabled = appSettingsClient.notificationsEnabled()
                state.diagnostics.isDebugSectionVisible = false
                state.notifications.notificationReminderTime = appSettingsClient.notificationReminderTime()
                state.appearance.routineListSectioningMode = appSettingsClient.routineListSectioningMode()
                state.appearance.tagCounterDisplayMode = appSettingsClient.tagCounterDisplayMode()
                state.appearance.selectedAppIcon = appSettingsClient.selectedAppIcon()
                state.appearance.hasTemporaryViewStateToReset = hasTemporaryViewStateToReset()
                state.appearance.appIconStatusMessage = ""
                state.appearance.temporaryViewStateStatusMessage = ""
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.diagnostics.cloudDiagnosticsSummary = diagnostics.summary
                state.diagnostics.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.diagnostics.pushDiagnosticsStatus = diagnostics.pushStatus
                return .run { @MainActor send in
                    let context = self.modelContext()
                    let systemEnabled = await self.notificationClient.systemNotificationsAuthorized()
                    send(.systemNotificationPermissionChecked(systemEnabled))
                    send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                    let placeSummaries = try? self.fetchPlaceSummaries(in: context)
                    send(.placesLoaded(placeSummaries ?? []))
                    let tagSummaries = try? self.fetchTagSummaries(in: context)
                    send(.tagsLoaded(tagSummaries ?? []))
                    let locationSnapshot = await self.locationClient.snapshot(false)
                    send(.locationSnapshotUpdated(locationSnapshot))
                }

            case .tagManagerAppeared:
                return .run { @MainActor send in
                    let tagSummaries = try? self.fetchTagSummaries(in: self.modelContext())
                    send(.tagsLoaded(tagSummaries ?? []))
                }

            case .contactUsTapped:
                if let emailURL = URL(string: "mailto:h.qadirian@gmail.com") {
                    return .run { @MainActor _ in
                        self.urlOpenerClient.open(emailURL)
                    }
                }
                return .none

            case .aboutSectionLongPressed:
                state.diagnostics.isDebugSectionVisible = true
                return .none

            case let .systemNotificationPermissionChecked(value):
                state.notifications.systemSettingsNotificationsEnabled = value
                return .none

            case .cloudDiagnosticsUpdated:
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                state.diagnostics.cloudDiagnosticsSummary = diagnostics.summary
                state.diagnostics.cloudDiagnosticsTimestamp = diagnostics.timestampText
                state.diagnostics.pushDiagnosticsStatus = diagnostics.pushStatus
                return .none

            case let .cloudUsageEstimateLoaded(estimate):
                state.cloud.cloudUsageEstimate = estimate
                return .none

            case .onAppBecameActive:
                let notificationsEnabled = state.notifications.notificationsEnabled
                state.appearance.hasTemporaryViewStateToReset = hasTemporaryViewStateToReset()
                return .run { @MainActor send in
                    let context = self.modelContext()
                    let systemEnabled = await self.notificationClient.systemNotificationsAuthorized()
                    send(.systemNotificationPermissionChecked(systemEnabled))
                    send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                    let placeSummaries = try? self.fetchPlaceSummaries(in: context)
                    send(.placesLoaded(placeSummaries ?? []))
                    let tagSummaries = try? self.fetchTagSummaries(in: context)
                    send(.tagsLoaded(tagSummaries ?? []))
                    let locationSnapshot = await self.locationClient.snapshot(false)
                    send(.locationSnapshotUpdated(locationSnapshot))
                    if notificationsEnabled {
                        if systemEnabled {
                            try? await self.rescheduleNotificationsIfNeeded(in: context)
                        } else {
                            await self.notificationClient.cancelAll()
                        }
                    }
                }

            case .syncNowTapped:
                guard !state.cloud.isCloudDataResetInProgress else {
                    return .none
                }
                guard state.cloud.cloudSyncAvailable else {
                    state.cloud.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.cloud.isCloudSyncInProgress = true
                state.cloud.cloudStatusMessage = "Syncing with iCloud..."
                return .run { @MainActor send in
                    do {
                        let context = modelContext()
                        if context.hasChanges {
                            try context.save()
                        }
                        try await self.cloudSyncClient.pullLatestIntoLocalStore(context)
                        send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                        NotificationCenter.default.postRoutineDidUpdate()
                        await send(
                            .cloudSyncFinished(
                                success: true,
                                message: "Sync completed."
                            )
                        )
                    } catch {
                        await send(
                            .cloudSyncFinished(
                                success: false,
                                message: "Sync failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case let .setCloudDataResetConfirmation(isPresented):
                state.cloud.isCloudDataResetConfirmationPresented = isPresented
                return .none

            case .resetCloudDataConfirmed:
                state.cloud.isCloudDataResetConfirmationPresented = false

                guard !state.cloud.isCloudSyncInProgress,
                      !state.cloud.isCloudDataResetInProgress
                else {
                    return .none
                }

                guard state.cloud.cloudSyncAvailable,
                      let cloudContainerIdentifier = AppEnvironment.cloudKitContainerIdentifier
                else {
                    state.cloud.cloudStatusMessage = "iCloud sync is disabled in this build."
                    return .none
                }

                state.cloud.isCloudDataResetInProgress = true
                state.cloud.cloudStatusMessage = "Deleting iCloud data..."
                return .run { @MainActor send in
                    do {
                        try await CloudDataResetService.resetAllUserData(
                            cloudKitContainerIdentifier: cloudContainerIdentifier,
                            modelContext: modelContext()
                        )
                        let refreshedContext = modelContext()
                        send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: refreshedContext)))
                        NotificationCenter.default.postRoutineDidUpdate()
                        await send(
                            .cloudDataResetFinished(
                                success: true,
                                message: "All Routina data was deleted from iCloud and this device."
                            )
                        )
                    } catch {
                        await send(
                            .cloudDataResetFinished(
                                success: false,
                                message: cloudDataResetErrorMessage(for: error)
                            )
                        )
                    }
                }

            case let .setDeletePlaceConfirmation(isPresented):
                state.places.isDeletePlaceConfirmationPresented = isPresented
                if !isPresented {
                    state.places.placePendingDeletion = nil
                }
                return .none

            case let .setDeleteTagConfirmation(isPresented):
                state.tags.isDeleteTagConfirmationPresented = isPresented
                if !isPresented {
                    state.tags.tagPendingDeletion = nil
                }
                return .none

            case let .setTagRenameSheet(isPresented):
                state.tags.isTagRenameSheetPresented = isPresented
                if !isPresented {
                    state.tags.tagPendingRename = nil
                    state.tags.tagRenameDraft = ""
                }
                return .none

            case let .placesLoaded(places):
                state.places.savedPlaces = places
                if let pendingPlace = state.places.placePendingDeletion,
                   let updatedPlace = places.first(where: { $0.id == pendingPlace.id }) {
                    state.places.placePendingDeletion = updatedPlace
                }
                return .none

            case let .tagsLoaded(tags):
                state.tags.savedTags = tags
                if let pendingTag = state.tags.tagPendingDeletion,
                   let updatedTag = self.tagSummary(named: pendingTag.name, in: tags) {
                    state.tags.tagPendingDeletion = updatedTag
                }
                if let pendingTag = state.tags.tagPendingRename,
                   let updatedTag = self.tagSummary(named: pendingTag.name, in: tags) {
                    state.tags.tagPendingRename = updatedTag
                }
                return .none

            case let .locationSnapshotUpdated(snapshot):
                state.places.locationAuthorizationStatus = snapshot.authorizationStatus
                if let coordinate = snapshot.coordinate {
                    state.places.lastKnownLocationCoordinate = coordinate
                }
                return .none

            case let .placeDraftNameChanged(name):
                state.places.placeDraftName = name
                state.places.placeStatusMessage = ""
                return .none

            case let .tagRenameDraftChanged(name):
                state.tags.tagRenameDraft = name
                state.tags.tagStatusMessage = ""
                return .none

            case let .placeDraftCoordinateChanged(coordinate):
                state.places.placeDraftCoordinate = coordinate
                state.places.placeStatusMessage = ""
                return .none

            case let .placeDraftRadiusChanged(radius):
                state.places.placeDraftRadiusMeters = min(max(radius, 25), 2_000)
                state.places.placeStatusMessage = ""
                return .none

            case let .renameTagTapped(tagName):
                guard !state.tags.isTagOperationInProgress,
                      let tag = self.tagSummary(named: tagName, in: state.tags.savedTags)
                else {
                    return .none
                }

                state.tags.tagPendingRename = tag
                state.tags.tagRenameDraft = tag.name
                state.tags.tagStatusMessage = ""
                state.tags.isTagRenameSheetPresented = true
                return .none

            case .savePlaceTapped:
                let cleanedName = RoutinePlace.cleanedName(state.places.placeDraftName)
                guard let cleanedName else {
                    state.places.placeStatusMessage = "Enter a place name first."
                    return .none
                }
                guard let coordinate = state.places.placeDraftCoordinate else {
                    state.places.placeStatusMessage = "Choose a location on the map first."
                    return .none
                }
                guard !state.places.isPlaceOperationInProgress else {
                    return .none
                }

                state.places.isPlaceOperationInProgress = true
                state.places.placeStatusMessage = ""
                let radiusMeters = state.places.placeDraftRadiusMeters

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        if try self.hasDuplicatePlaceName(cleanedName, in: context) {
                            send(
                                .placeOperationFinished(
                                    success: false,
                                    message: "A place with this name already exists."
                                )
                            )
                            return
                        }

                        context.insert(
                            RoutinePlace(
                                name: cleanedName,
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                radiusMeters: radiusMeters
                            )
                        )
                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        let summaries = try self.fetchPlaceSummaries(in: context)
                        send(.placesLoaded(summaries))
                        send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                        send(
                            .placeOperationFinished(
                                success: true,
                                message: "Saved \(cleanedName)."
                            )
                        )
                    } catch {
                        send(
                            .placeOperationFinished(
                                success: false,
                                message: "Saving place failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case .saveTagRenameTapped:
                guard !state.tags.isTagOperationInProgress else {
                    return .none
                }
                guard let pendingTag = state.tags.tagPendingRename else {
                    return .none
                }
                guard let cleanedName = RoutineTag.cleaned(state.tags.tagRenameDraft) else {
                    state.tags.tagStatusMessage = "Enter a tag name first."
                    return .none
                }

                state.tags.isTagRenameSheetPresented = false
                state.tags.tagPendingRename = nil
                state.tags.tagRenameDraft = ""
                state.tags.isTagOperationInProgress = true
                state.tags.tagStatusMessage = ""
                let originalTagName = pendingTag.name

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        var updatedRoutineCount = 0

                        for task in tasks where RoutineTag.contains(originalTagName, in: task.tags) {
                            let updatedTags = RoutineTag.replacing(
                                originalTagName,
                                with: cleanedName,
                                in: task.tags
                            )
                            if updatedTags != task.tags {
                                task.tags = updatedTags
                                updatedRoutineCount += 1
                            }
                        }

                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        NotificationCenter.default.postRoutineTagDidRename(from: originalTagName, to: cleanedName)
                        let summaries = try self.fetchTagSummaries(in: context)
                        send(.tagsLoaded(summaries))
                        send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                        send(
                            .tagOperationFinished(
                                success: true,
                                message: self.renameTagSuccessMessage(
                                    updatedTagName: cleanedName,
                                    updatedRoutineCount: updatedRoutineCount
                                )
                            )
                        )
                    } catch {
                        send(
                            .tagOperationFinished(
                                success: false,
                                message: "Updating tag failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case let .deletePlaceTapped(placeID):
                guard !state.places.isPlaceOperationInProgress else {
                    return .none
                }

                guard let place = state.places.savedPlaces.first(where: { $0.id == placeID }) else {
                    return .none
                }

                state.places.placePendingDeletion = place
                state.places.isDeletePlaceConfirmationPresented = true
                return .none

            case let .deleteTagTapped(tagName):
                guard !state.tags.isTagOperationInProgress,
                      let tag = self.tagSummary(named: tagName, in: state.tags.savedTags)
                else {
                    return .none
                }

                state.tags.tagPendingDeletion = tag
                state.tags.tagStatusMessage = ""
                state.tags.isDeleteTagConfirmationPresented = true
                return .none

            case .deletePlaceConfirmed:
                guard !state.places.isPlaceOperationInProgress else {
                    return .none
                }
                guard let pendingPlace = state.places.placePendingDeletion else {
                    return .none
                }

                state.places.isDeletePlaceConfirmationPresented = false
                state.places.placePendingDeletion = nil
                state.places.isPlaceOperationInProgress = true
                state.places.placeStatusMessage = ""
                let placeID = pendingPlace.id

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let placeDescriptor = FetchDescriptor<RoutinePlace>(
                            predicate: #Predicate { place in
                                place.id == placeID
                            }
                        )

                        if let place = try context.fetch(placeDescriptor).first {
                            context.delete(place)
                        }

                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        for task in tasks where task.placeID == placeID {
                            task.placeID = nil
                        }

                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        let summaries = try self.fetchPlaceSummaries(in: context)
                        send(.placesLoaded(summaries))
                        send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                        send(.placeOperationFinished(success: true, message: "Place deleted."))
                    } catch {
                        send(
                            .placeOperationFinished(
                                success: false,
                                message: "Deleting place failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case .deleteTagConfirmed:
                guard !state.tags.isTagOperationInProgress else {
                    return .none
                }
                guard let pendingTag = state.tags.tagPendingDeletion else {
                    return .none
                }

                state.tags.isDeleteTagConfirmationPresented = false
                state.tags.tagPendingDeletion = nil
                state.tags.isTagOperationInProgress = true
                state.tags.tagStatusMessage = ""
                let tagName = pendingTag.name

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        var updatedRoutineCount = 0

                        for task in tasks where RoutineTag.contains(tagName, in: task.tags) {
                            let updatedTags = RoutineTag.removing(tagName, from: task.tags)
                            if updatedTags != task.tags {
                                task.tags = updatedTags
                                updatedRoutineCount += 1
                            }
                        }

                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                        NotificationCenter.default.postRoutineTagDidDelete(tagName)
                        let summaries = try self.fetchTagSummaries(in: context)
                        send(.tagsLoaded(summaries))
                        send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                        send(
                            .tagOperationFinished(
                                success: true,
                                message: self.deleteTagSuccessMessage(
                                    deletedTagName: tagName,
                                    updatedRoutineCount: updatedRoutineCount
                                )
                            )
                        )
                    } catch {
                        send(
                            .tagOperationFinished(
                                success: false,
                                message: "Deleting tag failed: \(error.localizedDescription)"
                            )
                        )
                    }
                }

            case let .placeOperationFinished(success, message):
                state.places.isPlaceOperationInProgress = false
                state.places.placeStatusMessage = message
                if success {
                    state.places.placeDraftName = ""
                    state.places.placeDraftCoordinate = nil
                }
                return .none

            case let .tagOperationFinished(_, message):
                state.tags.isTagOperationInProgress = false
                state.tags.tagStatusMessage = message
                return .none

            case .exportRoutineDataTapped:
                return handleExportRoutineDataTapped(state: &state)

            case .importRoutineDataTapped:
                return handleImportRoutineDataTapped(state: &state)

            case let .appIconSelected(option):
                state.appearance.appIconStatusMessage = ""
                return .run { send in
                    let errorMessage = await self.appIconClient.requestChange(option)
                    await send(.appIconChangeFinished(requestedOption: option, errorMessage: errorMessage))
                }

            case let .appIconChangeFinished(option, errorMessage):
                if let errorMessage {
                    state.appearance.appIconStatusMessage = "App icon update failed: \(errorMessage)"
                } else {
                    state.appearance.selectedAppIcon = option
                    AppIconOption.persist(option)
                }
                return .none

            case let .routineDataTransferFinished(_, message):
                state.dataTransfer.isDataTransferInProgress = false
                state.dataTransfer.dataTransferStatusMessage = message
                return .none

            case let .cloudSyncFinished(_, message):
                state.cloud.isCloudSyncInProgress = false
                state.cloud.cloudStatusMessage = message
                return .none

            case let .cloudDataResetFinished(_, message):
                state.cloud.isCloudDataResetInProgress = false
                state.cloud.cloudStatusMessage = message
                return .none
            }
        }
    }

    private func cloudDataResetErrorMessage(for error: Error) -> String {
        guard let cloudError = error as? CKError else {
            return "Data reset failed: \(error.localizedDescription)"
        }

        switch cloudError.code {
        case .notAuthenticated:
            return "Please sign in to iCloud and try again."
        case .networkUnavailable, .networkFailure:
            return "Network issue while deleting iCloud data. Please try again."
        case .serviceUnavailable, .requestRateLimited:
            return "iCloud is temporarily unavailable. Please try again shortly."
        default:
            return "Data reset failed: \(cloudError.localizedDescription)"
        }
    }

    private func handleExportRoutineDataTapped(state: inout State) -> Effect<Action> {
        guard !state.dataTransfer.isDataTransferInProgress else {
            return .none
        }

        state.dataTransfer.isDataTransferInProgress = true
        state.dataTransfer.dataTransferStatusMessage = "Saving routine data..."
        return .run { @MainActor send in
            do {
                guard let destinationURL = await self.routineDataTransferClient.selectExportURL(
                    self.defaultRoutineDataBackupFileName()
                ) else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Save canceled."
                        )
                    )
                    return
                }

                let context = self.modelContext()
                if context.hasChanges {
                    try context.save()
                }

                let backupData = try self.buildRoutineDataBackupJSON(from: context)
                try self.withSecurityScopedAccess(to: destinationURL) {
                    try backupData.write(to: destinationURL, options: .atomic)
                }

                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Saved to \(destinationURL.lastPathComponent)."
                    )
                )
            } catch {
                await send(
                    .routineDataTransferFinished(
                        success: false,
                        message: "Save failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }

    private func handleImportRoutineDataTapped(state: inout State) -> Effect<Action> {
        guard !state.dataTransfer.isDataTransferInProgress else {
            return .none
        }

        state.dataTransfer.isDataTransferInProgress = true
        state.dataTransfer.dataTransferStatusMessage = "Loading routine data..."
        return .run { @MainActor send in
            do {
                guard let sourceURL = await self.routineDataTransferClient.selectImportURL() else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Load canceled."
                        )
                    )
                    return
                }

                let jsonData = try self.withSecurityScopedAccess(to: sourceURL) {
                    try Data(contentsOf: sourceURL)
                }
                let context = self.modelContext()
                let importedSummary = try self.replaceAllRoutineData(with: jsonData, in: context)
                try await self.rescheduleNotificationsAfterImport(in: context)

                send(.cloudUsageEstimateLoaded(self.loadCloudUsageEstimate(in: context)))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Loaded \(importedSummary.tasks) routines, \(importedSummary.places) places, and \(importedSummary.logs) logs."
                    )
                )
            } catch {
                await send(
                    .routineDataTransferFinished(
                        success: false,
                        message: "Load failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }

    @MainActor
    private func fetchPlaceSummaries(in context: ModelContext) throws -> [RoutinePlaceSummary] {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return RoutinePlace.summaries(from: places, linkedTo: tasks)
    }

    @MainActor
    func loadCloudUsageEstimate(in context: ModelContext) -> CloudUsageEstimate {
        (try? CloudUsageEstimate.estimate(in: context)) ?? .zero
    }

    @MainActor
    private func fetchTagSummaries(in context: ModelContext) throws -> [RoutineTagSummary] {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return RoutineTag.summaries(from: tasks)
    }

    private func hasDuplicatePlaceName(_ name: String, in context: ModelContext) throws -> Bool {
        guard let normalizedName = RoutinePlace.normalizedName(name) else { return false }
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        return places.contains { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }
    }

    private func tagSummary(named name: String, in tags: [RoutineTagSummary]) -> RoutineTagSummary? {
        guard let normalizedTagName = RoutineTag.normalized(name) else { return nil }
        return tags.first { RoutineTag.normalized($0.name) == normalizedTagName }
    }

    private func renameTagSuccessMessage(updatedTagName: String, updatedRoutineCount: Int) -> String {
        switch updatedRoutineCount {
        case ..<1:
            return "Updated tag to \(updatedTagName)."
        case 1:
            return "Updated tag to \(updatedTagName) in 1 routine."
        default:
            return "Updated tag to \(updatedTagName) in \(updatedRoutineCount) routines."
        }
    }

    private func deleteTagSuccessMessage(deletedTagName: String, updatedRoutineCount: Int) -> String {
        switch updatedRoutineCount {
        case ..<1:
            return "Deleted \(deletedTagName)."
        case 1:
            return "Deleted \(deletedTagName) from 1 routine."
        default:
            return "Deleted \(deletedTagName) from \(updatedRoutineCount) routines."
        }
    }

    private struct RoutineDataBackup: Codable {
        var schemaVersion: Int
        var exportedAt: Date
        var places: [Place]?
        var tasks: [Task]
        var logs: [Log]

        struct Place: Codable {
            var id: UUID
            var name: String
            var latitude: Double
            var longitude: Double
            var radiusMeters: Double
            var createdAt: Date?
        }

        struct Task: Codable {
            var id: UUID
            var name: String?
            var emoji: String?
            var notes: String?
            var link: String?
            var deadline: Date?
            var imageData: Data?
            var placeID: UUID?
            var tags: [String]?
            var steps: [RoutineStep]?
            var checklistItems: [RoutineChecklistItem]?
            var scheduleMode: RoutineScheduleMode?
            var interval: Int
            var recurrenceRule: RoutineRecurrenceRule?
            var lastDone: Date?
            var canceledAt: Date?
            var scheduleAnchor: Date?
            var pausedAt: Date?
            var pinnedAt: Date?
            var completedStepCount: Int?
            var sequenceStartedAt: Date?
        }

        struct Log: Codable {
            var id: UUID
            var timestamp: Date?
            var taskID: UUID
            var kind: RoutineLogKind?
        }
    }

    struct ImportSummary {
        var places: Int
        var tasks: Int
        var logs: Int
    }

    private enum RoutineDataTransferError: LocalizedError {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedSchema(version):
                return "Unsupported backup format version: \(version)."
            }
        }
    }

    func defaultRoutineDataBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "routina-backup-\(formatter.string(from: Date())).json"
    }

    @MainActor
    func buildRoutineDataBackupJSON(from context: ModelContext) throws -> Data {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        let backup = RoutineDataBackup(
            schemaVersion: 10,
            exportedAt: Date(),
            places: places.map {
                .init(
                    id: $0.id,
                    name: $0.displayName,
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    radiusMeters: $0.radiusMeters,
                    createdAt: $0.createdAt
                )
            },
            tasks: tasks.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    emoji: $0.emoji,
                    notes: $0.notes,
                    link: $0.link,
                    deadline: $0.deadline,
                    imageData: $0.imageData,
                    placeID: $0.placeID,
                    tags: $0.tags,
                    steps: $0.steps,
                    checklistItems: $0.checklistItems,
                    scheduleMode: $0.scheduleMode,
                    interval: max(Int($0.interval), 1),
                    recurrenceRule: $0.recurrenceRule,
                    lastDone: $0.lastDone,
                    canceledAt: $0.canceledAt,
                    scheduleAnchor: $0.scheduleAnchor,
                    pausedAt: $0.pausedAt,
                    pinnedAt: $0.pinnedAt,
                    completedStepCount: $0.completedSteps,
                    sequenceStartedAt: $0.sequenceStartedAt
                )
            },
            logs: logs.map {
                .init(
                    id: $0.id,
                    timestamp: $0.timestamp,
                    taskID: $0.taskID,
                    kind: $0.kind
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    @MainActor
    func replaceAllRoutineData(
        with jsonData: Data,
        in context: ModelContext
    ) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(RoutineDataBackup.self, from: jsonData)

        guard (1...10).contains(backup.schemaVersion) else {
            throw RoutineDataTransferError.unsupportedSchema(backup.schemaVersion)
        }

        do {
            let existingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
            for log in existingLogs {
                context.delete(log)
            }

            let existingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
            for task in existingTasks {
                context.delete(task)
            }

            let existingPlaces = try context.fetch(FetchDescriptor<RoutinePlace>())
            for place in existingPlaces {
                context.delete(place)
            }

            var importedPlaceIDs = Set<UUID>()
            var importedPlaceCount = 0
            for place in backup.places ?? [] {
                guard importedPlaceIDs.insert(place.id).inserted else { continue }

                let importedPlace = RoutinePlace(
                    id: place.id,
                    name: place.name,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    radiusMeters: place.radiusMeters,
                    createdAt: place.createdAt ?? Date()
                )
                context.insert(importedPlace)
                importedPlaceCount += 1
            }

            var importedTaskIDs = Set<UUID>()
            var importedTaskCount = 0
            for task in backup.tasks {
                guard importedTaskIDs.insert(task.id).inserted else { continue }

                let clampedInterval = min(max(task.interval, 1), Int(Int16.max))
                let importedTask = RoutineTask(
                    id: task.id,
                    name: task.name,
                    emoji: task.emoji,
                    notes: task.notes,
                    link: task.link,
                    deadline: task.deadline,
                    imageData: task.imageData,
                    placeID: task.placeID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
                    tags: task.tags ?? [],
                    steps: task.steps ?? [],
                    checklistItems: task.checklistItems ?? [],
                    scheduleMode: task.scheduleMode,
                    interval: Int16(clampedInterval),
                    recurrenceRule: task.recurrenceRule,
                    lastDone: task.lastDone,
                    canceledAt: task.canceledAt,
                    scheduleAnchor: task.scheduleAnchor,
                    pausedAt: task.pausedAt,
                    pinnedAt: task.pinnedAt,
                    completedStepCount: Int16(clamping: task.completedStepCount ?? 0),
                    sequenceStartedAt: task.sequenceStartedAt
                )
                context.insert(importedTask)
                importedTaskCount += 1
            }

            var importedLogIDs = Set<UUID>()
            var importedLogCount = 0
            for log in backup.logs {
                guard importedTaskIDs.contains(log.taskID) else { continue }
                guard importedLogIDs.insert(log.id).inserted else { continue }

                let importedLog = RoutineLog(
                    id: log.id,
                    timestamp: log.timestamp,
                    taskID: log.taskID,
                    kind: log.kind ?? .completed
                )
                context.insert(importedLog)
                importedLogCount += 1
            }

            try context.save()
            return ImportSummary(places: importedPlaceCount, tasks: importedTaskCount, logs: importedLogCount)
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    func rescheduleNotificationsAfterImport(in context: ModelContext) async throws {
        try await rescheduleNotificationsIfNeeded(in: context)
    }

    func withSecurityScopedAccess<T>(
        to url: URL,
        _ operation: () throws -> T
    ) throws -> T {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    @MainActor
    private func rescheduleNotificationsIfNeeded(in context: ModelContext) async throws {
        await notificationClient.cancelAll()

        guard appSettingsClient.notificationsEnabled() else { return }
        guard await notificationClient.systemNotificationsAuthorized() else { return }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks {
            guard !task.isPaused, !task.isOneOffTask else { continue }
            await notificationClient.schedule(NotificationCoordinator.notificationPayload(for: task))
        }
    }

    private func hasTemporaryViewStateToReset() -> Bool {
        appSettingsClient.hideUnavailableRoutines()
        || appSettingsClient.temporaryViewState() != nil
    }
}
