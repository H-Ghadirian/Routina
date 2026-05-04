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

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
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

    init(
        id: UUID = UUID(),
        sprintID: UUID,
        startedAt: Date = Date(),
        stoppedAt: Date? = nil
    ) {
        self.id = id
        self.sprintID = sprintID
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
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
