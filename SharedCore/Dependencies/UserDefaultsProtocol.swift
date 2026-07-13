import Foundation

extension UserDefaults: @retroactive @unchecked Sendable {}

extension UserDefaults: UserDefaultsProtocol {
    public subscript(key: UserDefaultBoolValueKey) -> Bool {
        get {
            return object(forKey: key.rawValue) as? Bool ?? false
        }
        set {
            self.set(newValue, forKey: key.rawValue)
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
        if let suiteDefaults = UserDefaults(suiteName: AppEnvironment.userDefaultsSuiteName) {
            return suiteDefaults
        }

        NSLog("Invalid UserDefaults suite '\(AppEnvironment.userDefaultsSuiteName)'. Falling back to standard defaults.")
        return .standard
    }()
}

enum AppSettingsDefaults {
    static let boolValues: [UserDefaultBoolValueKey: Bool] = [
        .appSettingNotificationsEnabled: false,
        .appSettingHideUnavailableRoutines: false,
        .appSettingAppLockEnabled: false,
        .appSettingTaskSharingEnabled: false,
        .appSettingTaskRelationshipVisualizerEnabled: false,
        .appSettingPlacesEnabled: false,
        .appSettingNotesEnabled: false,
        .appSettingAwayEnabled: false,
        .appSettingFilterQuerySectionsEnabled: false,
        .appSettingUnlockUnlimitedTasks: AppEnvironment.defaultUnlocksAllTasks,
        .appSettingHomeTaskListModeTabsVisible: false,
        .appSettingMacHomeSectionFocusTimersEnabled: false,
        .appSettingMacTimelineQuickFiltersVisible: false,
        .appSettingMacStatusComposerEnabled: false,
        .appSettingMacShowDoneCountInToolbar: false,
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
        .appSettingDailyRoutinesSectionCollapsed: false,
        .appSettingMacPlanTodayDailyRoutinesGroupCollapsed: true,
        .appSettingMacFutureTasksSectionCollapsed: true,
        .appSettingArchivedRoutinesSectionCollapsed: false
    ]

    static let stringValues: [String: String] = [
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue: RoutineListSectioningMode.defaultValue.rawValue,
        UserDefaultStringValueKey.appSettingCollapsedTagTaskListSections.rawValue: "",
        UserDefaultStringValueKey.appSettingHomeTaskRowHiddenFields.rawValue: "",
        UserDefaultStringValueKey.appSettingHomeTimelineRowHiddenFields.rawValue: "",
        UserDefaultStringValueKey.appSettingProtectionBlockingEnabledModes.rawValue: ProtectionBlockingMode.encodedSet(
            ProtectionBlockingMode.defaultEnabledModes
        ),
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue: "optionCommandN"
    ]

    static let intValues: [String: Int] = [
        BatteryRoutinePreferences.thresholdPercentDefaultsKey: BatteryRoutinePreferences.defaultThresholdPercent,
        NotificationPreferences.reminderHourDefaultsKey: NotificationPreferences.defaultReminderHour,
        NotificationPreferences.reminderMinuteDefaultsKey: NotificationPreferences.defaultReminderMinute
    ]

    static let resetOnlyStringKeys: [UserDefaultStringValueKey] = [
        .selectedMacAppIcon,
        .appSettingAppColorScheme,
        .appSettingTagCounterDisplayMode,
        .appSettingRelatedTagRules,
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
        .appSettingBlockingWebsiteDomains,
        .appSettingFocusShieldSelection,
        .appSettingMacFocusBlockedApps,
        .macFormSectionOrder
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
    case appSettingDailyRoutinesSectionCollapsed
    case appSettingMacPlanTodayDailyRoutinesGroupCollapsed
    case appSettingMacFutureTasksSectionCollapsed
    case appSettingArchivedRoutinesSectionCollapsed
    case requestNotificationPermission
}

public enum UserDefaultStringValueKey: String, Sendable {
    case selectedMacAppIcon
    case appSettingAppColorScheme
    case appSettingRoutineListSectioningMode
    case appSettingCollapsedTagTaskListSections
    case appSettingTagCounterDisplayMode
    case appSettingHomeTaskRowHiddenFields
    case appSettingHomeTimelineRowHiddenFields
    case appSettingRelatedTagRules
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
    var filterQuerySectionsEnabled: @Sendable () -> Bool = { false }
    var setFilterQuerySectionsEnabled: @Sendable (Bool) -> Void = { _ in }
    var unlockUnlimitedTasks: @Sendable () -> Bool = { false }
    var setUnlockUnlimitedTasks: @Sendable (Bool) -> Void = { _ in }
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
    var temporaryViewState: @Sendable () -> TemporaryViewState?
    var setTemporaryViewState: @Sendable (TemporaryViewState?) -> Void
    var resetTemporaryViewState: @Sendable () -> Void
    var resetAllSettingsToDefaults: @Sendable () -> Void = {}
}

enum CloudSettingsKeyValueSync {
    static let didChangeNotification = Notification.Name("CloudSettingsKeyValueSync.didChange")

    private static let observerBox = CloudSettingsObserverBox()
    private static let syncedStringKeys: Set<UserDefaultStringValueKey> = [
        .selectedMacAppIcon,
        .appSettingRelatedTagRules,
        .appSettingTagColors,
        .appSettingFastFilterTags,
        .appSettingIOSStatsDashboardHiddenItemIDs,
        .appSettingIOSStatsDashboardItemOrderIDs,
        .appSettingIOSStatsSummaryDisplayMode,
        .appSettingMacStatsDashboardHiddenItemIDs,
        .appSettingMacStatsDashboardItemOrderIDs,
        .appSettingMacStatsSummaryDisplayMode,
        .appSettingHiddenDayPlanTimelineActivityIDs
    ]

    static func startIfNeeded() {
        guard AppEnvironment.isCloudSyncEnabled,
              !AppEnvironment.isAutomatedTestMode else {
            return
        }

        guard observerBox.observer == nil else {
            synchronizeKnownValues()
            return
        }

        let observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { notification in
            handleExternalChange(notification)
        }
        observerBox.observer = observer
        synchronizeKnownValues()
    }

    static func string(for key: UserDefaultStringValueKey) -> String? {
        guard syncedStringKeys.contains(key),
              AppEnvironment.isCloudSyncEnabled,
              !AppEnvironment.isAutomatedTestMode else {
            return SharedDefaults.app[key]
        }

        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        guard let remoteValue = store.string(forKey: key.rawValue) else {
            return SharedDefaults.app[key]
        }

        if SharedDefaults.app[key] != remoteValue {
            SharedDefaults.app[key] = remoteValue
        }
        return remoteValue
    }

    static func setString(_ value: String?, for key: UserDefaultStringValueKey) {
        SharedDefaults.app[key] = value
        AppSettingsPersistenceMirror.schedule()

        guard syncedStringKeys.contains(key),
              AppEnvironment.isCloudSyncEnabled,
              !AppEnvironment.isAutomatedTestMode else {
            return
        }

        let store = NSUbiquitousKeyValueStore.default
        if let value {
            store.set(value, forKey: key.rawValue)
        } else {
            store.removeObject(forKey: key.rawValue)
        }
        store.synchronize()
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func synchronizeKnownValues() {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        var didUpdateLocalDefaults = false

        for key in syncedStringKeys {
            if let remoteValue = store.string(forKey: key.rawValue) {
                if SharedDefaults.app[key] != remoteValue {
                    SharedDefaults.app[key] = remoteValue
                    didUpdateLocalDefaults = true
                }
            } else if let localValue = SharedDefaults.app[key] {
                store.set(localValue, forKey: key.rawValue)
            }
        }

        store.synchronize()
        if didUpdateLocalDefaults {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }

    private static func handleExternalChange(_ notification: Notification) {
        guard let changedRawKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            synchronizeKnownValues()
            return
        }

        let store = NSUbiquitousKeyValueStore.default
        var didUpdateLocalDefaults = false
        for key in syncedStringKeys where changedRawKeys.contains(key.rawValue) {
            let value = store.string(forKey: key.rawValue)
            if SharedDefaults.app[key] != value {
                SharedDefaults.app[key] = value
                didUpdateLocalDefaults = true
            }
        }

        if didUpdateLocalDefaults {
            NotificationCenter.default.post(name: didChangeNotification, object: nil)
        }
    }
}

private final class CloudSettingsObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: NSObjectProtocol?

    var observer: NSObjectProtocol? {
        get {
            lock.withLock { value }
        }
        set {
            lock.withLock {
                value = newValue
            }
        }
    }
}

extension AppSettingsClient {
    static let live = AppSettingsClient(
        notificationsEnabled: {
            SharedDefaults.app[.appSettingNotificationsEnabled]
        },
        setNotificationsEnabled: { isEnabled in
            SharedDefaults.app[.appSettingNotificationsEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        hideUnavailableRoutines: {
            SharedDefaults.app[.appSettingHideUnavailableRoutines]
        },
        setHideUnavailableRoutines: { isHidden in
            SharedDefaults.app[.appSettingHideUnavailableRoutines] = isHidden
            AppSettingsPersistenceMirror.schedule()
        },
        appLockEnabled: {
            SharedDefaults.app[.appSettingAppLockEnabled]
        },
        setAppLockEnabled: { isEnabled in
            SharedDefaults.app[.appSettingAppLockEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        gitFeaturesEnabled: {
            SharedDefaults.app[.appSettingGitFeaturesEnabled]
        },
        setGitFeaturesEnabled: { isEnabled in
            SharedDefaults.app[.appSettingGitFeaturesEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        taskSharingEnabled: {
            SharedDefaults.app[.appSettingTaskSharingEnabled]
        },
        setTaskSharingEnabled: { isEnabled in
            SharedDefaults.app[.appSettingTaskSharingEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        taskRelationshipVisualizerEnabled: {
            SharedDefaults.app[.appSettingTaskRelationshipVisualizerEnabled]
        },
        setTaskRelationshipVisualizerEnabled: { isEnabled in
            SharedDefaults.app[.appSettingTaskRelationshipVisualizerEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        placesEnabled: {
            SharedDefaults.app[.appSettingPlacesEnabled]
        },
        setPlacesEnabled: { isEnabled in
            SharedDefaults.app[.appSettingPlacesEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        notesEnabled: {
            SharedDefaults.app[.appSettingNotesEnabled]
        },
        setNotesEnabled: { isEnabled in
            SharedDefaults.app[.appSettingNotesEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        awayEnabled: {
            SharedDefaults.app[.appSettingAwayEnabled]
        },
        setAwayEnabled: { isEnabled in
            SharedDefaults.app[.appSettingAwayEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        filterQuerySectionsEnabled: {
            SharedDefaults.app[.appSettingFilterQuerySectionsEnabled]
        },
        setFilterQuerySectionsEnabled: { isEnabled in
            SharedDefaults.app[.appSettingFilterQuerySectionsEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        unlockUnlimitedTasks: {
            SharedDefaults.app[.appSettingUnlockUnlimitedTasks]
        },
        setUnlockUnlimitedTasks: { isEnabled in
            SharedDefaults.app[.appSettingUnlockUnlimitedTasks] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        showPersianDates: {
            SharedDefaults.app[.appSettingShowPersianDates]
        },
        setShowPersianDates: { isEnabled in
            SharedDefaults.app[.appSettingShowPersianDates] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        automaticPlaceCheckInEnabled: {
            SharedDefaults.app[.appSettingAutomaticPlaceCheckInEnabled]
        },
        setAutomaticPlaceCheckInEnabled: { isEnabled in
            SharedDefaults.app[.appSettingAutomaticPlaceCheckInEnabled] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        showTimelineTasksInDayPlanner: {
            SharedDefaults.app[.appSettingShowTimelineTasksInDayPlanner]
        },
        setShowTimelineTasksInDayPlanner: { isEnabled in
            SharedDefaults.app[.appSettingShowTimelineTasksInDayPlanner] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        separateDailyRoutinesInTaskList: {
            SharedDefaults.app[.appSettingSeparateDailyRoutinesInTaskList]
        },
        setSeparateDailyRoutinesInTaskList: { isEnabled in
            SharedDefaults.app[.appSettingSeparateDailyRoutinesInTaskList] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        showTomorrowInTaskList: {
            SharedDefaults.app[.appSettingShowTomorrowInTaskList]
        },
        setShowTomorrowInTaskList: { isEnabled in
            SharedDefaults.app[.appSettingShowTomorrowInTaskList] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        showDoneCountInToolbar: {
            SharedDefaults.app[.appSettingMacShowDoneCountInToolbar]
        },
        setShowDoneCountInToolbar: { isEnabled in
            SharedDefaults.app[.appSettingMacShowDoneCountInToolbar] = isEnabled
            AppSettingsPersistenceMirror.schedule()
        },
        appColorScheme: {
            AppColorScheme(
                rawValue: SharedDefaults.app[.appSettingAppColorScheme] ?? ""
            ) ?? .system
        },
        setAppColorScheme: { scheme in
            SharedDefaults.app[.appSettingAppColorScheme] = scheme.rawValue
            AppSettingsPersistenceMirror.schedule()
        },
        routineListSectioningMode: {
            RoutineListSectioningMode.preferenceValue(
                rawValue: SharedDefaults.app[.appSettingRoutineListSectioningMode]
            )
        },
        setRoutineListSectioningMode: { mode in
            SharedDefaults.app[.appSettingRoutineListSectioningMode] = mode.availableValue.rawValue
            AppSettingsPersistenceMirror.schedule()
        },
        tagCounterDisplayMode: {
            TagCounterDisplayMode(
                rawValue: SharedDefaults.app[.appSettingTagCounterDisplayMode] ?? ""
            ) ?? .defaultValue
        },
        setTagCounterDisplayMode: { mode in
            SharedDefaults.app[.appSettingTagCounterDisplayMode] = mode.rawValue
            AppSettingsPersistenceMirror.schedule()
        },
        taskRowVisibility: {
            HomeTaskRowVisibility(
                storageRawValue: SharedDefaults.app[.appSettingHomeTaskRowHiddenFields]
            )
        },
        setTaskRowVisibility: { visibility in
            SharedDefaults.app[.appSettingHomeTaskRowHiddenFields] = visibility.storageRawValue
            AppSettingsPersistenceMirror.schedule()
        },
        timelineRowVisibility: {
            HomeTimelineRowVisibility(
                storageRawValue: SharedDefaults.app[.appSettingHomeTimelineRowHiddenFields]
            )
        },
        setTimelineRowVisibility: { visibility in
            SharedDefaults.app[.appSettingHomeTimelineRowHiddenFields] = visibility.storageRawValue
            AppSettingsPersistenceMirror.schedule()
        },
        relatedTagRules: {
            guard let rawValue = CloudSettingsKeyValueSync.string(for: .appSettingRelatedTagRules),
                  let data = rawValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([RoutineRelatedTagRule].self, from: data)
            else {
                return []
            }
            return RoutineTagRelations.sanitized(decoded)
        },
        setRelatedTagRules: { rules in
            let sanitizedRules = RoutineTagRelations.sanitized(rules)
            guard !sanitizedRules.isEmpty else {
                CloudSettingsKeyValueSync.setString(nil, for: .appSettingRelatedTagRules)
                return
            }
            guard let data = try? JSONEncoder().encode(sanitizedRules),
                  let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }
            CloudSettingsKeyValueSync.setString(rawValue, for: .appSettingRelatedTagRules)
        },
        tagColors: {
            guard let rawValue = CloudSettingsKeyValueSync.string(for: .appSettingTagColors),
                  let data = rawValue.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String: String].self, from: data)
            else {
                return [:]
            }
            return RoutineTagColors.sanitized(decoded)
        },
        setTagColors: { colors in
            let sanitizedColors = RoutineTagColors.sanitized(colors)
            guard !sanitizedColors.isEmpty else {
                CloudSettingsKeyValueSync.setString(nil, for: .appSettingTagColors)
                return
            }
            guard let data = try? JSONEncoder().encode(sanitizedColors),
                  let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }
            CloudSettingsKeyValueSync.setString(rawValue, for: .appSettingTagColors)
        },
        fastFilterTags: {
            FastFilterTags.decoded(from: CloudSettingsKeyValueSync.string(for: .appSettingFastFilterTags))
        },
        setFastFilterTags: { tags in
            CloudSettingsKeyValueSync.setString(
                FastFilterTags.encoded(tags),
                for: .appSettingFastFilterTags
            )
        },
        notificationReminderTime: {
            NotificationPreferences.reminderTimeDate()
        },
        setNotificationReminderTime: { date in
            NotificationPreferences.storeReminderTime(date)
            AppSettingsPersistenceMirror.schedule()
        },
        lastRoutineDataBackupDate: {
            guard let rawValue = SharedDefaults.app[.appSettingLastRoutineDataBackupDate],
                  let timestamp = TimeInterval(rawValue)
            else {
                return nil
            }
            return Date(timeIntervalSince1970: timestamp)
        },
        setLastRoutineDataBackupDate: { date in
            SharedDefaults.app[.appSettingLastRoutineDataBackupDate] = date.map {
                String($0.timeIntervalSince1970)
            }
            AppSettingsPersistenceMirror.schedule()
        },
        selectedAppIcon: {
            .persistedSelection
        },
        hiddenDayPlanTimelineActivityIDs: {
            SharedDefaults.app[.appSettingHiddenDayPlanTimelineActivityIDs]
        },
        temporaryViewState: {
            guard let rawValue = SharedDefaults.app[.appSettingTemporaryViewState],
                  let data = rawValue.data(using: .utf8)
            else {
                return nil
            }

            return try? JSONDecoder().decode(TemporaryViewState.self, from: data)
        },
        setTemporaryViewState: { state in
            guard let state else {
                SharedDefaults.app[.appSettingTemporaryViewState] = nil
                AppSettingsPersistenceMirror.schedule()
                return
            }

            guard let data = try? JSONEncoder().encode(state),
                  let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }

            SharedDefaults.app[.appSettingTemporaryViewState] = rawValue
            AppSettingsPersistenceMirror.schedule()
        },
        resetTemporaryViewState: {
            SharedDefaults.app[.appSettingHideUnavailableRoutines] = false
            SharedDefaults.app[.appSettingTemporaryViewState] = nil
            SharedDefaults.app[.appSettingHiddenDayPlanTimelineActivityIDs] = nil
            AppSettingsPersistenceMirror.schedule()
        },
        resetAllSettingsToDefaults: {
            for (key, value) in AppSettingsDefaults.boolValues {
                SharedDefaults.app[key] = value
            }
            for key in AppSettingsDefaults.resetOnlyStringKeys {
                CloudSettingsKeyValueSync.setString(nil, for: key)
            }
            for (key, value) in AppSettingsDefaults.stringValues {
                SharedDefaults.app.set(value, forKey: key)
            }
            for (key, value) in AppSettingsDefaults.intValues {
                SharedDefaults.app.set(value, forKey: key)
            }
            BatteryRoutinePreferences.notifyChanged()
            AppSettingsPersistenceMirror.schedule()
        }
    )

    static let noop = AppSettingsClient(
        notificationsEnabled: { false },
        setNotificationsEnabled: { _ in },
        hideUnavailableRoutines: { false },
        setHideUnavailableRoutines: { _ in },
        appLockEnabled: { false },
        setAppLockEnabled: { _ in },
        gitFeaturesEnabled: { false },
        setGitFeaturesEnabled: { _ in },
        taskSharingEnabled: { false },
        setTaskSharingEnabled: { _ in },
        taskRelationshipVisualizerEnabled: { false },
        setTaskRelationshipVisualizerEnabled: { _ in },
        placesEnabled: { false },
        setPlacesEnabled: { _ in },
        notesEnabled: { false },
        setNotesEnabled: { _ in },
        awayEnabled: { false },
        setAwayEnabled: { _ in },
        filterQuerySectionsEnabled: { false },
        setFilterQuerySectionsEnabled: { _ in },
        unlockUnlimitedTasks: { false },
        setUnlockUnlimitedTasks: { _ in },
        showPersianDates: { false },
        setShowPersianDates: { _ in },
        automaticPlaceCheckInEnabled: { true },
        setAutomaticPlaceCheckInEnabled: { _ in },
        showTimelineTasksInDayPlanner: { true },
        setShowTimelineTasksInDayPlanner: { _ in },
        separateDailyRoutinesInTaskList: { false },
        setSeparateDailyRoutinesInTaskList: { _ in },
        showTomorrowInTaskList: { false },
        setShowTomorrowInTaskList: { _ in },
        showDoneCountInToolbar: { false },
        setShowDoneCountInToolbar: { _ in },
        appColorScheme: { .system },
        setAppColorScheme: { _ in },
        routineListSectioningMode: { .defaultValue },
        setRoutineListSectioningMode: { _ in },
        tagCounterDisplayMode: { .defaultValue },
        setTagCounterDisplayMode: { _ in },
        taskRowVisibility: { .defaultValue },
        setTaskRowVisibility: { _ in },
        timelineRowVisibility: { .defaultValue },
        setTimelineRowVisibility: { _ in },
        relatedTagRules: { [] },
        setRelatedTagRules: { _ in },
        tagColors: { [:] },
        setTagColors: { _ in },
        fastFilterTags: { [] },
        setFastFilterTags: { _ in },
        notificationReminderTime: { Date() },
        setNotificationReminderTime: { _ in },
        lastRoutineDataBackupDate: { nil },
        setLastRoutineDataBackupDate: { _ in },
        selectedAppIcon: { .orange },
        hiddenDayPlanTimelineActivityIDs: { nil },
        temporaryViewState: { nil },
        setTemporaryViewState: { _ in },
        resetTemporaryViewState: { },
        resetAllSettingsToDefaults: { }
    )
}
