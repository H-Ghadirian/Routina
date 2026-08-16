import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct SettingsRoutineDataBackupMappingTests {
    @Test
    func goalMappingIncludesParentGoalLink() {
        let parentID = UUID()
        let rejectedTaskID = UUID()
        let goal = RoutineGoal(
            title: "Run 5K",
            tags: ["Health", "Race"],
            parentGoalID: parentID,
            rejectedTaskSuggestionIDs: [rejectedTaskID]
        )

        let backupGoal = SettingsRoutineDataBackupMapping.goal(goal)

        #expect(backupGoal.title == "Run 5K")
        #expect(backupGoal.tags == ["Health", "Race"])
        #expect(backupGoal.parentGoalID == parentID)
        #expect(backupGoal.rejectedTaskSuggestionIDs == [rejectedTaskID])
    }

    @Test
    func taskMappingChoosesInlineImageOrAttachmentReference() {
        let taskID = UUID()
        let attachmentID = UUID()
        let voiceAttachmentID = UUID()
        let customSectionID = UUID()
        let imageData = Data([1, 2, 3])
        let voiceData = Data([7, 8, 9])
        let voiceCreatedAt = Date(timeIntervalSince1970: 100)
        let deadline = Date(timeIntervalSince1970: 200)
        let task = RoutineTask(
            id: taskID,
            name: "Archive receipt",
            taskDescription: "Keep the original and a scanned copy.",
            deadline: deadline,
            customTaskSectionID: customSectionID,
            isAllDay: true,
            pressure: .high,
            thinkingNeeded: .medium,
            imageData: imageData,
            voiceNoteData: voiceData,
            voiceNoteDurationSeconds: 2.5,
            voiceNoteCreatedAt: voiceCreatedAt,
            scheduleMode: .oneOff,
            interval: 0,
            showsTaskDetailHeatmap: true,
            showsTaskDetailHistory: true,
            isTaskDetailCalendarExpanded: true,
            showsTaskDetailPriority: true,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )

        let inline = SettingsRoutineDataBackupMapping.task(
            task,
            imageData: imageData,
            imageAttachmentID: nil,
            voiceNoteData: voiceData,
            voiceNoteAttachmentID: nil,
            includesPressure: true
        )
        let packaged = SettingsRoutineDataBackupMapping.task(
            task,
            imageData: nil,
            imageAttachmentID: attachmentID,
            voiceNoteData: nil,
            voiceNoteAttachmentID: voiceAttachmentID,
            includesPressure: true
        )

        #expect(inline.id == taskID)
        #expect(inline.taskDescription == "Keep the original and a scanned copy.")
        #expect(inline.imageData == imageData)
        #expect(inline.imageAttachmentID == nil)
        #expect(inline.deadline == deadline)
        #expect(inline.customTaskSectionID == customSectionID)
        #expect(inline.isAllDay == true)
        #expect(inline.routineDurationMode == .oneDay)
        #expect(inline.voiceNoteData == voiceData)
        #expect(inline.voiceNoteAttachmentID == nil)
        #expect(inline.voiceNoteDurationSeconds == 2.5)
        #expect(inline.voiceNoteCreatedAt == voiceCreatedAt)
        #expect(inline.interval == 1)
        #expect(inline.showsTaskDetailHeatmap == true)
        #expect(inline.showsTaskDetailHistory == true)
        #expect(inline.isTaskDetailCalendarExpanded == true)
        #expect(inline.showsTaskDetailPriority == true)
        #expect(inline.hasExplicitImportance == true)
        #expect(inline.hasExplicitUrgency == true)
        #expect(inline.pressure == .high)
        #expect(inline.thinkingNeeded == .medium)
        #expect(packaged.imageData == nil)
        #expect(packaged.taskDescription == "Keep the original and a scanned copy.")
        #expect(packaged.imageAttachmentID == attachmentID)
        #expect(packaged.voiceNoteData == nil)
        #expect(packaged.voiceNoteAttachmentID == voiceAttachmentID)
        #expect(packaged.showsTaskDetailHeatmap == true)
        #expect(packaged.showsTaskDetailHistory == true)
        #expect(packaged.isTaskDetailCalendarExpanded == true)
        #expect(packaged.showsTaskDetailPriority == true)
        #expect(packaged.hasExplicitImportance == true)
        #expect(packaged.hasExplicitUrgency == true)
        #expect(packaged.pressure == .high)
        #expect(packaged.thinkingNeeded == .medium)
    }

    @Test
    func taskMappingIncludesRoutineDurationMode() {
        let task = RoutineTask(
            name: "Travel",
            isAllDay: false,
            routineDurationMode: .multiDay,
            scheduleMode: .fixedInterval
        )

        let backupTask = SettingsRoutineDataBackupMapping.task(
            task,
            imageData: nil,
            imageAttachmentID: nil,
            voiceNoteData: nil,
            voiceNoteAttachmentID: nil,
            includesPressure: false
        )

        #expect(backupTask.routineDurationMode == .multiDay)
    }

    @Test
    func taskMappingIncludesTimeRangeRoleForTimeBlocks() {
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 18, minute: 30),
            end: RoutineTimeOfDay(hour: 20, minute: 0)
        )
        let task = RoutineTask(
            name: "Group session",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 5, timeRange: window),
            recurrenceTimeRangeRole: .scheduledBlock
        )

        let backupTask = SettingsRoutineDataBackupMapping.task(
            task,
            imageData: nil,
            imageAttachmentID: nil,
            voiceNoteData: nil,
            voiceNoteAttachmentID: nil,
            includesPressure: false
        )

        #expect(backupTask.recurrenceTimeRangeRole == .scheduledBlock)
    }

    @Test
    func earlyScheduledCompletionMappingPreservesActualAndOccurrenceDates() {
        let completedAt = makeDate("2026-07-26T10:00:00Z")
        let scheduledOccurrence = makeDate("2026-07-27T00:00:00Z")
        let task = RoutineTask(
            name: "Rent",
            scheduleMode: .fixedInterval,
            recurrenceRule: .monthly(on: [27]),
            lastDone: completedAt,
            lastSatisfiedScheduledOccurrenceAt: scheduledOccurrence
        )
        let log = RoutineLog(
            timestamp: completedAt,
            scheduledOccurrenceAt: scheduledOccurrence,
            taskID: task.id,
            hasSpecificWorkTime: false
        )

        let backupTask = SettingsRoutineDataBackupMapping.task(
            task,
            imageData: nil,
            imageAttachmentID: nil,
            voiceNoteData: nil,
            voiceNoteAttachmentID: nil,
            includesPressure: false
        )
        let backupLog = SettingsRoutineDataBackupMapping.log(log)

        #expect(backupTask.lastDone == completedAt)
        #expect(backupTask.lastSatisfiedScheduledOccurrenceAt == scheduledOccurrence)
        #expect(backupLog.timestamp == completedAt)
        #expect(backupLog.scheduledOccurrenceAt == scheduledOccurrence)
        #expect(backupLog.hasSpecificWorkTime == false)
    }

    @Test
    func placeCheckInMappingChoosesInlineImageOrAttachmentReference() {
        let sessionID = UUID()
        let attachmentID = UUID()
        let imageData = Data([4, 5, 6])
        let session = PlaceCheckInSession(
            id: sessionID,
            placeID: nil,
            placeName: "Office",
            imageData: imageData
        )

        let inline = SettingsRoutineDataBackupMapping.placeCheckIn(
            session,
            imageData: imageData,
            imageAttachmentID: nil
        )
        let packaged = SettingsRoutineDataBackupMapping.placeCheckIn(
            session,
            imageData: nil,
            imageAttachmentID: attachmentID
        )

        #expect(inline.id == sessionID)
        #expect(inline.imageData == imageData)
        #expect(inline.imageAttachmentID == nil)
        #expect(packaged.imageData == nil)
        #expect(packaged.imageAttachmentID == attachmentID)
    }
}
