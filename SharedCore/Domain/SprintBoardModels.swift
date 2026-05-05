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

struct BoardBacklog: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var routingTags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        routingTags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.routingTags = RoutineTag.deduplicated(routingTags)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case routingTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        routingTags = RoutineTag.deduplicated(
            try container.decodeIfPresent([String].self, forKey: .routingTags) ?? []
        )
    }
}

struct SprintAssignment: Codable, Equatable, Sendable {
    var todoID: UUID
    var sprintID: UUID
}

struct SprintFocusAllocation: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var taskID: UUID
    var minutes: Int

    init(
        id: UUID = UUID(),
        taskID: UUID,
        minutes: Int
    ) {
        self.id = id
        self.taskID = taskID
        self.minutes = max(0, minutes)
    }
}

struct SprintFocusSession: Codable, Equatable, Sendable, Identifiable {
    var id: UUID
    var sprintID: UUID
    var startedAt: Date
    var stoppedAt: Date?
    var allocations: [SprintFocusAllocation]

    init(
        id: UUID = UUID(),
        sprintID: UUID,
        startedAt: Date = Date(),
        stoppedAt: Date? = nil,
        allocations: [SprintFocusAllocation] = []
    ) {
        self.id = id
        self.sprintID = sprintID
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.allocations = allocations
    }

    var isActive: Bool {
        stoppedAt == nil
    }

    var durationSeconds: TimeInterval {
        let endDate = stoppedAt ?? Date()
        return max(0, endDate.timeIntervalSince(startedAt))
    }

    var roundedDurationMinutes: Int {
        max(1, Int((durationSeconds / 60).rounded()))
    }

    var allocatedMinutes: Int {
        allocations.reduce(0) { $0 + max(0, $1.minutes) }
    }
}

struct BacklogAssignment: Codable, Equatable, Sendable {
    var todoID: UUID
    var backlogID: UUID
}

struct SprintBoardData: Codable, Equatable, Sendable {
    var sprints: [BoardSprint] = []
    var assignments: [SprintAssignment] = []
    var backlogs: [BoardBacklog] = []
    var backlogAssignments: [BacklogAssignment] = []
    var focusSessions: [SprintFocusSession] = []

    var activeSprints: [BoardSprint] {
        sprints.filter { $0.status == .active }
    }

    var activeSprint: BoardSprint? {
        activeSprints.first
    }

    func sprintID(for todoID: UUID) -> UUID? {
        assignments.last(where: { $0.todoID == todoID })?.sprintID
    }

    func sprint(for todoID: UUID) -> BoardSprint? {
        guard let sprintID = sprintID(for: todoID) else { return nil }
        return sprints.first(where: { $0.id == sprintID })
    }

    func backlogID(for todoID: UUID) -> UUID? {
        backlogAssignments.last(where: { $0.todoID == todoID })?.backlogID
    }

    func backlog(for todoID: UUID) -> BoardBacklog? {
        guard let backlogID = backlogID(for: todoID) else { return nil }
        return backlogs.first(where: { $0.id == backlogID })
    }

    var activeFocusSession: SprintFocusSession? {
        focusSessions.first(where: \.isActive)
    }

    func focusSessions(for sprintID: UUID) -> [SprintFocusSession] {
        focusSessions
            .filter { $0.sprintID == sprintID }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private enum CodingKeys: String, CodingKey {
        case sprints
        case assignments
        case backlogs
        case backlogAssignments
        case focusSessions
    }

    init(
        sprints: [BoardSprint] = [],
        assignments: [SprintAssignment] = [],
        backlogs: [BoardBacklog] = [],
        backlogAssignments: [BacklogAssignment] = [],
        focusSessions: [SprintFocusSession] = []
    ) {
        self.sprints = sprints
        self.assignments = assignments
        self.backlogs = backlogs
        self.backlogAssignments = backlogAssignments
        self.focusSessions = focusSessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sprints = try container.decodeIfPresent([BoardSprint].self, forKey: .sprints) ?? []
        assignments = try container.decodeIfPresent([SprintAssignment].self, forKey: .assignments) ?? []
        backlogs = try container.decodeIfPresent([BoardBacklog].self, forKey: .backlogs) ?? []
        backlogAssignments = try container.decodeIfPresent([BacklogAssignment].self, forKey: .backlogAssignments) ?? []
        focusSessions = try container.decodeIfPresent([SprintFocusSession].self, forKey: .focusSessions) ?? []
    }
}
