import Foundation
import SwiftData

@Model
final class RoutineLog {
    var id: UUID = UUID()
    var timestamp: Date?
    var taskID: UUID = UUID()
    var kindRawValue: String = RoutineLogKind.completed.rawValue
    var actualDurationMinutes: Int?

    var kind: RoutineLogKind {
        get { RoutineLogKind(rawValue: kindRawValue) ?? .completed }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date? = nil,
        taskID: UUID,
        kind: RoutineLogKind = .completed,
        actualDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
        self.kindRawValue = kind.rawValue
        self.actualDurationMinutes = RoutineLog.sanitizedActualDurationMinutes(actualDurationMinutes)
    }

    func detachedCopy() -> RoutineLog {
        RoutineLog(
            id: id,
            timestamp: timestamp,
            taskID: taskID,
            kind: kind,
            actualDurationMinutes: actualDurationMinutes
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
