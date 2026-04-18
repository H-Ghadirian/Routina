import Foundation

enum SprintStatus: String, Codable, CaseIterable, Equatable, Sendable, Identifiable {
    case planned
    case active
    case finished

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .planned: return "Planned"
        case .active: return "Active"
        case .finished: return "Finished"
        }
    }
}

struct BoardSprint: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var status: SprintStatus
    var createdAt: Date
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
        self.status = status
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    func activeDayCount(relativeTo referenceDate: Date, calendar: Calendar = .current) -> Int? {
        guard let startedAt else { return nil }

        let endDate: Date
        switch status {
        case .planned:
            return nil
        case .active:
            endDate = referenceDate
        case .finished:
            endDate = finishedAt ?? referenceDate
        }

        let startDay = calendar.startOfDay(for: startedAt)
        let endDay = calendar.startOfDay(for: endDate)
        let difference = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(1, difference + 1)
    }
}

struct SprintAssignment: Codable, Equatable, Sendable {
    var todoID: UUID
    var sprintID: UUID
}

struct SprintBoardData: Codable, Equatable, Sendable {
    var sprints: [BoardSprint] = []
    var assignments: [SprintAssignment] = []

    var activeSprint: BoardSprint? {
        sprints.first(where: { $0.status == .active })
    }

    func sprintID(for todoID: UUID) -> UUID? {
        assignments.last(where: { $0.todoID == todoID })?.sprintID
    }

    func sprint(for todoID: UUID) -> BoardSprint? {
        guard let sprintID = sprintID(for: todoID) else { return nil }
        return sprints.first(where: { $0.id == sprintID })
    }
}
