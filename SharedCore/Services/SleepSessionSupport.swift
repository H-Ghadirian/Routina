import Foundation
import SwiftData

enum SleepSessionSupport {
    @MainActor
    static func activeSession(in context: ModelContext) throws -> SleepSession? {
        var descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate<SleepSession> { session in
                session.endedAt == nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    static func activeFocusTimerWarningMessage(in context: ModelContext) throws -> String? {
        let taskFocusSessions = try activeTaskFocusSessions(in: context)
        let sprintFocusSessions = try activeSprintFocusSessions(in: context)
        let activeFocusCount = taskFocusSessions.count + sprintFocusSessions.count
        guard activeFocusCount > 0 else { return nil }

        if activeFocusCount > 1 {
            return "\(activeFocusCount) focus timers are running. Starting sleep mode will stop them."
        }

        if let taskFocusSession = taskFocusSessions.first,
           let taskName = try activeTaskFocusTitle(for: taskFocusSession, in: context) {
            return "Focus timer for \(taskName) is running. Starting sleep mode will stop it."
        }

        if let sprintFocusSession = sprintFocusSessions.first,
           let sprintTitle = try activeSprintFocusTitle(for: sprintFocusSession, in: context) {
            return "Sprint focus timer for \(sprintTitle) is running. Starting sleep mode will stop it."
        }

        return "A focus timer is running. Starting sleep mode will stop it."
    }

    @discardableResult
    @MainActor
    static func startSleep(
        in context: ModelContext,
        at startedAt: Date = Date()
    ) throws -> SleepSession {
        let stoppedFocusTimers = try stopActiveFocusTimers(in: context, at: startedAt)
        if let activeSession = try activeSession(in: context) {
            if stoppedFocusTimers {
                try context.save()
                syncFocusTimerSurfaces()
                NotificationCenter.default.postRoutineDidUpdate()
            }
            return activeSession
        }

        let session = SleepSession(startedAt: startedAt)
        context.insert(session)
        try context.save()
        if stoppedFocusTimers {
            syncFocusTimerSurfaces()
        }
        NotificationCenter.default.postRoutineDidUpdate()
        return session
    }

    @discardableResult
    @MainActor
    static func endActiveSleep(
        in context: ModelContext,
        at endedAt: Date = Date()
    ) throws -> SleepSession? {
        guard let activeSession = try activeSession(in: context) else {
            return nil
        }

        activeSession.end(at: endedAt)
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return activeSession
    }

    @MainActor
    static func delete(
        _ session: SleepSession,
        in context: ModelContext
    ) throws {
        context.delete(session)
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
    }

    @MainActor
    private static func stopActiveFocusTimers(
        in context: ModelContext,
        at stoppedAt: Date
    ) throws -> Bool {
        var didStopFocusTimer = false
        for session in try activeTaskFocusSessions(in: context) {
            session.abandonedAt = stoppedAt
            didStopFocusTimer = true
        }

        for session in try activeSprintFocusSessions(in: context) {
            session.stoppedAt = stoppedAt
            didStopFocusTimer = true
        }

        return didStopFocusTimer
    }

    @MainActor
    private static func activeTaskFocusSessions(in context: ModelContext) throws -> [FocusSession] {
        let activeTaskFocusPredicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        return try context.fetch(
            FetchDescriptor<FocusSession>(predicate: activeTaskFocusPredicate)
        )
    }

    @MainActor
    private static func activeSprintFocusSessions(in context: ModelContext) throws -> [SprintFocusSessionRecord] {
        let activeSprintFocusPredicate = #Predicate<SprintFocusSessionRecord> { session in
            session.stoppedAt == nil
        }
        return try context.fetch(
            FetchDescriptor<SprintFocusSessionRecord>(predicate: activeSprintFocusPredicate)
        )
    }

    @MainActor
    private static func activeTaskFocusTitle(
        for session: FocusSession,
        in context: ModelContext
    ) throws -> String? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let title = RoutineTask.trimmedName(
            tasks.first { $0.id == session.taskID }?.name
        )
        return title?.isEmpty == false ? title : "Untitled task"
    }

    @MainActor
    private static func activeSprintFocusTitle(
        for session: SprintFocusSessionRecord,
        in context: ModelContext
    ) throws -> String? {
        let sprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let title = sprints
            .first { $0.id == session.sprintID }?
            .title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title?.isEmpty == false ? title : nil
    }

    private static func syncFocusTimerSurfaces() {
        #if os(iOS) && canImport(ActivityKit)
        Task { @MainActor in
            await FocusTimerLiveActivityService.sync(
                using: PersistenceController.shared.container.mainContext
            )
        }
        #endif
    }
}
