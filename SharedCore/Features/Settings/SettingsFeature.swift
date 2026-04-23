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
        case appLockToggled(Bool)
        case appLockEnableFinished(DeviceAuthenticationResult)
        case notificationAuthorizationFinished(Bool)
        case notificationReminderTimeChanged(Date)
        case openAppSettingsTapped
        case gitHubScopeChanged(GitHubStatsScope)
        case gitHubOwnerChanged(String)
        case gitHubRepositoryChanged(String)
        case gitHubTokenChanged(String)
        case saveGitHubConnectionTapped
        case clearGitHubConnectionTapped
        case gitHubConnectionUpdateFinished(connection: GitHubConnectionStatus, success: Bool, message: String)
        case gitLabTokenChanged(String)
        case saveGitLabConnectionTapped
        case clearGitLabConnectionTapped
        case gitLabConnectionUpdateFinished(connection: GitLabConnectionStatus, success: Bool, message: String)
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
    @Dependency(\.deviceAuthenticationClient) var deviceAuthenticationClient
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.appInfoClient) var appInfoClient
    @Dependency(\.urlOpenerClient) var urlOpenerClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.routineDataTransferClient) var routineDataTransferClient
    @Dependency(\.gitHubStatsClient) var gitHubStatsClient
    @Dependency(\.gitLabStatsClient) var gitLabStatsClient

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

            case let .appLockToggled(isEnabled):
                let authenticationStatus = deviceAuthenticationClient.status()
                SettingsAppearanceEditor.beginAppLockToggle(
                    enabling: isEnabled,
                    deviceAuthenticationStatus: authenticationStatus,
                    state: &state.appearance
                )

                guard isEnabled else {
                    appSettingsClient.setAppLockEnabled(false)
                    SettingsAppearanceEditor.finishAppLockToggle(
                        enabled: false,
                        message: "",
                        deviceAuthenticationStatus: authenticationStatus,
                        state: &state.appearance
                    )
                    return .none
                }

                guard authenticationStatus.isAvailable else {
                    SettingsAppearanceEditor.finishAppLockToggle(
                        enabled: false,
                        message: authenticationStatus.unavailableReason
                            ?? "Device authentication is unavailable.",
                        deviceAuthenticationStatus: authenticationStatus,
                        state: &state.appearance
                    )
                    return .none
                }

                return .run { send in
                    let result = await self.deviceAuthenticationClient.authenticate(
                        "Enable app lock for Routina"
                    )
                    await send(.appLockEnableFinished(result))
                }

            case let .appLockEnableFinished(result):
                let authenticationStatus = deviceAuthenticationClient.status()
                switch result {
                case .success:
                    appSettingsClient.setAppLockEnabled(true)
                    SettingsAppearanceEditor.finishAppLockToggle(
                        enabled: true,
                        message: "App lock is on.",
                        deviceAuthenticationStatus: authenticationStatus,
                        state: &state.appearance
                    )
                case .failure(let message):
                    SettingsAppearanceEditor.finishAppLockToggle(
                        enabled: false,
                        message: message,
                        deviceAuthenticationStatus: authenticationStatus,
                        state: &state.appearance
                    )
                }
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
                        appSettingsClient: appSettingsClient,
                        deviceAuthenticationClient: deviceAuthenticationClient,
                        gitHubConnection: gitHubStatsClient.loadConnectionStatus(),
                        gitLabConnection: gitLabStatsClient.loadConnectionStatus()
                    ),
                    state: &state
                )
                return refreshSettingsContext(
                    reconcileNotificationsIfEnabled: false
                )

            case let .gitHubScopeChanged(scope):
                state.github.scope = scope
                state.github.statusMessage = ""
                return .none

            case let .gitHubOwnerChanged(owner):
                state.github.repositoryOwner = owner
                return .none

            case let .gitHubRepositoryChanged(name):
                state.github.repositoryName = name
                return .none

            case let .gitHubTokenChanged(token):
                state.github.accessTokenDraft = token
                return .none

            case .saveGitHubConnectionTapped:
                guard !state.github.isSaveDisabled else {
                    if let validationMessage = state.github.saveValidationMessage {
                        state.github.statusMessage = validationMessage
                    }
                    return .none
                }

                state.github.isOperationInProgress = true
                state.github.statusMessage = ""

                let configuration = GitHubStatsConfiguration(
                    scope: state.github.scope,
                    repository: state.github.scope == .repository
                        ? GitHubRepositoryReference(
                            owner: state.github.repositoryOwner,
                            name: state.github.repositoryName
                        )
                        : nil,
                    viewerLogin: nil
                )
                let accessToken = state.github.accessTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)

                return .run { send in
                    do {
                        let connection = try await self.gitHubStatsClient.saveConnection(
                            configuration,
                            accessToken.isEmpty ? nil : accessToken
                        )
                        let message: String = switch connection.scope {
                        case .repository:
                            "Connected to \(connection.repository?.fullName ?? "repository")."
                        case .profile:
                            "Connected to @\(connection.viewerLogin ?? "viewer") GitHub profile."
                        }
                        await send(
                            .gitHubConnectionUpdateFinished(
                                connection: connection,
                                success: true,
                                message: message
                            )
                        )
                    } catch {
                        await send(
                            .gitHubConnectionUpdateFinished(
                                connection: self.gitHubStatsClient.loadConnectionStatus(),
                                success: false,
                                message: error.localizedDescription
                            )
                        )
                    }
                }

            case .clearGitHubConnectionTapped:
                state.github.isOperationInProgress = true
                state.github.statusMessage = ""
                let draftScope = state.github.scope

                return .run { send in
                    do {
                        try self.gitHubStatsClient.clearConnection()
                        await send(
                            .gitHubConnectionUpdateFinished(
                                connection: .disconnected(scope: draftScope),
                                success: true,
                                message: "GitHub connection removed."
                            )
                        )
                    } catch {
                        await send(
                            .gitHubConnectionUpdateFinished(
                                connection: self.gitHubStatsClient.loadConnectionStatus(),
                                success: false,
                                message: error.localizedDescription
                            )
                        )
                    }
                }

            case let .gitHubConnectionUpdateFinished(connection, _, message):
                state.github.isOperationInProgress = false
                state.github.scope = connection.scope
                state.github.connectedScope = connection.scope
                state.github.connectedRepository = connection.repository
                state.github.connectedViewerLogin = connection.viewerLogin
                state.github.hasSavedAccessToken = connection.hasAccessToken
                state.github.statusMessage = message
                state.github.accessTokenDraft = ""
                state.github.repositoryOwner = connection.repository?.owner ?? ""
                state.github.repositoryName = connection.repository?.name ?? ""
                return .none

            case let .gitLabTokenChanged(token):
                state.gitlab.accessTokenDraft = token
                return .none

            case .saveGitLabConnectionTapped:
                guard !state.gitlab.isSaveDisabled else {
                    if let validationMessage = state.gitlab.saveValidationMessage {
                        state.gitlab.statusMessage = validationMessage
                    }
                    return .none
                }

                state.gitlab.isOperationInProgress = true
                state.gitlab.statusMessage = ""
                let accessToken = state.gitlab.accessTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)

                return .run { send in
                    do {
                        let connection = try await self.gitLabStatsClient.saveConnection(accessToken)
                        let message = "Connected to @\(connection.username ?? "viewer") GitLab profile."
                        await send(
                            .gitLabConnectionUpdateFinished(
                                connection: connection,
                                success: true,
                                message: message
                            )
                        )
                    } catch {
                        await send(
                            .gitLabConnectionUpdateFinished(
                                connection: self.gitLabStatsClient.loadConnectionStatus(),
                                success: false,
                                message: error.localizedDescription
                            )
                        )
                    }
                }

            case .clearGitLabConnectionTapped:
                state.gitlab.isOperationInProgress = true
                state.gitlab.statusMessage = ""

                return .run { send in
                    do {
                        try self.gitLabStatsClient.clearConnection()
                        await send(
                            .gitLabConnectionUpdateFinished(
                                connection: .disconnected,
                                success: true,
                                message: "GitLab connection removed."
                            )
                        )
                    } catch {
                        await send(
                            .gitLabConnectionUpdateFinished(
                                connection: self.gitLabStatsClient.loadConnectionStatus(),
                                success: false,
                                message: error.localizedDescription
                            )
                        )
                    }
                }

            case let .gitLabConnectionUpdateFinished(connection, _, message):
                state.gitlab.isOperationInProgress = false
                state.gitlab.connectedUsername = connection.username
                state.gitlab.hasSavedAccessToken = connection.hasAccessToken
                state.gitlab.statusMessage = message
                state.gitlab.accessTokenDraft = ""
                return .none

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
                    appLockEnabled: appSettingsClient.appLockEnabled(),
                    deviceAuthenticationStatus: deviceAuthenticationClient.status(),
                    state: &state
                )
                return refreshSettingsContext(
                    reconcileNotificationsIfEnabled: notificationsEnabled
                )

            case .syncNowTapped:
                return SettingsCloudActionExecution.beginSync(
                    state: &state.cloud,
                    modelContext: self.modelContext,
                    cloudSyncClient: self.cloudSyncClient
                )

            case let .setCloudDataResetConfirmation(isPresented):
                SettingsCloudEditor.setDataResetConfirmation(isPresented, state: &state.cloud)
                return .none

            case .resetCloudDataConfirmed:
                return SettingsCloudActionExecution.beginDataReset(
                    cloudContainerIdentifier: AppEnvironment.cloudKitContainerIdentifier,
                    state: &state.cloud,
                    modelContext: self.modelContext
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
                return SettingsRoutineDataTransferActionExecution.beginExport(
                    state: &state.dataTransfer,
                    routineDataTransferClient: self.routineDataTransferClient,
                    modelContext: self.modelContext
                )

            case .importRoutineDataTapped:
                return SettingsRoutineDataTransferActionExecution.beginImport(
                    state: &state.dataTransfer,
                    routineDataTransferClient: self.routineDataTransferClient,
                    modelContext: self.modelContext,
                    appSettingsClient: { self.appSettingsClient },
                    notificationClient: { self.notificationClient }
                )

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

}
