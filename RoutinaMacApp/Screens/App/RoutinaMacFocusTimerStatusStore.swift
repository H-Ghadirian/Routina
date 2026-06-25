import Combine
import Foundation
import SwiftData

@MainActor
final class RoutinaMacFocusTimerStatusStore: ObservableObject {
    @Published private(set) var status: RoutinaMacFocusTimerStatus = .inactive

    private let persistence: PersistenceController
    private var scheduledRefreshTask: Task<Void, Never>?

    init(persistence: PersistenceController) {
        self.persistence = persistence
        refresh()
    }

    var statusUpdates: Published<RoutinaMacFocusTimerStatus>.Publisher {
        $status
    }

    @discardableResult
    func togglePauseResume(
        for status: RoutinaMacFocusTimerStatus,
        at date: Date = Date()
    ) throws -> Bool {
        guard status.supportsPauseResume,
              let sessionID = status.id else {
            return false
        }

        let context = persistence.container.mainContext
        let didChange: Bool
        if status.isPaused {
            didChange = try FocusSessionSupport.resumeFocus(
                sessionID: sessionID,
                kind: status.focusSessionKind,
                resumedAt: date,
                context: context
            )
        } else {
            didChange = try FocusSessionSupport.pauseFocus(
                sessionID: sessionID,
                kind: status.focusSessionKind,
                pausedAt: date,
                context: context
            )
        }

        if didChange {
            refresh()
        }
        return didChange
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

    func scheduleRefresh(delayNanoseconds: UInt64 = 500_000_000) {
        scheduledRefreshTask?.cancel()
        scheduledRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.refresh()
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

        let task: RoutineTask?
        if !session.isTaskFocus {
            task = nil
        } else {
            let taskID = session.taskID
            var taskDescriptor = FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.id == taskID
                }
            )
            taskDescriptor.fetchLimit = 1
            task = try context.fetch(taskDescriptor).first
        }

        let kind: RoutinaMacFocusTimerStatus.Kind
        let title: String
        let targetID: UUID?
        if let tagTitle = session.focusTagTitle {
            kind = .tag
            title = tagTitle
            targetID = nil
        } else if session.isUnassigned {
            kind = .unassigned
            title = "Unassigned focus"
            targetID = nil
        } else {
            kind = .task
            title = normalizedTitle(task?.name, fallback: "Task focus")
            targetID = session.taskID
        }

        return RoutinaMacFocusTimerStatus(
            id: session.id,
            targetID: targetID,
            kind: kind,
            title: title,
            startedAt: startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds,
            pausedAt: session.pausedAt,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds
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
            plannedDurationSeconds: 0,
            pausedAt: session.pausedAt,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds
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
        case tag
        case sprint
        case unassigned

        var systemImage: String {
            switch self {
            case .task:
                return "timer"
            case .tag:
                return "tag.fill"
            case .sprint:
                return "flag.checkered"
            case .unassigned:
                return "stopwatch"
            }
        }

        var displayTitle: String {
            switch self {
            case .task:
                return "Task Focus"
            case .tag:
                return "Tag Focus"
            case .sprint:
                return "Sprint Focus"
            case .unassigned:
                return "Focus"
            }
        }
    }

    var id: UUID?
    var targetID: UUID?
    var kind: Kind?
    var title: String
    var startedAt: Date
    var plannedDurationSeconds: TimeInterval
    var pausedAt: Date?
    var accumulatedPausedSeconds: TimeInterval

    var isActive: Bool {
        id != nil && kind != nil
    }

    var isPaused: Bool {
        isActive && pausedAt != nil
    }

    var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    var systemImage: String {
        if isPaused {
            return "pause.circle.fill"
        }
        return kind?.systemImage ?? "timer"
    }

    static let inactive = RoutinaMacFocusTimerStatus(
        id: nil,
        targetID: nil,
        kind: nil,
        title: "No focus timer",
        startedAt: .distantPast,
        plannedDurationSeconds: 0,
        pausedAt: nil,
        accumulatedPausedSeconds: 0
    )

    func displaySeconds(at date: Date) -> TimeInterval {
        let elapsed = elapsedSeconds(at: date)
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
        if isPaused {
            return "paused"
        }
        if overtimeSeconds(at: date) > 0 {
            return "overtime"
        }
        return isCountUp ? "elapsed" : "remaining"
    }

    private func overtimeSeconds(at date: Date) -> TimeInterval {
        guard !isCountUp else { return 0 }
        let elapsed = elapsedSeconds(at: date)
        return max(0, elapsed - plannedDurationSeconds)
    }

    private func elapsedSeconds(at date: Date) -> TimeInterval {
        let endDate = pausedAt ?? date
        return max(0, endDate.timeIntervalSince(startedAt) - max(0, accumulatedPausedSeconds))
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
        case .tag:
            return nil
        case .sprint:
            return .sprint(targetID)
        case .unassigned:
            return nil
        }
    }

    var focusSessionKind: FocusSessionKind? {
        switch kind {
        case .task:
            return .task
        case .tag:
            return .tag
        case .sprint:
            return .sprint
        case .unassigned:
            return .unassigned
        case nil:
            return nil
        }
    }

    var supportsPauseResume: Bool {
        switch kind {
        case .task, .tag, .unassigned:
            return true
        case .sprint, nil:
            return false
        }
    }
}
