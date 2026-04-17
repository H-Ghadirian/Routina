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
                SettingsAppearanceEditor.updateRoutineListSectioningMode(
                    mode,
                    state: &state.appearance
                )
                appSettingsClient.setRoutineListSectioningMode(mode)
                return .none

            case let .tagCounterDisplayModeChanged(mode):
                SettingsAppearanceEditor.updateTagCounterDisplayMode(
                    mode,
                    state: &state.appearance
                )
                appSettingsClient.setTagCounterDisplayMode(mode)
                return .none

            case .resetTemporaryViewStateTapped:
                appSettingsClient.resetTemporaryViewState()
                SettingsAppearanceEditor.resetTemporaryViewState(state: &state.appearance)
                return .none

            case .toggleNotifications(let isOn):
                guard isOn else {
                    SettingsNotificationsEditor.setNotificationsEnabled(
                        false,
                        state: &state.notifications
                    )
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
                SettingsNotificationsEditor.applyAuthorizationResult(
                    isGranted,
                    state: &state.notifications
                )
                appSettingsClient.setNotificationsEnabled(isGranted)

                guard isGranted else { return .none }
                return .run { @MainActor _ in
                    try? await SettingsExecutionSupport.rescheduleNotificationsIfNeeded(
                        in: self.modelContext(),
                        appSettingsClient: self.appSettingsClient,
                        notificationClient: self.notificationClient
                    )
                }

            case .notificationReminderTimeChanged(let reminderTime):
                SettingsNotificationsEditor.updateReminderTime(
                    reminderTime,
                    state: &state.notifications
                )
                appSettingsClient.setNotificationReminderTime(reminderTime)

                guard state.notifications.notificationsEnabled else { return .none }
                return .run { @MainActor _ in
                    try? await SettingsExecutionSupport.rescheduleNotificationsIfNeeded(
                        in: self.modelContext(),
                        appSettingsClient: self.appSettingsClient,
                        notificationClient: self.notificationClient
                    )
                }

            case .openAppSettingsTapped:
                if let url = urlOpenerClient.notificationSettingsURL() {
                    return .run { @MainActor _ in
                        self.urlOpenerClient.open(url)
                    }
                }
                return .none

            case .onAppear:
                let diagnostics = CloudKitSyncDiagnostics.snapshot()
                SettingsRefreshEditor.hydrateOnAppear(
                    SettingsOnAppearSnapshot(
                        appVersion: appInfoClient.versionString(),
                        dataModeDescription: appInfoClient.dataModeDescription(),
                        iCloudContainerDescription: appInfoClient.cloudContainerDescription(),
                        cloudSyncAvailable: appInfoClient.isCloudSyncEnabled(),
                        notificationsEnabled: appSettingsClient.notificationsEnabled(),
                        notificationReminderTime: appSettingsClient.notificationReminderTime(),
                        routineListSectioningMode: appSettingsClient.routineListSectioningMode(),
                        tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode(),
                        selectedAppIcon: appSettingsClient.selectedAppIcon(),
                        hasTemporaryViewStateToReset: SettingsExecutionSupport.hasTemporaryViewStateToReset(
                            appSettingsClient: appSettingsClient
                        ),
                        cloudDiagnosticsSummary: diagnostics.summary,
                        cloudDiagnosticsTimestamp: diagnostics.timestampText,
                        pushDiagnosticsStatus: diagnostics.pushStatus
                    ),
                    state: &state
                )
                return refreshSettingsContext(
                    reconcileNotificationsIfEnabled: false
                )

            case .tagManagerAppeared:
                return .run { @MainActor send in
                    let tagSummaries = try? SettingsDataQueries.fetchTagSummaries(in: self.modelContext())
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
                SettingsNotificationsEditor.updateSystemPermission(
                    value,
                    state: &state.notifications
                )
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
                SettingsRefreshEditor.refreshOnAppBecameActive(
                    hasTemporaryViewStateToReset: SettingsExecutionSupport.hasTemporaryViewStateToReset(
                        appSettingsClient: appSettingsClient
                    ),
                    state: &state
                )
                return refreshSettingsContext(
                    reconcileNotificationsIfEnabled: notificationsEnabled
                )

            case .syncNowTapped:
                guard SettingsCloudEditor.beginSync(state: &state.cloud) else {
                    return .none
                }
                return handleSyncNow()

            case let .setCloudDataResetConfirmation(isPresented):
                SettingsCloudEditor.setDataResetConfirmation(isPresented, state: &state.cloud)
                return .none

            case .resetCloudDataConfirmed:
                let hasCloudContainerIdentifier = AppEnvironment.cloudKitContainerIdentifier != nil
                guard SettingsCloudEditor.prepareDataReset(
                    hasCloudContainerIdentifier: hasCloudContainerIdentifier,
                    state: &state.cloud
                ),
                let cloudContainerIdentifier = AppEnvironment.cloudKitContainerIdentifier
                else {
                    return .none
                }
                return handleResetCloudData(
                    cloudContainerIdentifier: cloudContainerIdentifier
                )

            case let .setDeletePlaceConfirmation(isPresented):
                SettingsPlaceEditor.setDeleteConfirmation(isPresented, state: &state.places)
                return .none

            case let .setDeleteTagConfirmation(isPresented):
                SettingsTagEditor.setDeleteConfirmation(isPresented, state: &state.tags)
                return .none

            case let .setTagRenameSheet(isPresented):
                SettingsTagEditor.setRenameSheet(isPresented, state: &state.tags)
                return .none

            case let .placesLoaded(places):
                SettingsPlaceEditor.loadedPlaces(places, state: &state.places)
                return .none

            case let .tagsLoaded(tags):
                SettingsTagEditor.loadedTags(tags, state: &state.tags)
                return .none

            case let .locationSnapshotUpdated(snapshot):
                SettingsPlaceEditor.applyLocationSnapshot(snapshot, state: &state.places)
                return .none

            case let .placeDraftNameChanged(name):
                SettingsPlaceEditor.updateDraftName(name, state: &state.places)
                return .none

            case let .tagRenameDraftChanged(name):
                SettingsTagEditor.updateRenameDraft(name, state: &state.tags)
                return .none

            case let .placeDraftCoordinateChanged(coordinate):
                SettingsPlaceEditor.updateDraftCoordinate(coordinate, state: &state.places)
                return .none

            case let .placeDraftRadiusChanged(radius):
                SettingsPlaceEditor.updateDraftRadius(radius, state: &state.places)
                return .none

            case let .renameTagTapped(tagName):
                guard SettingsTagEditor.beginRename(tagName: tagName, state: &state.tags) else {
                    return .none
                }
                return .none

            case .savePlaceTapped:
                guard let request = SettingsPlaceEditor.prepareSave(state: &state.places) else {
                    return .none
                }

                return handleSavePlace(request)

            case .saveTagRenameTapped:
                guard let request = SettingsTagEditor.prepareRename(state: &state.tags) else {
                    return .none
                }

                return handleSaveTagRename(request)

            case let .deletePlaceTapped(placeID):
                guard SettingsPlaceEditor.beginDelete(placeID: placeID, state: &state.places) else {
                    return .none
                }
                return .none

            case let .deleteTagTapped(tagName):
                guard SettingsTagEditor.beginDelete(tagName: tagName, state: &state.tags) else {
                    return .none
                }
                return .none

            case .deletePlaceConfirmed:
                guard let request = SettingsPlaceEditor.prepareDeleteConfirmation(state: &state.places) else {
                    return .none
                }
                return handleDeletePlace(request)

            case .deleteTagConfirmed:
                guard let request = SettingsTagEditor.prepareDeleteConfirmation(state: &state.tags) else {
                    return .none
                }

                return handleDeleteTag(request)

            case let .placeOperationFinished(success, message):
                SettingsPlaceEditor.finishOperation(
                    success: success,
                    message: message,
                    state: &state.places
                )
                return .none

            case let .tagOperationFinished(_, message):
                SettingsTagEditor.finishOperation(message: message, state: &state.tags)
                return .none

            case .exportRoutineDataTapped:
                return handleExportRoutineDataTapped(state: &state)

            case .importRoutineDataTapped:
                return handleImportRoutineDataTapped(state: &state)

            case let .appIconSelected(option):
                SettingsAppearanceEditor.beginAppIconChange(state: &state.appearance)
                return .run { send in
                    let errorMessage = await self.appIconClient.requestChange(option)
                    await send(.appIconChangeFinished(requestedOption: option, errorMessage: errorMessage))
                }

            case let .appIconChangeFinished(option, errorMessage):
                SettingsAppearanceEditor.finishAppIconChange(
                    requestedOption: option,
                    errorMessage: errorMessage,
                    state: &state.appearance
                )
                return .none

            case let .routineDataTransferFinished(_, message):
                SettingsRoutineDataTransferEditor.finish(
                    message: message,
                    state: &state.dataTransfer
                )
                return .none

            case let .cloudSyncFinished(_, message):
                SettingsCloudEditor.finishSync(message: message, state: &state.cloud)
                return .none

            case let .cloudDataResetFinished(_, message):
                SettingsCloudEditor.finishDataReset(message: message, state: &state.cloud)
                return .none
            }
        }
    }

    private func refreshSettingsContext(
        reconcileNotificationsIfEnabled notificationsEnabled: Bool
    ) -> Effect<Action> {
        .run { @MainActor send in
            let context = self.modelContext()
            let systemEnabled = await self.notificationClient.systemNotificationsAuthorized()
            send(.systemNotificationPermissionChecked(systemEnabled))
            send(.cloudUsageEstimateLoaded(SettingsDataQueries.loadCloudUsageEstimate(in: context)))
            let placeSummaries = try? SettingsDataQueries.fetchPlaceSummaries(in: context)
            send(.placesLoaded(placeSummaries ?? []))
            let tagSummaries = try? SettingsDataQueries.fetchTagSummaries(in: context)
            send(.tagsLoaded(tagSummaries ?? []))
            let locationSnapshot = await self.locationClient.snapshot(false)
            send(.locationSnapshotUpdated(locationSnapshot))

            guard notificationsEnabled else { return }
            if systemEnabled {
                try? await SettingsExecutionSupport.rescheduleNotificationsIfNeeded(
                    in: context,
                    appSettingsClient: self.appSettingsClient,
                    notificationClient: self.notificationClient
                )
            } else {
                await self.notificationClient.cancelAll()
            }
        }
    }

    private func handleSavePlace(
        _ request: SettingsPlaceSaveRequest
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = self.modelContext()
                let result = try SettingsPlacePersistence.save(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                send(.placesLoaded(result.placeSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(
                    .placeOperationFinished(
                        success: true,
                        message: "Saved \(request.cleanedName)."
                    )
                )
            } catch let error as SettingsPlacePersistenceError {
                send(
                    .placeOperationFinished(
                        success: false,
                        message: error.localizedDescription
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
    }

    private func handleDeletePlace(
        _ request: SettingsPlaceDeletionRequest
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = self.modelContext()
                let result = try SettingsPlacePersistence.delete(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                send(.placesLoaded(result.placeSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
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
    }

    private func handleSaveTagRename(
        _ request: SettingsTagRenameRequest
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = self.modelContext()
                let result = try SettingsTagPersistence.rename(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                NotificationCenter.default.postRoutineTagDidRename(
                    from: request.originalTagName,
                    to: request.cleanedName
                )
                send(.tagsLoaded(result.tagSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(
                    .tagOperationFinished(
                        success: true,
                        message: SettingsFeedbackSupport.renameTagSuccessMessage(
                            updatedTagName: request.cleanedName,
                            updatedRoutineCount: result.updatedRoutineCount
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
    }

    private func handleDeleteTag(
        _ request: SettingsTagDeletionRequest
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = self.modelContext()
                let result = try SettingsTagPersistence.delete(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                NotificationCenter.default.postRoutineTagDidDelete(request.tagName)
                send(.tagsLoaded(result.tagSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(
                    .tagOperationFinished(
                        success: true,
                        message: SettingsFeedbackSupport.deleteTagSuccessMessage(
                            deletedTagName: request.tagName,
                            updatedRoutineCount: result.updatedRoutineCount
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
    }

    private func handleExportRoutineDataTapped(state: inout State) -> Effect<Action> {
        guard SettingsRoutineDataTransferEditor.begin(.export, state: &state.dataTransfer) else {
            return .none
        }

        return executeExportRoutineDataTransfer()
    }

    private func handleSyncNow() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                if context.hasChanges {
                    try context.save()
                }
                try await self.cloudSyncClient.pullLatestIntoLocalStore(context)
                send(.cloudUsageEstimateLoaded(SettingsDataQueries.loadCloudUsageEstimate(in: context)))
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
    }

    private func handleResetCloudData(
        cloudContainerIdentifier: String
    ) -> Effect<Action> {
        .run { @MainActor send in
            do {
                try await CloudDataResetService.resetAllUserData(
                    cloudKitContainerIdentifier: cloudContainerIdentifier,
                    modelContext: modelContext()
                )
                let refreshedContext = modelContext()
                send(.cloudUsageEstimateLoaded(SettingsDataQueries.loadCloudUsageEstimate(in: refreshedContext)))
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
                        message: SettingsFeedbackSupport.cloudDataResetErrorMessage(for: error)
                    )
                )
            }
        }
    }

    private func handleImportRoutineDataTapped(state: inout State) -> Effect<Action> {
        guard SettingsRoutineDataTransferEditor.begin(.import, state: &state.dataTransfer) else {
            return .none
        }

        return executeImportRoutineDataTransfer()
    }

    private func executeExportRoutineDataTransfer() -> Effect<Action> {
        .run { @MainActor send in
            do {
                guard let destinationURL = await self.routineDataTransferClient.selectExportURL(
                    SettingsRoutineDataPersistence.defaultBackupFileName()
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

                let backupData = try SettingsRoutineDataPersistence.buildBackupJSON(from: context)
                try SettingsExecutionSupport.withSecurityScopedAccess(to: destinationURL) {
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

    private func executeImportRoutineDataTransfer() -> Effect<Action> {
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

                let jsonData = try SettingsExecutionSupport.withSecurityScopedAccess(to: sourceURL) {
                    try Data(contentsOf: sourceURL)
                }
                let context = self.modelContext()
                let importedSummary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
                    with: jsonData,
                    in: context
                )
                try await SettingsExecutionSupport.rescheduleNotificationsAfterImport(
                    in: context,
                    appSettingsClient: self.appSettingsClient,
                    notificationClient: self.notificationClient
                )

                send(.cloudUsageEstimateLoaded(SettingsDataQueries.loadCloudUsageEstimate(in: context)))
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

}
