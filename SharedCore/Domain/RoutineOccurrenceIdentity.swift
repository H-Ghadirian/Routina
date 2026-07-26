import Foundation

/// The persisted `RoutineLog.timestamp` is the occurrence identity for schedules
/// that can produce more than one occurrence per calendar day. Older and
/// single-occurrence schedules intentionally retain calendar-day identity.
enum RoutineOccurrenceIdentity {
    static let timestampTolerance: TimeInterval = 1

    static func isTimestampScoped(for task: RoutineTask) -> Bool {
        !task.usesEffectiveRoutineCadence || task.recurrenceRule.occursMoreThanOncePerDay
    }

    static func matches(
        _ lhs: Date?,
        _ rhs: Date,
        for task: RoutineTask,
        calendar: Calendar = .current
    ) -> Bool {
        guard let lhs else { return false }
        return matches(lhs, rhs, timestampScoped: isTimestampScoped(for: task), calendar: calendar)
    }

    static func matches(
        _ lhs: Date,
        _ rhs: Date,
        timestampScoped: Bool,
        calendar: Calendar = .current
    ) -> Bool {
        if timestampScoped {
            return abs(lhs.timeIntervalSince(rhs)) < timestampTolerance
        }
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func contains(
        _ dates: Set<Date>,
        occurrence: Date,
        for task: RoutineTask,
        calendar: Calendar = .current
    ) -> Bool {
        dates.contains {
            matches($0, occurrence, for: task, calendar: calendar)
        }
    }
}
