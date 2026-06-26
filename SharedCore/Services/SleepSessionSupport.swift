import Foundation
import SwiftData

enum SleepSessionSupportError: LocalizedError, Equatable {
    case invalidDuration
    case invalidTimeline
    case overlappingProtectedSession

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Choose a sleep duration from 5 minutes to 16 hours."
        case .invalidTimeline:
            return "Choose an end time after the start time."
        case .overlappingProtectedSession:
            return "Sleep cannot overlap Away, Focus, or another Sleep session."
        }
    }
}

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
    static func activeSessions(in context: ModelContext) throws -> [SleepSession] {
        let descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate<SleepSession> { session in
                session.endedAt == nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
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
    static func logSleep(
        id: UUID = UUID(),
        durationMinutes: Int,
        startedAt: Date,
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> SleepSession {
        guard (5...(16 * 60)).contains(durationMinutes) else {
            throw SleepSessionSupportError.invalidDuration
        }
        let endedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
        guard endedAt > startedAt else {
            throw SleepSessionSupportError.invalidTimeline
        }
        if let existing = try sleepSession(id: id, in: context) {
            return existing
        }
        guard try !hasProtectedSessionOverlap(
            startedAt: startedAt,
            endedAt: endedAt,
            in: context
        ) else {
            throw SleepSessionSupportError.overlappingProtectedSession
        }

        let session = SleepSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            targetDurationMinutes: durationMinutes,
            createdAt: Date(),
            updatedAt: Date()
        )
        context.insert(session)
        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .sleepSession,
            entityID: session.id,
            entityTitle: "Sleep",
            details: "Logged sleep session",
            sourceDevice: sourceDevice,
            at: endedAt,
            in: context
        )
        try context.save()
        notifySleepChanged(using: context)
        return session
    }

    @discardableResult
    @MainActor
    static func startSleep(
        in context: ModelContext,
        at startedAt: Date = Date(),
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> SleepSession {
        let stoppedFocusTimers = try stopActiveFocusTimers(in: context, at: startedAt)
        if let activeSession = try activeSession(in: context) {
            if stoppedFocusTimers {
                try context.save()
                syncFocusTimerSurfaces()
                notifySleepChanged(using: context)
            }
            return activeSession
        }

        let session = SleepSession(startedAt: startedAt)
        context.insert(session)
        DeviceActivityRecorder.recordAction(
            .started,
            entity: .sleepSession,
            entityID: session.id,
            entityTitle: "Sleep",
            sourceDevice: sourceDevice,
            at: startedAt,
            in: context
        )
        try context.save()
        if stoppedFocusTimers {
            syncFocusTimerSurfaces()
        }
        notifySleepChanged(using: context)
        return session
    }

    @discardableResult
    @MainActor
    static func endActiveSleep(
        in context: ModelContext,
        at endedAt: Date = Date(),
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> SleepSession? {
        let activeSessions = try activeSessions(in: context)
        guard let activeSession = activeSessions.first else {
            return nil
        }

        for session in activeSessions {
            session.end(at: endedAt)
            DeviceActivityRecorder.recordAction(
                .ended,
                entity: .sleepSession,
                entityID: session.id,
                entityTitle: "Sleep",
                sourceDevice: sourceDevice,
                at: endedAt,
                in: context
            )
        }
        try context.save()
        notifySleepChanged(using: context)
        return activeSession
    }

    @MainActor
    static func delete(
        _ session: SleepSession,
        in context: ModelContext
    ) throws {
        DeviceActivityRecorder.recordAction(
            .deleted,
            entity: .sleepSession,
            entityID: session.id,
            entityTitle: "Sleep",
            in: context
        )
        context.delete(session)
        try context.save()
        notifySleepChanged(using: context)
    }

    @MainActor
    private static func sleepSession(id: UUID, in context: ModelContext) throws -> SleepSession? {
        var descriptor = FetchDescriptor<SleepSession>(
            predicate: #Predicate { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private static func hasProtectedSessionOverlap(
        startedAt: Date,
        endedAt: Date,
        in context: ModelContext
    ) throws -> Bool {
        guard endedAt > startedAt else { return false }

        let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
        if sleepSessions.contains(where: { session in
            guard let sessionStartedAt = session.startedAt else { return false }
            return intervalsOverlap(startedAt, endedAt, sessionStartedAt, session.endedAt ?? .distantFuture)
        }) {
            return true
        }

        let awaySessions = SharedDefaults.app[.appSettingAwayEnabled]
            ? try context.fetch(FetchDescriptor<AwaySession>())
            : []
        if awaySessions.contains(where: { session in
            guard let sessionStartedAt = session.startedAt else { return false }
            let sessionEndedAt = session.finishedAt ?? session.plannedEndAt ?? .distantFuture
            return intervalsOverlap(startedAt, endedAt, sessionStartedAt, sessionEndedAt)
        }) {
            return true
        }

        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        if focusSessions.contains(where: { session in
            guard let sessionStartedAt = session.startedAt,
                  session.abandonedAt == nil
            else { return false }
            return intervalsOverlap(startedAt, endedAt, sessionStartedAt, session.completedAt ?? .distantFuture)
        }) {
            return true
        }

        let sprintFocusSessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        return sprintFocusSessions.contains(where: { session in
            intervalsOverlap(startedAt, endedAt, session.startedAt, session.stoppedAt ?? .distantFuture)
        })
    }

    private static func intervalsOverlap(
        _ lhsStart: Date,
        _ lhsEnd: Date,
        _ rhsStart: Date,
        _ rhsEnd: Date
    ) -> Bool {
        max(lhsStart, rhsStart) < min(lhsEnd, rhsEnd)
    }

    @MainActor
    private static func stopActiveFocusTimers(
        in context: ModelContext,
        at stoppedAt: Date
    ) throws -> Bool {
        var didStopFocusTimer = false
        for session in try activeTaskFocusSessions(in: context) {
            session.closePauseIfNeeded(at: stoppedAt)
            session.abandonedAt = stoppedAt
            DayPlanFocusSessionPlannerSync.removeFocusBlock(
                for: session,
                context: context
            )
            didStopFocusTimer = true
        }

        for session in try activeSprintFocusSessions(in: context) {
            session.closePauseIfNeeded(at: stoppedAt)
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
        if let tagTitle = session.focusTagTitle {
            return tagTitle
        }
        guard session.isTaskFocus else {
            return nil
        }
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

    @MainActor
    private static func notifySleepChanged(using context: ModelContext) {
        #if (os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)) || os(macOS)
        FocusShieldSupport.syncFocusShield(using: context)
        #endif
        NotificationCenter.default.postRoutineDidUpdate()
    }
}
