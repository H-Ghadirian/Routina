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
            status = try Self.activeStatus(in: persistence.container.mainContext)
        } catch {
            status = .inactive
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
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        guard let session = sessions
            .filter({ $0.state == .active && $0.startedAt != nil })
            .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
            .first,
            let startedAt = session.startedAt
        else {
            return nil
        }

        return RoutinaMacFocusTimerStatus(
            id: session.id,
            kind: .task,
            title: normalizedTitle(tasks.first { $0.id == session.taskID }?.name, fallback: "Task focus"),
            startedAt: startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds
        )
    }

    private static func activeSprintStatus(in context: ModelContext) throws -> RoutinaMacFocusTimerStatus? {
        let sprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let sessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        guard let session = sessions
            .filter({ $0.stoppedAt == nil })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first
        else {
            return nil
        }

        return RoutinaMacFocusTimerStatus(
            id: session.id,
            kind: .sprint,
            title: normalizedTitle(sprints.first { $0.id == session.sprintID }?.title, fallback: "Sprint focus"),
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
}
