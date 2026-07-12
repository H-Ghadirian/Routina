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
struct CloudKitDirectPullRecurrenceTests {
    @Test
    func cloudKitMerge_readsSwiftDataRecurrenceColumns() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let timeRange = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 7, minute: 0),
            end: RoutineTimeOfDay(hour: 10, minute: 0)
        )
        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: taskID.uuidString)
        )
        remoteTask["name"] = "Breakfast" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 1)
        remoteTask["scheduleModeRawValue"] = RoutineScheduleMode.fixedInterval.rawValue as CKRecordValue
        remoteTask["recurrenceStorageVersion"] = NSNumber(value: 1)
        remoteTask["recurrenceKindRawValue"] = RoutineRecurrenceRule.Kind.dailyTime.rawValue as CKRecordValue
        remoteTask["recurrenceTimeRangeStartHour"] = NSNumber(value: timeRange.start.hour)
        remoteTask["recurrenceTimeRangeStartMinute"] = NSNumber(value: timeRange.start.minute)
        remoteTask["recurrenceTimeRangeEndHour"] = NSNumber(value: timeRange.end.hour)
        remoteTask["recurrenceTimeRangeEndMinute"] = NSNumber(value: timeRange.end.minute)
        remoteTask["recurrenceTimeRangeRoleRawValue"] = RoutineTimeRangeRole.scheduledBlock.rawValue as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remoteTask], deletedRecordIDs: []),
            into: context
        )

        let task = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(task.recurrenceRule == .daily(in: timeRange))
        #expect(task.recurrenceTimeRangeRole == .scheduledBlock)
        #expect(task.recurrenceStorageVersion == 1)
        #expect(task.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func cloudKitMerge_readsTaskEventIDStorage() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let eventID = UUID()
        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: taskID.uuidString)
        )
        remoteTask["name"] = "Prepare notes" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 1)
        remoteTask["eventIDsStorage"] = RoutineEventIDStorage.serialize([eventID]) as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remoteTask], deletedRecordIDs: []),
            into: context
        )

        let task = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(task.eventIDs == [eventID])
    }
}
