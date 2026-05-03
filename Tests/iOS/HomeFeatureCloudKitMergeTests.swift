import CloudKit
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

@MainActor
struct HomeFeatureCloudKitMergeTests {
    @Test
    func cloudKitMerge_skipsLogicalDuplicateLogsFromRefresh() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        let timestamp = makeDate("2026-03-15T08:00:00Z")
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        try context.save()

        let cloudLog = CKRecord(
            recordType: "RoutineLog",
            recordID: CKRecord.ID(recordName: UUID().uuidString)
        )
        cloudLog["taskID"] = task.id.uuidString as CKRecordValue
        cloudLog["timestamp"] = timestamp as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [cloudLog], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_removesExistingDuplicateLogsDuringRefresh() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Walk", interval: 1, lastDone: nil, emoji: "🚶")
        let timestamp = makeDate("2026-03-15T09:30:00Z")
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        try context.save()

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_sameNamedTaskRemapsLogsToExistingLocalTask() throws {
        let context = makeInMemoryContext()
        let localTask = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        try context.save()

        let remoteTaskID = UUID()
        let timestamp = makeDate("2026-03-14T08:00:00Z")

        let remoteLog = CKRecord(
            recordType: "RoutineLog",
            recordID: CKRecord.ID(recordName: UUID().uuidString)
        )
        remoteLog["taskID"] = remoteTaskID.uuidString as CKRecordValue
        remoteLog["timestamp"] = timestamp as CKRecordValue

        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: remoteTaskID.uuidString)
        )
        remoteTask["name"] = "Read" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 1)
        remoteTask["lastDone"] = timestamp as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remoteLog, remoteTask], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == localTask.id)

        let localTaskID = localTask.id
        let refreshedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == localTaskID
                    }
                )
            ).first
        )
        #expect(refreshedTask.lastDone == timestamp)

        let detailLogs = HomeFeature.detailLogs(taskID: localTask.id, context: context)
        #expect(detailLogs.count == 1)
        #expect(detailLogs.first?.taskID == localTask.id)
        #expect(detailLogs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_sameNamedPlaceReusesExistingLocalPlace() throws {
        let context = makeInMemoryContext()
        let localPlace = RoutinePlace(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Home",
            latitude: 52.5200,
            longitude: 13.4050,
            radiusMeters: 150,
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        context.insert(localPlace)
        try context.save()

        let remotePlaceID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let remoteTaskID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!

        let remotePlace = CKRecord(
            recordType: "RoutinePlace",
            recordID: CKRecord.ID(recordName: remotePlaceID.uuidString)
        )
        remotePlace["name"] = " home " as CKRecordValue
        remotePlace["latitude"] = NSNumber(value: 52.5300)
        remotePlace["longitude"] = NSNumber(value: 13.4100)
        remotePlace["radiusMeters"] = NSNumber(value: 200)
        remotePlace["createdAt"] = makeDate("2026-03-03T08:00:00Z") as CKRecordValue

        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: remoteTaskID.uuidString)
        )
        remoteTask["name"] = "Stretch" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 1)
        remoteTask["placeID"] = remotePlaceID.uuidString as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remotePlace, remoteTask], deletedRecordIDs: []),
            into: context
        )

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        #expect(places.count == 1)
        #expect(places.first?.id == localPlace.id)
        #expect(places.first?.displayName == "Home")
        #expect(places.first?.radiusMeters == 200)

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.id == remoteTaskID)
        #expect(tasks.first?.placeID == localPlace.id)
    }
}
