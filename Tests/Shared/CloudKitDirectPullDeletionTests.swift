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
    func cloudKitMerge_deletedTaskRemovesAssociatedTimelineRows() throws {
        let context = makeInMemoryContext()
        let deletedTask = makeTask(in: context, name: "Old", interval: 1, lastDone: nil, emoji: nil)
        let keptTask = makeTask(in: context, name: "Kept", interval: 1, lastDone: nil, emoji: nil)
        _ = makeLog(in: context, task: deletedTask, timestamp: makeDate("2026-03-14T08:00:00Z"))
        let keptLog = makeLog(in: context, task: keptTask, timestamp: makeDate("2026-03-15T08:00:00Z"))
        context.insert(FocusSession(taskID: deletedTask.id, startedAt: makeDate("2026-03-14T08:00:00Z")))
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
        #expect(focusSessions.isEmpty)
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
