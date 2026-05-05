import Foundation
import SwiftData

struct SprintBoardClient: Sendable {
    var load: @Sendable () async throws -> SprintBoardData
    var save: @Sendable (SprintBoardData) async throws -> Void
}

extension SprintBoardClient {
    static let live = SprintBoardClient(
        load: {
            try await MainActor.run {
                try loadLiveSnapshot()
            }
        },
        save: { sprintBoardData in
            try await MainActor.run {
                try saveLiveSnapshot(sprintBoardData)
            }
        }
    )

    static let noop = SprintBoardClient(
        load: { SprintBoardData() },
        save: { _ in }
    )

    @MainActor
    static func loadLiveSnapshot() throws -> SprintBoardData {
        let context = PersistenceController.shared.container.mainContext
        let data = try loadSwiftDataSnapshot(in: context)
        if !data.isEmpty {
            try removeLegacyJSONSnapshot()
            return data
        }

        guard let legacyData = try loadLegacyJSONSnapshot(), !legacyData.isEmpty else {
            return data
        }

        try saveSwiftDataSnapshot(legacyData, in: context)
        try removeLegacyJSONSnapshot()
        return legacyData
    }

    @MainActor
    static func saveLiveSnapshot(_ sprintBoardData: SprintBoardData) throws {
        let context = PersistenceController.shared.container.mainContext
        try saveSwiftDataSnapshot(sprintBoardData, in: context)
        try removeLegacyJSONSnapshot()
    }

    @MainActor
    private static func loadSwiftDataSnapshot(in context: ModelContext) throws -> SprintBoardData {
        let sprintRecords = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let assignmentRecords = try context.fetch(FetchDescriptor<SprintAssignmentRecord>())
        let backlogRecords = try context.fetch(FetchDescriptor<BoardBacklogRecord>())
        let backlogAssignmentRecords = try context.fetch(FetchDescriptor<BacklogAssignmentRecord>())
        let focusSessionRecords = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        let focusAllocationRecords = try context.fetch(FetchDescriptor<SprintFocusAllocationRecord>())

        let allocationsBySessionID = Dictionary(grouping: focusAllocationRecords, by: \.sessionID)
        let sprints = sprintRecords
            .sorted { $0.createdAt > $1.createdAt }
            .map { record in
                BoardSprint(
                    id: record.id,
                    title: record.title,
                    status: SprintStatus(rawValue: record.statusRawValue) ?? .planned,
                    createdAt: record.createdAt,
                    startedAt: record.startedAt,
                    finishedAt: record.finishedAt
                )
            }
        let assignments = assignmentRecords
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { SprintAssignment(todoID: $0.todoID, sprintID: $0.sprintID) }
        let backlogs = backlogRecords
            .sorted { $0.createdAt > $1.createdAt }
            .map {
                BoardBacklog(
                    id: $0.id,
                    title: $0.title,
                    createdAt: $0.createdAt,
                    routingTags: $0.routingTags
                )
            }
        let backlogAssignments = backlogAssignmentRecords
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { BacklogAssignment(todoID: $0.todoID, backlogID: $0.backlogID) }
        let focusSessions = focusSessionRecords
            .sorted { $0.startedAt > $1.startedAt }
            .map { record in
                let allocations = (allocationsBySessionID[record.id] ?? [])
                    .sorted { $0.sortOrder < $1.sortOrder }
                    .map {
                        SprintFocusAllocation(
                            id: $0.id,
                            taskID: $0.taskID,
                            minutes: $0.minutes
                        )
                    }
                return SprintFocusSession(
                    id: record.id,
                    sprintID: record.sprintID,
                    startedAt: record.startedAt,
                    stoppedAt: record.stoppedAt,
                    allocations: allocations
                )
            }

        return SprintBoardData(
            sprints: sprints,
            assignments: assignments,
            backlogs: backlogs,
            backlogAssignments: backlogAssignments,
            focusSessions: focusSessions
        )
    }

    @MainActor
    private static func saveSwiftDataSnapshot(
        _ sprintBoardData: SprintBoardData,
        in context: ModelContext
    ) throws {
        try deleteExistingBoardRecords(in: context)

        for sprint in sprintBoardData.sprints {
            context.insert(
                BoardSprintRecord(
                    id: sprint.id,
                    title: sprint.title,
                    status: sprint.status,
                    createdAt: sprint.createdAt,
                    startedAt: sprint.startedAt,
                    finishedAt: sprint.finishedAt
                )
            )
        }

        for (index, assignment) in sprintBoardData.assignments.enumerated() {
            context.insert(
                SprintAssignmentRecord(
                    todoID: assignment.todoID,
                    sprintID: assignment.sprintID,
                    sortOrder: index
                )
            )
        }

        for backlog in sprintBoardData.backlogs {
            context.insert(
                BoardBacklogRecord(
                    id: backlog.id,
                    title: backlog.title,
                    createdAt: backlog.createdAt,
                    routingTags: backlog.routingTags
                )
            )
        }

        for (index, assignment) in sprintBoardData.backlogAssignments.enumerated() {
            context.insert(
                BacklogAssignmentRecord(
                    todoID: assignment.todoID,
                    backlogID: assignment.backlogID,
                    sortOrder: index
                )
            )
        }

        for focusSession in sprintBoardData.focusSessions {
            context.insert(
                SprintFocusSessionRecord(
                    id: focusSession.id,
                    sprintID: focusSession.sprintID,
                    startedAt: focusSession.startedAt,
                    stoppedAt: focusSession.stoppedAt
                )
            )

            for (index, allocation) in focusSession.allocations.enumerated() {
                context.insert(
                    SprintFocusAllocationRecord(
                        id: allocation.id,
                        sessionID: focusSession.id,
                        taskID: allocation.taskID,
                        minutes: allocation.minutes,
                        sortOrder: index
                    )
                )
            }
        }

        try context.save()
    }

    @MainActor
    private static func deleteExistingBoardRecords(in context: ModelContext) throws {
        for record in try context.fetch(FetchDescriptor<SprintFocusAllocationRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<SprintFocusSessionRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<BacklogAssignmentRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<BoardBacklogRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<SprintAssignmentRecord>()) {
            context.delete(record)
        }
        for record in try context.fetch(FetchDescriptor<BoardSprintRecord>()) {
            context.delete(record)
        }
    }

    @MainActor
    static func routeNewTodoToMatchingBacklog(_ task: RoutineTask) throws {
        var sprintBoardData = try loadLiveSnapshot()
        guard HomeBoardMutationSupport.assignNewTodoToMatchingBacklog(
            taskID: task.id,
            tags: task.tags,
            isOneOffTask: task.isOneOffTask,
            data: &sprintBoardData
        ) else { return }

        try saveLiveSnapshot(sprintBoardData)
    }

    private static func loadLegacyJSONSnapshot() throws -> SprintBoardData? {
        let url = try sprintBoardStoreURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SprintBoardData.self, from: data)
    }

    private static func removeLegacyJSONSnapshot() throws {
        let url = try sprintBoardStoreURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

private func sprintBoardStoreURL() throws -> URL {
    let applicationSupportDirectory = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let storesDirectory = applicationSupportDirectory.appendingPathComponent("RoutinaData", isDirectory: true)
    return storesDirectory.appendingPathComponent("SprintBoard.json")
}

private extension SprintBoardData {
    var isEmpty: Bool {
        sprints.isEmpty
            && assignments.isEmpty
            && backlogs.isEmpty
            && backlogAssignments.isEmpty
            && focusSessions.isEmpty
    }
}
