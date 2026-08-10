import Foundation
import SwiftData

@Model
final class RoutineLog {
    var id: UUID = UUID()
    var timestamp: Date?
    var scheduledOccurrenceAt: Date?
    var taskID: UUID = UUID()
    var kindRawValue: String = RoutineLogKind.completed.rawValue
    var actualDurationMinutes: Int?
    var hasSpecificWorkTime: Bool?
    var sourceTaskID: UUID?
    var isConfirmedAssumedDone: Bool = false

    var kind: RoutineLogKind {
        get { RoutineLogKind(rawValue: kindRawValue) ?? .completed }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date? = nil,
        scheduledOccurrenceAt: Date? = nil,
        taskID: UUID,
        kind: RoutineLogKind = .completed,
        actualDurationMinutes: Int? = nil,
        hasSpecificWorkTime: Bool? = nil,
        sourceTaskID: UUID? = nil,
        isConfirmedAssumedDone: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.scheduledOccurrenceAt = scheduledOccurrenceAt
        self.taskID = taskID
        self.kindRawValue = kind.rawValue
        self.actualDurationMinutes = RoutineLog.sanitizedActualDurationMinutes(actualDurationMinutes)
        self.hasSpecificWorkTime = hasSpecificWorkTime
        self.sourceTaskID = sourceTaskID
        self.isConfirmedAssumedDone = isConfirmedAssumedDone
    }

    func detachedCopy() -> RoutineLog {
        RoutineLog(
            id: id,
            timestamp: timestamp,
            scheduledOccurrenceAt: scheduledOccurrenceAt,
            taskID: taskID,
            kind: kind,
            actualDurationMinutes: actualDurationMinutes,
            hasSpecificWorkTime: hasSpecificWorkTime,
            sourceTaskID: sourceTaskID,
            isConfirmedAssumedDone: isConfirmedAssumedDone
        )
    }

    static func sanitizedActualDurationMinutes(_ value: Int?) -> Int? {
        RoutineModelValueSanitizer.sanitizedPositiveInteger(value)
    }
}

extension RoutineLog: Equatable {
    static func == (lhs: RoutineLog, rhs: RoutineLog) -> Bool {
        lhs.id == rhs.id
    }
}
