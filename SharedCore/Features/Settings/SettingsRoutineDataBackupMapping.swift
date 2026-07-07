import Foundation

enum SettingsRoutineDataBackupMapping {
    typealias Backup = SettingsRoutineDataPersistence.Backup

    static func place(_ place: RoutinePlace) -> Backup.Place {
        Backup.Place(
            id: place.id,
            name: place.displayName,
            kind: place.displayKind,
            latitude: place.latitude,
            longitude: place.longitude,
            radiusMeters: place.radiusMeters,
            createdAt: place.createdAt
        )
    }

    static func goal(_ goal: RoutineGoal) -> Backup.Goal {
        Backup.Goal(
            id: goal.id,
            title: goal.displayTitle,
            emoji: goal.emoji,
            notes: goal.notes,
            targetDate: goal.targetDate,
            tags: goal.tags,
            status: goal.status,
            color: goal.color,
            parentGoalID: goal.parentGoalID,
            rejectedTaskSuggestionIDs: goal.rejectedTaskSuggestionIDs,
            createdAt: goal.createdAt,
            sortOrder: goal.sortOrder
        )
    }

    static func task(
        _ task: RoutineTask,
        imageData: Data?,
        imageAttachmentID: UUID?,
        voiceNoteData: Data?,
        voiceNoteAttachmentID: UUID?,
        includesPressure: Bool
    ) -> Backup.Task {
        Backup.Task(
            id: task.id,
            name: task.name,
            emoji: task.emoji,
            notes: task.notes,
            link: task.link,
            links: task.links.isEmpty ? nil : task.links,
            linkItems: task.linkItems.isEmpty ? nil : task.linkItems,
            deadline: task.deadline,
            plannedDate: task.plannedDate,
            isAllDay: task.isAllDay,
            routineDurationMode: task.routineDurationMode,
            availabilityStartDate: task.availabilityStartDate,
            availabilityEndDate: task.availabilityEndDate,
            reminderAt: task.reminderAt,
            imageData: imageData,
            imageAttachmentID: imageAttachmentID,
            voiceNoteData: voiceNoteData,
            voiceNoteAttachmentID: voiceNoteAttachmentID,
            voiceNoteDurationSeconds: task.voiceNoteDurationSeconds,
            voiceNoteCreatedAt: task.voiceNoteCreatedAt,
            placeID: task.placeID,
            placeIDs: task.placeIDs.isEmpty ? nil : task.placeIDs,
            tags: task.tags,
            goalIDs: task.goalIDs,
            eventIDs: task.eventIDs.isEmpty ? nil : task.eventIDs,
            steps: task.steps,
            checklistItems: task.checklistItems,
            scheduleMode: task.scheduleMode,
            interval: max(Int(task.interval), 1),
            recurrenceRule: task.recurrenceRule,
            lastDone: task.lastDone,
            canceledAt: task.canceledAt,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            snoozedUntil: task.snoozedUntil,
            pinnedAt: task.pinnedAt,
            completedStepCount: task.completedSteps,
            sequenceStartedAt: task.sequenceStartedAt,
            createdAt: task.createdAt,
            todoStateRawValue: task.todoStateRawValue,
            activityStateRawValue: task.activityStateRawValue,
            ongoingSince: task.ongoingSince,
            autoAssumeDailyDone: task.autoAssumeDailyDone,
            autoAssumeDoneTimeOfDay: task.autoAssumeDoneTimeOfDay,
            estimatedDurationMinutes: task.estimatedDurationMinutes,
            actualDurationMinutes: task.actualDurationMinutes,
            storyPoints: task.storyPoints,
            pressure: includesPressure ? task.pressure : nil,
            pressureUpdatedAt: includesPressure ? task.pressureUpdatedAt : nil,
            comments: task.comments
        )
    }

    static func log(_ log: RoutineLog) -> Backup.Log {
        Backup.Log(
            id: log.id,
            timestamp: log.timestamp,
            taskID: log.taskID,
            kind: log.kind,
            actualDurationMinutes: log.actualDurationMinutes
        )
    }

    static func focus(_ session: FocusSession) -> Backup.Focus {
        Backup.Focus(
            id: session.id,
            taskID: session.taskID,
            tagName: session.focusTagName,
            startedAt: session.startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds,
            completedAt: session.completedAt,
            abandonedAt: session.abandonedAt,
            pausedAt: session.pausedAt,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds
        )
    }

    static func sleep(_ session: SleepSession) -> Backup.Sleep {
        Backup.Sleep(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            targetDurationMinutes: session.targetDurationMinutes,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt
        )
    }

    static func away(_ session: AwaySession) -> Backup.Away {
        Backup.Away(
            id: session.id,
            preset: session.preset,
            title: session.title,
            linkedTaskID: session.linkedTaskID,
            startedAt: session.startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds,
            completedAt: session.completedAt,
            endedEarlyAt: session.endedEarlyAt,
            extensionCount: session.extensionCount,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt
        )
    }

    static func placeCheckIn(
        _ session: PlaceCheckInSession,
        imageData: Data?,
        imageAttachmentID: UUID?
    ) -> Backup.PlaceCheckIn {
        Backup.PlaceCheckIn(
            id: session.id,
            placeID: session.placeID,
            placeName: session.displayPlaceName,
            latitude: session.latitude,
            longitude: session.longitude,
            horizontalAccuracyMeters: session.horizontalAccuracyMeters,
            placeRadiusMeters: session.placeRadiusMeters,
            activity: session.activity,
            note: session.note,
            imageData: imageData,
            imageAttachmentID: imageAttachmentID,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            createdAt: session.createdAt,
            updatedAt: session.updatedAt,
            captureMode: session.captureMode,
            confirmedAt: session.confirmedAt
        )
    }

    static func emotion(_ emotion: EmotionLog) -> Backup.Emotion {
        Backup.Emotion(
            id: emotion.id,
            family: emotion.family,
            label: emotion.primaryDisplayLabel,
            families: emotion.families,
            labels: emotion.displayLabels,
            valence: emotion.valence,
            arousal: emotion.arousal,
            intensity: emotion.clampedIntensity,
            bodyAreas: emotion.bodyAreas,
            reflection: emotion.reflection,
            linkedNoteID: emotion.linkedNoteID,
            linkedGoalID: emotion.linkedGoalID,
            linkedTaskID: emotion.linkedTaskID,
            linkedPlaceID: emotion.linkedPlaceID,
            linkedSleepSessionID: emotion.linkedSleepSessionID,
            createdAt: emotion.createdAt,
            updatedAt: emotion.updatedAt
        )
    }

    static func note(
        _ note: RoutineNote,
        imageData: Data?,
        imageAttachmentID: UUID?,
        voiceNoteData: Data?,
        voiceNoteAttachmentID: UUID?
    ) -> Backup.Note {
        Backup.Note(
            id: note.id,
            title: note.title,
            body: note.body,
            tags: note.tags,
            imageData: imageData,
            imageAttachmentID: imageAttachmentID,
            voiceNoteData: voiceNoteData,
            voiceNoteAttachmentID: voiceNoteAttachmentID,
            voiceNoteDurationSeconds: note.voiceNoteDurationSeconds,
            voiceNoteCreatedAt: note.voiceNoteCreatedAt,
            createdAt: note.createdAt,
            updatedAt: note.updatedAt
        )
    }

    static func event(_ event: RoutineEvent) -> Backup.Event {
        Backup.Event(
            id: event.id,
            title: event.title,
            notes: event.notes,
            emoji: event.emoji,
            tags: event.tags,
            isAllDay: event.isAllDay,
            startedAt: event.startedAt,
            endedAt: event.endedAt,
            reminderAt: event.reminderAt,
            createdAt: event.createdAt,
            updatedAt: event.updatedAt
        )
    }

    static func dayPlanBlock(_ record: DayPlanBlockRecord) -> Backup.DayPlanBlock {
        Backup.DayPlanBlock(
            id: record.id,
            taskID: record.taskID,
            dayKey: record.dayKey,
            startMinute: record.startMinute,
            durationMinutes: record.durationMinutes,
            titleSnapshot: record.titleSnapshot,
            emojiSnapshot: record.emojiSnapshot,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
    }

    static func boardSprint(_ sprint: BoardSprintRecord) -> Backup.BoardSprint {
        Backup.BoardSprint(
            id: sprint.id,
            title: sprint.title,
            status: SprintStatus(rawValue: sprint.statusRawValue) ?? .planned,
            createdAt: sprint.createdAt,
            startedAt: sprint.startedAt,
            finishedAt: sprint.finishedAt
        )
    }

    static func sprintAssignment(_ assignment: SprintAssignmentRecord) -> Backup.SprintAssignment {
        Backup.SprintAssignment(
            todoID: assignment.todoID,
            sprintID: assignment.sprintID,
            sortOrder: assignment.sortOrder
        )
    }

    static func boardBacklog(_ backlog: BoardBacklogRecord) -> Backup.BoardBacklog {
        Backup.BoardBacklog(
            id: backlog.id,
            title: backlog.title,
            createdAt: backlog.createdAt,
            routingTags: backlog.routingTags
        )
    }

    static func backlogAssignment(_ assignment: BacklogAssignmentRecord) -> Backup.BacklogAssignment {
        Backup.BacklogAssignment(
            todoID: assignment.todoID,
            backlogID: assignment.backlogID,
            sortOrder: assignment.sortOrder
        )
    }

    static func sprintFocus(_ session: SprintFocusSessionRecord) -> Backup.SprintFocus {
        Backup.SprintFocus(
            id: session.id,
            sprintID: session.sprintID,
            startedAt: session.startedAt,
            stoppedAt: session.stoppedAt,
            pausedAt: session.pausedAt,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds
        )
    }

    static func sprintFocusAllocation(_ allocation: SprintFocusAllocationRecord) -> Backup.SprintFocusAllocation {
        Backup.SprintFocusAllocation(
            id: allocation.id,
            sessionID: allocation.sessionID,
            taskID: allocation.taskID,
            minutes: allocation.minutes,
            sortOrder: allocation.sortOrder
        )
    }

    static func deviceSession(_ session: RoutinaDeviceSession) -> Backup.DeviceSession {
        Backup.DeviceSession(
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
    }

    static func deviceActionLog(_ log: RoutinaDeviceActionLog) -> Backup.DeviceActionLog {
        Backup.DeviceActionLog(
            id: log.id,
            timestamp: log.timestamp,
            action: log.action,
            entity: log.entity,
            entityID: log.entityID,
            entityTitle: log.entityTitle,
            deviceInstallationID: log.deviceInstallationID,
            deviceDisplayName: log.deviceDisplayName,
            devicePlatform: log.devicePlatform,
            deviceModelName: log.deviceModelName,
            systemName: log.systemName,
            systemVersion: log.systemVersion,
            appVersion: log.appVersion,
            details: log.details
        )
    }

    static func userPreferences(_ preferences: RoutinaUserPreferences) -> Backup.UserPreferences {
        Backup.UserPreferences(
            id: preferences.id,
            selectedAppIcon: preferences.selectedAppIcon,
            appColorScheme: preferences.appColorScheme,
            routineListSectioningMode: preferences.routineListSectioningMode,
            tagCounterDisplayMode: preferences.tagCounterDisplayMode,
            homeTaskRowHiddenFields: preferences.homeTaskRowHiddenFields,
            relatedTagRules: preferences.relatedTagRules,
            tagColors: preferences.tagColors,
            fastFilterTags: preferences.fastFilterTags,
            iOSStatsDashboardHiddenItemIDs: preferences.iOSStatsDashboardHiddenItemIDs,
            iOSStatsDashboardItemOrderIDs: preferences.iOSStatsDashboardItemOrderIDs,
            iOSStatsSummaryDisplayMode: preferences.iOSStatsSummaryDisplayMode,
            macStatsDashboardHiddenItemIDs: preferences.macStatsDashboardHiddenItemIDs,
            macStatsDashboardItemOrderIDs: preferences.macStatsDashboardItemOrderIDs,
            macStatsSummaryDisplayMode: preferences.macStatsSummaryDisplayMode,
            hiddenDayPlanTimelineActivityIDs: preferences.hiddenDayPlanTimelineActivityIDs,
            protectionBlockingEnabledModes: preferences.protectionBlockingEnabledModes,
            blockingWebsiteDomains: preferences.blockingWebsiteDomains,
            focusShieldSelection: preferences.focusShieldSelection,
            macFocusBlockedApps: preferences.macFocusBlockedApps,
            macFormSectionOrder: preferences.macFormSectionOrder,
            macQuickAddShortcut: preferences.macQuickAddShortcut,
            macAdventureOwnedItemIDs: preferences.macAdventureOwnedItemIDs,
            macAdventureUnlockedWorldIDs: preferences.macAdventureUnlockedWorldIDs,
            macAdventureUnlockedStageIDs: preferences.macAdventureUnlockedStageIDs,
            notificationsEnabled: preferences.notificationsEnabled,
            hideUnavailableRoutines: preferences.hideUnavailableRoutines,
            appLockEnabled: preferences.appLockEnabled,
            gitFeaturesEnabled: preferences.gitFeaturesEnabled,
            taskSharingEnabled: preferences.taskSharingEnabled,
            taskRelationshipVisualizerEnabled: preferences.taskRelationshipVisualizerEnabled,
            placesEnabled: preferences.placesEnabled,
            notesEnabled: preferences.notesEnabled,
            awayEnabled: preferences.awayEnabled,
            filterQuerySectionsEnabled: preferences.filterQuerySectionsEnabled,
            unlockUnlimitedTasks: preferences.unlockUnlimitedTasks,
            showPersianDates: preferences.showPersianDates,
            batteryRoutineMonitoringEnabled: preferences.batteryRoutineMonitoringEnabled,
            sleepHomeActionEnabled: preferences.sleepHomeActionEnabled,
            sleepHomeMenuEnabled: preferences.sleepHomeMenuEnabled,
            shakeToStartSleepEnabled: preferences.shakeToStartSleepEnabled,
            focusShieldEnabled: preferences.focusShieldEnabled,
            macFocusAppBlockingEnabled: preferences.macFocusAppBlockingEnabled,
            automaticPlaceCheckInEnabled: preferences.automaticPlaceCheckInEnabled,
            showTimelineTasksInDayPlanner: preferences.showTimelineTasksInDayPlanner,
            separateDailyRoutinesInTaskList: preferences.separateDailyRoutinesInTaskList,
            showTomorrowInTaskList: preferences.showTomorrowInTaskList,
            separateTodosAndRoutinesInTagTaskListSections: preferences
                .separateTodosAndRoutinesInTagTaskListSections,
            notificationReminderHour: preferences.notificationReminderHour,
            notificationReminderMinute: preferences.notificationReminderMinute,
            batteryRoutineThresholdPercent: preferences.batteryRoutineThresholdPercent,
            updatedAt: preferences.updatedAt
        )
    }
}
