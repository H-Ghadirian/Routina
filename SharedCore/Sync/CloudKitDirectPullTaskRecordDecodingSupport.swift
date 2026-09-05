import CloudKit
import Foundation

extension CloudKitDirectPullTaskRecordParser {
    static func isTaskRecordType(_ recordType: String) -> Bool {
        CloudKitDirectPullService.isTaskRecordType(recordType)
    }

    static func stringValue(in record: CKRecord, keys: [String]) -> String? {
        CloudKitDirectPullService.stringValue(in: record, keys: keys)
    }

    static func dataValue(in record: CKRecord, keys: [String]) -> Data? {
        CloudKitDirectPullService.dataValue(in: record, keys: keys)
    }

    static func intValue(in record: CKRecord, keys: [String]) -> Int? {
        CloudKitDirectPullService.intValue(in: record, keys: keys)
    }

    static func boolValue(in record: CKRecord, keys: [String]) -> Bool? {
        CloudKitDirectPullService.boolValue(in: record, keys: keys)
    }

    static func doubleValue(in record: CKRecord, keys: [String]) -> Double? {
        CloudKitDirectPullService.doubleValue(in: record, keys: keys)
    }

    static func dateValue(in record: CKRecord, keys: [String]) -> Date? {
        CloudKitDirectPullService.dateValue(in: record, keys: keys)
    }

    static func uuidValue(in record: CKRecord, keys: [String]) -> UUID? {
        CloudKitDirectPullService.uuidValue(in: record, keys: keys)
    }

    static func storageKeys(_ property: String) -> [String] {
        [
            property,
            property.lowercased(),
            property.uppercased(),
            "z\(property.lowercased())",
            "Z\(property.uppercased())",
            "cd_\(property.lowercased())",
        ]
    }

    static func recurrenceRuleFromColumns(
        storageVersion: Int?,
        kindRawValue: String?,
        interval: Int?,
        timeOfDayHour: Int?,
        timeOfDayMinute: Int?,
        timeRangeStartHour: Int?,
        timeRangeStartMinute: Int?,
        timeRangeEndHour: Int?,
        timeRangeEndMinute: Int?,
        weekday: Int?,
        dayOfMonth: Int?
    ) -> RoutineRecurrenceRule? {
        guard
            storageVersion != nil
                || kindRawValue != nil
                || timeOfDayHour != nil
                || timeOfDayMinute != nil
                || timeRangeStartHour != nil
                || timeRangeStartMinute != nil
                || timeRangeEndHour != nil
                || timeRangeEndMinute != nil
                || weekday != nil
                || dayOfMonth != nil
        else {
            return nil
        }

        let kind = kindRawValue.flatMap(RoutineRecurrenceRule.Kind.init(rawValue:)) ?? .intervalDays
        let exactTime = timeOfDay(hour: timeOfDayHour, minute: timeOfDayMinute)
        let range = timeRange(
            startHour: timeRangeStartHour,
            startMinute: timeRangeStartMinute,
            endHour: timeRangeEndHour,
            endMinute: timeRangeEndMinute
        )

        switch kind {
        case .intervalDays:
            return .interval(
                days: max(interval ?? 1, 1),
                at: exactTime,
                timeRange: range
            )
        case .dailyTime:
            return RoutineRecurrenceRule(
                kind: .dailyTime,
                timeOfDay: exactTime,
                timeRange: range
            )
        case .weekly:
            return .weekly(
                on: weekday ?? Calendar.current.firstWeekday,
                at: exactTime,
                timeRange: range
            )
        case .monthlyDay:
            return .monthly(
                on: dayOfMonth ?? Calendar.current.component(.day, from: Date()),
                at: exactTime,
                timeRange: range
            )
        }
    }

    static func timeOfDay(hour: Int?, minute: Int?) -> RoutineTimeOfDay? {
        guard let hour, let minute else { return nil }
        return RoutineTimeOfDay(hour: hour, minute: minute)
    }

    static func timeRange(
        startHour: Int?,
        startMinute: Int?,
        endHour: Int?,
        endMinute: Int?
    ) -> RoutineTimeRange? {
        guard let start = timeOfDay(hour: startHour, minute: startMinute),
            let end = timeOfDay(hour: endHour, minute: endMinute)
        else {
            return nil
        }
        return RoutineTimeRange(start: start, end: end)
    }
}
