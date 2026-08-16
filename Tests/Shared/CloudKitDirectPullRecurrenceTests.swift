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
    func cloudKitMergeReadsTemporalTaskLadderRuleStorage() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let rule = RoutineTaskTemporalWeightRule(
            curve: .gradual,
            leadDays: 5,
            urgencyAtDue: .level4,
            pressureAtDue: .high
        )
        let storage = RoutineTaskTemporalWeightStorage.serialize(rule)
        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: taskID.uuidString)
        )
        remoteTask["name"] = "Quarterly filing" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 90)
        remoteTask["scheduleModeRawValue"] = RoutineScheduleMode.fixedInterval.rawValue as CKRecordValue
        remoteTask["temporalWeightRuleStorage"] = storage as CKRecordValue

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
        #expect(task.temporalWeightRule == rule)
    }

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
        remoteTask["taskDescription"] = "Prepare oats and fresh fruit." as CKRecordValue
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
        #expect(task.taskDescription == "Prepare oats and fresh fruit.")
        #expect(task.recurrenceTimeRangeRole == .scheduledBlock)
        #expect(task.recurrenceStorageVersion == 1)
        #expect(task.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func cloudKitMerge_prefersStructuredAdvancedHourlyRecurrenceOverCompatibilityColumns() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let calendar = makeTestCalendar()
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .hourly,
            interval: 6,
            startDate: makeDate("2026-07-21T07:00:00Z"),
            hourlyMode: .dailyWindow,
            dailyWindowStart: RoutineTimeOfDay(hour: 7, minute: 0),
            dailyWindowEnd: RoutineTimeOfDay(hour: 22, minute: 0),
            endMode: .afterCount,
            occurrenceCount: 20,
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let recurrenceRule = RoutineRecurrenceRule.advanced(advanced)
        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: taskID.uuidString)
        )
        remoteTask["name"] = "Medicine" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: recurrenceRule.approximateIntervalDays)
        remoteTask["scheduleModeRawValue"] = RoutineScheduleMode.fixedInterval.rawValue as CKRecordValue
        remoteTask["recurrenceStorageVersion"] = NSNumber(value: 1)
        remoteTask["recurrenceKindRawValue"] = recurrenceRule.kind.rawValue as CKRecordValue
        remoteTask["recurrenceTimeOfDayHour"] = NSNumber(value: recurrenceRule.timeOfDay?.hour ?? 0)
        remoteTask["recurrenceTimeOfDayMinute"] = NSNumber(value: recurrenceRule.timeOfDay?.minute ?? 0)
        remoteTask["recurrenceRuleStorage"] = RoutineRecurrenceRuleStorage.serialize(recurrenceRule) as CKRecordValue

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
        #expect(task.recurrenceRule == recurrenceRule)
        #expect(task.recurrenceRule.advanced == advanced.normalized(calendar: calendar))
        #expect(!task.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func cloudKitMerge_preservesStructuredRecurrenceAvailabilityWindowAndRole() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let calendar = makeTestCalendar()
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 18, minute: 0),
            end: RoutineTimeOfDay(hour: 21, minute: 0)
        )
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: 2,
            startDate: makeDate("2026-07-20T09:00:00Z"),
            weekdays: [2, 4],
            timesOfDay: [RoutineTimeOfDay(hour: 9, minute: 0)],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let recurrenceRule = RoutineRecurrenceRule.advanced(
            advanced,
            timeRange: window
        )
        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: taskID.uuidString)
        )
        remoteTask["name"] = "Training" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: recurrenceRule.approximateIntervalDays)
        remoteTask["scheduleModeRawValue"] = RoutineScheduleMode.fixedInterval.rawValue as CKRecordValue
        remoteTask["recurrenceStorageVersion"] = NSNumber(value: 1)
        remoteTask["recurrenceKindRawValue"] = recurrenceRule.kind.rawValue as CKRecordValue
        remoteTask["recurrenceTimeRangeStartHour"] = NSNumber(value: window.start.hour)
        remoteTask["recurrenceTimeRangeStartMinute"] = NSNumber(value: window.start.minute)
        remoteTask["recurrenceTimeRangeEndHour"] = NSNumber(value: window.end.hour)
        remoteTask["recurrenceTimeRangeEndMinute"] = NSNumber(value: window.end.minute)
        remoteTask["recurrenceTimeRangeRoleRawValue"] = RoutineTimeRangeRole.scheduledBlock.rawValue as CKRecordValue
        remoteTask["recurrenceRuleStorage"] = RoutineRecurrenceRuleStorage.serialize(recurrenceRule) as CKRecordValue

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
        #expect(task.recurrenceRule == recurrenceRule)
        #expect(task.recurrenceRule.advanced == advanced.normalized(calendar: calendar))
        #expect(task.recurrenceRule.timeRange == window)
        #expect(task.recurrenceTimeRangeRole == .scheduledBlock)
        #expect(!task.recurrenceRuleStorage.isEmpty)
    }

    @Test
    func cloudKitMerge_prefersStructuredMonthlyOrdinalRecurrenceOverCompatibilityColumns() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let calendar = makeTestCalendar()
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .monthly,
            interval: 2,
            startDate: makeDate("2026-07-21T09:00:00Z"),
            monthlyPattern: .ordinalWeekday,
            weekdayOrdinal: .first,
            ordinalWeekday: 6,
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let recurrenceRule = RoutineRecurrenceRule.advanced(advanced)
        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: taskID.uuidString)
        )
        remoteTask["name"] = "Review" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: recurrenceRule.approximateIntervalDays)
        remoteTask["scheduleModeRawValue"] = RoutineScheduleMode.fixedInterval.rawValue as CKRecordValue
        remoteTask["recurrenceStorageVersion"] = NSNumber(value: 1)
        remoteTask["recurrenceKindRawValue"] = recurrenceRule.kind.rawValue as CKRecordValue
        remoteTask["recurrenceDayOfMonth"] = NSNumber(value: recurrenceRule.dayOfMonth ?? 1)
        remoteTask["recurrenceTimeOfDayHour"] = NSNumber(value: recurrenceRule.timeOfDay?.hour ?? 0)
        remoteTask["recurrenceTimeOfDayMinute"] = NSNumber(value: recurrenceRule.timeOfDay?.minute ?? 0)
        remoteTask["recurrenceRuleStorage"] = RoutineRecurrenceRuleStorage.serialize(recurrenceRule) as CKRecordValue

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
        #expect(task.recurrenceRule == recurrenceRule)
        #expect(task.recurrenceRule.advanced == advanced.normalized(calendar: calendar))
        #expect(!task.recurrenceRuleStorage.isEmpty)
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
