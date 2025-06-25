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
                        await SettingsNotificationsExecution.disableNotifications(
                            notificationClient: self.notificationClient
                        )
                    }
                }

                return .run { send in
                    let granted = await SettingsNotificationsExecution.requestAuthorization(
                        notificationClient: self.notificationClient
                    )
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
                    await SettingsNotificationsExecution.reconcileAuthorizationResult(
                        isGranted: isGranted,
                        modelContext: self.modelContext,
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

                let notificationsEnabled = state.notifications.notificationsEnabled
                guard notificationsEnabled else { return .none }
                return .run { @MainActor _ in
                    await SettingsNotificationsExecution.reconcileReminderChange(
                        notificationsEnabled: notificationsEnabled,
                        modelContext: self.modelContext,
                        appSettingsClient: self.appSettingsClient,
                        notificationClient: self.notificationClient
                    )
                }

            case .openAppSettingsTapped:
                return .run { @MainActor _ in
                    SettingsAppInteractionExecution.openNotificationSettings(
                        urlOpenerClient: self.urlOpenerClient
                    )
                }

            case .onAppear:
                SettingsRefreshEditor.hydrateOnAppear(
                    SettingsDiagnosticsLoader.makeOnAppearSnapshot(
                        appInfoClient: appInfoClient,
                        appSettingsClient: appSettingsClient
                    ),
                    state: &state
                )
                return refreshSettingsContext(
                    reconcileNotificationsIfEnabled: false
                )

            case .tagManagerAppeared:
                return .run { @MainActor send in
                    send(.tagsLoaded(SettingsRefreshExecution.loadTagSummaries(
                        modelContext: self.modelContext
                    )))
                }

            case .contactUsTapped:
                return .run { @MainActor _ in
                    SettingsAppInteractionExecution.contactSupport(
                        urlOpenerClient: self.urlOpenerClient
                    )
                }

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
                SettingsDiagnosticsLoader.refreshCloudDiagnostics(state: &state.diagnostics)
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

                return SettingsPlaceExecution.save(
                    request,
                    modelContext: self.modelContext
                )

            case .saveTagRenameTapped:
                guard let request = SettingsTagEditor.prepareRename(state: &state.tags) else {
                    return .none
                }

                return SettingsTagExecution.rename(
                    request,
                    modelContext: self.modelContext
                )

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
                return SettingsPlaceExecution.delete(
                    request,
                    modelContext: self.modelContext
                )

            case .deleteTagConfirmed:
                guard let request = SettingsTagEditor.prepareDeleteConfirmation(state: &state.tags) else {
                    return .none
                }

                return SettingsTagExecution.delete(
                    request,
                    modelContext: self.modelContext
                )

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
                    let errorMessage = await SettingsAppInteractionExecution.requestAppIconChange(
                        option,
                        appIconClient: self.appIconClient
                    )
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
            let result = await SettingsRefreshExecution.loadContext(
                modelContext: self.modelContext,
                notificationClient: self.notificationClient,
                locationClient: self.locationClient
            )
            send(.systemNotificationPermissionChecked(result.systemNotificationsEnabled))
            send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
            send(.placesLoaded(result.placeSummaries))
            send(.tagsLoaded(result.tagSummaries))
            send(.locationSnapshotUpdated(result.locationSnapshot))

            await SettingsRefreshExecution.reconcileNotificationsIfNeeded(
                notificationsEnabled: notificationsEnabled,
                systemNotificationsEnabled: result.systemNotificationsEnabled,
                modelContext: self.modelContext,
                appSettingsClient: self.appSettingsClient,
                notificationClient: self.notificationClient
            )
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
                let estimate = try await SettingsCloudExecution.syncNow(
                    modelContext: self.modelContext,
                    cloudSyncClient: self.cloudSyncClient
                )
                send(.cloudUsageEstimateLoaded(estimate))
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
                let estimate = try await SettingsCloudExecution.resetCloudData(
                    cloudContainerIdentifier: cloudContainerIdentifier,
                    modelContext: self.modelContext
                )
                send(.cloudUsageEstimateLoaded(estimate))
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
                guard let result = try await SettingsRoutineDataTransferExecution.exportData(
                    routineDataTransferClient: self.routineDataTransferClient,
                    modelContext: self.modelContext
                ) else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Save canceled."
                        )
                    )
                    return
                }

                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Saved to \(result.destinationFileName)."
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
                guard let result = try await SettingsRoutineDataTransferExecution.importData(
                    routineDataTransferClient: self.routineDataTransferClient,
                    modelContext: self.modelContext,
                    appSettingsClient: { self.appSettingsClient },
                    notificationClient: { self.notificationClient }
                ) else {
                    await send(
                        .routineDataTransferFinished(
                            success: false,
                            message: "Load canceled."
                        )
                    )
                    return
                }

                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                NotificationCenter.default.postRoutineDidUpdate()
                await send(
                    .routineDataTransferFinished(
                        success: true,
                        message: "Loaded \(result.importedSummary.tasks) routines, \(result.importedSummary.places) places, and \(result.importedSummary.logs) logs."
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
