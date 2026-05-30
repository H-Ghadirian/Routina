import CloudKit
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct CloudKitDirectPullDeletionTests {
    @Test
    func cloudKitMerge_readsGoalParentLink() throws {
        let context = makeInMemoryContext()
        let parentID = UUID()
        let childID = UUID()
        let rejectedTaskID = UUID()
        let parentGoal = CKRecord(
            recordType: "RoutineGoal",
            recordID: CKRecord.ID(recordName: parentID.uuidString)
        )
        parentGoal["title"] = "Health" as CKRecordValue
        let childGoal = CKRecord(
            recordType: "RoutineGoal",
            recordID: CKRecord.ID(recordName: childID.uuidString)
        )
        childGoal["title"] = "Run 5K" as CKRecordValue
        childGoal["parentGoalID"] = parentID.uuidString as CKRecordValue
        childGoal["tagsStorage"] = "Health\nRace" as CKRecordValue
        childGoal["rejectedTaskSuggestionIDsStorage"] = RoutineGoalIDStorage.serialize([rejectedTaskID]) as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [parentGoal, childGoal], deletedRecordIDs: []),
            into: context
        )

        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let child = try #require(goals.first { $0.id == childID })
        #expect(child.parentGoalID == parentID)
        #expect(child.tags == ["Health", "Race"])
        #expect(child.rejectedTaskSuggestionIDs == [rejectedTaskID])
    }

    @Test
    func cloudKitMerge_deletedGoalClearsChildParentLink() throws {
        let context = makeInMemoryContext()
        let parent = RoutineGoal(title: "Health")
        let child = RoutineGoal(title: "Run 5K", parentGoalID: parent.id)
        context.insert(parent)
        context.insert(child)
        try context.save()

        try CloudKitDirectPullService.mergeForTesting(
            .init(
                changedRecords: [],
                deletedRecordIDs: [CKRecord.ID(recordName: parent.id.uuidString)]
            ),
            into: context
        )

        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let remainingGoal = try #require(goals.first)
        #expect(remainingGoal.id == child.id)
        #expect(remainingGoal.parentGoalID == nil)
    }

    @Test
    func cloudKitMerge_deletedTaskRemovesAssociatedTimelineRows() throws {
        let context = makeInMemoryContext()
        let deletedTask = makeTask(in: context, name: "Old", interval: 1, lastDone: nil, emoji: nil)
        let keptTask = makeTask(in: context, name: "Kept", interval: 1, lastDone: nil, emoji: nil)
        _ = makeLog(in: context, task: deletedTask, timestamp: makeDate("2026-03-14T08:00:00Z"))
        let keptLog = makeLog(in: context, task: keptTask, timestamp: makeDate("2026-03-15T08:00:00Z"))
        context.insert(FocusSession(taskID: deletedTask.id, startedAt: makeDate("2026-03-14T08:00:00Z")))
        let unassignedFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: makeDate("2026-03-14T09:00:00Z")
        )
        context.insert(unassignedFocus)
        context.insert(RoutineAttachment(taskID: deletedTask.id, fileName: "old.txt", data: Data([1, 2, 3])))
        try context.save()

        try CloudKitDirectPullService.mergeForTesting(
            .init(
                changedRecords: [],
                deletedRecordIDs: [CKRecord.ID(recordName: deletedTask.id.uuidString)]
            ),
            into: context
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        let attachments = try context.fetch(FetchDescriptor<RoutineAttachment>())

        #expect(tasks.map(\.id) == [keptTask.id])
        #expect(logs.map(\.id) == [keptLog.id])
        #expect(focusSessions.map(\.id) == [unassignedFocus.id])
        #expect(attachments.isEmpty)
    }

    @Test
    func cloudKitMerge_discardsLogWhoseTaskIsMissingFromRefresh() throws {
        let context = makeInMemoryContext()
        let missingTaskID = UUID()
        let cloudLog = CKRecord(
            recordType: "RoutineLog",
            recordID: CKRecord.ID(recordName: UUID().uuidString)
        )
        cloudLog["taskID"] = missingTaskID.uuidString as CKRecordValue
        cloudLog["timestamp"] = makeDate("2026-03-15T08:00:00Z") as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [cloudLog], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.isEmpty)
    }
}
