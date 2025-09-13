import Foundation
import SwiftData

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var tagsStorage: String = ""
    var interval: Int16 = 1
    var lastDone: Date?
    var scheduleAnchor: Date?
    var pausedAt: Date?

    var isPaused: Bool {
        pausedAt != nil
    }

    var tags: [String] {
        get { RoutineTag.deserialize(tagsStorage) }
        set { tagsStorage = RoutineTag.serialize(newValue) }
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        emoji: String? = nil,
        tags: [String] = [],
        interval: Int16 = 1,
        lastDone: Date? = nil,
        scheduleAnchor: Date? = nil,
        pausedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.tagsStorage = RoutineTag.serialize(tags)
        self.interval = interval
        self.lastDone = lastDone
        self.scheduleAnchor = scheduleAnchor ?? lastDone
        self.pausedAt = pausedAt
    }
}

@Model
final class RoutineLog {
    var id: UUID = UUID()
    var timestamp: Date?
    var taskID: UUID = UUID()

    init(
        id: UUID = UUID(),
        timestamp: Date? = nil,
        taskID: UUID
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
    }
}

extension RoutineTask: Equatable {
    static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.id == rhs.id
    }
}

extension RoutineLog: Equatable {
    static func == (lhs: RoutineLog, rhs: RoutineLog) -> Bool {
        lhs.id == rhs.id
    }
}
