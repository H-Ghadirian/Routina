import ComposableArchitecture
import Foundation

@Reducer
struct SettingsFeature {
    typealias State = SettingsFeatureState

    enum Action: Equatable {
        case toggleNotifications(Bool)
        case appColorSchemeChanged(AppColorScheme)
        case routineListSectioningModeChanged(RoutineListSectioningMode)
        case tagCounterDisplayModeChanged(TagCounterDisplayMode)
        case taskRowFieldVisibilityChanged(HomeTaskRowField, Bool)
        case taskRowMultilineTitlesChanged(Bool)
        case taskRowMultilineDetailsChanged(Bool)
        case timelineRowFieldVisibilityChanged(HomeTimelineRowField, Bool)
        case appLockToggled(Bool)
        case appLockEnableFinished(DeviceAuthenticationResult)
        case appLockDisableFinished(DeviceAuthenticationResult)
        case resetAllSettingsToDefaultsTapped
        case settingsDefaultsResetAuthenticationFinished(DeviceAuthenticationResult)
        case gitFeaturesToggled(Bool)
        case taskSharingToggled(Bool)
        case taskRelationshipVisualizerToggled(Bool)
        case placesToggled(Bool)
        case notesToggled(Bool)
        case awayToggled(Bool)
        case filterQuerySectionsToggled(Bool)
        case showPersianDatesToggled(Bool)
        case automaticPlaceCheckInToggled(Bool)
        case showTimelineTasksInDayPlannerToggled(Bool)
        case separateDailyRoutinesInTaskListToggled(Bool)
        case showTomorrowInTaskListToggled(Bool)
        case showDoneCountInToolbarToggled(Bool)
        case notificationAuthorizationFinished(Bool)
        case notificationReminderTimeChanged(Date)
        case scheduledNotificationsLoaded([ScheduledNotificationSummary])
        case removeScheduledNotificationTapped(ScheduledNotificationSummary)
        case pauseScheduledNotificationTapped(ScheduledNotificationSummary, until: Date)
        case openAppSettingsTapped
        case openLocationSettingsTapped
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
        case deviceSessionsLoaded([RoutinaDeviceSessionSummary])
        case syncNowTapped
        case setCloudDataResetConfirmation(Bool)
        case resetCloudDataConfirmed
        case cloudDataResetAuthenticationFinished(DeviceAuthenticationResult)
        case setDeletePlaceConfirmation(Bool)
        case setDeleteTagConfirmation(Bool)
        case setTagRenameSheet(Bool)
        case setTagNormalizationConfirmation(Bool)
        case placesLoaded([RoutinePlaceSummary])
        case tagsLoaded([RoutineTagSummary])
        case fastFilterTagsLoaded([String])
        case tagColorsLoaded([String: String])
        case relatedTagRulesLoaded([RoutineRelatedTagRule])
        case tagRulesLoaded([RoutineTagRule])
        case flagRulesLoaded([RoutineFlagRule])
        case definedFlagsLoaded([String])
        case learnedRelatedTagRulesLoaded([RoutineRelatedTagRule])
        case locationSnapshotUpdated(LocationSnapshot)
        case placeDraftNameChanged(String)
        case placeDraftKindChanged(String)
        case tagRenameDraftChanged(String)
        case tagSearchQueryChanged(String)
        case fastFilterTagToggled(String)
        case relatedTagDraftChanged(tagName: String, draft: String)
        case tagColorChanged(tagName: String, colorHex: String?)
        case addTagRuleTapped(tagName: String, kind: RoutineTagRuleKind)
        case removeTagRuleTapped(tagName: String, kind: RoutineTagRuleKind)
        case flagDraftChanged(String)
        case addFlagTapped
        case removeFlagTapped(String)
        case addFlagRuleTapped(flagName: String, kind: RoutineFlagRuleKind)
        case removeFlagRuleTapped(flagName: String, kind: RoutineFlagRuleKind)
        case saveRelatedTagsTapped(String)
        case addRelatedTagDraftSubmitted(tagName: String, draft: String)
        case appendRelatedTagSuggestionTapped(tagName: String, suggestion: String)
        case removeRelatedTagTapped(tagName: String, relatedTag: String)
        case placeDraftCoordinateChanged(LocationCoordinate?)
        case placeDraftRadiusChanged(Double)
        case savePlaceTapped
        case renameTagTapped(String)
        case saveTagRenameTapped
        case normalizeTagSuggestionTapped(sourceTagName: String, replacementTagName: String)
        case normalizeTagSuggestionConfirmed
        case deletePlaceTapped(UUID)
        case deleteTagTapped(String)
        case deletePlaceConfirmed
        case deleteTagConfirmed
        case placeOperationFinished(success: Bool, message: String)
        case tagOperationFinished(success: Bool, message: String)
        case exportRoutineDataTapped
        case exportRoutineDataDestinationSelected(URL)
        case importRoutineDataTapped
        case importRoutineDataSourceSelected(URL)
        case verifyRoutineDataTapped
        case verifyRoutineDataSourceSelected(URL)
        case recoveryPointsLoaded([SettingsRoutineDataRecoveryPoint])
        case restoreRecoveryPointTapped(String)
        case setRecoveryPointRestoreConfirmation(Bool)
        case restoreRecoveryPointConfirmed
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
    @Dependency(\.date.now) var now

    var body: some ReducerOf<Self> {
        Reduce(reduceDisplayPreferenceActions)
        Reduce(reduceSecurityPreferenceActions)
        Reduce(reduceFeatureAvailabilityPreferenceActions)
        Reduce(reduceNotificationAuthorizationActions)
        Reduce(reduceNotificationScheduleActions)
        Reduce(reduceAppIconAndTemporaryStateActions)
        Reduce(reduceAppInteractionActions)
        Reduce(reduceRefreshActions)
        Reduce(reduceGitHubConnectionActions)
        Reduce(reduceGitLabConnectionActions)
        Reduce(reduceCloudDiagnosticsActions)
        Reduce(reduceCloudActions)
        Reduce(reducePlaceEditingActions)
        Reduce(reducePlaceMutationActions)
        Reduce(reduceTagLoadingActions)
        Reduce(reduceTagEditingActions)
        Reduce(reduceTagMetadataMutationActions)
        Reduce(reduceFlagActions)
        Reduce(reduceTagPersistenceActions)
        Reduce(reduceDataTransferSelectionActions)
        Reduce(reduceRecoveryPointActions)
        Reduce(reduceDataTransferCompletionActions)
    }
}
