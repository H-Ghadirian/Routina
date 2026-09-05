import Foundation

// Foundation documents UserDefaults as thread-safe, but it does not yet
// declare Sendable. Keep this compatibility conformance centralized here so
// callers do not add scattered concurrency escapes.
extension UserDefaults: @retroactive @unchecked Sendable {}

extension UserDefaults: UserDefaultsProtocol {
    public subscript(key: UserDefaultBoolValueKey) -> Bool {
        get {
            RoutinaExperimentalFeaturePolicy.resolvedValue(
                for: key,
                storedValue: object(forKey: key.rawValue) as? Bool ?? false
            )
        }
        set {
            self.set(
                RoutinaExperimentalFeaturePolicy.resolvedValue(
                    for: key,
                    storedValue: newValue
                ),
                forKey: key.rawValue
            )
        }
    }

    public subscript(key: UserDefaultStringValueKey) -> String? {
        get {
            string(forKey: key.rawValue)
        }
        set {
            set(newValue, forKey: key.rawValue)
        }
    }

    public func register(defaults keysWithValues: [UserDefaultBoolValueKey: Bool]) {
        var rawDefaults: [String: Any] = [:]
        for (key, value) in keysWithValues {
            rawDefaults[key.rawValue] = value
        }
        self.register(defaults: rawDefaults)
    }
}

protocol SharedDefaultsProtocol {
    static var app: UserDefaults { get }
}

enum SharedDefaults: SharedDefaultsProtocol {
    static let app: UserDefaults = {
        let defaults: UserDefaults
        if let suiteDefaults = UserDefaults(suiteName: AppEnvironment.userDefaultsSuiteName) {
            defaults = suiteDefaults
        } else {
            NSLog("Invalid UserDefaults suite '\(AppEnvironment.userDefaultsSuiteName)'. Falling back to standard defaults.")
            defaults = .standard
        }

        RoutinaExperimentalFeaturePolicy.enforceReleaseState(in: defaults)
        return defaults
    }()
}

enum AppSettingsDefaults {
    static let boolValues: [UserDefaultBoolValueKey: Bool] = [
        .appSettingNotificationsEnabled: false,
        .appSettingHideUnavailableRoutines: false,
        .appSettingAppLockEnabled: false,
        .appSettingGitFeaturesEnabled: false,
        .appSettingTaskSharingEnabled: false,
        .appSettingTaskRelationshipVisualizerEnabled: false,
        .appSettingPlacesEnabled: false,
        .appSettingNotesEnabled: false,
        .appSettingAwayEnabled: false,
        .appSettingFilterQuerySectionsEnabled: false,
        .appSettingUnlockUnlimitedTasks: false,
        .appSettingHomeTaskListModeTabsVisible: false,
        .appSettingMacHomeSectionFocusTimersEnabled: false,
        .appSettingMacTimelineQuickFiltersVisible: false,
        .appSettingMacStatusComposerEnabled: false,
        .appSettingMacShowDoneCountInToolbar: false,
        .appSettingMacDevelopmentBadgeVisible: true,
        .appSettingMacLocalAIAccessEnabled: false,
        .appSettingSettingsDevicesSectionEnabled: false,
        .appSettingMacEventEmotionActionsEnabled: false,
        .appSettingRelatedTagRulesEnabled: false,
        .appSettingGoalsTabEnabled: false,
        .appSettingAdventureMapEnabled: false,
        .appSettingBoardScreenEnabled: false,
        .appSettingStatsWinsEnabled: false,
        .appSettingStatsSleepTabEnabled: false,
        .appSettingStatsAchievementsEnabled: false,
        .appSettingMacStatsDashboardControlsEnabled: false,
        .appSettingShowPersianDates: false,
        .appSettingBatteryRoutineMonitoringEnabled: BatteryRoutinePreferences.defaultMonitoringEnabled,
        .appSettingSleepHomeActionEnabled: true,
        .appSettingSleepHomeMenuEnabled: true,
        .appSettingShakeToStartSleepEnabled: true,
        .appSettingFocusShieldEnabled: false,
        .appSettingMacFocusAppBlockingEnabled: true,
        .appSettingMacWebsiteBlockingEnabled: false,
        .appSettingAutomaticPlaceCheckInEnabled: true,
        .appSettingShowTimelineTasksInDayPlanner: true,
        .appSettingSeparateDailyRoutinesInTaskList: false,
        .appSettingShowTomorrowInTaskList: false,
        .appSettingSeparateTodosAndRoutinesInTagTaskListSections: false,
        .appSettingSeparateDeadlineStatusInTagTaskListSections: false,
        .appSettingDayPlanCalendarListAssumedDoneCollapsedByDefault: true,
        .appSettingDailyRoutinesSectionCollapsed: false,
        .appSettingMacPlanTodayDailyRoutinesGroupCollapsed: true,
        .appSettingMacFutureTasksSectionCollapsed: true,
        .appSettingArchivedRoutinesSectionCollapsed: false,
    ]
    static let stringValues: [String: String] = [
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue: RoutineListSectioningMode.defaultValue.rawValue,
        UserDefaultStringValueKey.appSettingCollapsedTagTaskListSections.rawValue: "",
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue: "",
        UserDefaultStringValueKey.appSettingMacHomeTaskListSectionOrder.rawValue: "",
        UserDefaultStringValueKey.appSettingMacTaskRankingReversedMetrics.rawValue: "",
        UserDefaultStringValueKey.appSettingHomeTaskRowHiddenFields.rawValue: "",
        UserDefaultStringValueKey.appSettingBacklogTaskRowHiddenFields.rawValue: HomeTaskRowVisibility.backlogDefaultStorageRawValue,
        UserDefaultStringValueKey.appSettingTaskLadderTaskRowHiddenFields.rawValue: HomeTaskRowVisibility.taskLadderDefaultStorageRawValue,
        UserDefaultStringValueKey.appSettingHomeTimelineRowHiddenFields.rawValue: "",
        UserDefaultStringValueKey.appSettingDayPlanCalendarListRowHiddenFields.rawValue: "",
        UserDefaultStringValueKey.appSettingProtectionBlockingEnabledModes.rawValue: ProtectionBlockingMode.encodedSet(
            ProtectionBlockingMode.defaultEnabledModes
        ),
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue: "optionCommandN",
    ]
    static let intValues: [String: Int] = [
        BatteryRoutinePreferences.thresholdPercentDefaultsKey: BatteryRoutinePreferences.defaultThresholdPercent,
        NotificationPreferences.reminderHourDefaultsKey: NotificationPreferences.defaultReminderHour,
        NotificationPreferences.reminderMinuteDefaultsKey: NotificationPreferences.defaultReminderMinute,
    ]

    static let resetOnlyStringKeys: [UserDefaultStringValueKey] = [
        .selectedMacAppIcon,
        .appSettingAppColorScheme,
        .appSettingTagCounterDisplayMode,
        .appSettingRelatedTagRules,
        .appSettingTagRules,
        .appSettingFlagRules,
        .appSettingDefinedFlags,
        .appSettingTagColors,
        .appSettingFastFilterTags,
        .appSettingIOSStatsDashboardHiddenItemIDs,
        .appSettingIOSStatsDashboardItemOrderIDs,
        .appSettingIOSStatsSummaryDisplayMode,
        .appSettingMacStatsDashboardHiddenItemIDs,
        .appSettingMacStatsDashboardItemOrderIDs,
        .appSettingMacStatsSummaryDisplayMode,
        .appSettingHiddenDayPlanTimelineActivityIDs,
        .appSettingTemporaryViewState,
        .appSettingMacPlannerPresentationPreferences,
        .appSettingCustomTaskSections,
        .appSettingMacHomeTaskListSectionOrder,
        .appSettingMacTaskRankingReversedMetrics,
        .appSettingMacTaskLadderOrganization,
        .appSettingTaskLadderTaskRowHiddenFields,
        .appSettingBlockingWebsiteDomains,
        .appSettingFocusShieldSelection,
        .appSettingMacFocusBlockedApps,
        .macFormSectionOrder,
    ]
}

enum AppSettingsPersistenceMirror {
    static func schedule() {
        Task { @MainActor in
            RoutinaUserPreferencesStore.mirrorDefaultsToStore(
                in: PersistenceController.shared.container.mainContext
            )
        }
    }
}

public enum UserDefaultBoolValueKey: String, Sendable {
    case appSettingNotificationsEnabled
    case appSettingHideUnavailableRoutines
    case appSettingAppLockEnabled
    case appSettingGitFeaturesEnabled
    case appSettingTaskSharingEnabled
    case appSettingTaskRelationshipVisualizerEnabled
    case appSettingPlacesEnabled
    case appSettingNotesEnabled
    case appSettingAwayEnabled
    case appSettingFilterQuerySectionsEnabled
    case appSettingUnlockUnlimitedTasks
    case appSettingGoalsTabEnabled
    case appSettingAdventureMapEnabled
    case appSettingBoardScreenEnabled
    case appSettingStatsWinsEnabled
    case appSettingStatsSleepTabEnabled
    case appSettingStatsAchievementsEnabled
    case appSettingMacStatsDashboardControlsEnabled
    case appSettingHomeTaskListModeTabsVisible
    case appSettingMacHomeSectionFocusTimersEnabled
    case appSettingMacTimelineQuickFiltersVisible
    case appSettingMacStatusComposerEnabled
    case appSettingMacShowDoneCountInToolbar
    case appSettingMacDevelopmentBadgeVisible
    case appSettingMacLocalAIAccessEnabled
    case appSettingSettingsDevicesSectionEnabled
    case appSettingRelatedTagRulesEnabled
    case appSettingMacEventEmotionActionsEnabled
    case appSettingShowPersianDates
    case appSettingBatteryRoutineMonitoringEnabled
    case appSettingSleepHomeActionEnabled = "appSettingSleepHomeDockEnabled"
    case appSettingSleepHomeMenuEnabled
    case appSettingShakeToStartSleepEnabled
    case appSettingFocusShieldEnabled
    case appSettingMacFocusAppBlockingEnabled
    case appSettingMacWebsiteBlockingEnabled
    case appSettingAutomaticPlaceCheckInEnabled
    case appSettingShowTimelineTasksInDayPlanner = "appSettingShowDayPlanUnplannedDoneBadges"
    case appSettingSeparateDailyRoutinesInTaskList
    case appSettingShowTomorrowInTaskList
    case appSettingSeparateTodosAndRoutinesInTagTaskListSections
    case appSettingSeparateDeadlineStatusInTagTaskListSections
    case appSettingDayPlanCalendarListAssumedDoneCollapsedByDefault
    case appSettingDailyRoutinesSectionCollapsed
    case appSettingMacPlanTodayDailyRoutinesGroupCollapsed
    case appSettingMacFutureTasksSectionCollapsed
    case appSettingArchivedRoutinesSectionCollapsed
    case requestNotificationPermission
}

enum RoutinaExperimentalFeaturePolicy {
    static let preferenceKeys: Set<UserDefaultBoolValueKey> = [
        .appSettingGitFeaturesEnabled,
        .appSettingTaskSharingEnabled,
        .appSettingTaskRelationshipVisualizerEnabled,
        .appSettingPlacesEnabled,
        .appSettingNotesEnabled,
        .appSettingAwayEnabled,
        .appSettingFilterQuerySectionsEnabled,
        .appSettingUnlockUnlimitedTasks,
        .appSettingGoalsTabEnabled,
        .appSettingAdventureMapEnabled,
        .appSettingBoardScreenEnabled,
        .appSettingStatsWinsEnabled,
        .appSettingStatsSleepTabEnabled,
        .appSettingStatsAchievementsEnabled,
        .appSettingMacStatsDashboardControlsEnabled,
        .appSettingHomeTaskListModeTabsVisible,
        .appSettingMacHomeSectionFocusTimersEnabled,
        .appSettingMacTimelineQuickFiltersVisible,
        .appSettingMacStatusComposerEnabled,
        .appSettingSettingsDevicesSectionEnabled,
        .appSettingRelatedTagRulesEnabled,
        .appSettingMacEventEmotionActionsEnabled,
        .appSettingMacWebsiteBlockingEnabled,
    ]

    static var isAvailableInCurrentProcess: Bool {
        #if SWIFT_PACKAGE
            true
        #else
            AppEnvironment.isDevelopmentAppVariant || AppEnvironment.isAutomatedTestMode
        #endif
    }

    static func resolvedValue(
        for key: UserDefaultBoolValueKey,
        storedValue: Bool,
        isDevelopmentAppVariant: Bool = isAvailableInCurrentProcess
    ) -> Bool {
        guard preferenceKeys.contains(key) else { return storedValue }
        return isDevelopmentAppVariant && storedValue
    }

    static func enforceReleaseState(
        in defaults: UserDefaults,
        isDevelopmentAppVariant: Bool = isAvailableInCurrentProcess
    ) {
        guard !isDevelopmentAppVariant else { return }

        for key in preferenceKeys {
            defaults.set(false, forKey: key.rawValue)
        }
    }
}

public enum UserDefaultStringValueKey: String, Sendable {
    case selectedMacAppIcon
    case appSettingAppColorScheme
    case appSettingRoutineListSectioningMode
    case appSettingCollapsedTagTaskListSections
    case appSettingCustomTaskSections
    case appSettingMacHomeTaskListSectionOrder
    case appSettingMacTaskRankingReversedMetrics
    case appSettingMacTaskLadderOrganization
    case appSettingTagCounterDisplayMode
    case appSettingHomeTaskRowHiddenFields
    case appSettingBacklogTaskRowHiddenFields
    case appSettingTaskLadderTaskRowHiddenFields
    case appSettingHomeTimelineRowHiddenFields
    case appSettingDayPlanCalendarListRowHiddenFields
    case appSettingRelatedTagRules
    case appSettingTagRules
    case appSettingFlagRules
    case appSettingDefinedFlags
    case appSettingTagColors
    case appSettingFastFilterTags
    case appSettingIOSStatsDashboardHiddenItemIDs
    case appSettingIOSStatsDashboardItemOrderIDs
    case appSettingIOSStatsSummaryDisplayMode
    case appSettingMacStatsDashboardHiddenItemIDs
    case appSettingMacStatsDashboardItemOrderIDs
    case appSettingMacStatsSummaryDisplayMode
    case appSettingMacAdventureOwnedItemIDs
    case appSettingMacAdventureUnlockedWorldIDs
    case appSettingMacAdventureUnlockedStageIDs
    case appSettingHiddenDayPlanTimelineActivityIDs
    case appSettingTemporaryViewState
    case appSettingMacPlannerPresentationPreferences
    case appSettingProtectionBlockingEnabledModes
    case appSettingBlockingWebsiteDomains
    case appSettingFocusShieldSelection
    case appSettingMacFocusBlockedApps
    case appSettingLastRoutineDataBackupDate
    case macFormSectionOrder
    case macQuickAddShortcut
}

public protocol UserDefaultsProtocol {
    subscript(key: UserDefaultBoolValueKey) -> Bool { get set }
    subscript(key: UserDefaultStringValueKey) -> String? { get set }
    func register(defaults keysWithValues: [UserDefaultBoolValueKey: Bool])
}

struct AppSettingsClient: Sendable {
    var notificationsEnabled: @Sendable () -> Bool
    var setNotificationsEnabled: @Sendable (Bool) -> Void
    var hideUnavailableRoutines: @Sendable () -> Bool
    var setHideUnavailableRoutines: @Sendable (Bool) -> Void
    var appLockEnabled: @Sendable () -> Bool
    var setAppLockEnabled: @Sendable (Bool) -> Void
    var gitFeaturesEnabled: @Sendable () -> Bool
    var setGitFeaturesEnabled: @Sendable (Bool) -> Void
    var taskSharingEnabled: @Sendable () -> Bool = { false }
    var setTaskSharingEnabled: @Sendable (Bool) -> Void = { _ in }
    var taskRelationshipVisualizerEnabled: @Sendable () -> Bool = { false }
    var setTaskRelationshipVisualizerEnabled: @Sendable (Bool) -> Void = { _ in }
    var placesEnabled: @Sendable () -> Bool = { false }
    var setPlacesEnabled: @Sendable (Bool) -> Void = { _ in }
    var notesEnabled: @Sendable () -> Bool = { false }
    var setNotesEnabled: @Sendable (Bool) -> Void = { _ in }
    var awayEnabled: @Sendable () -> Bool = { false }
    var setAwayEnabled: @Sendable (Bool) -> Void = { _ in }
    var goalsEnabled: @Sendable () -> Bool = { false }
    var eventEmotionActionsEnabled: @Sendable () -> Bool = { false }
    var filterQuerySectionsEnabled: @Sendable () -> Bool = { false }
    var setFilterQuerySectionsEnabled: @Sendable (Bool) -> Void = { _ in }
    var showPersianDates: @Sendable () -> Bool
    var setShowPersianDates: @Sendable (Bool) -> Void
    var automaticPlaceCheckInEnabled: @Sendable () -> Bool
    var setAutomaticPlaceCheckInEnabled: @Sendable (Bool) -> Void
    var showTimelineTasksInDayPlanner: @Sendable () -> Bool
    var setShowTimelineTasksInDayPlanner: @Sendable (Bool) -> Void
    var separateDailyRoutinesInTaskList: @Sendable () -> Bool
    var setSeparateDailyRoutinesInTaskList: @Sendable (Bool) -> Void
    var showTomorrowInTaskList: @Sendable () -> Bool = { false }
    var setShowTomorrowInTaskList: @Sendable (Bool) -> Void = { _ in }
    var showDoneCountInToolbar: @Sendable () -> Bool = { false }
    var setShowDoneCountInToolbar: @Sendable (Bool) -> Void = { _ in }
    var appColorScheme: @Sendable () -> AppColorScheme
    var setAppColorScheme: @Sendable (AppColorScheme) -> Void
    var routineListSectioningMode: @Sendable () -> RoutineListSectioningMode
    var setRoutineListSectioningMode: @Sendable (RoutineListSectioningMode) -> Void
    var tagCounterDisplayMode: @Sendable () -> TagCounterDisplayMode
    var setTagCounterDisplayMode: @Sendable (TagCounterDisplayMode) -> Void
    var taskRowVisibility: @Sendable () -> HomeTaskRowVisibility
    var setTaskRowVisibility: @Sendable (HomeTaskRowVisibility) -> Void
    var timelineRowVisibility: @Sendable () -> HomeTimelineRowVisibility
    var setTimelineRowVisibility: @Sendable (HomeTimelineRowVisibility) -> Void
    var relatedTagRules: @Sendable () -> [RoutineRelatedTagRule]
    var setRelatedTagRules: @Sendable ([RoutineRelatedTagRule]) -> Void
    var tagRules: @Sendable () -> [RoutineTagRule]
    var setTagRules: @Sendable ([RoutineTagRule]) -> Void
    var flagRules: @Sendable () -> [RoutineFlagRule] = { [] }
    var setFlagRules: @Sendable ([RoutineFlagRule]) -> Void = { _ in }
    var taskLadderOrganization: @Sendable () -> TaskLadderOrganization = { TaskLadderOrganization() }
    var setTaskLadderOrganization: @Sendable (TaskLadderOrganization) -> Void = { _ in }
    var definedFlags: @Sendable () -> [String] = { [] }
    var setDefinedFlags: @Sendable ([String]) -> Void = { _ in }
    var tagColors: @Sendable () -> [String: String]
    var setTagColors: @Sendable ([String: String]) -> Void
    var fastFilterTags: @Sendable () -> [String]
    var setFastFilterTags: @Sendable ([String]) -> Void
    var notificationReminderTime: @Sendable () -> Date
    var setNotificationReminderTime: @Sendable (Date) -> Void
    var lastRoutineDataBackupDate: @Sendable () -> Date?
    var setLastRoutineDataBackupDate: @Sendable (Date?) -> Void
    var selectedAppIcon: @Sendable () -> AppIconOption
    var hiddenDayPlanTimelineActivityIDs: @Sendable () -> String?
    var customTaskSections: @Sendable () -> [HomeCustomTaskSection] = { [] }
    var temporaryViewState: @Sendable () -> TemporaryViewState?
    var setTemporaryViewState: @Sendable (TemporaryViewState?) -> Void
    var hasSavedMacPlannerPresentationPreferences: @Sendable () -> Bool = { false }
    var resetTemporaryViewState: @Sendable () -> Void
    var resetAllSettingsToDefaults: @Sendable () -> Void = {}
}
