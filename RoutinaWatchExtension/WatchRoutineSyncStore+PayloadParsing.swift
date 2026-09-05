import Foundation

extension WatchRoutineSyncStore {
    nonisolated static func parsePayload(_ payload: [String: Any]) -> [WatchRoutine] {
        guard let rawRoutines = payload["routines"] as? [[String: Any]] else { return [] }

        return rawRoutines.compactMap { raw in
            guard
                let idString = raw["id"] as? String,
                let id = UUID(uuidString: idString)
            else {
                return nil
            }

            let name = ((raw["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let safeName = name.isEmpty ? "Unnamed task" : name
            let emoji = ((raw["emoji"] as? String) ?? "").isEmpty ? "✨" : ((raw["emoji"] as? String) ?? "✨")
            let interval = max((raw["interval"] as? Int) ?? 1, 1)
            let scheduleModeRawValue = (raw["scheduleMode"] as? String) ?? "fixedInterval"
            let isOneOffTask = scheduleModeRawValue == "oneOff"
            let isChecklistDriven = (raw["isChecklistDriven"] as? Bool) ?? false
            let isChecklistCompletionRoutine = (raw["isChecklistCompletionRoutine"] as? Bool) ?? false
            let steps = ((raw["steps"] as? [String]) ?? []).compactMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            let checklistItemCount = max((raw["checklistItemCount"] as? Int) ?? 0, 0)
            let completedChecklistItemCount = max((raw["completedChecklistItemCount"] as? Int) ?? 0, 0)
            let nextPendingChecklistItemTitle = (raw["nextPendingChecklistItemTitle"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let dueDateTimestamp = raw["dueDate"] as? TimeInterval
            let dueDate = dueDateTimestamp.map(Date.init(timeIntervalSince1970:))
            let dueChecklistItemCount = max((raw["dueChecklistItemCount"] as? Int) ?? 0, 0)
            let nextDueChecklistItemTitle = (raw["nextDueChecklistItemTitle"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lastDoneTimestamp = raw["lastDone"] as? TimeInterval
            let lastDone = lastDoneTimestamp.map(Date.init(timeIntervalSince1970:))
            let completedStepCount = max((raw["completedStepCount"] as? Int) ?? 0, 0)

            return WatchRoutine(
                id: id,
                name: safeName,
                emoji: emoji,
                intervalDays: interval,
                isOneOffTask: isOneOffTask,
                isChecklistDriven: isChecklistDriven,
                isChecklistCompletionRoutine: isChecklistCompletionRoutine,
                steps: steps,
                checklistItemCount: checklistItemCount,
                completedChecklistItemCount: min(completedChecklistItemCount, checklistItemCount),
                nextPendingChecklistItemTitle: nextPendingChecklistItemTitle?.isEmpty == true ? nil : nextPendingChecklistItemTitle,
                dueDate: dueDate,
                dueChecklistItemCount: dueChecklistItemCount,
                nextDueChecklistItemTitle: nextDueChecklistItemTitle?.isEmpty == true ? nil : nextDueChecklistItemTitle,
                lastDone: lastDone,
                completedStepCount: min(completedStepCount, steps.count)
            )
        }
    }

    nonisolated static func parsePlacesPayload(_ payload: [String: Any]) -> [WatchPlace] {
        guard let rawPlaces = payload["places"] as? [[String: Any]] else { return [] }

        return rawPlaces.compactMap { raw in
            guard
                let idString = raw["id"] as? String,
                let id = UUID(uuidString: idString)
            else {
                return nil
            }

            let name = ((raw["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return WatchPlace(id: id, name: name.isEmpty ? "Unnamed place" : name)
        }
    }

    nonisolated static func parsePlaceCheckInPayload(_ payload: [String: Any]) -> PlaceCheckInPayloadUpdate {
        guard let rawCheckIn = payload["placeCheckIn"] as? [String: Any] else {
            return PlaceCheckInPayloadUpdate(wasPresent: false, checkIn: nil)
        }

        guard (rawCheckIn["isActive"] as? Bool) == true else {
            return PlaceCheckInPayloadUpdate(wasPresent: true, checkIn: nil)
        }

        guard
            let sessionIDString = rawCheckIn["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let startedAtTimestamp = rawCheckIn["startedAt"] as? TimeInterval
        else {
            return PlaceCheckInPayloadUpdate(wasPresent: true, checkIn: nil)
        }

        let placeName = ((rawCheckIn["placeName"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let placeID = (rawCheckIn["placeID"] as? String).flatMap(UUID.init(uuidString:))
        let activity = (rawCheckIn["activity"] as? String).flatMap(WatchPlaceActivity.init(rawValue:))

        return PlaceCheckInPayloadUpdate(
            wasPresent: true,
            checkIn: WatchPlaceCheckIn(
                id: sessionID,
                placeID: placeID,
                placeName: placeName.isEmpty ? "Current place" : placeName,
                activity: activity,
                startedAt: Date(timeIntervalSince1970: startedAtTimestamp)
            )
        )
    }

    nonisolated static func parseSleepPayload(_ payload: [String: Any]) -> SleepPayloadUpdate {
        guard let rawSleep = payload["sleep"] as? [String: Any] else {
            return SleepPayloadUpdate(wasPresent: false, sleep: nil)
        }

        guard (rawSleep["isActive"] as? Bool) == true else {
            return SleepPayloadUpdate(wasPresent: true, sleep: nil)
        }

        guard
            let sessionIDString = rawSleep["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let startedAtTimestamp = rawSleep["startedAt"] as? TimeInterval
        else {
            return SleepPayloadUpdate(wasPresent: true, sleep: nil)
        }

        let startedAt = Date(timeIntervalSince1970: startedAtTimestamp)
        let targetDurationMinutes = max((rawSleep["targetDurationMinutes"] as? Int) ?? 8 * 60, 1)
        let targetWakeAt =
            (rawSleep["targetWakeAt"] as? TimeInterval)
            .map(Date.init(timeIntervalSince1970:))
            ?? startedAt.addingTimeInterval(TimeInterval(targetDurationMinutes * 60))

        return SleepPayloadUpdate(
            wasPresent: true,
            sleep: WatchSleepSession(
                id: sessionID,
                startedAt: startedAt,
                targetWakeAt: targetWakeAt,
                targetDurationMinutes: targetDurationMinutes
            )
        )
    }

    nonisolated static func parseFocusPayload(_ payload: [String: Any]) -> FocusPayloadUpdate {
        guard let rawFocus = payload["focus"] as? [String: Any] else {
            return FocusPayloadUpdate(wasPresent: false, focus: nil)
        }

        guard (rawFocus["isActive"] as? Bool) == true else {
            return FocusPayloadUpdate(wasPresent: true, focus: nil)
        }

        guard
            let sessionIDString = rawFocus["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionIDString),
            let startedAtTimestamp = rawFocus["startedAt"] as? TimeInterval
        else {
            return FocusPayloadUpdate(wasPresent: true, focus: nil)
        }

        let focusKind = WatchFocusKind(rawValue: (rawFocus["focusKind"] as? String) ?? "") ?? .task
        let taskID = (rawFocus["taskID"] as? String).flatMap(UUID.init(uuidString:))
        let targetID =
            ((rawFocus["targetID"] as? String) ?? (rawFocus["sprintID"] as? String))
            .flatMap(UUID.init(uuidString:))
            ?? taskID

        guard focusKind == .unassigned || targetID != nil else {
            return FocusPayloadUpdate(wasPresent: true, focus: nil)
        }

        let taskName = ((rawFocus["taskName"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let taskEmoji =
            ((rawFocus["taskEmoji"] as? String) ?? "").isEmpty
            ? "🎯"
            : ((rawFocus["taskEmoji"] as? String) ?? "🎯")

        return FocusPayloadUpdate(
            wasPresent: true,
            focus: WatchFocusSession(
                id: sessionID,
                focusKind: focusKind,
                targetID: targetID,
                taskID: taskID,
                taskName: taskName.isEmpty ? "Focus session" : taskName,
                taskEmoji: taskEmoji,
                startedAt: Date(timeIntervalSince1970: startedAtTimestamp),
                plannedDurationSeconds: (rawFocus["plannedDurationSeconds"] as? TimeInterval) ?? 0,
                pausedAt: (rawFocus["pausedAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)),
                accumulatedPausedSeconds: max(0, (rawFocus["accumulatedPausedSeconds"] as? TimeInterval) ?? 0)
            )
        )
    }

}
