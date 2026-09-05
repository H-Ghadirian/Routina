import Foundation
import SwiftData

extension SettingsRoutineDataImportEntityInserter {
    @MainActor
    static func insertPlaces(
        from backup: Backup,
        in context: ModelContext,
        importDate: Date
    ) -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for place in backup.places ?? [] {
            guard importedIDs.insert(place.id).inserted else { continue }

            let importedPlace = RoutinePlace(
                id: place.id,
                name: place.name,
                latitude: place.latitude,
                longitude: place.longitude,
                radiusMeters: place.radiusMeters,
                kind: place.kind,
                createdAt: place.createdAt ?? importDate
            )
            context.insert(importedPlace)
            importedCount += 1
        }
        return (importedIDs, importedCount)
    }

    @MainActor
    static func insertGoals(
        from backup: Backup,
        in context: ModelContext,
        importDate: Date
    ) -> (ids: Set<UUID>, count: Int) {
        let validGoalIDs = Set(
            (backup.goals ?? [])
                .filter { RoutineGoal.cleanedTitle($0.title) != nil }
                .map(\.id)
        )
        var importedIDs = Set<UUID>()
        var importedCount = 0
        var importedGoals: [RoutineGoal] = []
        for goal in backup.goals ?? [] {
            guard RoutineGoal.cleanedTitle(goal.title) != nil else { continue }
            guard importedIDs.insert(goal.id).inserted else { continue }
            let parentGoalID = goal.parentGoalID.flatMap { parentID in
                validGoalIDs.contains(parentID) && parentID != goal.id ? parentID : nil
            }

            let importedGoal = RoutineGoal(
                id: goal.id,
                title: goal.title,
                emoji: goal.emoji,
                notes: goal.notes,
                targetDate: goal.targetDate,
                tags: goal.tags ?? [],
                status: goal.status ?? .active,
                color: goal.color ?? .none,
                parentGoalID: parentGoalID,
                rejectedTaskSuggestionIDs: goal.rejectedTaskSuggestionIDs ?? [],
                createdAt: goal.createdAt ?? importDate,
                sortOrder: goal.sortOrder ?? importedCount
            )
            context.insert(importedGoal)
            importedGoals.append(importedGoal)
            importedCount += 1
        }
        for goal in importedGoals where goal.parentGoalID != nil {
            goal.parentGoalID = RoutineGoalHierarchy.sanitizedParentGoalID(
                goal.parentGoalID,
                for: goal.id,
                in: importedGoals,
                id: { $0.id },
                parentGoalID: { $0.parentGoalID }
            )
        }
        return (importedIDs, importedCount)
    }

    @MainActor
    static func insertTasks(
        from backup: Backup,
        attachmentData: (String) throws -> Data?,
        importedPlaceIDs: Set<UUID>,
        importedGoalIDs: Set<UUID>,
        importedEventIDs: Set<UUID>,
        in context: ModelContext,
        importDate: Date
    ) throws -> (ids: Set<UUID>, count: Int) {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        var attachmentManifestsByID: [UUID: Backup.Attachment] = [:]
        for attachment in backup.attachments ?? [] {
            attachmentManifestsByID[attachment.id] = attachment
        }

        for task in backup.tasks {
            guard importedIDs.insert(task.id).inserted else { continue }

            let imageData = try importedImageData(
                for: task,
                attachmentManifestsByID: attachmentManifestsByID,
                attachmentData: attachmentData
            )
            let voiceNoteData = try importedVoiceNoteData(
                for: task,
                attachmentManifestsByID: attachmentManifestsByID,
                attachmentData: attachmentData
            )

            let importedTask = makeImportedTask(
                from: task,
                imageData: imageData,
                voiceNoteData: voiceNoteData,
                importedPlaceIDs: importedPlaceIDs,
                importedGoalIDs: importedGoalIDs,
                importedEventIDs: importedEventIDs
            )
            if let linkItems = task.linkItems {
                importedTask.linkItems = linkItems
            }
            importedTask.taskRankingOrderStorage = task.taskRankingOrderStorage ?? ""
            importedTask.temporalWeightRuleStorage = task.temporalWeightRuleStorage ?? ""
            context.insert(importedTask)
            importedCount += 1
        }
        return (importedIDs, importedCount)
    }

    private static func makeImportedTask(
        from task: Backup.Task,
        imageData: Data?,
        voiceNoteData: Data?,
        importedPlaceIDs: Set<UUID>,
        importedGoalIDs: Set<UUID>,
        importedEventIDs: Set<UUID>
    ) -> RoutineTask {
        RoutineTask(
            id: task.id,
            name: task.name,
            emoji: task.emoji,
            taskDescription: task.taskDescription,
            notes: task.notes,
            link: task.link,
            links: task.links ?? task.link.map { [$0] } ?? [],
            deadline: task.deadline,
            plannedDate: task.plannedDate,
            customTaskSectionID: task.customTaskSectionID,
            isAllDay: task.isAllDay ?? false,
            routineDurationMode: task.scheduleMode == .oneOff
                ? .oneDay
                : (task.routineDurationMode ?? .oneDay),
            availabilityStartDate: task.availabilityStartDate,
            availabilityEndDate: task.availabilityEndDate,
            reminderAt: task.reminderAt,
            pressure: task.pressure ?? .none,
            pressureUpdatedAt: task.pressureUpdatedAt,
            thinkingNeeded: task.thinkingNeeded ?? .none,
            imageData: imageData,
            voiceNoteData: voiceNoteData,
            voiceNoteDurationSeconds: task.voiceNoteDurationSeconds,
            voiceNoteCreatedAt: task.voiceNoteCreatedAt,
            placeID: task.placeID.flatMap { importedPlaceIDs.contains($0) ? $0 : nil },
            placeIDs: (task.placeIDs ?? task.placeID.map { [$0] } ?? []).filter { importedPlaceIDs.contains($0) },
            destinationAddress: task.destinationAddress,
            destinationLatitude: task.destinationLatitude,
            destinationLongitude: task.destinationLongitude,
            tags: task.tags ?? [],
            flags: task.flags ?? [],
            goalIDs: (task.goalIDs ?? []).filter { importedGoalIDs.contains($0) },
            eventIDs: (task.eventIDs ?? []).filter { importedEventIDs.contains($0) },
            steps: task.steps ?? [],
            checklistItems: task.checklistItems ?? [],
            scheduleMode: task.scheduleMode,
            interval: Int16(clampedInterval(task.interval)),
            recurrenceRule: task.recurrenceRule,
            recurrenceTimeRangeRole: task.recurrenceTimeRangeRole ?? .availability,
            lastDone: task.lastDone,
            lastSatisfiedScheduledOccurrenceAt: task.lastSatisfiedScheduledOccurrenceAt,
            canceledAt: task.canceledAt,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            pauseUntil: task.pauseUntil,
            snoozedUntil: task.snoozedUntil,
            pinnedAt: task.pinnedAt,
            completedStepCount: Int16(clamping: task.completedStepCount ?? 0),
            sequenceStartedAt: task.sequenceStartedAt,
            createdAt: task.createdAt,
            todoStateRawValue: task.todoStateRawValue,
            activityStateRawValue: task.activityStateRawValue,
            ongoingSince: task.ongoingSince,
            autoAssumeDailyDone: task.autoAssumeDailyDone ?? false,
            hidesAssumedDoneCalendarBlock: task.hidesAssumedDoneCalendarBlock ?? false,
            autoAssumeDoneTimeOfDay: task.autoAssumeDoneTimeOfDay,
            estimatedDurationMinutes: task.estimatedDurationMinutes,
            actualDurationMinutes: task.actualDurationMinutes,
            storyPoints: task.storyPoints,
            taskChoiceTieBreakScore: task.taskChoiceTieBreakScore ?? 0,
            taskChoiceComparisonCount: task.taskChoiceComparisonCount ?? 0,
            cadenceEnabled: task.cadenceEnabled ?? true,
            autoPauseAfterCompletion: task.autoPauseAfterCompletion ?? false,
            nudgesEnabled: task.nudgesEnabled ?? true,
            showsTaskDetailHeatmap: task.showsTaskDetailHeatmap ?? false,
            showsTaskDetailHistory: task.showsTaskDetailHistory ?? false,
            isTaskDetailCalendarExpanded: task.isTaskDetailCalendarExpanded ?? false,
            hasExplicitImportance: task.hasExplicitImportance ?? false,
            hasExplicitUrgency: task.hasExplicitUrgency ?? false,
            comments: task.comments ?? []

        )
    }

    private static func importedImageData(
        for task: Backup.Task,
        attachmentManifestsByID: [UUID: Backup.Attachment],
        attachmentData: (String) throws -> Data?
    ) throws -> Data? {
        guard let imageAttachmentID = task.imageAttachmentID,
            let imageAttachment = attachmentManifestsByID[imageAttachmentID]
        else {
            return task.imageData
        }

        guard let data = try attachmentData(imageAttachment.fileName) else {
            throw SettingsRoutineDataPersistence.Error.missingAttachment(imageAttachment.fileName)
        }
        return data
    }

    private static func importedVoiceNoteData(
        for task: Backup.Task,
        attachmentManifestsByID: [UUID: Backup.Attachment],
        attachmentData: (String) throws -> Data?
    ) throws -> Data? {
        guard let voiceNoteAttachmentID = task.voiceNoteAttachmentID,
            let voiceNoteAttachment = attachmentManifestsByID[voiceNoteAttachmentID]
        else {
            return task.voiceNoteData
        }

        guard let data = try attachmentData(voiceNoteAttachment.fileName) else {
            throw SettingsRoutineDataPersistence.Error.missingAttachment(voiceNoteAttachment.fileName)
        }
        return data
    }

    @MainActor
    static func insertFileAttachments(
        from backup: Backup,
        attachmentData: (String) throws -> Data?,
        importedTaskIDs: Set<UUID>,
        in context: ModelContext,
        importDate: Date
    ) throws -> Int {
        var importedIDs = Set<UUID>()
        var importedCount = 0
        for attachment in backup.attachments ?? [] where attachment.role == .fileAttachment {
            guard let taskID = attachment.taskID,
                importedTaskIDs.contains(taskID)
            else { continue }
            guard importedIDs.insert(attachment.id).inserted else { continue }
            guard let data = try attachmentData(attachment.fileName) else {
                if SettingsRoutineDataPersistence.requiresExternalAttachmentFiles(schemaVersion: backup.schemaVersion) {
                    throw SettingsRoutineDataPersistence.Error.missingAttachment(attachment.fileName)
                }
                continue
            }

            let importedAttachment = RoutineAttachment(
                id: attachment.id,
                taskID: taskID,
                fileName: attachment.originalFileName ?? attachment.fileName,
                data: data,
                createdAt: attachment.createdAt ?? importDate
            )
            context.insert(importedAttachment)
            importedCount += 1
        }
        return importedCount
    }

    private static func clampedInterval(_ interval: Int) -> Int {
        min(max(interval, 1), Int(Int16.max))
    }
}
