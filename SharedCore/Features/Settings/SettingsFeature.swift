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
        case appColorSchemeChanged(AppColorScheme)
        case routineListSectioningModeChanged(RoutineListSectioningMode)
        case tagCounterDisplayModeChanged(TagCounterDisplayMode)
        case appLockToggled(Bool)
        case appLockEnableFinished(DeviceAuthenticationResult)
        case gitFeaturesToggled(Bool)
        case showPersianDatesToggled(Bool)
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
        case fastFilterTagsLoaded([String])
        case tagColorsLoaded([String: String])
        case relatedTagRulesLoaded([RoutineRelatedTagRule])
        case learnedRelatedTagRulesLoaded([RoutineRelatedTagRule])
        case locationSnapshotUpdated(LocationSnapshot)
        case placeDraftNameChanged(String)
        case tagRenameDraftChanged(String)
        case tagSearchQueryChanged(String)
        case fastFilterTagToggled(String)
        case relatedTagDraftChanged(tagName: String, draft: String)
        case tagColorChanged(tagName: String, colorHex: String?)
        case saveRelatedTagsTapped(String)
        case addRelatedTagDraftSubmitted(tagName: String, draft: String)
        case appendRelatedTagSuggestionTapped(tagName: String, suggestion: String)
        case removeRelatedTagTapped(tagName: String, relatedTag: String)
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
            case let .appColorSchemeChanged(scheme):
                SettingsAppearanceEditor.updateAppColorScheme(
                    scheme,
                    state: &state.appearance
                )
                appSettingsClient.setAppColorScheme(scheme)
                return .none

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

            case let .gitFeaturesToggled(isEnabled):
                state.appearance.isGitFeaturesEnabled = isEnabled
                appSettingsClient.setGitFeaturesEnabled(isEnabled)
                return .none

            case let .showPersianDatesToggled(isEnabled):
                state.appearance.showPersianDates = isEnabled
                appSettingsClient.setShowPersianDates(isEnabled)
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
                return SettingsRefreshActionExecution.refreshContext(
                    reconcileNotificationsIfEnabled: false,
                    modelContext: self.modelContext,
                    notificationClient: self.notificationClient,
                    locationClient: self.locationClient,
                    appSettingsClient: self.appSettingsClient
                )

            case let .gitHubScopeChanged(scope):
                return SettingsGitConnectionActionHandler.gitHubScopeChanged(
                    scope,
                    state: &state.github
                )

            case let .gitHubOwnerChanged(owner):
                return SettingsGitConnectionActionHandler.gitHubOwnerChanged(
                    owner,
                    state: &state.github
                )

            case let .gitHubRepositoryChanged(name):
                return SettingsGitConnectionActionHandler.gitHubRepositoryChanged(
                    name,
                    state: &state.github
                )

            case let .gitHubTokenChanged(token):
                return SettingsGitConnectionActionHandler.gitHubTokenChanged(
                    token,
                    state: &state.github
                )

            case .saveGitHubConnectionTapped:
                return SettingsGitConnectionActionHandler.saveGitHubConnectionTapped(
                    state: &state.github,
                    gitHubStatsClient: gitHubStatsClient
                )

            case .clearGitHubConnectionTapped:
                return SettingsGitConnectionActionHandler.clearGitHubConnectionTapped(
                    state: &state.github,
                    gitHubStatsClient: gitHubStatsClient
                )

            case let .gitHubConnectionUpdateFinished(connection, _, message):
                return SettingsGitConnectionActionHandler.gitHubConnectionUpdateFinished(
                    connection: connection,
                    message: message,
                    state: &state.github
                )

            case let .gitLabTokenChanged(token):
                return SettingsGitConnectionActionHandler.gitLabTokenChanged(
                    token,
                    state: &state.gitlab
                )

            case .saveGitLabConnectionTapped:
                return SettingsGitConnectionActionHandler.saveGitLabConnectionTapped(
                    state: &state.gitlab,
                    gitLabStatsClient: gitLabStatsClient
                )

            case .clearGitLabConnectionTapped:
                return SettingsGitConnectionActionHandler.clearGitLabConnectionTapped(
                    state: &state.gitlab,
                    gitLabStatsClient: gitLabStatsClient
                )

            case let .gitLabConnectionUpdateFinished(connection, _, message):
                return SettingsGitConnectionActionHandler.gitLabConnectionUpdateFinished(
                    connection: connection,
                    message: message,
                    state: &state.gitlab
                )

            case .tagManagerAppeared:
                return SettingsTagManagerRefreshActionExecution.tagManagerAppeared(
                    modelContext: self.modelContext,
                    appSettingsClient: self.appSettingsClient
                )

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
                    gitFeaturesEnabled: appSettingsClient.gitFeaturesEnabled(),
                    deviceAuthenticationStatus: deviceAuthenticationClient.status(),
                    state: &state
                )
                return SettingsRefreshActionExecution.refreshContext(
                    reconcileNotificationsIfEnabled: notificationsEnabled,
                    modelContext: self.modelContext,
                    notificationClient: self.notificationClient,
                    locationClient: self.locationClient,
                    appSettingsClient: self.appSettingsClient
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
                return SettingsFastFilterActionHandler.tagsLoaded(
                    tags,
                    state: &state.tags,
                    appSettingsClient: self.appSettingsClient
                )

            case let .fastFilterTagsLoaded(tags):
                return SettingsFastFilterActionHandler.fastFilterTagsLoaded(
                    tags,
                    state: &state.tags,
                    appSettingsClient: self.appSettingsClient
                )

            case let .tagColorsLoaded(colors):
                SettingsTagEditor.loadedTagColors(colors, state: &state.tags)
                return .none

            case let .relatedTagRulesLoaded(rules):
                SettingsTagEditor.loadedRelatedTagRules(rules, state: &state.tags)
                return .none

            case let .learnedRelatedTagRulesLoaded(rules):
                SettingsTagEditor.loadedLearnedRelatedTagRules(rules, state: &state.tags)
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

            case let .tagSearchQueryChanged(query):
                state.tags.tagSearchQuery = query
                return .none

            case let .fastFilterTagToggled(tag):
                return SettingsFastFilterActionHandler.fastFilterTagToggled(
                    tag,
                    state: &state.tags,
                    appSettingsClient: self.appSettingsClient
                )

            case let .relatedTagDraftChanged(tagName, draft):
                SettingsTagEditor.updateRelatedTagDraft(
                    tagName: tagName,
                    draft: draft,
                    state: &state.tags
                )
                return .none

            case let .tagColorChanged(tagName, colorHex):
                let colors = SettingsTagEditor.updateTagColor(
                    tagName: tagName,
                    colorHex: colorHex,
                    state: &state.tags
                )
                appSettingsClient.setTagColors(colors)
                return .none

            case let .saveRelatedTagsTapped(tagName):
                let rules = SettingsTagEditor.saveRelatedTags(for: tagName, state: &state.tags)
                appSettingsClient.setRelatedTagRules(rules)
                return .none

            case let .addRelatedTagDraftSubmitted(tagName, draft):
                let rules = SettingsTagEditor.appendRelatedTagDraft(
                    tagName: tagName,
                    draft: draft,
                    state: &state.tags
                )
                appSettingsClient.setRelatedTagRules(rules)
                return .none

            case let .appendRelatedTagSuggestionTapped(tagName, suggestion):
                let rules = SettingsTagEditor.appendRelatedTagSuggestion(
                    tagName: tagName,
                    suggestion: suggestion,
                    state: &state.tags
                )
                appSettingsClient.setRelatedTagRules(rules)
                return .none

            case let .removeRelatedTagTapped(tagName, relatedTag):
                let rules = SettingsTagEditor.removeRelatedTag(
                    relatedTag,
                    from: tagName,
                    state: &state.tags
                )
                appSettingsClient.setRelatedTagRules(rules)
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
                let updatedRules = RoutineTagRelations.replacing(
                    request.originalTagName,
                    with: request.cleanedName,
                    in: appSettingsClient.relatedTagRules()
                )
                appSettingsClient.setRelatedTagRules(updatedRules)
                SettingsTagEditor.loadedRelatedTagRules(updatedRules, state: &state.tags)
                let updatedColors = RoutineTagColors.replacing(
                    request.originalTagName,
                    with: request.cleanedName,
                    in: appSettingsClient.tagColors()
                )
                appSettingsClient.setTagColors(updatedColors)
                SettingsTagEditor.loadedTagColors(updatedColors, state: &state.tags)

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
                let updatedRules = RoutineTagRelations.removing(
                    request.tagName,
                    from: appSettingsClient.relatedTagRules()
                )
                appSettingsClient.setRelatedTagRules(updatedRules)
                SettingsTagEditor.loadedRelatedTagRules(updatedRules, state: &state.tags)
                let updatedColors = RoutineTagColors.removing(
                    request.tagName,
                    from: appSettingsClient.tagColors()
                )
                appSettingsClient.setTagColors(updatedColors)
                SettingsTagEditor.loadedTagColors(updatedColors, state: &state.tags)

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
                return SettingsAppIconActionHandler.appIconSelected(
                    option,
                    state: &state.appearance,
                    appIconClient: self.appIconClient
                )

            case let .appIconChangeFinished(option, errorMessage):
                return SettingsAppIconActionHandler.appIconChangeFinished(
                    requestedOption: option,
                    errorMessage: errorMessage,
                    state: &state.appearance
                )

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
}
