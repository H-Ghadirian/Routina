import Foundation
import SwiftData

@Model
final class RoutinaUserPreferences {
    static let singletonID = "routina-user-preferences-v1"

    var id: String = RoutinaUserPreferences.singletonID
    var selectedAppIcon: String?
    var appColorScheme: String?
    var routineListSectioningMode: String?
    var tagCounterDisplayMode: String?
    var customTaskSections: String?
    var macHomeTaskListSectionOrder: String?
    var macTaskRankingReversedMetrics: String?
    var macTaskLadderOrganization: String?
    var homeTaskRowHiddenFields: String?
    var homeTimelineRowHiddenFields: String?
    var dayPlanCalendarListRowHiddenFields: String?
    var relatedTagRules: String?
    var tagRules: String?
    var flagRules: String?
    var definedFlags: String?
    var tagColors: String?
    var fastFilterTags: String?
    var iOSStatsDashboardHiddenItemIDs: String?
    var iOSStatsDashboardItemOrderIDs: String?
    var iOSStatsSummaryDisplayMode: String?
    var macStatsDashboardHiddenItemIDs: String?
    var macStatsDashboardItemOrderIDs: String?
    var macStatsSummaryDisplayMode: String?
    var hiddenDayPlanTimelineActivityIDs: String?
    var protectionBlockingEnabledModes: String?
    var blockingWebsiteDomains: String?
    var focusShieldSelection: String?
    var macFocusBlockedApps: String?
    var macFormSectionOrder: String?
    var macQuickAddShortcut: String?
    var macAdventureOwnedItemIDs: String?
    var macAdventureUnlockedWorldIDs: String?
    var macAdventureUnlockedStageIDs: String?
    var showHomeTaskListModeTabsVisible: Bool = false
    var notificationsEnabled: Bool = false
    var hideUnavailableRoutines: Bool = false
    var appLockEnabled: Bool = false
    var gitFeaturesEnabled: Bool = false
    var taskSharingEnabled: Bool = false
    var taskRelationshipVisualizerEnabled: Bool = false
    var placesEnabled: Bool = false
    var notesEnabled: Bool = false
    var awayEnabled: Bool = false
    var filterQuerySectionsEnabled: Bool = false
    var unlockUnlimitedTasks: Bool = false
    var showPersianDates: Bool = false
    var batteryRoutineMonitoringEnabled: Bool = false
    var sleepHomeActionEnabled: Bool = true
    var sleepHomeMenuEnabled: Bool = true
    var shakeToStartSleepEnabled: Bool = true
    var focusShieldEnabled: Bool = false
    var macFocusAppBlockingEnabled: Bool = true
    var automaticPlaceCheckInEnabled: Bool = true
    var showTimelineTasksInDayPlanner: Bool = true
    var dayPlanCalendarListAssumedDoneCollapsedByDefault: Bool = true
    var separateDailyRoutinesInTaskList: Bool = false
    var showTomorrowInTaskList: Bool = false
    var macShowDoneCountInToolbar: Bool = false
    var separateTodosAndRoutinesInTagTaskListSections: Bool = false
    var separateDeadlineStatusInTagTaskListSections: Bool = false
    var notificationReminderHour: Int = NotificationPreferences.defaultReminderHour
    var notificationReminderMinute: Int = NotificationPreferences.defaultReminderMinute
    var batteryRoutineThresholdPercent: Int = BatteryRoutinePreferences.defaultThresholdPercent
    var updatedAt: Date = Date()

    init(
        id: String = RoutinaUserPreferences.singletonID,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.updatedAt = updatedAt
    }
}

@MainActor
enum RoutinaUserPreferencesStore {
    private static let migratedDefaultsKey = "routina.userPreferences.defaultsMigrated.v1"
    private static var defaultsObserver: NSObjectProtocol?
    private static var pendingMirrorTask: Task<Void, Never>?

    static func startDefaultsMirror() {
        guard defaultsObserver == nil else { return }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: SharedDefaults.app,
            queue: .main
        ) { _ in
            Task { @MainActor in
                scheduleDefaultsMirror()
            }
        }
    }

    private static func scheduleDefaultsMirror() {
        pendingMirrorTask?.cancel()
        pendingMirrorTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            mirrorDefaultsToStore(in: PersistenceController.shared.container.mainContext)
        }
    }

    static func fetchOrCreate(in context: ModelContext) throws -> RoutinaUserPreferences {
        let result = try fetchOrCreateResult(in: context)
        if result.removedDuplicates {
            try context.save()
        }
        return result.preferences
    }

    private static func fetchOrCreateResult(
        in context: ModelContext
    ) throws -> (
        preferences: RoutinaUserPreferences,
        wasInserted: Bool,
        removedDuplicates: Bool
    ) {
        let result = try canonicalPreferences(in: context)
        if let preferences = result.preferences {
            return (preferences, false, result.removedDuplicates)
        }

        let preferences = RoutinaUserPreferences()
        context.insert(preferences)
        return (preferences, true, false)
    }

    private static func canonicalPreferences(
        in context: ModelContext
    ) throws -> (
        preferences: RoutinaUserPreferences?,
        removedDuplicates: Bool
    ) {
        let singletonID = RoutinaUserPreferences.singletonID
        let descriptor = FetchDescriptor<RoutinaUserPreferences>(
            predicate: #Predicate { $0.id == singletonID }
        )
        let matching = try context.fetch(descriptor)
        guard let canonical = matching.max(by: { $0.updatedAt < $1.updatedAt }) else {
            return (nil, false)
        }

        for duplicate in matching where duplicate !== canonical {
            context.delete(duplicate)
        }
        return (canonical, matching.count > 1)
    }

    static func migrateDefaultsIfNeeded(in context: ModelContext) {
        guard !SharedDefaults.app.bool(forKey: migratedDefaultsKey) else {
            applyToDefaults(from: context)
            return
        }

        do {
            let result = try fetchOrCreateResult(in: context)
            let didChange = copyDefaults(to: result.preferences, from: SharedDefaults.app)
            if result.wasInserted || didChange {
                result.preferences.updatedAt = Date()
            }
            if result.wasInserted || didChange || result.removedDuplicates {
                try context.save()
            }
            SharedDefaults.app.set(true, forKey: migratedDefaultsKey)
        } catch {
            NSLog("User preference migration failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func mirrorDefaultsToStore(
        in context: ModelContext,
        defaults: UserDefaults = SharedDefaults.app
    ) -> Bool {
        do {
            let result = try fetchOrCreateResult(in: context)
            let didChange = copyDefaults(to: result.preferences, from: defaults)
            guard result.wasInserted || didChange || result.removedDuplicates else { return false }
            if result.wasInserted || didChange {
                result.preferences.updatedAt = Date()
            }
            try context.save()
            return true
        } catch {
            NSLog("User preference defaults mirror failed: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    static func applyToDefaults(
        from context: ModelContext,
        defaults: UserDefaults = SharedDefaults.app
    ) -> Bool {
        do {
            let result = try canonicalPreferences(in: context)
            guard let preferences = result.preferences else { return false }
            let didChange = copy(preferences, to: defaults)
            if result.removedDuplicates {
                try context.save()
            }
            return didChange
        } catch {
            NSLog("User preference defaults apply failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func copyDefaults(
        to preferences: RoutinaUserPreferences,
        from defaults: UserDefaults
    ) -> Bool {
        var didChange = false
        func store<Value: Equatable>(
            _ value: Value,
            at keyPath: ReferenceWritableKeyPath<RoutinaUserPreferences, Value>
        ) {
            guard preferences[keyPath: keyPath] != value else { return }
            preferences[keyPath: keyPath] = value
            didChange = true
        }

        store(defaults[.selectedMacAppIcon], at: \.selectedAppIcon)
        store(defaults[.appSettingAppColorScheme], at: \.appColorScheme)
        store(
            RoutineListSectioningMode.preferenceValue(
                rawValue: defaults[.appSettingRoutineListSectioningMode]
            ).rawValue,
            at: \.routineListSectioningMode
        )
        store(defaults[.appSettingTagCounterDisplayMode], at: \.tagCounterDisplayMode)
        store(defaults[.appSettingCustomTaskSections], at: \.customTaskSections)
        store(defaults[.appSettingMacHomeTaskListSectionOrder], at: \.macHomeTaskListSectionOrder)
        store(defaults[.appSettingMacTaskRankingReversedMetrics], at: \.macTaskRankingReversedMetrics)
        store(defaults[.appSettingMacTaskLadderOrganization], at: \.macTaskLadderOrganization)
        store(defaults[.appSettingHomeTaskRowHiddenFields], at: \.homeTaskRowHiddenFields)
        store(defaults[.appSettingHomeTimelineRowHiddenFields], at: \.homeTimelineRowHiddenFields)
        store(
            defaults[.appSettingDayPlanCalendarListRowHiddenFields],
            at: \.dayPlanCalendarListRowHiddenFields
        )
        store(defaults[.appSettingRelatedTagRules], at: \.relatedTagRules)
        store(defaults[.appSettingTagRules], at: \.tagRules)
        store(defaults[.appSettingFlagRules], at: \.flagRules)
        store(defaults[.appSettingDefinedFlags], at: \.definedFlags)
        store(defaults[.appSettingTagColors], at: \.tagColors)
        store(defaults[.appSettingFastFilterTags], at: \.fastFilterTags)
        store(defaults[.appSettingIOSStatsDashboardHiddenItemIDs], at: \.iOSStatsDashboardHiddenItemIDs)
        store(defaults[.appSettingIOSStatsDashboardItemOrderIDs], at: \.iOSStatsDashboardItemOrderIDs)
        store(defaults[.appSettingIOSStatsSummaryDisplayMode], at: \.iOSStatsSummaryDisplayMode)
        store(defaults[.appSettingMacStatsDashboardHiddenItemIDs], at: \.macStatsDashboardHiddenItemIDs)
        store(defaults[.appSettingMacStatsDashboardItemOrderIDs], at: \.macStatsDashboardItemOrderIDs)
        store(defaults[.appSettingMacStatsSummaryDisplayMode], at: \.macStatsSummaryDisplayMode)
        store(defaults[.appSettingHiddenDayPlanTimelineActivityIDs], at: \.hiddenDayPlanTimelineActivityIDs)
        store(defaults[.appSettingProtectionBlockingEnabledModes], at: \.protectionBlockingEnabledModes)
        store(defaults[.appSettingBlockingWebsiteDomains], at: \.blockingWebsiteDomains)
        store(defaults[.appSettingFocusShieldSelection], at: \.focusShieldSelection)
        store(defaults[.appSettingMacFocusBlockedApps], at: \.macFocusBlockedApps)
        store(
            defaults.data(forKey: UserDefaultStringValueKey.macFormSectionOrder.rawValue)?
                .base64EncodedString(),
            at: \.macFormSectionOrder
        )
        store(defaults[.macQuickAddShortcut], at: \.macQuickAddShortcut)
        store(defaults[.appSettingMacAdventureOwnedItemIDs], at: \.macAdventureOwnedItemIDs)
        store(defaults[.appSettingMacAdventureUnlockedWorldIDs], at: \.macAdventureUnlockedWorldIDs)
        store(defaults[.appSettingMacAdventureUnlockedStageIDs], at: \.macAdventureUnlockedStageIDs)
        store(defaults[.appSettingNotificationsEnabled], at: \.notificationsEnabled)
        store(defaults[.appSettingHomeTaskListModeTabsVisible], at: \.showHomeTaskListModeTabsVisible)
        store(defaults[.appSettingHideUnavailableRoutines], at: \.hideUnavailableRoutines)
        store(defaults[.appSettingAppLockEnabled], at: \.appLockEnabled)
        store(defaults[.appSettingGitFeaturesEnabled], at: \.gitFeaturesEnabled)
        store(defaults[.appSettingTaskSharingEnabled], at: \.taskSharingEnabled)
        store(
            defaults[.appSettingTaskRelationshipVisualizerEnabled],
            at: \.taskRelationshipVisualizerEnabled
        )
        store(defaults[.appSettingPlacesEnabled], at: \.placesEnabled)
        store(defaults[.appSettingNotesEnabled], at: \.notesEnabled)
        store(defaults[.appSettingAwayEnabled], at: \.awayEnabled)
        store(defaults[.appSettingFilterQuerySectionsEnabled], at: \.filterQuerySectionsEnabled)
        store(defaults[.appSettingUnlockUnlimitedTasks], at: \.unlockUnlimitedTasks)
        store(defaults[.appSettingShowPersianDates], at: \.showPersianDates)
        store(defaults[.appSettingBatteryRoutineMonitoringEnabled], at: \.batteryRoutineMonitoringEnabled)
        store(defaults[.appSettingSleepHomeActionEnabled], at: \.sleepHomeActionEnabled)
        store(defaults[.appSettingSleepHomeMenuEnabled], at: \.sleepHomeMenuEnabled)
        store(defaults[.appSettingShakeToStartSleepEnabled], at: \.shakeToStartSleepEnabled)
        store(defaults[.appSettingFocusShieldEnabled], at: \.focusShieldEnabled)
        store(defaults[.appSettingMacFocusAppBlockingEnabled], at: \.macFocusAppBlockingEnabled)
        store(defaults[.appSettingAutomaticPlaceCheckInEnabled], at: \.automaticPlaceCheckInEnabled)
        store(defaults[.appSettingShowTimelineTasksInDayPlanner], at: \.showTimelineTasksInDayPlanner)
        store(
            defaults[.appSettingDayPlanCalendarListAssumedDoneCollapsedByDefault],
            at: \.dayPlanCalendarListAssumedDoneCollapsedByDefault
        )
        store(defaults[.appSettingSeparateDailyRoutinesInTaskList], at: \.separateDailyRoutinesInTaskList)
        store(defaults[.appSettingShowTomorrowInTaskList], at: \.showTomorrowInTaskList)
        store(defaults[.appSettingMacShowDoneCountInToolbar], at: \.macShowDoneCountInToolbar)
        store(
            defaults[.appSettingSeparateTodosAndRoutinesInTagTaskListSections],
            at: \.separateTodosAndRoutinesInTagTaskListSections
        )
        store(
            defaults[.appSettingSeparateDeadlineStatusInTagTaskListSections],
            at: \.separateDeadlineStatusInTagTaskListSections
        )
        store(
            defaults.integer(forKey: NotificationPreferences.reminderHourDefaultsKey),
            at: \.notificationReminderHour
        )
        store(
            defaults.integer(forKey: NotificationPreferences.reminderMinuteDefaultsKey),
            at: \.notificationReminderMinute
        )
        store(
            defaults.integer(forKey: BatteryRoutinePreferences.thresholdPercentDefaultsKey),
            at: \.batteryRoutineThresholdPercent
        )
        return didChange
    }

    private static func copy(
        _ preferences: RoutinaUserPreferences,
        to defaults: UserDefaults
    ) -> Bool {
        var didChange = false
        func store(_ value: String?, at key: UserDefaultStringValueKey) {
            guard defaults[key] != value else { return }
            defaults[key] = value
            didChange = true
        }
        func store(_ value: Bool, at key: UserDefaultBoolValueKey) {
            let resolvedValue = RoutinaExperimentalFeaturePolicy.resolvedValue(
                for: key,
                storedValue: value
            )
            guard defaults[key] != resolvedValue else { return }
            defaults[key] = resolvedValue
            didChange = true
        }
        func store(_ value: Int, at key: String) {
            guard defaults.integer(forKey: key) != value else { return }
            defaults.set(value, forKey: key)
            didChange = true
        }
        func store(_ value: Data?, at key: String) {
            guard defaults.data(forKey: key) != value else { return }
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
            didChange = true
        }

        store(preferences.selectedAppIcon, at: .selectedMacAppIcon)
        store(preferences.appColorScheme, at: .appSettingAppColorScheme)
        store(
            RoutineListSectioningMode.preferenceValue(
                rawValue: preferences.routineListSectioningMode
            ).rawValue,
            at: .appSettingRoutineListSectioningMode
        )
        store(preferences.tagCounterDisplayMode, at: .appSettingTagCounterDisplayMode)
        store(preferences.customTaskSections, at: .appSettingCustomTaskSections)
        store(preferences.macHomeTaskListSectionOrder, at: .appSettingMacHomeTaskListSectionOrder)
        store(preferences.macTaskRankingReversedMetrics, at: .appSettingMacTaskRankingReversedMetrics)
        store(preferences.macTaskLadderOrganization, at: .appSettingMacTaskLadderOrganization)
        store(preferences.homeTaskRowHiddenFields, at: .appSettingHomeTaskRowHiddenFields)
        store(preferences.homeTimelineRowHiddenFields, at: .appSettingHomeTimelineRowHiddenFields)
        store(
            preferences.dayPlanCalendarListRowHiddenFields,
            at: .appSettingDayPlanCalendarListRowHiddenFields
        )
        store(preferences.relatedTagRules, at: .appSettingRelatedTagRules)
        store(preferences.tagRules, at: .appSettingTagRules)
        store(preferences.flagRules, at: .appSettingFlagRules)
        store(preferences.definedFlags, at: .appSettingDefinedFlags)
        store(preferences.tagColors, at: .appSettingTagColors)
        store(preferences.fastFilterTags, at: .appSettingFastFilterTags)
        store(preferences.iOSStatsDashboardHiddenItemIDs, at: .appSettingIOSStatsDashboardHiddenItemIDs)
        store(preferences.iOSStatsDashboardItemOrderIDs, at: .appSettingIOSStatsDashboardItemOrderIDs)
        store(preferences.iOSStatsSummaryDisplayMode, at: .appSettingIOSStatsSummaryDisplayMode)
        store(preferences.macStatsDashboardHiddenItemIDs, at: .appSettingMacStatsDashboardHiddenItemIDs)
        store(preferences.macStatsDashboardItemOrderIDs, at: .appSettingMacStatsDashboardItemOrderIDs)
        store(preferences.macStatsSummaryDisplayMode, at: .appSettingMacStatsSummaryDisplayMode)
        store(preferences.hiddenDayPlanTimelineActivityIDs, at: .appSettingHiddenDayPlanTimelineActivityIDs)
        store(preferences.protectionBlockingEnabledModes, at: .appSettingProtectionBlockingEnabledModes)
        store(preferences.blockingWebsiteDomains, at: .appSettingBlockingWebsiteDomains)
        store(preferences.focusShieldSelection, at: .appSettingFocusShieldSelection)
        store(preferences.macFocusBlockedApps, at: .appSettingMacFocusBlockedApps)
        store(
            preferences.macFormSectionOrder.flatMap { Data(base64Encoded: $0) },
            at: UserDefaultStringValueKey.macFormSectionOrder.rawValue
        )
        store(preferences.macQuickAddShortcut, at: .macQuickAddShortcut)
        store(preferences.macAdventureOwnedItemIDs, at: .appSettingMacAdventureOwnedItemIDs)
        store(preferences.macAdventureUnlockedWorldIDs, at: .appSettingMacAdventureUnlockedWorldIDs)
        store(preferences.macAdventureUnlockedStageIDs, at: .appSettingMacAdventureUnlockedStageIDs)
        store(preferences.notificationsEnabled, at: .appSettingNotificationsEnabled)
        store(preferences.showHomeTaskListModeTabsVisible, at: .appSettingHomeTaskListModeTabsVisible)
        store(preferences.hideUnavailableRoutines, at: .appSettingHideUnavailableRoutines)
        store(preferences.appLockEnabled, at: .appSettingAppLockEnabled)
        store(preferences.gitFeaturesEnabled, at: .appSettingGitFeaturesEnabled)
        store(preferences.taskSharingEnabled, at: .appSettingTaskSharingEnabled)
        store(
            preferences.taskRelationshipVisualizerEnabled,
            at: .appSettingTaskRelationshipVisualizerEnabled
        )
        store(preferences.placesEnabled, at: .appSettingPlacesEnabled)
        store(preferences.notesEnabled, at: .appSettingNotesEnabled)
        store(preferences.awayEnabled, at: .appSettingAwayEnabled)
        store(preferences.filterQuerySectionsEnabled, at: .appSettingFilterQuerySectionsEnabled)
        store(preferences.unlockUnlimitedTasks, at: .appSettingUnlockUnlimitedTasks)
        store(preferences.showPersianDates, at: .appSettingShowPersianDates)
        store(
            preferences.batteryRoutineMonitoringEnabled,
            at: .appSettingBatteryRoutineMonitoringEnabled
        )
        store(preferences.sleepHomeActionEnabled, at: .appSettingSleepHomeActionEnabled)
        store(preferences.sleepHomeMenuEnabled, at: .appSettingSleepHomeMenuEnabled)
        store(preferences.shakeToStartSleepEnabled, at: .appSettingShakeToStartSleepEnabled)
        store(preferences.focusShieldEnabled, at: .appSettingFocusShieldEnabled)
        store(preferences.macFocusAppBlockingEnabled, at: .appSettingMacFocusAppBlockingEnabled)
        store(preferences.automaticPlaceCheckInEnabled, at: .appSettingAutomaticPlaceCheckInEnabled)
        store(preferences.showTimelineTasksInDayPlanner, at: .appSettingShowTimelineTasksInDayPlanner)
        store(
            preferences.dayPlanCalendarListAssumedDoneCollapsedByDefault,
            at: .appSettingDayPlanCalendarListAssumedDoneCollapsedByDefault
        )
        store(
            preferences.separateDailyRoutinesInTaskList,
            at: .appSettingSeparateDailyRoutinesInTaskList
        )
        store(preferences.showTomorrowInTaskList, at: .appSettingShowTomorrowInTaskList)
        store(preferences.macShowDoneCountInToolbar, at: .appSettingMacShowDoneCountInToolbar)
        store(
            preferences.separateTodosAndRoutinesInTagTaskListSections,
            at: .appSettingSeparateTodosAndRoutinesInTagTaskListSections
        )
        store(
            preferences.separateDeadlineStatusInTagTaskListSections,
            at: .appSettingSeparateDeadlineStatusInTagTaskListSections
        )
        store(
            preferences.notificationReminderHour,
            at: NotificationPreferences.reminderHourDefaultsKey
        )
        store(
            preferences.notificationReminderMinute,
            at: NotificationPreferences.reminderMinuteDefaultsKey
        )
        store(
            preferences.batteryRoutineThresholdPercent,
            at: BatteryRoutinePreferences.thresholdPercentDefaultsKey
        )
        return didChange
    }
}
