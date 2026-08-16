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
struct CloudKitDirectPullTaskRelationshipTests {
    @Test
    func cloudKitMerge_restoresRelationshipAndBlockedState() throws {
        let context = makeInMemoryContext()
        let blockedTaskID = UUID()
        let blockerID = UUID()
        let relationship = RoutineTaskRelationship(
            targetTaskID: blockerID,
            kind: .blockedBy
        )
        let blockedRecord = taskRecord(
            id: blockedTaskID,
            name: "Open merge request",
            relationships: [relationship],
            relationshipStorageKey: "CD_relationshipsStorage"
        )
        let blockerRecord = taskRecord(
            id: blockerID,
            name: "Merge release branch"
        )

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [blockedRecord, blockerRecord], deletedRecordIDs: []),
            into: context
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let blockedTask = try #require(tasks.first { $0.id == blockedTaskID })
        #expect(blockedTask.relationships == [relationship])
        #expect(HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
            taskID: blockedTaskID,
            tasks: tasks,
            referenceDate: Date(),
            calendar: .current
        ))
    }

    @Test
    func cloudKitMerge_appliesEmptyRelationshipStorageButPreservesAbsentField() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let blockerID = UUID()
        let relationship = RoutineTaskRelationship(
            targetTaskID: blockerID,
            kind: .blockedBy
        )
        let task = RoutineTask(
            id: taskID,
            name: "Open merge request",
            relationships: [relationship]
        )
        context.insert(task)
        try context.save()

        let recordWithoutRelationshipField = taskRecord(
            id: taskID,
            name: "Open merge request"
        )
        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [recordWithoutRelationshipField], deletedRecordIDs: []),
            into: context
        )
        #expect(task.relationships == [relationship])

        let recordWithEmptyRelationships = taskRecord(
            id: taskID,
            name: "Open merge request",
            relationships: []
        )
        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [recordWithEmptyRelationships], deletedRecordIDs: []),
            into: context
        )
        #expect(task.relationships.isEmpty)
    }

    private func taskRecord(
        id: UUID,
        name: String,
        relationships: [RoutineTaskRelationship]? = nil,
        relationshipStorageKey: String = "relationshipsStorage"
    ) -> CKRecord {
        let record = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: id.uuidString)
        )
        record["name"] = name as CKRecordValue
        record["interval"] = NSNumber(value: 1)
        if let relationships {
            record[relationshipStorageKey] = RoutineTaskRelationshipStorage.serialize(
                relationships,
                ownerID: id
            ) as CKRecordValue
        }
        return record
    }
}
