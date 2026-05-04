import CloudKit
import Foundation

enum CloudKitDirectPullTaskRecordParser {
    typealias TaskPayload = CloudKitDirectPullService.TaskPayload

    static func parse(from record: CKRecord) -> TaskPayload? {
        guard isTaskRecordType(record.recordType) else { return nil }
        let id = UUID(uuidString: record.recordID.recordName)
        guard let id else { return nil }

        let intervalValue = intValue(in: record, keys: ["interval", "INTERVAL", "zinterval", "ZINTERVAL", "cd_interval"])
        let nameValue = stringValue(in: record, keys: ["name", "NAME", "zname", "ZNAME", "cd_name"])
        let emojiValue = stringValue(in: record, keys: ["emoji", "EMOJI", "zemoji", "ZEMOJI", "cd_emoji"])
        let notesValue = stringValue(in: record, keys: ["notes", "NOTES", "znotes", "ZNOTES", "cd_notes"])
        let linkValue = stringValue(in: record, keys: ["link", "LINK", "zlink", "ZLINK", "cd_link"])
        let deadlineValue = dateValue(in: record, keys: ["deadline", "DEADLINE", "zdeadline", "ZDEADLINE", "cd_deadline"])
        let reminderAtValue = dateValue(in: record, keys: ["reminderAt", "REMINDERAT", "zreminderat", "ZREMINDERAT", "cd_reminderat"])
        let placeIDValue = uuidValue(in: record, keys: ["placeID", "placeId", "PLACEID", "zplaceid", "ZPLACEID", "cd_placeid"])
        let tagsStorageValue = stringValue(in: record, keys: ["tagsStorage", "tagsstorage", "TAGSSTORAGE", "ztagsstorage", "ZTAGSSTORAGE", "cd_tagsstorage"])
        let goalIDsStorageValue = stringValue(
            in: record,
            keys: [
                "goalIDsStorage",
                "goalidsstorage",
                "GOALIDSSTORAGE",
                "zgoalidsstorage",
                "ZGOALIDSSTORAGE",
                "cd_goalidsstorage"
            ]
        )
        let stepsStorageValue = stringValue(
            in: record,
            keys: ["stepsStorage", "stepsstorage", "STEPSSTORAGE", "zstepsstorage", "ZSTEPSSTORAGE", "cd_stepsstorage"]
        )
        let checklistItemsStorageValue = stringValue(
            in: record,
            keys: [
                "checklistItemsStorage",
                "checklistitemsstorage",
                "CHECKLISTITEMSSTORAGE",
                "zchecklistitemsstorage",
                "ZCHECKLISTITEMSSTORAGE",
                "cd_checklistitemsstorage"
            ]
        )
        let scheduleModeValue = stringValue(
            in: record,
            keys: [
                "scheduleModeRawValue",
                "schedulemoderawvalue",
                "SCHEDULEMODERAWVALUE",
                "zschedulemoderawvalue",
                "ZSCHEDULEMODERAWVALUE",
                "cd_schedulemoderawvalue"
            ]
        )
        let recurrenceRuleStorageValue = stringValue(
            in: record,
            keys: [
                "recurrenceRuleStorage",
                "recurrencerulestorage",
                "RECURRENCERULESTORAGE",
                "zrecurrencerulestorage",
                "ZRECURRENCERULESTORAGE",
                "cd_recurrencerulestorage"
            ]
        )
        let imageDataValue = dataValue(
            in: record,
            keys: ["imageData", "IMAGEDATA", "zimagedata", "ZIMAGEDATA", "cd_imagedata"]
        )
        let lastDoneValue = dateValue(in: record, keys: ["lastDone", "LASTDONE", "zlastdone", "ZLASTDONE", "cd_lastdone"])
        let canceledAtValue = dateValue(in: record, keys: ["canceledAt", "CANCELEDAT", "zcanceledat", "ZCANCELEDAT", "cd_canceledat"])
        let scheduleAnchorValue = dateValue(
            in: record,
            keys: ["scheduleAnchor", "SCHEDULEANCHOR", "zscheduleanchor", "ZSCHEDULEANCHOR", "cd_scheduleanchor"]
        )
        let pausedAtValue = dateValue(
            in: record,
            keys: ["pausedAt", "PAUSEDAT", "zpausedat", "ZPAUSEDAT", "cd_pausedat"]
        )
        let snoozedUntilValue = dateValue(
            in: record,
            keys: ["snoozedUntil", "SNOOZEDUNTIL", "zsnoozeduntil", "ZSNOOZEDUNTIL", "cd_snoozeduntil"]
        )
        let pinnedAtValue = dateValue(
            in: record,
            keys: ["pinnedAt", "PINNEDAT", "zpinnedat", "ZPINNEDAT", "cd_pinnedat"]
        )
        let completedStepCountValue = intValue(
            in: record,
            keys: ["completedStepCount", "COMPLETEDSTEPCOUNT", "zcompletedstepcount", "ZCOMPLETEDSTEPCOUNT", "cd_completedstepcount"]
        )
        let sequenceStartedAtValue = dateValue(
            in: record,
            keys: ["sequenceStartedAt", "SEQUENCESTARTEDAT", "zsequencestartedat", "ZSEQUENCESTARTEDAT", "cd_sequencestartedat"]
        )
        let createdAtValue = dateValue(
            in: record,
            keys: ["createdAt", "CREATEDAT", "zcreatedat", "ZCREATEDAT", "cd_createdat"]
        )
        let todoStateRawValueValue = stringValue(
            in: record,
            keys: ["todoStateRawValue", "TODOSTATERAWVALUE", "ztodostaterawvalue", "ZTODOSTATERAWVALUE", "cd_todostaterawvalue"]
        )
        let activityStateRawValueValue = stringValue(
            in: record,
            keys: ["activityStateRawValue", "ACTIVITYSTATERAWVALUE", "zactivitystaterawvalue", "ZACTIVITYSTATERAWVALUE", "cd_activitystaterawvalue"]
        )
        let ongoingSinceValue = dateValue(
            in: record,
            keys: ["ongoingSince", "ONGOINGSINCE", "zongoingsince", "ZONGOINGSINCE", "cd_ongoingsince"]
        )
        let autoAssumeDailyDoneValue = boolValue(
            in: record,
            keys: [
                "autoAssumeDailyDone",
                "AUTOASSUMEDAILYDONE",
                "zautoassumedailydone",
                "ZAUTOASSUMEDAILYDONE",
                "cd_autoassumedailydone"
            ]
        )
        let estimatedDurationMinutesValue = intValue(
            in: record,
            keys: [
                "estimatedDurationMinutes",
                "ESTIMATEDDURATIONMINUTES",
                "zestimateddurationminutes",
                "ZESTIMATEDDURATIONMINUTES",
                "cd_estimateddurationminutes"
            ]
        )
        let actualDurationMinutesValue = intValue(
            in: record,
            keys: [
                "actualDurationMinutes",
                "ACTUALDURATIONMINUTES",
                "zactualdurationminutes",
                "ZACTUALDURATIONMINUTES",
                "cd_actualdurationminutes"
            ]
        )
        let storyPointsValue = intValue(
            in: record,
            keys: [
                "storyPoints",
                "STORYPOINTS",
                "zstorypoints",
                "ZSTORYPOINTS",
                "cd_storypoints"
            ]
        )
        let pressureValue = stringValue(
            in: record,
            keys: ["pressureRawValue", "PRESSURERAWVALUE", "zpressurerawvalue", "ZPRESSURERAWVALUE", "cd_pressurerawvalue"]
        ).flatMap(RoutineTaskPressure.init(rawValue:))
        let pressureUpdatedAtValue = dateValue(
            in: record,
            keys: ["pressureUpdatedAt", "PRESSUREUPDATEDAT", "zpressureupdatedat", "ZPRESSUREUPDATEDAT", "cd_pressureupdatedat"]
        )

        guard
            intervalValue != nil
                || nameValue != nil
                || emojiValue != nil
                || notesValue != nil
                || linkValue != nil
                || deadlineValue != nil
                || placeIDValue != nil
                || tagsStorageValue != nil
                || goalIDsStorageValue != nil
                || stepsStorageValue != nil
                || checklistItemsStorageValue != nil
                || imageDataValue != nil
                || scheduleModeValue != nil
                || recurrenceRuleStorageValue != nil
                || lastDoneValue != nil
                || canceledAtValue != nil
                || scheduleAnchorValue != nil
                || pausedAtValue != nil
                || snoozedUntilValue != nil
                || pinnedAtValue != nil
                || completedStepCountValue != nil
                || sequenceStartedAtValue != nil
                || activityStateRawValueValue != nil
                || ongoingSinceValue != nil
                || pressureValue != nil
                || pressureUpdatedAtValue != nil
                || estimatedDurationMinutesValue != nil
                || actualDurationMinutesValue != nil
                || storyPointsValue != nil
                || autoAssumeDailyDoneValue != nil
        else {
            return nil
        }

        let stepsValue: [RoutineStep]?
        if let stepsStorageValue {
            let data = Data(stepsStorageValue.utf8)
            stepsValue = (try? JSONDecoder().decode([RoutineStep].self, from: data)).map(RoutineStep.sanitized)
        } else {
            stepsValue = nil
        }

        let checklistItemsValue: [RoutineChecklistItem]?
        if let checklistItemsStorageValue {
            let data = Data(checklistItemsStorageValue.utf8)
            checklistItemsValue = (try? JSONDecoder().decode([RoutineChecklistItem].self, from: data)).map(RoutineChecklistItem.sanitized)
        } else {
            checklistItemsValue = nil
        }

        return TaskPayload(
            id: id,
            name: nameValue,
            emoji: emojiValue,
            notes: notesValue,
            link: linkValue,
            deadline: deadlineValue,
            reminderAt: reminderAtValue,
            placeID: placeIDValue,
            tags: tagsStorageValue.map(RoutineTag.deserialize),
            goalIDs: goalIDsStorageValue.map(RoutineGoalIDStorage.deserialize),
            steps: stepsValue,
            checklistItems: checklistItemsValue,
            imageData: imageDataValue,
            scheduleMode: scheduleModeValue.flatMap(RoutineScheduleMode.init(rawValue:)),
            interval: Int16(clamping: intervalValue ?? 1),
            recurrenceRule: recurrenceRuleStorageValue.flatMap(RoutineRecurrenceRuleStorage.deserialize),
            lastDone: lastDoneValue,
            canceledAt: canceledAtValue,
            scheduleAnchor: scheduleAnchorValue,
            pausedAt: pausedAtValue,
            snoozedUntil: snoozedUntilValue,
            pinnedAt: pinnedAtValue,
            completedStepCount: Int16(clamping: completedStepCountValue ?? 0),
            sequenceStartedAt: sequenceStartedAtValue,
            createdAt: createdAtValue,
            todoStateRawValue: todoStateRawValueValue,
            activityStateRawValue: activityStateRawValueValue,
            ongoingSince: ongoingSinceValue,
            autoAssumeDailyDone: autoAssumeDailyDoneValue,
            estimatedDurationMinutes: estimatedDurationMinutesValue,
            actualDurationMinutes: RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutesValue),
            storyPoints: storyPointsValue,
            pressure: pressureValue,
            pressureUpdatedAt: pressureUpdatedAtValue
        )
    }

    private static func isTaskRecordType(_ recordType: String) -> Bool {
        CloudKitDirectPullService.isTaskRecordType(recordType)
    }

    private static func stringValue(in record: CKRecord, keys: [String]) -> String? {
        CloudKitDirectPullService.stringValue(in: record, keys: keys)
    }

    private static func dataValue(in record: CKRecord, keys: [String]) -> Data? {
        CloudKitDirectPullService.dataValue(in: record, keys: keys)
    }

    private static func intValue(in record: CKRecord, keys: [String]) -> Int? {
        CloudKitDirectPullService.intValue(in: record, keys: keys)
    }

    private static func boolValue(in record: CKRecord, keys: [String]) -> Bool? {
        CloudKitDirectPullService.boolValue(in: record, keys: keys)
    }

    private static func dateValue(in record: CKRecord, keys: [String]) -> Date? {
        CloudKitDirectPullService.dateValue(in: record, keys: keys)
    }

    private static func uuidValue(in record: CKRecord, keys: [String]) -> UUID? {
        CloudKitDirectPullService.uuidValue(in: record, keys: keys)
    }
}
