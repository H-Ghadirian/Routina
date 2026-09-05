import Foundation

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
        goalsEnabled: {
            SharedDefaults.app[.appSettingGoalsTabEnabled]
        },
        eventEmotionActionsEnabled: {
            SharedDefaults.app[.appSettingMacEventEmotionActionsEnabled]
        },
        filterQuerySectionsEnabled: {
            SharedDefaults.app[.appSettingFilterQuerySectionsEnabled]
        },
        setFilterQuerySectionsEnabled: { isEnabled in
            SharedDefaults.app[.appSettingFilterQuerySectionsEnabled] = isEnabled
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
        tagRules: {
            guard let rawValue = CloudSettingsKeyValueSync.string(for: .appSettingTagRules),
                let data = rawValue.data(using: .utf8),
                let decoded = try? JSONDecoder().decode([RoutineTagRule].self, from: data)
            else {
                return []
            }
            return RoutineTagRules.sanitized(decoded)
        },
        setTagRules: { rules in
            let sanitizedRules = RoutineTagRules.sanitized(rules)
            guard !sanitizedRules.isEmpty else {
                CloudSettingsKeyValueSync.setString(nil, for: .appSettingTagRules)
                return
            }
            guard let data = try? JSONEncoder().encode(sanitizedRules),
                let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }
            CloudSettingsKeyValueSync.setString(rawValue, for: .appSettingTagRules)
        },
        flagRules: {
            guard let rawValue = CloudSettingsKeyValueSync.string(for: .appSettingFlagRules),
                let data = rawValue.data(using: .utf8),
                let decoded = try? JSONDecoder().decode([RoutineFlagRule].self, from: data)
            else {
                return []
            }
            return RoutineFlagRules.sanitized(decoded)
        },
        setFlagRules: { rules in
            let sanitizedRules = RoutineFlagRules.sanitized(rules)
            guard !sanitizedRules.isEmpty else {
                CloudSettingsKeyValueSync.setString(nil, for: .appSettingFlagRules)
                return
            }
            guard let data = try? JSONEncoder().encode(sanitizedRules),
                let rawValue = String(data: data, encoding: .utf8)
            else {
                return
            }
            CloudSettingsKeyValueSync.setString(rawValue, for: .appSettingFlagRules)
        },
        taskLadderOrganization: {
            TaskLadderOrganizationStorage.decode(
                CloudSettingsKeyValueSync.string(for: .appSettingMacTaskLadderOrganization)
            )
        },
        setTaskLadderOrganization: { organization in
            CloudSettingsKeyValueSync.setString(
                TaskLadderOrganizationStorage.encode(organization),
                for: .appSettingMacTaskLadderOrganization
            )
        },
        definedFlags: {
            RoutineFlag.deserialize(
                CloudSettingsKeyValueSync.string(for: .appSettingDefinedFlags) ?? ""
            )
        },
        setDefinedFlags: { flags in
            let sanitizedFlags = RoutineFlag.deduplicated(flags)
            CloudSettingsKeyValueSync.setString(
                sanitizedFlags.isEmpty ? nil : RoutineFlag.serialize(sanitizedFlags),
                for: .appSettingDefinedFlags
            )
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
        customTaskSections: {
            HomeCustomTaskSectionStorage.decoded(
                from: SharedDefaults.app[.appSettingCustomTaskSections]
            )
        },
        temporaryViewState: {
            TemporaryViewStateDefaultsStore.load()
        },
        setTemporaryViewState: { state in
            TemporaryViewStateDefaultsStore.storeIfChanged(state)
        },
        hasSavedMacPlannerPresentationPreferences: {
            SharedDefaults.app[.appSettingMacPlannerPresentationPreferences] != nil
        },
        resetTemporaryViewState: {
            SharedDefaults.app[.appSettingHideUnavailableRoutines] = false
            SharedDefaults.app[.appSettingTemporaryViewState] = nil
            SharedDefaults.app[.appSettingHiddenDayPlanTimelineActivityIDs] = nil
            SharedDefaults.app[.appSettingMacPlannerPresentationPreferences] = nil
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
        goalsEnabled: { false },
        eventEmotionActionsEnabled: { false },
        filterQuerySectionsEnabled: { false },
        setFilterQuerySectionsEnabled: { _ in },
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
        tagRules: { [] },
        setTagRules: { _ in },
        flagRules: { [] },
        setFlagRules: { _ in },
        definedFlags: { [] },
        setDefinedFlags: { _ in },
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
        resetTemporaryViewState: {},
        resetAllSettingsToDefaults: {}
    )
}
