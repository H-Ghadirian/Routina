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
        let imageData = Data([1, 2, 3])
        let voiceData = Data([7, 8, 9])
        let voiceCreatedAt = Date(timeIntervalSince1970: 100)
        let deadline = Date(timeIntervalSince1970: 200)
        let task = RoutineTask(
            id: taskID,
            name: "Archive receipt",
            deadline: deadline,
            isAllDay: true,
            pressure: .high,
            imageData: imageData,
            voiceNoteData: voiceData,
            voiceNoteDurationSeconds: 2.5,
            voiceNoteCreatedAt: voiceCreatedAt,
            scheduleMode: .oneOff,
            interval: 0
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
            includesPressure: false
        )

        #expect(inline.id == taskID)
        #expect(inline.imageData == imageData)
        #expect(inline.imageAttachmentID == nil)
        #expect(inline.deadline == deadline)
        #expect(inline.isAllDay == true)
        #expect(inline.voiceNoteData == voiceData)
        #expect(inline.voiceNoteAttachmentID == nil)
        #expect(inline.voiceNoteDurationSeconds == 2.5)
        #expect(inline.voiceNoteCreatedAt == voiceCreatedAt)
        #expect(inline.interval == 1)
        #expect(inline.pressure == .high)
        #expect(packaged.imageData == nil)
        #expect(packaged.imageAttachmentID == attachmentID)
        #expect(packaged.voiceNoteData == nil)
        #expect(packaged.voiceNoteAttachmentID == voiceAttachmentID)
        #expect(packaged.pressure == nil)
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
