import Combine
import Foundation
import SwiftData

@MainActor
final class RoutinaMacFocusTimerStatusStore: ObservableObject {
    @Published private(set) var status: RoutinaMacFocusTimerStatus = .inactive

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
        refresh()
    }

    var statusUpdates: Published<RoutinaMacFocusTimerStatus>.Publisher {
        $status
    }

    func refresh() {
        do {
            let context = persistence.container.mainContext
            let refreshedStatus = try Self.activeStatus(in: context)
            if refreshedStatus != status {
                status = refreshedStatus
            }
            FocusShieldSupport.syncFocusShield(using: context)
        } catch {
            if status != .inactive {
                status = .inactive
            }
            FocusShieldSupport.syncFocusShield(using: persistence.container.mainContext)
            NSLog("RoutinaMacFocusTimerStatusStore: failed to refresh focus timer status: \(error)")
        }
    }

    private static func activeStatus(in context: ModelContext) throws -> RoutinaMacFocusTimerStatus {
        let taskStatus = try activeTaskStatus(in: context)
        let sprintStatus = try activeSprintStatus(in: context)

        switch (taskStatus, sprintStatus) {
        case let (.some(task), .some(sprint)):
            return task.startedAt >= sprint.startedAt ? task : sprint
        case let (.some(task), nil):
            return task
        case let (nil, .some(sprint)):
            return sprint
        case (nil, nil):
            return .inactive
        }
    }

    private static func activeTaskStatus(in context: ModelContext) throws -> RoutinaMacFocusTimerStatus? {
        let activeSessionPredicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        var sessionDescriptor = FetchDescriptor<FocusSession>(
            predicate: activeSessionPredicate,
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        sessionDescriptor.fetchLimit = 1

        guard let session = try context.fetch(sessionDescriptor).first,
              let startedAt = session.startedAt else {
            return nil
        }

        let taskID = session.taskID
        var taskDescriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        taskDescriptor.fetchLimit = 1
        let task = try context.fetch(taskDescriptor).first

        return RoutinaMacFocusTimerStatus(
            id: session.id,
            targetID: session.taskID,
            kind: .task,
            title: normalizedTitle(task?.name, fallback: "Task focus"),
            startedAt: startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds
        )
    }

    private static func activeSprintStatus(in context: ModelContext) throws -> RoutinaMacFocusTimerStatus? {
        var sessionDescriptor = FetchDescriptor<SprintFocusSessionRecord>(
            predicate: #Predicate { session in
                session.stoppedAt == nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        sessionDescriptor.fetchLimit = 1

        guard let session = try context.fetch(sessionDescriptor).first else {
            return nil
        }

        let sprintID = session.sprintID
        var sprintDescriptor = FetchDescriptor<BoardSprintRecord>(
            predicate: #Predicate { sprint in
                sprint.id == sprintID
            }
        )
        sprintDescriptor.fetchLimit = 1
        let sprint = try context.fetch(sprintDescriptor).first

        return RoutinaMacFocusTimerStatus(
            id: session.id,
            targetID: session.sprintID,
            kind: .sprint,
            title: normalizedTitle(sprint?.title, fallback: "Sprint focus"),
            startedAt: session.startedAt,
            plannedDurationSeconds: 0
        )
    }

    private static func normalizedTitle(_ title: String?, fallback: String) -> String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? fallback : trimmedTitle
    }
}

struct RoutinaMacFocusTimerStatus: Equatable {
    enum Kind: Equatable {
        case task
        case sprint

        var systemImage: String {
            switch self {
            case .task:
                return "timer"
            case .sprint:
                return "flag.checkered"
            }
        }

        var displayTitle: String {
            switch self {
            case .task:
                return "Task Focus"
            case .sprint:
                return "Sprint Focus"
            }
        }
    }

    var id: UUID?
    var targetID: UUID?
    var kind: Kind?
    var title: String
    var startedAt: Date
    var plannedDurationSeconds: TimeInterval

    var isActive: Bool {
        id != nil && kind != nil
    }

    var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    static let inactive = RoutinaMacFocusTimerStatus(
        id: nil,
        targetID: nil,
        kind: nil,
        title: "No focus timer",
        startedAt: .distantPast,
        plannedDurationSeconds: 0
    )

    func displaySeconds(at date: Date) -> TimeInterval {
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        guard !isCountUp else { return elapsed }
        return max(0, plannedDurationSeconds - elapsed)
    }

    func menuBarTimeText(at date: Date) -> String {
        if overtimeSeconds(at: date) > 0 {
            return "+\(FocusSessionFormatting.durationText(seconds: overtimeSeconds(at: date)))"
        }
        return FocusSessionFormatting.durationText(seconds: displaySeconds(at: date))
    }

    func menuBarModeText(at date: Date) -> String {
        if overtimeSeconds(at: date) > 0 {
            return "overtime"
        }
        return isCountUp ? "elapsed" : "remaining"
    }

    private func overtimeSeconds(at date: Date) -> TimeInterval {
        guard !isCountUp else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        return max(0, elapsed - plannedDurationSeconds)
    }

    var shortTitle: String {
        guard title.count > 30 else { return title }
        return String(title.prefix(27)) + "..."
    }

    var deepLink: RoutinaDeepLink? {
        guard let targetID, let kind else { return nil }
        switch kind {
        case .task:
            return .task(targetID)
        case .sprint:
            return .sprint(targetID)
        }
    }
}
