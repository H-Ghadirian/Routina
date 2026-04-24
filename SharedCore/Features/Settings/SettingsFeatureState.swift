import ComposableArchitecture
import Foundation

struct SettingsDiagnosticsState: Equatable {
    var appVersion: String = ""
    var dataModeDescription: String = ""
    var iCloudContainerDescription: String = "Disabled"
    var cloudDiagnosticsSummary: String = "No CloudKit event yet"
    var cloudDiagnosticsTimestamp: String = "Never"
    var pushDiagnosticsStatus: String = "Push not registered yet"
    var isDebugSectionVisible: Bool = false
}

struct SettingsNotificationsState: Equatable {
    var notificationsEnabled: Bool = false
    var systemSettingsNotificationsEnabled: Bool = true
    var notificationReminderTime: Date = Date()
}

struct SettingsAppearanceState: Equatable {
    var routineListSectioningMode: RoutineListSectioningMode = .defaultValue
    var tagCounterDisplayMode: TagCounterDisplayMode = .defaultValue
    var isAppLockEnabled: Bool = false
    var isAppLockToggleInProgress: Bool = false
    var appLockMethodDescription: String = DeviceAuthenticationClient.defaultMethodDescription
    var appLockUnavailableReason: String?
    var appLockStatusMessage: String = ""
    var isGitFeaturesEnabled: Bool = false
    var appIconStatusMessage: String = ""
    var selectedAppIcon: AppIconOption = .orange
    var hasTemporaryViewStateToReset: Bool = false
    var temporaryViewStateStatusMessage: String = ""
}

struct SettingsCloudState: Equatable {
    var cloudUsageEstimate: CloudUsageEstimate = .zero
    var cloudSyncAvailable: Bool = false
    var isCloudSyncInProgress: Bool = false
    var isCloudDataResetInProgress: Bool = false
    var isCloudDataResetConfirmationPresented: Bool = false
    var cloudStatusMessage: String = ""
}

struct SettingsDataTransferState: Equatable {
    var isDataTransferInProgress: Bool = false
    var dataTransferStatusMessage: String = ""
}

struct SettingsGitHubState: Equatable {
    var scope: GitHubStatsScope = .repository
    var repositoryOwner: String = ""
    var repositoryName: String = ""
    var accessTokenDraft: String = ""
    var connectedScope: GitHubStatsScope = .repository
    var connectedRepository: GitHubRepositoryReference?
    var connectedViewerLogin: String?
    var hasSavedAccessToken: Bool = false
    var isOperationInProgress: Bool = false
    var statusMessage: String = ""

    var hasConnectedConfiguration: Bool {
        connectedRepository != nil || connectedViewerLogin?.isEmpty == false
    }
}

struct SettingsGitLabState: Equatable {
    var accessTokenDraft: String = ""
    var connectedUsername: String?
    var hasSavedAccessToken: Bool = false
    var isOperationInProgress: Bool = false
    var statusMessage: String = ""

    var isConnected: Bool {
        hasSavedAccessToken && (connectedUsername?.isEmpty == false)
    }
}

struct SettingsPlacesState: Equatable {
    var savedPlaces: [RoutinePlaceSummary] = []
    var placePendingDeletion: RoutinePlaceSummary?
    var placeDraftName: String = ""
    var placeDraftCoordinate: LocationCoordinate?
    var placeDraftRadiusMeters: Double = 150
    var placeStatusMessage: String = ""
    var isPlaceOperationInProgress: Bool = false
    var locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined
    var lastKnownLocationCoordinate: LocationCoordinate?
    var isDeletePlaceConfirmationPresented: Bool = false
}

struct SettingsTagsState: Equatable {
    var savedTags: [RoutineTagSummary] = []
    var relatedTagRules: [RoutineRelatedTagRule] = []
    var relatedTagDrafts: [String: String] = [:]
    var tagPendingDeletion: RoutineTagSummary?
    var tagPendingRename: RoutineTagSummary?
    var tagRenameDraft: String = ""
    var tagStatusMessage: String = ""
    var isTagOperationInProgress: Bool = false
    var isDeleteTagConfirmationPresented: Bool = false
    var isTagRenameSheetPresented: Bool = false
}

@ObservableState
struct SettingsFeatureState: Equatable {
    var diagnostics = SettingsDiagnosticsState()
    var notifications = SettingsNotificationsState()
    var appearance = SettingsAppearanceState()
    var cloud = SettingsCloudState()
    var dataTransfer = SettingsDataTransferState()
    var github = SettingsGitHubState()
    var gitlab = SettingsGitLabState()
    var places = SettingsPlacesState()
    var tags = SettingsTagsState()
}
