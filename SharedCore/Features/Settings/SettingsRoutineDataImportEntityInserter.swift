import Foundation
import SwiftData

enum SettingsRoutineDataImportEntityInserter {
    typealias Backup = SettingsRoutineDataPersistence.Backup
    typealias ImportSummary = SettingsRoutineDataPersistence.ImportSummary

    @MainActor
    static func insertBackup(
        _ backup: Backup,
        attachmentData: (String) throws -> Data?,
        in context: ModelContext,
        importDate: Date,
        appliesUserPreferencesToDefaults: Bool = true
    ) throws -> ImportSummary {
        let places = insertPlaces(from: backup, in: context, importDate: importDate)
        let goals = insertGoals(from: backup, in: context, importDate: importDate)
        let importedEventIDs = Set((backup.events ?? []).map(\.id))
        let tasks = try insertTasks(
            from: backup,
            attachmentData: attachmentData,
            importedPlaceIDs: places.ids,
            importedGoalIDs: goals.ids,
            importedEventIDs: importedEventIDs,
            in: context,
            importDate: importDate
        )
        let taskAttachmentCount = try insertFileAttachments(
            from: backup,
            attachmentData: attachmentData,
            importedTaskIDs: tasks.ids,
            in: context,
            importDate: importDate
        )
        let logCount = insertLogs(
            from: backup,
            importedTaskIDs: tasks.ids,
            in: context
        )
        let focusSessionCount = insertFocusSessions(
            from: backup,
            importedTaskIDs: tasks.ids,
            in: context
        )
        let sleepSessions = insertSleepSessions(from: backup, in: context)
        let awaySessions = insertAwaySessions(from: backup, in: context)
        let placeCheckInCount = try insertPlaceCheckInSessions(
            from: backup,
            attachmentData: attachmentData,
            importedPlaceIDs: places.ids,
            in: context
        )
        let notes = try insertNotes(
            from: backup,
            attachmentData: attachmentData,
            in: context,
            importDate: importDate
        )
        let eventCount = insertEvents(
            from: backup,
            in: context,
            importDate: importDate
        )
        let emotionLogCount = insertEmotionLogs(
            from: backup,
            importedNoteIDs: notes.ids,
            importedGoalIDs: goals.ids,
            importedTaskIDs: tasks.ids,
            importedPlaceIDs: places.ids,
            importedSleepSessionIDs: sleepSessions.ids,
            in: context
        )
        let noteAttachmentCount = try insertNoteFileAttachments(
            from: backup,
            attachmentData: attachmentData,
            importedNoteIDs: notes.ids,
            in: context,
            importDate: importDate
        )
        let dayPlanBlockCount = insertDayPlanBlocks(
            from: backup,
            importedTaskIDs: tasks.ids,
            in: context
        )
        let boardSprints = insertBoardSprints(
            from: backup,
            in: context
        )
        let boardBacklogs = insertBoardBacklogs(
            from: backup,
            in: context
        )
        let sprintAssignmentCount = insertSprintAssignments(
            from: backup,
            importedTaskIDs: tasks.ids,
            importedSprintIDs: boardSprints.ids,
            in: context
        )
        let backlogAssignmentCount = insertBacklogAssignments(
            from: backup,
            importedTaskIDs: tasks.ids,
            importedBacklogIDs: boardBacklogs.ids,
            in: context
        )
        let sprintFocusSessions = insertSprintFocusSessions(
            from: backup,
            importedSprintIDs: boardSprints.ids,
            in: context
        )
        let sprintFocusAllocationCount = insertSprintFocusAllocations(
            from: backup,
            importedSprintFocusSessionIDs: sprintFocusSessions.ids,
            importedTaskIDs: tasks.ids,
            in: context
        )
        let deviceSessionCount = insertDeviceSessions(
            from: backup,
            in: context
        )
        let deviceActionLogCount = insertDeviceActionLogs(
            from: backup,
            in: context
        )
        let userPreferenceCount = insertUserPreferences(
            from: backup,
            in: context,
            importDate: importDate,
            appliesToDefaults: appliesUserPreferencesToDefaults
        )

        return ImportSummary(
            places: places.count,
            goals: goals.count,
            tasks: tasks.count,
            logs: logCount,
            sleepSessions: sleepSessions.count,
            awaySessions: awaySessions.count,
            placeCheckInSessions: placeCheckInCount,
            emotionLogs: emotionLogCount,
            notes: notes.count,
            events: eventCount,
            attachments: taskAttachmentCount + noteAttachmentCount,
            focusSessions: focusSessionCount,
            dayPlanBlocks: dayPlanBlockCount,
            boardSprints: boardSprints.count,
            sprintAssignments: sprintAssignmentCount,
            boardBacklogs: boardBacklogs.count,
            backlogAssignments: backlogAssignmentCount,
            sprintFocusSessions: sprintFocusSessions.count,
            sprintFocusAllocations: sprintFocusAllocationCount,
            deviceSessions: deviceSessionCount,
            deviceActionLogs: deviceActionLogCount,
            userPreferences: userPreferenceCount
        )
    }

}
