import Foundation
import SwiftData

extension SettingsRoutineDataImportEntityInserter {
    @MainActor
    static func insertDayPlanBlocks(
        from backup: Backup,
        importedTaskIDs: Set<UUID>,
        in context: ModelContext
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for block in backup.dayPlanBlocks ?? [] {
            guard importedTaskIDs.contains(block.taskID) else { continue }
            guard importedIDs.insert(block.id).inserted else { continue }

            let importedBlock = DayPlanBlockRecord(
                id: block.id,
                taskID: block.taskID,
                dayKey: block.dayKey,
                startMinute: block.startMinute,
                durationMinutes: block.durationMinutes,
                titleSnapshot: block.titleSnapshot,
                emojiSnapshot: block.emojiSnapshot,
                createdAt: block.createdAt,
                updatedAt: block.updatedAt,
                placementSource: block.placementSourceRawValue.flatMap(
                    DayPlanBlockPlacementSource.init(rawValue:)
                ) ?? .legacy
            )
            context.insert(importedBlock)
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertBoardSprints(
        from backup: Backup,
        in context: ModelContext
    ) -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for sprint in backup.boardSprints ?? [] {
            guard importedIDs.insert(sprint.id).inserted else { continue }

            let importedSprint = BoardSprintRecord(
                id: sprint.id,
                title: sprint.title,
                status: sprint.status,
                createdAt: sprint.createdAt,
                startedAt: sprint.startedAt,
                finishedAt: sprint.finishedAt
            )
            context.insert(importedSprint)
            importedCount += 1
        }

        return (importedIDs, importedCount)
    }

    @MainActor
    static func insertSprintAssignments(
        from backup: Backup,
        importedTaskIDs: Set<UUID>,
        importedSprintIDs: Set<UUID>,
        in context: ModelContext
    ) -> Int {
        var importedKeys = Set<String>()
        var importedCount = 0

        for assignment in backup.sprintAssignments ?? [] {
            guard importedTaskIDs.contains(assignment.todoID),
                importedSprintIDs.contains(assignment.sprintID)
            else { continue }
            let key = "\(assignment.todoID.uuidString):\(assignment.sprintID.uuidString)"
            guard importedKeys.insert(key).inserted else { continue }

            context.insert(
                SprintAssignmentRecord(
                    todoID: assignment.todoID,
                    sprintID: assignment.sprintID,
                    sortOrder: max(0, assignment.sortOrder ?? importedCount)
                )
            )
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertBoardBacklogs(
        from backup: Backup,
        in context: ModelContext
    ) -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for backlog in backup.boardBacklogs ?? [] {
            guard importedIDs.insert(backlog.id).inserted else { continue }

            let importedBacklog = BoardBacklogRecord(
                id: backlog.id,
                title: backlog.title,
                createdAt: backlog.createdAt,
                routingTags: backlog.routingTags ?? []
            )
            context.insert(importedBacklog)
            importedCount += 1
        }

        return (importedIDs, importedCount)
    }

    @MainActor
    static func insertBacklogAssignments(
        from backup: Backup,
        importedTaskIDs: Set<UUID>,
        importedBacklogIDs: Set<UUID>,
        in context: ModelContext
    ) -> Int {
        var importedKeys = Set<String>()
        var importedCount = 0

        for assignment in backup.backlogAssignments ?? [] {
            guard importedTaskIDs.contains(assignment.todoID),
                importedBacklogIDs.contains(assignment.backlogID)
            else { continue }
            let key = "\(assignment.todoID.uuidString):\(assignment.backlogID.uuidString)"
            guard importedKeys.insert(key).inserted else { continue }

            context.insert(
                BacklogAssignmentRecord(
                    todoID: assignment.todoID,
                    backlogID: assignment.backlogID,
                    sortOrder: max(0, assignment.sortOrder ?? importedCount)
                )
            )
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertSprintFocusSessions(
        from backup: Backup,
        importedSprintIDs: Set<UUID>,
        in context: ModelContext
    ) -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for session in backup.sprintFocusSessions ?? [] {
            guard importedSprintIDs.contains(session.sprintID) else { continue }
            guard importedIDs.insert(session.id).inserted else { continue }

            let importedSession = SprintFocusSessionRecord(
                id: session.id,
                sprintID: session.sprintID,
                startedAt: session.startedAt,
                stoppedAt: session.stoppedAt,
                pausedAt: session.pausedAt,
                accumulatedPausedSeconds: session.accumulatedPausedSeconds ?? 0
            )
            context.insert(importedSession)
            importedCount += 1
        }

        return (importedIDs, importedCount)
    }

    @MainActor
    static func insertSprintFocusAllocations(
        from backup: Backup,
        importedSprintFocusSessionIDs: Set<UUID>,
        importedTaskIDs: Set<UUID>,
        in context: ModelContext
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for allocation in backup.sprintFocusAllocations ?? [] {
            guard importedSprintFocusSessionIDs.contains(allocation.sessionID),
                importedTaskIDs.contains(allocation.taskID)
            else { continue }
            guard importedIDs.insert(allocation.id).inserted else { continue }

            context.insert(
                SprintFocusAllocationRecord(
                    id: allocation.id,
                    sessionID: allocation.sessionID,
                    taskID: allocation.taskID,
                    minutes: allocation.minutes,
                    sortOrder: max(0, allocation.sortOrder ?? importedCount)
                )
            )
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertDeviceSessions(
        from backup: Backup,
        in context: ModelContext
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for session in backup.deviceSessions ?? [] {
            guard importedIDs.insert(session.id).inserted else { continue }

            let importedSession = RoutinaDeviceSession(
                id: session.id,
                installationID: session.installationID,
                displayName: session.displayName,
                platform: session.platform,
                modelName: session.modelName,
                systemName: session.systemName,
                systemVersion: session.systemVersion,
                appVersion: session.appVersion,
                bundleIdentifier: session.bundleIdentifier,
                firstSeenAt: session.firstSeenAt,
                lastSeenAt: session.lastSeenAt,
                lastActiveAt: session.lastActiveAt,
                lastMutationAt: session.lastMutationAt
            )
            context.insert(importedSession)
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertDeviceActionLogs(
        from backup: Backup,
        in context: ModelContext
    ) -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0

        for log in backup.deviceActionLogs ?? [] {
            guard importedIDs.insert(log.id).inserted else { continue }

            let source = RoutinaDeviceActivitySource(
                installationID: log.deviceInstallationID,
                displayName: log.deviceDisplayName,
                platform: log.devicePlatform,
                modelName: log.deviceModelName,
                systemName: log.systemName,
                systemVersion: log.systemVersion,
                appVersion: log.appVersion,
                bundleIdentifier: ""
            )
            let importedLog = RoutinaDeviceActionLog(
                id: log.id,
                timestamp: log.timestamp,
                action: log.action,
                entity: log.entity,
                entityID: log.entityID,
                entityTitle: log.entityTitle,
                source: source,
                details: log.details
            )
            context.insert(importedLog)
            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    static func insertUserPreferences(
        from backup: Backup,
        in context: ModelContext,
        importDate: Date,
        appliesToDefaults: Bool
    ) -> Int {
        guard let backupPreferences = backup.userPreferences else { return 0 }

        let preferences = RoutinaUserPreferences(
            id: RoutinaUserPreferences.singletonID,
            updatedAt: backupPreferences.updatedAt ?? importDate
        )
        applyStoredPreferences(backupPreferences, to: preferences)
        applyDefaultedPreferences(backupPreferences, to: preferences)

        context.insert(preferences)
        if appliesToDefaults {
            RoutinaUserPreferencesStore.applyToDefaults(from: context)
        }
        return 1
    }

    private static func applyStoredPreferences(
        _ backupPreferences: Backup.UserPreferences,
        to preferences: RoutinaUserPreferences
    ) {
        preferences.selectedAppIcon = backupPreferences.selectedAppIcon
        preferences.appColorScheme = backupPreferences.appColorScheme
        preferences.routineListSectioningMode = backupPreferences.routineListSectioningMode
        preferences.tagCounterDisplayMode = backupPreferences.tagCounterDisplayMode
        preferences.customTaskSections = backupPreferences.customTaskSections
        preferences.macHomeTaskListSectionOrder = backupPreferences.macHomeTaskListSectionOrder
        preferences.macTaskRankingReversedMetrics = backupPreferences.macTaskRankingReversedMetrics
        preferences.macTaskLadderOrganization = backupPreferences.macTaskLadderOrganization
        preferences.homeTaskRowHiddenFields = backupPreferences.homeTaskRowHiddenFields
        preferences.backlogTaskRowHiddenFields = backupPreferences.backlogTaskRowHiddenFields
        preferences.taskLadderTaskRowHiddenFields = backupPreferences.taskLadderTaskRowHiddenFields
        preferences.dayPlanCalendarListRowHiddenFields =
            backupPreferences.dayPlanCalendarListRowHiddenFields
        preferences.relatedTagRules = backupPreferences.relatedTagRules
        preferences.tagRules = backupPreferences.tagRules
        preferences.flagRules = backupPreferences.flagRules
        preferences.definedFlags = backupPreferences.definedFlags
        preferences.tagColors = backupPreferences.tagColors
        preferences.fastFilterTags = backupPreferences.fastFilterTags
        preferences.iOSStatsDashboardHiddenItemIDs = backupPreferences.iOSStatsDashboardHiddenItemIDs
        preferences.iOSStatsDashboardItemOrderIDs = backupPreferences.iOSStatsDashboardItemOrderIDs
        preferences.iOSStatsSummaryDisplayMode = backupPreferences.iOSStatsSummaryDisplayMode
        preferences.macStatsDashboardHiddenItemIDs = backupPreferences.macStatsDashboardHiddenItemIDs
        preferences.macStatsDashboardItemOrderIDs = backupPreferences.macStatsDashboardItemOrderIDs
        preferences.macStatsSummaryDisplayMode = backupPreferences.macStatsSummaryDisplayMode
        preferences.hiddenDayPlanTimelineActivityIDs = backupPreferences.hiddenDayPlanTimelineActivityIDs
        preferences.protectionBlockingEnabledModes = backupPreferences.protectionBlockingEnabledModes
        preferences.blockingWebsiteDomains = backupPreferences.blockingWebsiteDomains
        preferences.focusShieldSelection = backupPreferences.focusShieldSelection
        preferences.macFocusBlockedApps = backupPreferences.macFocusBlockedApps
        preferences.macFormSectionOrder = backupPreferences.macFormSectionOrder
        preferences.macQuickAddShortcut = backupPreferences.macQuickAddShortcut
        preferences.macAdventureOwnedItemIDs = backupPreferences.macAdventureOwnedItemIDs
        preferences.macAdventureUnlockedWorldIDs = backupPreferences.macAdventureUnlockedWorldIDs
        preferences.macAdventureUnlockedStageIDs = backupPreferences.macAdventureUnlockedStageIDs
    }

    private static func applyDefaultedPreferences(
        _ backupPreferences: Backup.UserPreferences,
        to preferences: RoutinaUserPreferences
    ) {
        preferences.notificationsEnabled = backupPreferences.notificationsEnabled ?? false
        preferences.hideUnavailableRoutines = backupPreferences.hideUnavailableRoutines ?? false
        preferences.appLockEnabled = backupPreferences.appLockEnabled ?? false
        preferences.gitFeaturesEnabled = backupPreferences.gitFeaturesEnabled ?? false
        preferences.taskSharingEnabled = backupPreferences.taskSharingEnabled ?? false
        preferences.taskRelationshipVisualizerEnabled = backupPreferences.taskRelationshipVisualizerEnabled ?? false
        preferences.placesEnabled = backupPreferences.placesEnabled ?? false
        preferences.notesEnabled = backupPreferences.notesEnabled ?? false
        preferences.awayEnabled = backupPreferences.awayEnabled ?? false
        preferences.filterQuerySectionsEnabled = backupPreferences.filterQuerySectionsEnabled ?? false
        preferences.unlockUnlimitedTasks = backupPreferences.unlockUnlimitedTasks ?? false
        preferences.showPersianDates = backupPreferences.showPersianDates ?? false
        preferences.batteryRoutineMonitoringEnabled =
            backupPreferences.batteryRoutineMonitoringEnabled ?? BatteryRoutinePreferences.defaultMonitoringEnabled
        preferences.sleepHomeActionEnabled = backupPreferences.sleepHomeActionEnabled ?? true
        preferences.sleepHomeMenuEnabled = backupPreferences.sleepHomeMenuEnabled ?? true
        preferences.shakeToStartSleepEnabled = backupPreferences.shakeToStartSleepEnabled ?? true
        preferences.focusShieldEnabled = backupPreferences.focusShieldEnabled ?? false
        preferences.macFocusAppBlockingEnabled = backupPreferences.macFocusAppBlockingEnabled ?? true
        preferences.automaticPlaceCheckInEnabled = backupPreferences.automaticPlaceCheckInEnabled ?? true
        preferences.showTimelineTasksInDayPlanner = backupPreferences.showTimelineTasksInDayPlanner ?? true
        preferences.dayPlanCalendarListAssumedDoneCollapsedByDefault =
            backupPreferences
            .dayPlanCalendarListAssumedDoneCollapsedByDefault ?? true
        preferences.separateDailyRoutinesInTaskList = backupPreferences.separateDailyRoutinesInTaskList ?? false
        preferences.showTomorrowInTaskList = backupPreferences.showTomorrowInTaskList ?? false
        preferences.macShowDoneCountInToolbar = backupPreferences.macShowDoneCountInToolbar ?? false
        preferences.separateTodosAndRoutinesInTagTaskListSections = backupPreferences.separateTodosAndRoutinesInTagTaskListSections ?? false
        preferences.separateDeadlineStatusInTagTaskListSections =
            backupPreferences
            .separateDeadlineStatusInTagTaskListSections ?? false
        preferences.notificationReminderHour = backupPreferences.notificationReminderHour ?? NotificationPreferences.defaultReminderHour
        preferences.notificationReminderMinute =
            backupPreferences.notificationReminderMinute ?? NotificationPreferences.defaultReminderMinute
        preferences.batteryRoutineThresholdPercent =
            backupPreferences.batteryRoutineThresholdPercent ?? BatteryRoutinePreferences.defaultThresholdPercent
    }

}
