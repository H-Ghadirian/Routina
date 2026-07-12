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
        log.taskID = payload.taskID
        log.kind = payload.kind
        log.actualDurationMinutes = payload.actualDurationMinutes
        log.sourceTaskID = payload.sourceTaskID
    }

    static func makeLog(from payload: CloudKitDirectPullService.LogPayload) -> RoutineLog {
        RoutineLog(
            id: payload.id,
            timestamp: payload.timestamp,
            taskID: payload.taskID,
            kind: payload.kind,
            actualDurationMinutes: payload.actualDurationMinutes,
            sourceTaskID: payload.sourceTaskID
        )
    }
}
