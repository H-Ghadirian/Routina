import Foundation
import SwiftData

enum FocusSessionSupport {
    @MainActor
    static func startUnassignedFocus(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        plannedDurationSeconds: TimeInterval = 0,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> FocusSession {
        if let existing = try focusSession(id: id, in: context) {
            return existing
        }

        guard try SleepSessionSupport.activeSession(in: context) == nil else {
            throw RoutinaQuickAddError.activeSleepSession
        }
        guard try AwaySessionSupport.activeSession(in: context) == nil else {
            throw RoutinaQuickAddError.activeAwaySession
        }
        guard try activeTaskFocus(in: context) == nil else {
            throw RoutinaQuickAddError.activeFocusSession(nil)
        }
        guard try activeSprintFocus(in: context) == nil else {
            throw RoutinaQuickAddError.activeFocusSession(nil)
        }

        let session = FocusSession(
            id: id,
            taskID: FocusSession.unassignedTaskID,
            startedAt: startedAt,
            plannedDurationSeconds: max(0, plannedDurationSeconds)
        )
        context.insert(session)
        DeviceActivityRecorder.recordAction(
            .started,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: "Unassigned focus",
            sourceDevice: sourceDevice,
            at: startedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return session
    }

    @MainActor
    @discardableResult
    static func finishFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        endedAt: Date = Date(),
        context: ModelContext,
        calendar: Calendar = .current,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        switch kind {
        case .sprint:
            return try finishSprintFocus(sessionID: sessionID, endedAt: endedAt, context: context, sourceDevice: sourceDevice)
        case .task, .unassigned, nil:
            if try finishTaskFocus(
                sessionID: sessionID,
                kind: kind,
                endedAt: endedAt,
                context: context,
                calendar: calendar,
                sourceDevice: sourceDevice
            ) {
                return true
            }

            guard kind == nil else { return false }
            return try finishSprintFocus(sessionID: sessionID, endedAt: endedAt, context: context, sourceDevice: sourceDevice)
        }
    }

    @MainActor
    @discardableResult
    static func pauseFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        pausedAt: Date = Date(),
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        guard kind != .sprint,
              let session = try activeTaskFocus(sessionID: sessionID, kind: kind, in: context),
              session.pause(at: pausedAt) else {
            return false
        }

        let title = try taskTitle(for: session, in: context) ?? "Unassigned focus"
        DeviceActivityRecorder.recordAction(
            .paused,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: title,
            details: "Paused focus session",
            sourceDevice: sourceDevice,
            at: pausedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    @discardableResult
    static func resumeFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        resumedAt: Date = Date(),
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        guard kind != .sprint,
              let session = try activeTaskFocus(sessionID: sessionID, kind: kind, in: context),
              session.resume(at: resumedAt) else {
            return false
        }

        let title = try taskTitle(for: session, in: context) ?? "Unassigned focus"
        DeviceActivityRecorder.recordAction(
            .resumed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: title,
            details: "Resumed focus session",
            sourceDevice: sourceDevice,
            at: resumedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    @discardableResult
    static func assignUnassignedFocus(
        sessionID: UUID,
        toTask taskID: UUID,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        guard let session = try focusSession(id: sessionID, in: context),
              session.isUnassigned,
              session.state == .completed,
              let task = try task(id: taskID, in: context) else {
            return false
        }

        session.taskID = task.id
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            details: "Assigned unassigned focus to task",
            sourceDevice: sourceDevice,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    @discardableResult
    static func assignUnassignedFocusToSprint(
        sessionID: UUID,
        sprintID: UUID,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        guard let session = try focusSession(id: sessionID, in: context),
              session.isUnassigned,
              session.state == .completed,
              let startedAt = session.startedAt,
              let endedAt = session.completedAt,
              let sprint = try sprint(id: sprintID, in: context) else {
            return false
        }

        context.insert(
            SprintFocusSessionRecord(
                id: session.id,
                sprintID: sprint.id,
                startedAt: startedAt,
                stoppedAt: endedAt
            )
        )
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: sprint.title,
            details: "Assigned unassigned focus to board",
            sourceDevice: sourceDevice,
            in: context
        )
        context.delete(session)
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    static func unassignedCompletedSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions
            .filter { $0.isUnassigned && $0.state == .completed }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    @MainActor
    private static func finishTaskFocus(
        sessionID: UUID?,
        kind: FocusSessionKind?,
        endedAt: Date,
        context: ModelContext,
        calendar: Calendar,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws -> Bool {
        guard let session = try activeTaskFocus(sessionID: sessionID, kind: kind, in: context) else {
            return false
        }

        session.closePauseIfNeeded(at: endedAt)
        session.completedAt = endedAt
        if !session.isUnassigned,
           session.plannedDurationSeconds <= 0,
           let task = try task(id: session.taskID, in: context) {
            DayPlanFocusSessionPlannerSync.saveEndedCountUpFocusBlock(
                for: task,
                session: session,
                endedAt: endedAt,
                calendar: calendar,
                context: context
            )
        }

        let title = try taskTitle(for: session, in: context) ?? "Unassigned focus"
        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: title,
            sourceDevice: sourceDevice,
            at: endedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    private static func finishSprintFocus(
        sessionID: UUID?,
        endedAt: Date,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource?
    ) throws -> Bool {
        guard let session = try activeSprintFocus(sessionID: sessionID, in: context) else {
            return false
        }

        session.stoppedAt = endedAt
        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: try sprint(id: session.sprintID, in: context)?.title ?? "Sprint focus",
            sourceDevice: sourceDevice,
            at: endedAt,
            in: context
        )
        try context.save()
        notifyFocusChanged(using: context)
        return true
    }

    @MainActor
    private static func activeTaskFocus(
        sessionID: UUID? = nil,
        kind: FocusSessionKind? = nil,
        in context: ModelContext
    ) throws -> FocusSession? {
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        return sessions
            .filter { session in
                session.state == .active && (sessionID == nil || session.id == sessionID)
            }
            .filter { session in
                switch kind {
                case .task:
                    return !session.isUnassigned
                case .unassigned:
                    return session.isUnassigned
                case .sprint, nil:
                    return true
                }
            }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
            .first
    }

    @MainActor
    private static func activeSprintFocus(sessionID: UUID? = nil, in context: ModelContext) throws -> SprintFocusSessionRecord? {
        let sessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        return sessions
            .filter { session in
                session.stoppedAt == nil && (sessionID == nil || session.id == sessionID)
            }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    @MainActor
    private static func focusSession(id: UUID, in context: ModelContext) throws -> FocusSession? {
        var descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private static func task(id: UUID, in context: ModelContext) throws -> RoutineTask? {
        guard id != FocusSession.unassignedTaskID else { return nil }
        var descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private static func sprint(id: UUID, in context: ModelContext) throws -> BoardSprintRecord? {
        var descriptor = FetchDescriptor<BoardSprintRecord>(
            predicate: #Predicate { sprint in
                sprint.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private static func taskTitle(for session: FocusSession, in context: ModelContext) throws -> String? {
        guard !session.isUnassigned,
              let task = try task(id: session.taskID, in: context) else {
            return nil
        }
        return RoutineTask.trimmedName(task.name) ?? "Untitled task"
    }

    @MainActor
    private static func notifyFocusChanged(using context: ModelContext) {
        #if (os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)) || os(macOS)
        FocusShieldSupport.syncFocusShield(using: context)
        #endif
        FocusTimerWidgetService.refreshAndReload(using: context)
        NotificationCenter.default.postRoutineDidUpdate()
        #if os(iOS) && canImport(ActivityKit)
        Task { @MainActor in
            await FocusTimerLiveActivityService.sync(using: PersistenceController.shared.container.mainContext)
        }
        #endif
    }
}

enum FocusSessionKind: String, Equatable, Sendable {
    case task
    case sprint
    case unassigned
}
