import Foundation

enum FocusStatsSessionCanonicalization {
    static func canonicalSessions(
        taskSessions: [FocusSession],
        sprintSessions: [SprintFocusSessionRecord]
    ) -> (taskSessions: [FocusSession], sprintSessions: [SprintFocusSessionRecord]) {
        let canonicalSprintSessions = canonicalSprintSessions(sprintSessions)
        let sprintSessionIDs = Set(canonicalSprintSessions.map(\.id))
        let canonicalTaskSessions = canonicalTaskSessions(taskSessions).filter {
            // Assigning unassigned focus to a board keeps the session ID while
            // replacing the task-backed row. During sync convergence both rows
            // can briefly exist, and the board row is the accepted record.
            !sprintSessionIDs.contains($0.id)
        }
        return (canonicalTaskSessions, canonicalSprintSessions)
    }

    static func canonicalTaskSessions(_ sessions: [FocusSession]) -> [FocusSession] {
        let uniqueIDs = preferredTaskSessions(
            sessions,
            keyedBy: { .storageID($0.id) }
        )
        return preferredTaskSessions(uniqueIDs) { session in
            guard let startedAt = session.startedAt else {
                return .storageID(session.id)
            }
            return .semantic(
                taskID: session.taskID,
                normalizedTag: session.focusTagName.flatMap(RoutineTag.normalized),
                startedAt: startedAt
            )
        }
    }

    static func canonicalSprintSessions(
        _ sessions: [SprintFocusSessionRecord]
    ) -> [SprintFocusSessionRecord] {
        let uniqueIDs = preferredSprintSessions(
            sessions,
            keyedBy: { .storageID($0.id) }
        )
        return preferredSprintSessions(uniqueIDs) { session in
            .semantic(sprintID: session.sprintID, startedAt: session.startedAt)
        }
    }

    private static func preferredTaskSessions(
        _ sessions: [FocusSession],
        keyedBy key: (FocusSession) -> TaskSessionKey
    ) -> [FocusSession] {
        var keyOrder: [TaskSessionKey] = []
        var preferredByKey: [TaskSessionKey: FocusSession] = [:]

        for session in sessions {
            let sessionKey = key(session)
            if let current = preferredByKey[sessionKey] {
                if taskSession(session, isPreferredOver: current) {
                    preferredByKey[sessionKey] = session
                }
            } else {
                keyOrder.append(sessionKey)
                preferredByKey[sessionKey] = session
            }
        }

        return keyOrder.compactMap { preferredByKey[$0] }
    }

    private static func preferredSprintSessions(
        _ sessions: [SprintFocusSessionRecord],
        keyedBy key: (SprintFocusSessionRecord) -> SprintSessionKey
    ) -> [SprintFocusSessionRecord] {
        var keyOrder: [SprintSessionKey] = []
        var preferredByKey: [SprintSessionKey: SprintFocusSessionRecord] = [:]

        for session in sessions {
            let sessionKey = key(session)
            if let current = preferredByKey[sessionKey] {
                if sprintSession(session, isPreferredOver: current) {
                    preferredByKey[sessionKey] = session
                }
            } else {
                keyOrder.append(sessionKey)
                preferredByKey[sessionKey] = session
            }
        }

        return keyOrder.compactMap { preferredByKey[$0] }
    }

    private static func taskSession(
        _ candidate: FocusSession,
        isPreferredOver current: FocusSession
    ) -> Bool {
        let candidateActivity = latestActivityDate(for: candidate)
        let currentActivity = latestActivityDate(for: current)
        if candidateActivity != currentActivity {
            return candidateActivity > currentActivity
        }

        let candidateStateRank = stateRank(candidate.state)
        let currentStateRank = stateRank(current.state)
        if candidateStateRank != currentStateRank {
            return candidateStateRank > currentStateRank
        }
        if candidate.accumulatedPausedSeconds != current.accumulatedPausedSeconds {
            return candidate.accumulatedPausedSeconds > current.accumulatedPausedSeconds
        }
        return candidate.id.uuidString > current.id.uuidString
    }

    private static func sprintSession(
        _ candidate: SprintFocusSessionRecord,
        isPreferredOver current: SprintFocusSessionRecord
    ) -> Bool {
        let candidateActivity = candidate.stoppedAt ?? candidate.pausedAt ?? candidate.startedAt
        let currentActivity = current.stoppedAt ?? current.pausedAt ?? current.startedAt
        if candidateActivity != currentActivity {
            return candidateActivity > currentActivity
        }
        if (candidate.stoppedAt != nil) != (current.stoppedAt != nil) {
            return candidate.stoppedAt != nil
        }
        if candidate.accumulatedPausedSeconds != current.accumulatedPausedSeconds {
            return candidate.accumulatedPausedSeconds > current.accumulatedPausedSeconds
        }
        return candidate.id.uuidString > current.id.uuidString
    }

    private static func latestActivityDate(for session: FocusSession) -> Date {
        [session.completedAt, session.abandonedAt, session.pausedAt, session.startedAt]
            .compactMap { $0 }
            .max() ?? .distantPast
    }

    private static func stateRank(_ state: FocusSessionState) -> Int {
        switch state {
        case .completed:
            return 2
        case .abandoned:
            return 1
        case .active:
            return 0
        }
    }

    private enum TaskSessionKey: Hashable {
        case storageID(UUID)
        case semantic(taskID: UUID, normalizedTag: String?, startedAt: Date)
    }

    private enum SprintSessionKey: Hashable {
        case storageID(UUID)
        case semantic(sprintID: UUID, startedAt: Date)
    }
}
