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
    var homeTaskRowHiddenFields: String?
    var homeTimelineRowHiddenFields: String?
    var relatedTagRules: String?
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
    var showPersianDates: Bool = false
    var batteryRoutineMonitoringEnabled: Bool = false
    var sleepHomeActionEnabled: Bool = true
    var sleepHomeMenuEnabled: Bool = true
    var shakeToStartSleepEnabled: Bool = true
    var focusShieldEnabled: Bool = false
    var macFocusAppBlockingEnabled: Bool = true
    var automaticPlaceCheckInEnabled: Bool = true
    var showTimelineTasksInDayPlanner: Bool = true
    var separateDailyRoutinesInTaskList: Bool = false
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
        let singletonID = RoutinaUserPreferences.singletonID
        let descriptor = FetchDescriptor<RoutinaUserPreferences>(
            predicate: #Predicate { $0.id == singletonID }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let preferences = RoutinaUserPreferences()
        context.insert(preferences)
        return preferences
    }

    static func migrateDefaultsIfNeeded(in context: ModelContext) {
        guard !SharedDefaults.app.bool(forKey: migratedDefaultsKey) else {
            applyToDefaults(from: context)
            return
        }

        do {
            let preferences = try fetchOrCreate(in: context)
            copyDefaults(to: preferences)
            preferences.updatedAt = Date()
            try context.save()
            SharedDefaults.app.set(true, forKey: migratedDefaultsKey)
        } catch {
            NSLog("User preference migration failed: \(error.localizedDescription)")
        }
    }

    static func mirrorDefaultsToStore(in context: ModelContext) {
        do {
            let preferences = try fetchOrCreate(in: context)
            copyDefaults(to: preferences)
            preferences.updatedAt = Date()
            try context.save()
        } catch {
            NSLog("User preference defaults mirror failed: \(error.localizedDescription)")
        }
    }

    static func applyToDefaults(from context: ModelContext) {
        do {
            guard let preferences = try context.fetch(FetchDescriptor<RoutinaUserPreferences>()).first else { return }
            copy(preferences, to: SharedDefaults.app)
        } catch {
            NSLog("User preference defaults apply failed: \(error.localizedDescription)")
        }
    }

    private static func copyDefaults(to preferences: RoutinaUserPreferences) {
        let defaults = SharedDefaults.app
        preferences.selectedAppIcon = defaults[.selectedMacAppIcon]
        preferences.appColorScheme = defaults[.appSettingAppColorScheme]
        preferences.routineListSectioningMode = defaults[.appSettingRoutineListSectioningMode]
        preferences.tagCounterDisplayMode = defaults[.appSettingTagCounterDisplayMode]
        preferences.homeTaskRowHiddenFields = defaults[.appSettingHomeTaskRowHiddenFields]
        preferences.homeTimelineRowHiddenFields = defaults[.appSettingHomeTimelineRowHiddenFields]
        preferences.relatedTagRules = defaults[.appSettingRelatedTagRules]
        preferences.tagColors = defaults[.appSettingTagColors]
        preferences.fastFilterTags = defaults[.appSettingFastFilterTags]
        preferences.iOSStatsDashboardHiddenItemIDs = defaults[.appSettingIOSStatsDashboardHiddenItemIDs]
        preferences.iOSStatsDashboardItemOrderIDs = defaults[.appSettingIOSStatsDashboardItemOrderIDs]
        preferences.iOSStatsSummaryDisplayMode = defaults[.appSettingIOSStatsSummaryDisplayMode]
        preferences.macStatsDashboardHiddenItemIDs = defaults[.appSettingMacStatsDashboardHiddenItemIDs]
        preferences.macStatsDashboardItemOrderIDs = defaults[.appSettingMacStatsDashboardItemOrderIDs]
        preferences.macStatsSummaryDisplayMode = defaults[.appSettingMacStatsSummaryDisplayMode]
        preferences.hiddenDayPlanTimelineActivityIDs = defaults[.appSettingHiddenDayPlanTimelineActivityIDs]
        preferences.protectionBlockingEnabledModes = defaults[.appSettingProtectionBlockingEnabledModes]
        preferences.blockingWebsiteDomains = defaults[.appSettingBlockingWebsiteDomains]
        preferences.focusShieldSelection = defaults[.appSettingFocusShieldSelection]
        preferences.macFocusBlockedApps = defaults[.appSettingMacFocusBlockedApps]
        preferences.macFormSectionOrder = defaults.data(forKey: UserDefaultStringValueKey.macFormSectionOrder.rawValue)?.base64EncodedString()
        preferences.macQuickAddShortcut = defaults[.macQuickAddShortcut]
        preferences.macAdventureOwnedItemIDs = defaults[.appSettingMacAdventureOwnedItemIDs]
        preferences.macAdventureUnlockedWorldIDs = defaults[.appSettingMacAdventureUnlockedWorldIDs]
        preferences.macAdventureUnlockedStageIDs = defaults[.appSettingMacAdventureUnlockedStageIDs]
        preferences.notificationsEnabled = defaults[.appSettingNotificationsEnabled]
        preferences.showHomeTaskListModeTabsVisible = defaults[.appSettingHomeTaskListModeTabsVisible]
        preferences.hideUnavailableRoutines = defaults[.appSettingHideUnavailableRoutines]
        preferences.appLockEnabled = defaults[.appSettingAppLockEnabled]
        preferences.gitFeaturesEnabled = defaults[.appSettingGitFeaturesEnabled]
        preferences.taskSharingEnabled = defaults[.appSettingTaskSharingEnabled]
        preferences.taskRelationshipVisualizerEnabled = defaults[.appSettingTaskRelationshipVisualizerEnabled]
        preferences.showPersianDates = defaults[.appSettingShowPersianDates]
        preferences.batteryRoutineMonitoringEnabled = BatteryRoutinePreferences.isMonitoringEnabled
        preferences.sleepHomeActionEnabled = defaults[.appSettingSleepHomeActionEnabled]
        preferences.sleepHomeMenuEnabled = defaults[.appSettingSleepHomeMenuEnabled]
        preferences.shakeToStartSleepEnabled = defaults[.appSettingShakeToStartSleepEnabled]
        preferences.focusShieldEnabled = defaults[.appSettingFocusShieldEnabled]
        preferences.macFocusAppBlockingEnabled = defaults[.appSettingMacFocusAppBlockingEnabled]
        preferences.automaticPlaceCheckInEnabled = defaults[.appSettingAutomaticPlaceCheckInEnabled]
        preferences.showTimelineTasksInDayPlanner = defaults[.appSettingShowTimelineTasksInDayPlanner]
        preferences.separateDailyRoutinesInTaskList = defaults[.appSettingSeparateDailyRoutinesInTaskList]
        preferences.notificationReminderHour = defaults.integer(forKey: NotificationPreferences.reminderHourDefaultsKey)
        preferences.notificationReminderMinute = defaults.integer(forKey: NotificationPreferences.reminderMinuteDefaultsKey)
        preferences.batteryRoutineThresholdPercent = BatteryRoutinePreferences.thresholdPercent
    }

    private static func copy(_ preferences: RoutinaUserPreferences, to defaults: UserDefaults) {
        defaults[.selectedMacAppIcon] = preferences.selectedAppIcon
        defaults[.appSettingAppColorScheme] = preferences.appColorScheme
        defaults[.appSettingRoutineListSectioningMode] = preferences.routineListSectioningMode
        defaults[.appSettingTagCounterDisplayMode] = preferences.tagCounterDisplayMode
        defaults[.appSettingHomeTaskRowHiddenFields] = preferences.homeTaskRowHiddenFields
        defaults[.appSettingHomeTimelineRowHiddenFields] = preferences.homeTimelineRowHiddenFields
        defaults[.appSettingRelatedTagRules] = preferences.relatedTagRules
        defaults[.appSettingTagColors] = preferences.tagColors
        defaults[.appSettingFastFilterTags] = preferences.fastFilterTags
        defaults[.appSettingIOSStatsDashboardHiddenItemIDs] = preferences.iOSStatsDashboardHiddenItemIDs
        defaults[.appSettingIOSStatsDashboardItemOrderIDs] = preferences.iOSStatsDashboardItemOrderIDs
        defaults[.appSettingIOSStatsSummaryDisplayMode] = preferences.iOSStatsSummaryDisplayMode
        defaults[.appSettingMacStatsDashboardHiddenItemIDs] = preferences.macStatsDashboardHiddenItemIDs
        defaults[.appSettingMacStatsDashboardItemOrderIDs] = preferences.macStatsDashboardItemOrderIDs
        defaults[.appSettingMacStatsSummaryDisplayMode] = preferences.macStatsSummaryDisplayMode
        defaults[.appSettingHiddenDayPlanTimelineActivityIDs] = preferences.hiddenDayPlanTimelineActivityIDs
        defaults[.appSettingProtectionBlockingEnabledModes] = preferences.protectionBlockingEnabledModes
        defaults[.appSettingBlockingWebsiteDomains] = preferences.blockingWebsiteDomains
        defaults[.appSettingFocusShieldSelection] = preferences.focusShieldSelection
        defaults[.appSettingMacFocusBlockedApps] = preferences.macFocusBlockedApps
        if let macFormSectionOrder = preferences.macFormSectionOrder,
           let data = Data(base64Encoded: macFormSectionOrder) {
            defaults.set(data, forKey: UserDefaultStringValueKey.macFormSectionOrder.rawValue)
        } else {
            defaults.removeObject(forKey: UserDefaultStringValueKey.macFormSectionOrder.rawValue)
        }
        defaults[.macQuickAddShortcut] = preferences.macQuickAddShortcut
        defaults[.appSettingMacAdventureOwnedItemIDs] = preferences.macAdventureOwnedItemIDs
        defaults[.appSettingMacAdventureUnlockedWorldIDs] = preferences.macAdventureUnlockedWorldIDs
        defaults[.appSettingMacAdventureUnlockedStageIDs] = preferences.macAdventureUnlockedStageIDs
        defaults[.appSettingNotificationsEnabled] = preferences.notificationsEnabled
        defaults[.appSettingHomeTaskListModeTabsVisible] = preferences.showHomeTaskListModeTabsVisible
        defaults[.appSettingHideUnavailableRoutines] = preferences.hideUnavailableRoutines
        defaults[.appSettingAppLockEnabled] = preferences.appLockEnabled
        defaults[.appSettingGitFeaturesEnabled] = preferences.gitFeaturesEnabled
        defaults[.appSettingTaskSharingEnabled] = preferences.taskSharingEnabled
        defaults[.appSettingTaskRelationshipVisualizerEnabled] = preferences.taskRelationshipVisualizerEnabled
        defaults[.appSettingShowPersianDates] = preferences.showPersianDates
        defaults[.appSettingBatteryRoutineMonitoringEnabled] = preferences.batteryRoutineMonitoringEnabled
        defaults[.appSettingSleepHomeActionEnabled] = preferences.sleepHomeActionEnabled
        defaults[.appSettingSleepHomeMenuEnabled] = preferences.sleepHomeMenuEnabled
        defaults[.appSettingShakeToStartSleepEnabled] = preferences.shakeToStartSleepEnabled
        defaults[.appSettingFocusShieldEnabled] = preferences.focusShieldEnabled
        defaults[.appSettingMacFocusAppBlockingEnabled] = preferences.macFocusAppBlockingEnabled
        defaults[.appSettingAutomaticPlaceCheckInEnabled] = preferences.automaticPlaceCheckInEnabled
        defaults[.appSettingShowTimelineTasksInDayPlanner] = preferences.showTimelineTasksInDayPlanner
        defaults[.appSettingSeparateDailyRoutinesInTaskList] = preferences.separateDailyRoutinesInTaskList
        defaults.set(preferences.notificationReminderHour, forKey: NotificationPreferences.reminderHourDefaultsKey)
        defaults.set(preferences.notificationReminderMinute, forKey: NotificationPreferences.reminderMinuteDefaultsKey)
        defaults.set(preferences.batteryRoutineThresholdPercent, forKey: BatteryRoutinePreferences.thresholdPercentDefaultsKey)
    }
}
