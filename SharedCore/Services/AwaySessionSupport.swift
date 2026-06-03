import Foundation
import SwiftData

enum AwaySessionSupportError: LocalizedError, Equatable {
    case activeSleepSession
    case activeAwaySession
    case activeFocusSession
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .activeSleepSession:
            return "Sleep mode is active. Wake up before starting away time."
        case .activeAwaySession:
            return "An away session is already active."
        case .activeFocusSession:
            return "A focus timer is already active. Finish it before starting away time."
        case .invalidDuration:
            return "Choose an away duration from 1 to 720 minutes."
        }
    }
}

enum AwaySessionSupport {
    @MainActor
    static func activeSession(in context: ModelContext) throws -> AwaySession? {
        var descriptor = FetchDescriptor<AwaySession>(
            predicate: #Predicate<AwaySession> { session in
                session.completedAt == nil && session.endedEarlyAt == nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    static func activeSessions(in context: ModelContext) throws -> [AwaySession] {
        let descriptor = FetchDescriptor<AwaySession>(
            predicate: #Predicate<AwaySession> { session in
                session.completedAt == nil && session.endedEarlyAt == nil
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    @MainActor
    static func startAway(
        id: UUID = UUID(),
        preset: AwaySessionPreset,
        durationMinutes: Int? = nil,
        countsUp: Bool = false,
        title: String? = nil,
        startedAt: Date = Date(),
        context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> AwaySession {
        let plannedDurationSeconds: TimeInterval
        if countsUp {
            plannedDurationSeconds = 0
        } else {
            let durationMinutes = durationMinutes ?? preset.defaultDurationMinutes
            guard (1...720).contains(durationMinutes) else {
                throw AwaySessionSupportError.invalidDuration
            }
            plannedDurationSeconds = TimeInterval(durationMinutes * 60)
        }
        guard plannedDurationSeconds == 0
            || (TimeInterval(60)...TimeInterval(720 * 60)).contains(plannedDurationSeconds)
        else {
            throw AwaySessionSupportError.invalidDuration
        }
        if let existing = try awaySession(id: id, in: context) {
            return existing
        }
        guard try SleepSessionSupport.activeSession(in: context) == nil else {
            throw AwaySessionSupportError.activeSleepSession
        }
        guard try activeSession(in: context) == nil else {
            throw AwaySessionSupportError.activeAwaySession
        }
        guard try !hasActiveFocusSession(in: context) else {
            throw AwaySessionSupportError.activeFocusSession
        }

        let session = AwaySession(
            id: id,
            preset: preset,
            title: title,
            startedAt: startedAt,
            plannedDurationSeconds: plannedDurationSeconds,
            createdAt: startedAt,
            updatedAt: startedAt
        )
        context.insert(session)
        DeviceActivityRecorder.recordAction(
            .started,
            entity: .awaySession,
            entityID: session.id,
            entityTitle: session.displayTitle,
            sourceDevice: sourceDevice,
            at: startedAt,
            in: context
        )
        try context.save()
        notifyAwayChanged(using: context)
        return session
    }

    @discardableResult
    @MainActor
    static func completeActiveAway(
        in context: ModelContext,
        at endedAt: Date = Date(),
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> AwaySession? {
        let sessions = try activeSessions(in: context)
        guard let first = sessions.first else { return nil }

        for session in sessions {
            session.complete(at: endedAt)
            DeviceActivityRecorder.recordAction(
                .completed,
                entity: .awaySession,
                entityID: session.id,
                entityTitle: session.displayTitle,
                sourceDevice: sourceDevice,
                at: session.completedAt ?? endedAt,
                in: context
            )
        }
        try context.save()
        notifyAwayChanged(using: context)
        return first
    }

    @discardableResult
    @MainActor
    static func endActiveAwayEarly(
        in context: ModelContext,
        at endedAt: Date = Date(),
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> AwaySession? {
        let sessions = try activeSessions(in: context)
        guard let first = sessions.first else { return nil }

        for session in sessions {
            let shouldComplete = session.isCountUp || session.isExpired(at: endedAt)
            session.endEarly(at: endedAt)
            DeviceActivityRecorder.recordAction(
                shouldComplete ? .completed : .ended,
                entity: .awaySession,
                entityID: session.id,
                entityTitle: session.displayTitle,
                sourceDevice: sourceDevice,
                at: session.finishedAt ?? endedAt,
                in: context
            )
        }
        try context.save()
        notifyAwayChanged(using: context)
        return first
    }

    @discardableResult
    @MainActor
    static func extendActiveAway(
        byMinutes minutes: Int,
        in context: ModelContext,
        at date: Date = Date(),
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> AwaySession? {
        guard let session = try activeSession(in: context) else { return nil }
        session.extend(byMinutes: minutes, at: date)
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .awaySession,
            entityID: session.id,
            entityTitle: session.displayTitle,
            details: "Extended away session by \(max(1, minutes)) minutes",
            sourceDevice: sourceDevice,
            at: date,
            in: context
        )
        try context.save()
        notifyAwayChanged(using: context)
        return session
    }

    @discardableResult
    @MainActor
    static func completeExpiredSessions(
        in context: ModelContext,
        referenceDate: Date = Date()
    ) throws -> Int {
        let expiredSessions = try activeSessions(in: context).filter { $0.isExpired(at: referenceDate) }
        guard !expiredSessions.isEmpty else { return 0 }

        for session in expiredSessions {
            session.complete(at: referenceDate)
            DeviceActivityRecorder.recordAction(
                .completed,
                entity: .awaySession,
                entityID: session.id,
                entityTitle: session.displayTitle,
                at: session.completedAt ?? referenceDate,
                in: context
            )
        }
        try context.save()
        notifyAwayChanged(using: context)
        return expiredSessions.count
    }

    @MainActor
    static func delete(
        _ session: AwaySession,
        in context: ModelContext
    ) throws {
        DeviceActivityRecorder.recordAction(
            .deleted,
            entity: .awaySession,
            entityID: session.id,
            entityTitle: session.displayTitle,
            in: context
        )
        context.delete(session)
        try context.save()
        notifyAwayChanged(using: context)
    }

    @MainActor
    private static func awaySession(id: UUID, in context: ModelContext) throws -> AwaySession? {
        var descriptor = FetchDescriptor<AwaySession>(
            predicate: #Predicate { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    private static func hasActiveFocusSession(in context: ModelContext) throws -> Bool {
        let taskFocusPredicate = #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        }
        var taskDescriptor = FetchDescriptor<FocusSession>(predicate: taskFocusPredicate)
        taskDescriptor.fetchLimit = 1
        if try !context.fetch(taskDescriptor).isEmpty {
            return true
        }

        let sprintFocusPredicate = #Predicate<SprintFocusSessionRecord> { session in
            session.stoppedAt == nil
        }
        var sprintDescriptor = FetchDescriptor<SprintFocusSessionRecord>(predicate: sprintFocusPredicate)
        sprintDescriptor.fetchLimit = 1
        return try !context.fetch(sprintDescriptor).isEmpty
    }

    @MainActor
    private static func notifyAwayChanged(using context: ModelContext) {
        #if (os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)) || os(macOS)
        FocusShieldSupport.syncFocusShield(using: context)
        #endif
        NotificationCenter.default.postRoutineDidUpdate()
    }
}
