import Foundation
import SwiftData

@Model
final class BoardSprintRecord {
    var id: UUID = UUID()
    var title: String = ""
    var statusRawValue: String = SprintStatus.planned.rawValue
    var createdAt: Date = Date()
    var startedAt: Date?
    var finishedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        status: SprintStatus = .planned,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}

extension BoardSprintRecord: Identifiable, Equatable {
    static func == (lhs: BoardSprintRecord, rhs: BoardSprintRecord) -> Bool {
        lhs.id == rhs.id
    }
}

@Model
final class SprintAssignmentRecord {
    var todoID: UUID = UUID()
    var sprintID: UUID = UUID()
    var sortOrder: Int = 0

    init(todoID: UUID, sprintID: UUID, sortOrder: Int = 0) {
        self.todoID = todoID
        self.sprintID = sprintID
        self.sortOrder = sortOrder
    }
}

@Model
final class BoardBacklogRecord {
    var id: UUID = UUID()
    var title: String = ""
    var createdAt: Date = Date()
    var routingTagsStorage: String = ""

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        routingTags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.routingTagsStorage = RoutineTag.serialize(routingTags)
    }

    var routingTags: [String] {
        get { RoutineTag.deserialize(routingTagsStorage) }
        set { routingTagsStorage = RoutineTag.serialize(newValue) }
    }
}

@Model
final class BacklogAssignmentRecord {
    var todoID: UUID = UUID()
    var backlogID: UUID = UUID()
    var sortOrder: Int = 0

    init(todoID: UUID, backlogID: UUID, sortOrder: Int = 0) {
        self.todoID = todoID
        self.backlogID = backlogID
        self.sortOrder = sortOrder
    }
}

@Model
final class SprintFocusSessionRecord {
    var id: UUID = UUID()
    var sprintID: UUID = UUID()
    var startedAt: Date = Date()
    var stoppedAt: Date?
    var pausedAt: Date?
    var accumulatedPausedSeconds: TimeInterval = 0

    init(
        id: UUID = UUID(),
        sprintID: UUID,
        startedAt: Date = Date(),
        stoppedAt: Date? = nil,
        pausedAt: Date? = nil,
        accumulatedPausedSeconds: TimeInterval = 0
    ) {
        self.id = id
        self.sprintID = sprintID
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = max(0, accumulatedPausedSeconds)
    }
}

extension SprintFocusSessionRecord: Identifiable, Equatable {
    static func == (lhs: SprintFocusSessionRecord, rhs: SprintFocusSessionRecord) -> Bool {
        lhs.id == rhs.id
    }

    var isActive: Bool {
        stoppedAt == nil
    }

    var isPaused: Bool {
        isActive && pausedAt != nil
    }

    func activeDurationSeconds(at date: Date = Date()) -> TimeInterval {
        let endDate = stoppedAt ?? pausedAt ?? date
        var pausedSeconds = max(0, accumulatedPausedSeconds)
        if let pausedAt,
           let stoppedAt,
           stoppedAt > pausedAt {
            pausedSeconds += stoppedAt.timeIntervalSince(pausedAt)
        }
        return max(0, endDate.timeIntervalSince(startedAt) - pausedSeconds)
    }

    @discardableResult
    func pause(at date: Date = Date()) -> Bool {
        guard isActive, pausedAt == nil else { return false }
        pausedAt = max(date, startedAt)
        return true
    }

    @discardableResult
    func resume(at date: Date = Date()) -> Bool {
        guard isActive, let pausedAt else { return false }
        let resumedAt = max(date, pausedAt)
        accumulatedPausedSeconds = max(0, accumulatedPausedSeconds) + resumedAt.timeIntervalSince(pausedAt)
        self.pausedAt = nil
        return true
    }

    func closePauseIfNeeded(at date: Date = Date()) {
        _ = resume(at: date)
    }
}

@Model
final class SprintFocusAllocationRecord {
    var id: UUID = UUID()
    var sessionID: UUID = UUID()
    var taskID: UUID = UUID()
    var minutes: Int = 0
    var sortOrder: Int = 0

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        taskID: UUID,
        minutes: Int,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.sessionID = sessionID
        self.taskID = taskID
        self.minutes = max(0, minutes)
        self.sortOrder = sortOrder
    }
}
