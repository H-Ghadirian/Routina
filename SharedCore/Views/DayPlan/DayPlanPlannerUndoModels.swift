import Foundation

struct DayPlanPlannerUndoSnapshot: Equatable {
    var dayKey: String
    var blocks: [DayPlanBlock]
}

struct DayPlanFocusSessionUndoSnapshot: Equatable {
    var id: UUID
    var startedAt: Date?
    var plannedDurationSeconds: TimeInterval
    var completedAt: Date?
    var abandonedAt: Date?
    var pausedAt: Date?
    var accumulatedPausedSeconds: TimeInterval

    init(session: FocusSession) {
        id = session.id
        startedAt = session.startedAt
        plannedDurationSeconds = session.plannedDurationSeconds
        completedAt = session.completedAt
        abandonedAt = session.abandonedAt
        pausedAt = session.pausedAt
        accumulatedPausedSeconds = session.accumulatedPausedSeconds
    }

    func apply(to session: FocusSession) {
        session.startedAt = startedAt
        session.plannedDurationSeconds = plannedDurationSeconds
        session.completedAt = completedAt
        session.abandonedAt = abandonedAt
        session.pausedAt = pausedAt
        session.accumulatedPausedSeconds = accumulatedPausedSeconds
    }
}

struct DayPlanPlannerUndoSide: Equatable {
    var snapshots: [DayPlanPlannerUndoSnapshot]
    var focusedBlockID: UUID
    var focusedDate: Date
    var focusedStartMinute: Int
    var focusSession: DayPlanFocusSessionUndoSnapshot?
}

struct DayPlanPlannerUndoChange: Equatable {
    var actionName: String
    var undoSide: DayPlanPlannerUndoSide
    var redoSide: DayPlanPlannerUndoSide
}

struct DayPlanPendingResizeUndo {
    var blockID: UUID
    var beforeSide: DayPlanPlannerUndoSide
}

@MainActor
final class DayPlanPlannerUndoTarget: NSObject {
    weak var planner: DayPlanPlannerState?
}
