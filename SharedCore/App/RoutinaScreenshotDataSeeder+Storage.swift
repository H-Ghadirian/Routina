import Foundation
import SwiftData

extension RoutinaScreenshotDataSeeder {
    @MainActor
    static func mergeCustomSections(
        _ customSections: [HomeCustomTaskSection],
        updatedAt: Date,
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let preferences = try RoutinaUserPreferencesStore.fetchOrCreate(in: context)
        let existingSections = HomeCustomTaskSectionStorage.decoded(
            from: preferences.customTaskSections
        )
        var mergedSections = existingSections
        for section in customSections {
            if let index = mergedSections.firstIndex(where: { $0.id == section.id }) {
                mergedSections[index] = section
                result.refreshedRecordCount += 1
            } else {
                mergedSections.append(section)
                result.sectionCount += 1
            }
        }
        preferences.customTaskSections = HomeCustomTaskSectionStorage.encoded(mergedSections)
        preferences.updatedAt = updatedAt
    }

    @MainActor
    static func upsertGoals(
        _ goals: [RoutineGoal],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws -> [UUID: RoutineGoal] {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<RoutineGoal>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for goal in goals {
            if let stored = existing[goal.id] {
                refresh(stored, from: goal)
                result.refreshedRecordCount += 1
            } else {
                context.insert(goal)
                result.goalCount += 1
            }
        }
        return existing
    }

    @MainActor
    static func upsertTasks(
        _ tasks: [RoutineTask],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<RoutineTask>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for task in tasks {
            if let stored = existing[task.id] {
                refresh(stored, from: task)
                result.refreshedRecordCount += 1
            } else {
                context.insert(task)
                result.taskCount += 1
            }
        }
    }

    @MainActor
    static func upsertLogs(
        _ logs: [RoutineLog],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<RoutineLog>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for log in logs {
            if let stored = existing[log.id] {
                refresh(stored, from: log)
                result.refreshedRecordCount += 1
            } else {
                context.insert(log)
                result.logCount += 1
            }
        }
    }

    @MainActor
    static func upsertPlannerBlocks(
        _ blocks: [DayPlanBlockRecord],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<DayPlanBlockRecord>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for block in blocks {
            if let stored = existing[block.id] {
                stored.apply(block.detachedBlock)
                result.refreshedRecordCount += 1
            } else {
                context.insert(block)
                result.plannerBlockCount += 1
            }
        }
    }

    @MainActor
    static func upsertFocusSessions(
        _ sessions: [FocusSession],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<FocusSession>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for session in sessions {
            if let stored = existing[session.id] {
                refresh(stored, from: session)
                result.refreshedRecordCount += 1
            } else {
                context.insert(session)
                result.focusSessionCount += 1
            }
        }
    }

    @MainActor
    static func upsertNotes(
        _ notes: [RoutineNote],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<RoutineNote>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for note in notes {
            if let stored = existing[note.id] {
                refresh(stored, from: note)
                result.refreshedRecordCount += 1
            } else {
                context.insert(note)
                result.noteCount += 1
            }
        }
    }

    @MainActor
    static func upsertEvents(
        _ events: [RoutineEvent],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws -> [UUID: RoutineEvent] {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<RoutineEvent>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for event in events {
            if let stored = existing[event.id] {
                refresh(stored, from: event)
                result.refreshedRecordCount += 1
            } else {
                context.insert(event)
                result.eventCount += 1
            }
        }
        return existing
    }

    @MainActor
    static func upsertSleepSessions(
        _ sessions: [SleepSession],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<SleepSession>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for session in sessions {
            if let stored = existing[session.id] {
                refresh(stored, from: session)
                result.refreshedRecordCount += 1
            } else {
                context.insert(session)
                result.sleepSessionCount += 1
            }
        }
    }

    @MainActor
    static func upsertAwaySessions(
        _ sessions: [AwaySession],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existing = Dictionary(
            try context.fetch(FetchDescriptor<AwaySession>()).map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        for session in sessions {
            if let stored = existing[session.id] {
                refresh(stored, from: session)
                result.refreshedRecordCount += 1
            } else {
                context.insert(session)
                result.awaySessionCount += 1
            }
        }
    }

    @MainActor
    static func removeRetiredRecords(
        existingGoals: [UUID: RoutineGoal],
        existingEvents: [UUID: RoutineEvent],
        in context: ModelContext,
        result: inout RoutinaScreenshotDataSeedResult
    ) throws {
        let existingEmotions = try context.fetch(FetchDescriptor<EmotionLog>())
        for emotion in existingEmotions where retiredEmotionIDs.contains(emotion.id) {
            context.delete(emotion)
            result.removedRecordCount += 1
        }
        for event in existingEvents.values where retiredEventIDs.contains(event.id) {
            context.delete(event)
            result.removedRecordCount += 1
        }
        for goal in existingGoals.values where retiredGoalIDs.contains(goal.id) {
            context.delete(goal)
            result.removedRecordCount += 1
        }
    }

    @MainActor
    private static func refresh(_ existing: RoutineTask, from template: RoutineTask) {
        CloudSharingService.SharedTaskPayload(task: template).apply(to: existing)
        existing.customTaskSectionID = template.customTaskSectionID
        existing.completedChecklistItemIDsStorage = template.completedChecklistItemIDsStorage
        existing.completedChecklistProgressStartedAt = template.completedChecklistProgressStartedAt
        existing.manualSectionOrderStorage = template.manualSectionOrderStorage
        existing.taskChoiceTieBreakScore = template.taskChoiceTieBreakScore
        existing.taskChoiceComparisonCount = template.taskChoiceComparisonCount
        existing.showsTaskDetailHeatmap = template.showsTaskDetailHeatmap
        existing.showsTaskDetailHistory = template.showsTaskDetailHistory
        existing.isTaskDetailCalendarExpanded = template.isTaskDetailCalendarExpanded
        existing.changeLogStorage = template.changeLogStorage
    }

    private static func refresh(_ existing: RoutineGoal, from template: RoutineGoal) {
        existing.title = template.title
        existing.emoji = template.emoji
        existing.notes = template.notes
        existing.targetDate = template.targetDate
        existing.tags = template.tags
        existing.status = template.status
        existing.color = template.color
        existing.parentGoalID = template.parentGoalID
        existing.rejectedTaskSuggestionIDs = template.rejectedTaskSuggestionIDs
        existing.createdAt = template.createdAt
        existing.sortOrder = template.sortOrder
    }

    private static func refresh(_ existing: RoutineLog, from template: RoutineLog) {
        existing.timestamp = template.timestamp
        existing.scheduledOccurrenceAt = template.scheduledOccurrenceAt
        existing.taskID = template.taskID
        existing.kind = template.kind
        existing.actualDurationMinutes = template.actualDurationMinutes
        existing.hasSpecificWorkTime = template.hasSpecificWorkTime
        existing.sourceTaskID = template.sourceTaskID
        existing.isConfirmedAssumedDone = template.isConfirmedAssumedDone
    }

    private static func refresh(_ existing: FocusSession, from template: FocusSession) {
        existing.taskID = template.taskID
        existing.startedAt = template.startedAt
        existing.plannedDurationSeconds = template.plannedDurationSeconds
        existing.completedAt = template.completedAt
        existing.abandonedAt = template.abandonedAt
        existing.pausedAt = template.pausedAt
        existing.accumulatedPausedSeconds = template.accumulatedPausedSeconds
        existing.tagName = template.tagName
    }

    private static func refresh(_ existing: RoutineNote, from template: RoutineNote) {
        existing.title = template.title
        existing.body = template.body
        existing.tags = template.tags
        existing.imageData = template.imageData
        existing.voiceNoteData = template.voiceNoteData
        existing.voiceNoteDurationSeconds = template.voiceNoteDurationSeconds
        existing.voiceNoteCreatedAt = template.voiceNoteCreatedAt
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

    private static func refresh(_ existing: RoutineEvent, from template: RoutineEvent) {
        existing.title = template.title
        existing.notes = template.notes
        existing.emoji = template.emoji
        existing.tags = template.tags
        existing.isAllDay = template.isAllDay
        existing.startedAt = template.startedAt
        existing.endedAt = template.endedAt
        existing.reminderAt = template.reminderAt
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

    private static func refresh(_ existing: SleepSession, from template: SleepSession) {
        existing.startedAt = template.startedAt
        existing.endedAt = template.endedAt
        existing.targetDurationMinutes = template.targetDurationMinutes
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

    private static func refresh(_ existing: AwaySession, from template: AwaySession) {
        existing.presetRawValue = template.presetRawValue
        existing.title = template.title
        existing.linkedTaskID = template.linkedTaskID
        existing.startedAt = template.startedAt
        existing.plannedDurationSeconds = template.plannedDurationSeconds
        existing.completedAt = template.completedAt
        existing.endedEarlyAt = template.endedEarlyAt
        existing.extensionCount = template.extensionCount
        existing.createdAt = template.createdAt
        existing.updatedAt = template.updatedAt
    }

}
