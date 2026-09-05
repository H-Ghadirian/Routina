import Foundation
import SwiftData
import UserNotifications

extension WatchRoutineSyncBridge {
    nonisolated static func parseIncomingAction(_ payload: [String: Any]) -> IncomingAction {
        let sourceDevice = RoutinaDeviceActivitySource(payload: payload["sourceDevice"] as? [String: Any])

        if let action = payload["action"] as? String,
            action == "markDone",
            let taskIDString = payload["taskID"] as? String,
            let taskID = UUID(uuidString: taskIDString)
        {
            let timestamp = (payload["completedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .markDone(taskID, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String,
            action == "checkInPlace",
            let placeIDString = payload["placeID"] as? String,
            let placeID = UUID(uuidString: placeIDString)
        {
            let timestamp = (payload["checkedInAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .checkInPlace(placeID, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "endPlaceCheckIn" {
            let timestamp = (payload["endedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .endPlaceCheckIn(timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "startSleep" {
            let timestamp = (payload["startedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .startSleep(timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "endSleep" {
            let timestamp = (payload["endedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .endSleep(timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "startUnassignedFocus" {
            let sessionID = (payload["sessionID"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
            let timestamp = (payload["startedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .startUnassignedFocus(sessionID, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "finishFocus" {
            let sessionID = (payload["sessionID"] as? String).flatMap(UUID.init(uuidString:))
            let kind = (payload["focusKind"] as? String).flatMap(FocusSessionKind.init(rawValue:))
            let timestamp = (payload["endedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .finishFocus(sessionID, kind, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "pauseFocus" {
            let sessionID = (payload["sessionID"] as? String).flatMap(UUID.init(uuidString:))
            let kind = (payload["focusKind"] as? String).flatMap(FocusSessionKind.init(rawValue:))
            let timestamp = (payload["pausedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .pauseFocus(sessionID, kind, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "resumeFocus" {
            let sessionID = (payload["sessionID"] as? String).flatMap(UUID.init(uuidString:))
            let kind = (payload["focusKind"] as? String).flatMap(FocusSessionKind.init(rawValue:))
            let timestamp = (payload["resumedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return .resumeFocus(sessionID, kind, timestamp, sourceDevice)
        }

        if let action = payload["action"] as? String, action == "openDeepLink" {
            if let rawURL = payload["url"] as? String,
                let url = URL(string: rawURL),
                let deepLink = RoutinaDeepLink(url: url)
            {
                return .openDeepLink(deepLink, sourceDevice)
            }

            let kind = (payload["focusKind"] as? String) ?? "task"
            let rawTargetID = (payload["targetID"] as? String) ?? (payload["taskID"] as? String)
            guard let rawTargetID, let targetID = UUID(uuidString: rawTargetID) else {
                return .ignore
            }

            if kind == "sprint" {
                return .openDeepLink(.sprint(targetID), sourceDevice)
            }

            return .openDeepLink(.task(targetID), sourceDevice)
        }

        if let action = payload["action"] as? String,
            action == "batteryStatus",
            let kindRawValue = payload["deviceKind"] as? String,
            let kind = BatteryRoutineDeviceKind(rawValue: kindRawValue),
            let levelPercent = payload["levelPercent"] as? Int,
            let isCharging = payload["isCharging"] as? Bool
        {
            let capturedAt =
                (payload["capturedAt"] as? TimeInterval)
                .map(Date.init(timeIntervalSince1970:))
                ?? Date()
            return .batteryStatus(
                BatteryDeviceSnapshot(
                    kind: kind,
                    levelPercent: levelPercent,
                    isCharging: isCharging,
                    capturedAt: capturedAt
                ),
                sourceDevice
            )
        }

        if let requestSync = payload["requestSync"] as? Bool, requestSync {
            return .requestSync(sourceDevice)
        }

        return .ignore
    }

    nonisolated static func canPresentOpenOnPhoneNotification(
        authorizationStatus: UNAuthorizationStatus
    ) -> Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    nonisolated static func openOnPhoneNotificationIdentifier(for deepLink: RoutinaDeepLink) -> String {
        switch deepLink {
        case let .task(taskID):
            return "watch-open-task-\(taskID.uuidString)"
        case let .goal(goalID):
            return "watch-open-goal-\(goalID.uuidString)"
        case let .note(noteID):
            return "watch-open-note-\(noteID.uuidString)"
        case let .event(eventID):
            return "watch-open-event-\(eventID.uuidString)"
        case let .sprint(sprintID):
            return "watch-open-sprint-\(sprintID.uuidString)"
        case let .sleep(sleepID):
            return "watch-open-sleep-\(sleepID.uuidString)"
        }
    }

    nonisolated static func openOnPhoneNotificationTitle(for deepLink: RoutinaDeepLink) -> String {
        switch deepLink {
        case .task:
            return "Open task timer on iPhone"
        case .goal:
            return "Open goal on iPhone"
        case .note:
            return "Open note on iPhone"
        case .event:
            return "Open event on iPhone"
        case .sprint:
            return "Open sprint timer on iPhone"
        case .sleep:
            return "Open sleep on iPhone"
        }
    }

    @MainActor
    static func placesPayload(
        from places: [RoutinePlace],
        sessions: [PlaceCheckInSession]
    ) -> [[String: Any]] {
        PlaceCheckInSupport.suggestedPlaces(
            places: places,
            sessions: sessions,
            limit: 8
        )
        .map { place in
            [
                "id": place.id.uuidString,
                "name": place.displayName,
            ]
        }
    }

    static func placeCheckInPayload(
        from sessions: [PlaceCheckInSession],
        referenceDate: Date
    ) -> [String: Any] {
        guard
            let active =
                sessions
                .filter({ $0.endedAt == nil })
                .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
                .first,
            let startedAt = active.startedAt
        else {
            return ["isActive": false]
        }

        var payload: [String: Any] = [
            "isActive": true,
            "sessionID": active.id.uuidString,
            "placeName": active.displayPlaceName,
            "startedAt": startedAt.timeIntervalSince1970,
            "lastUpdated": referenceDate.timeIntervalSince1970,
        ]
        payload["placeID"] = active.placeID?.uuidString
        payload["activity"] = active.activity?.rawValue
        return payload
    }

    static func sleepPayload(
        from sessions: [SleepSession],
        referenceDate: Date
    ) -> [String: Any] {
        guard
            let active =
                sessions
                .filter({ $0.endedAt == nil })
                .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
                .first,
            let startedAt = active.startedAt
        else {
            return ["isActive": false]
        }

        var payload: [String: Any] = [
            "isActive": true,
            "sessionID": active.id.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
            "targetDurationMinutes": active.targetDurationMinutes,
            "lastUpdated": referenceDate.timeIntervalSince1970,
        ]
        payload["targetWakeAt"] = active.targetWakeAt?.timeIntervalSince1970
        return payload
    }

    @MainActor
    static func focusPayload(
        from taskFocus: FocusTimerWidgetData,
        context: ModelContext,
        referenceDate: Date
    ) throws -> [String: Any] {
        let taskPayload = taskFocusPayload(from: taskFocus)
        let sprintPayload = try sprintFocusPayload(in: context, referenceDate: referenceDate)

        switch (taskPayload, sprintPayload) {
        case let (.some(task), .some(sprint)):
            return payloadStartedAt(task) >= payloadStartedAt(sprint) ? task : sprint
        case let (.some(task), nil):
            return task
        case let (nil, .some(sprint)):
            return sprint
        case (nil, nil):
            return ["isActive": false]
        }
    }

    nonisolated private static func taskFocusPayload(from focus: FocusTimerWidgetData) -> [String: Any]? {
        guard focus.isActive, let sessionID = focus.sessionID, let startedAt = focus.startedAt else {
            return nil
        }

        var payload: [String: Any] = [
            "isActive": true,
            "sessionID": sessionID.uuidString,
            "focusKind": focus.taskID == nil ? "unassigned" : "task",
            "taskName": focus.taskName,
            "taskEmoji": focus.taskEmoji,
            "startedAt": startedAt.timeIntervalSince1970,
            "plannedDurationSeconds": focus.plannedDurationSeconds,
            "accumulatedPausedSeconds": focus.accumulatedPausedSeconds,
        ]
        payload["pausedAt"] = focus.pausedAt?.timeIntervalSince1970
        if let taskID = focus.taskID {
            payload["targetID"] = taskID.uuidString
            payload["taskID"] = taskID.uuidString
        }
        return payload
    }

    @MainActor
    private static func sprintFocusPayload(in context: ModelContext, referenceDate: Date) throws -> [String: Any]? {
        let sessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        guard
            let session =
                sessions
                .filter({ $0.stoppedAt == nil })
                .sorted(by: { $0.startedAt > $1.startedAt })
                .first
        else {
            return nil
        }

        let sprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let title =
            sprints
            .first { $0.id == session.sprintID }?
            .title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = title.map { $0.isEmpty ? "Sprint focus" : $0 } ?? "Sprint focus"

        var payload: [String: Any] = [
            "isActive": true,
            "sessionID": session.id.uuidString,
            "focusKind": "sprint",
            "targetID": session.sprintID.uuidString,
            "sprintID": session.sprintID.uuidString,
            "taskName": displayTitle,
            "taskEmoji": "🏁",
            "startedAt": session.startedAt.timeIntervalSince1970,
            "plannedDurationSeconds": 0,
            "accumulatedPausedSeconds": session.accumulatedPausedSeconds,
            "lastUpdated": referenceDate.timeIntervalSince1970,
        ]
        payload["pausedAt"] = session.pausedAt?.timeIntervalSince1970
        return payload
    }

    nonisolated private static func payloadStartedAt(_ payload: [String: Any]) -> TimeInterval {
        payload["startedAt"] as? TimeInterval ?? .leastNonzeroMagnitude
    }
}
