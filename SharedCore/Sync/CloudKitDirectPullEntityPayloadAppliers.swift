import Foundation

enum CloudKitDirectPullGoalPayloadApplier {
    static func apply(
        _ payload: CloudKitDirectPullService.GoalPayload,
        to goal: RoutineGoal
    ) {
        goal.title = RoutineGoal.cleanedTitle(payload.title) ?? goal.displayTitle
        goal.emoji = RoutineGoal.cleanedEmoji(payload.emoji)
        goal.notes = payload.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.targetDate = payload.targetDate
        if let tags = payload.tags {
            goal.tags = tags
        }
        if let status = payload.status {
            goal.status = status
        }
        if let color = payload.color {
            goal.color = color
        }
        goal.parentGoalID = payload.parentGoalID == payload.id ? nil : payload.parentGoalID
        if let rejectedTaskSuggestionIDs = payload.rejectedTaskSuggestionIDs {
            goal.rejectedTaskSuggestionIDs = rejectedTaskSuggestionIDs
        }
        if let createdAt = payload.createdAt {
            goal.createdAt = createdAt
        }
        if let sortOrder = payload.sortOrder {
            goal.sortOrder = sortOrder
        }
    }

    static func makeGoal(from payload: CloudKitDirectPullService.GoalPayload) -> RoutineGoal {
        RoutineGoal(
            id: payload.id,
            title: RoutineGoal.cleanedTitle(payload.title) ?? "Goal",
            emoji: payload.emoji,
            notes: payload.notes,
            targetDate: payload.targetDate,
            tags: payload.tags ?? [],
            status: payload.status ?? .active,
            color: payload.color ?? .none,
            parentGoalID: payload.parentGoalID == payload.id ? nil : payload.parentGoalID,
            rejectedTaskSuggestionIDs: payload.rejectedTaskSuggestionIDs ?? [],
            createdAt: payload.createdAt ?? Date(),
            sortOrder: payload.sortOrder ?? 0
        )
    }
}

enum CloudKitDirectPullPlacePayloadApplier {
    static func apply(
        _ payload: CloudKitDirectPullService.PlacePayload,
        to place: RoutinePlace,
        updatesName: Bool
    ) {
        if updatesName {
            place.name = RoutinePlace.cleanedName(payload.name) ?? place.displayName
        }
        place.kind = RoutinePlace.cleanedKind(payload.kind)
        place.latitude = payload.latitude
        place.longitude = payload.longitude
        place.radiusMeters = max(payload.radiusMeters, 25)
        if let createdAt = payload.createdAt {
            place.createdAt = createdAt
        }
    }

    static func makePlace(from payload: CloudKitDirectPullService.PlacePayload) -> RoutinePlace {
        RoutinePlace(
            id: payload.id,
            name: RoutinePlace.cleanedName(payload.name) ?? "Place",
            latitude: payload.latitude,
            longitude: payload.longitude,
            radiusMeters: payload.radiusMeters,
            kind: payload.kind,
            createdAt: payload.createdAt ?? Date()
        )
    }
}

enum CloudKitDirectPullLogPayloadApplier {
    static func apply(
        _ payload: CloudKitDirectPullService.LogPayload,
        to log: RoutineLog
    ) {
        log.timestamp = payload.timestamp
        log.scheduledOccurrenceAt = payload.scheduledOccurrenceAt
        log.taskID = payload.taskID
        log.kind = payload.kind
        log.actualDurationMinutes = payload.actualDurationMinutes
        log.hasSpecificWorkTime = payload.hasSpecificWorkTime
        log.sourceTaskID = payload.sourceTaskID
    }

    static func makeLog(from payload: CloudKitDirectPullService.LogPayload) -> RoutineLog {
        RoutineLog(
            id: payload.id,
            timestamp: payload.timestamp,
            scheduledOccurrenceAt: payload.scheduledOccurrenceAt,
            taskID: payload.taskID,
            kind: payload.kind,
            actualDurationMinutes: payload.actualDurationMinutes,
            hasSpecificWorkTime: payload.hasSpecificWorkTime,
            sourceTaskID: payload.sourceTaskID
        )
    }
}

enum CloudKitDirectPullFocusSessionPayloadApplier {
    static func apply(
        _ payload: CloudKitDirectPullService.FocusSessionPayload,
        to session: FocusSession
    ) {
        session.taskID = payload.taskID
        if let startedAt = payload.startedAt {
            session.startedAt = startedAt
        }
        if let plannedDurationSeconds = payload.plannedDurationSeconds {
            session.plannedDurationSeconds = max(0, plannedDurationSeconds)
        }
        if let accumulatedPausedSeconds = payload.accumulatedPausedSeconds {
            session.accumulatedPausedSeconds = max(0, accumulatedPausedSeconds)
        }
        if let tagName = payload.tagName {
            session.tagName = RoutineTag.cleaned(tagName)
        }

        if let completedAt = payload.completedAt {
            session.completedAt = completedAt
            session.abandonedAt = nil
            session.pausedAt = nil
            return
        }

        if let abandonedAt = payload.abandonedAt {
            session.abandonedAt = abandonedAt
            session.completedAt = nil
            session.pausedAt = nil
            return
        }

        // A finished session never becomes active again. A delayed direct pull
        // can still contain the start record after this device has received the
        // terminal state through normal CloudKit mirroring.
        guard session.state == .active else { return }
        session.pausedAt = payload.pausedAt
    }

    static func makeFocusSession(
        from payload: CloudKitDirectPullService.FocusSessionPayload
    ) -> FocusSession {
        FocusSession(
            id: payload.id,
            taskID: payload.taskID,
            startedAt: payload.startedAt,
            plannedDurationSeconds: max(0, payload.plannedDurationSeconds ?? 0),
            completedAt: payload.completedAt,
            abandonedAt: payload.abandonedAt,
            pausedAt: payload.completedAt == nil && payload.abandonedAt == nil ? payload.pausedAt : nil,
            accumulatedPausedSeconds: max(0, payload.accumulatedPausedSeconds ?? 0),
            tagName: payload.tagName
        )
    }
}

enum CloudKitDirectPullSprintFocusSessionPayloadApplier {
    static func apply(
        _ payload: CloudKitDirectPullService.SprintFocusSessionPayload,
        to session: SprintFocusSessionRecord
    ) {
        session.sprintID = payload.sprintID
        if let startedAt = payload.startedAt {
            session.startedAt = startedAt
        }
        if let accumulatedPausedSeconds = payload.accumulatedPausedSeconds {
            session.accumulatedPausedSeconds = max(0, accumulatedPausedSeconds)
        }

        if let stoppedAt = payload.stoppedAt {
            session.stoppedAt = stoppedAt
            session.pausedAt = nil
            return
        }

        // A delayed active record must not reopen a focus session that already
        // stopped on this device.
        guard session.stoppedAt == nil else { return }
        session.pausedAt = payload.pausedAt
    }

    static func makeSprintFocusSession(
        from payload: CloudKitDirectPullService.SprintFocusSessionPayload
    ) -> SprintFocusSessionRecord {
        SprintFocusSessionRecord(
            id: payload.id,
            sprintID: payload.sprintID,
            startedAt: payload.startedAt ?? Date(),
            stoppedAt: payload.stoppedAt,
            pausedAt: payload.stoppedAt == nil ? payload.pausedAt : nil,
            accumulatedPausedSeconds: max(0, payload.accumulatedPausedSeconds ?? 0)
        )
    }
}
