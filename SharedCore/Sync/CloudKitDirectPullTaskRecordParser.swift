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
        let commentsStorageValue = stringValue(
            in: record,
            keys: [
                "commentsStorage",
                "commentsstorage",
                "COMMENTSSTORAGE",
                "zcommentsstorage",
                "ZCOMMENTSSTORAGE",
                "cd_commentsstorage"
            ]
        )
        let linkValue = stringValue(in: record, keys: ["link", "LINK", "zlink", "ZLINK", "cd_link"])
        let linksStorageValue = stringValue(in: record, keys: storageKeys("linksStorage"))
        let deadlineValue = dateValue(in: record, keys: ["deadline", "DEADLINE", "zdeadline", "ZDEADLINE", "cd_deadline"])
        let plannedDateValue = dateValue(in: record, keys: storageKeys("plannedDate"))
        let isAllDayValue = boolValue(in: record, keys: storageKeys("isAllDay"))
        let routineDurationModeValue = stringValue(
            in: record,
            keys: storageKeys("routineDurationModeRawValue")
        ).flatMap(RoutineDurationMode.init(rawValue:))
        let availabilityStartDateValue = dateValue(in: record, keys: storageKeys("availabilityStartDate"))
        let availabilityEndDateValue = dateValue(in: record, keys: storageKeys("availabilityEndDate"))
        let reminderAtValue = dateValue(in: record, keys: ["reminderAt", "REMINDERAT", "zreminderat", "ZREMINDERAT", "cd_reminderat"])
        let placeIDValue = uuidValue(in: record, keys: ["placeID", "placeId", "PLACEID", "zplaceid", "ZPLACEID", "cd_placeid"])
        let placeIDsStorageValue = stringValue(in: record, keys: storageKeys("placeIDsStorage"))
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
        let eventIDsStorageValue = stringValue(
            in: record,
            keys: [
                "eventIDsStorage",
                "eventidsstorage",
                "EVENTIDSSTORAGE",
                "zeventidsstorage",
                "ZEVENTIDSSTORAGE",
                "cd_eventidsstorage"
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
        let recurrenceStorageVersionValue = intValue(in: record, keys: storageKeys("recurrenceStorageVersion"))
        let recurrenceKindRawValueValue = stringValue(in: record, keys: storageKeys("recurrenceKindRawValue"))
        let recurrenceTimeOfDayHourValue = intValue(in: record, keys: storageKeys("recurrenceTimeOfDayHour"))
        let recurrenceTimeOfDayMinuteValue = intValue(in: record, keys: storageKeys("recurrenceTimeOfDayMinute"))
        let recurrenceTimeRangeStartHourValue = intValue(in: record, keys: storageKeys("recurrenceTimeRangeStartHour"))
        let recurrenceTimeRangeStartMinuteValue = intValue(in: record, keys: storageKeys("recurrenceTimeRangeStartMinute"))
        let recurrenceTimeRangeEndHourValue = intValue(in: record, keys: storageKeys("recurrenceTimeRangeEndHour"))
        let recurrenceTimeRangeEndMinuteValue = intValue(in: record, keys: storageKeys("recurrenceTimeRangeEndMinute"))
        let recurrenceTimeRangeRoleValue = stringValue(in: record, keys: storageKeys("recurrenceTimeRangeRoleRawValue"))
            .flatMap(RoutineTimeRangeRole.init(rawValue:))
        let recurrenceWeekdayValue = intValue(in: record, keys: storageKeys("recurrenceWeekday"))
        let recurrenceDayOfMonthValue = intValue(in: record, keys: storageKeys("recurrenceDayOfMonth"))
        let recurrenceRuleColumnValue = recurrenceRuleFromColumns(
            storageVersion: recurrenceStorageVersionValue,
            kindRawValue: recurrenceKindRawValueValue,
            interval: intervalValue,
            timeOfDayHour: recurrenceTimeOfDayHourValue,
            timeOfDayMinute: recurrenceTimeOfDayMinuteValue,
            timeRangeStartHour: recurrenceTimeRangeStartHourValue,
            timeRangeStartMinute: recurrenceTimeRangeStartMinuteValue,
            timeRangeEndHour: recurrenceTimeRangeEndHourValue,
            timeRangeEndMinute: recurrenceTimeRangeEndMinuteValue,
            weekday: recurrenceWeekdayValue,
            dayOfMonth: recurrenceDayOfMonthValue
        )
        let recurrenceRuleStorageRule = recurrenceRuleStorageValue.flatMap(RoutineRecurrenceRuleStorage.deserialize)
        let recurrenceRuleValue = recurrenceRuleStorageRule?.hasMultipleCalendarSelections == true
            ? recurrenceRuleStorageRule
            : (recurrenceRuleColumnValue ?? recurrenceRuleStorageRule)
        let imageDataValue = dataValue(
            in: record,
            keys: ["imageData", "IMAGEDATA", "zimagedata", "ZIMAGEDATA", "cd_imagedata"]
        )
        let voiceNoteDataValue = dataValue(in: record, keys: storageKeys("voiceNoteData"))
        let voiceNoteDurationSecondsValue = doubleValue(in: record, keys: storageKeys("voiceNoteDurationSeconds"))
        let voiceNoteCreatedAtValue = dateValue(in: record, keys: storageKeys("voiceNoteCreatedAt"))
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
        let autoAssumeDoneTimeOfDayHourValue = intValue(
            in: record,
            keys: [
                "autoAssumeDoneTimeOfDayHour",
                "AUTOASSUMEDONETIMEOFDAYHOUR",
                "zautoassumedonetimeofdayhour",
                "ZAUTOASSUMEDONETIMEOFDAYHOUR",
                "cd_autoassumedonetimeofdayhour"
            ]
        )
        let autoAssumeDoneTimeOfDayMinuteValue = intValue(
            in: record,
            keys: [
                "autoAssumeDoneTimeOfDayMinute",
                "AUTOASSUMEDONETIMEOFDAYMINUTE",
                "zautoassumedonetimeofdayminute",
                "ZAUTOASSUMEDONETIMEOFDAYMINUTE",
                "cd_autoassumedonetimeofdayminute"
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
                || commentsStorageValue != nil
                || linkValue != nil
                || linksStorageValue != nil
                || deadlineValue != nil
                || plannedDateValue != nil
                || isAllDayValue != nil
                || routineDurationModeValue != nil
                || availabilityStartDateValue != nil
                || availabilityEndDateValue != nil
                || placeIDValue != nil
                || tagsStorageValue != nil
                || goalIDsStorageValue != nil
                || eventIDsStorageValue != nil
                || stepsStorageValue != nil
                || checklistItemsStorageValue != nil
                || imageDataValue != nil
                || voiceNoteDataValue != nil
                || voiceNoteDurationSecondsValue != nil
                || voiceNoteCreatedAtValue != nil
                || scheduleModeValue != nil
                || recurrenceRuleValue != nil
                || recurrenceTimeRangeRoleValue != nil
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
                || autoAssumeDoneTimeOfDayHourValue != nil
                || autoAssumeDoneTimeOfDayMinuteValue != nil
                || placeIDsStorageValue != nil
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
            links: linksStorageValue.map(RoutineTaskLinkStorage.deserialize),
            linkItems: linksStorageValue.map(RoutineTaskLinkStorage.deserializeItems),
            deadline: deadlineValue,
            plannedDate: plannedDateValue,
            isAllDay: isAllDayValue,
            routineDurationMode: routineDurationModeValue,
            availabilityStartDate: availabilityStartDateValue,
            availabilityEndDate: availabilityEndDateValue,
            reminderAt: reminderAtValue,
            placeID: placeIDValue,
            placeIDs: placeIDsStorageValue.map(RoutinePlaceIDStorage.deserialize),
            tags: tagsStorageValue.map(RoutineTag.deserialize),
            goalIDs: goalIDsStorageValue.map(RoutineGoalIDStorage.deserialize),
            eventIDs: eventIDsStorageValue.map(RoutineEventIDStorage.deserialize),
            steps: stepsValue,
            checklistItems: checklistItemsValue,
            imageData: imageDataValue,
            voiceNoteData: voiceNoteDataValue,
            voiceNoteDurationSeconds: voiceNoteDurationSecondsValue,
            voiceNoteCreatedAt: voiceNoteCreatedAtValue,
            scheduleMode: scheduleModeValue.flatMap(RoutineScheduleMode.init(rawValue:)),
            interval: Int16(clamping: intervalValue ?? 1),
            recurrenceRule: recurrenceRuleValue,
            recurrenceTimeRangeRole: recurrenceTimeRangeRoleValue,
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
            autoAssumeDoneTimeOfDayHour: autoAssumeDoneTimeOfDayHourValue,
            autoAssumeDoneTimeOfDayMinute: autoAssumeDoneTimeOfDayMinuteValue,
            estimatedDurationMinutes: estimatedDurationMinutesValue,
            actualDurationMinutes: RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutesValue),
            storyPoints: storyPointsValue,
            pressure: pressureValue,
            pressureUpdatedAt: pressureUpdatedAtValue,
            comments: commentsStorageValue.map(RoutineTaskCommentStorage.deserialize)
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

    private static func doubleValue(in record: CKRecord, keys: [String]) -> Double? {
        CloudKitDirectPullService.doubleValue(in: record, keys: keys)
    }

    private static func dateValue(in record: CKRecord, keys: [String]) -> Date? {
        CloudKitDirectPullService.dateValue(in: record, keys: keys)
    }

    private static func uuidValue(in record: CKRecord, keys: [String]) -> UUID? {
        CloudKitDirectPullService.uuidValue(in: record, keys: keys)
    }

    private static func storageKeys(_ property: String) -> [String] {
        [
            property,
            property.lowercased(),
            property.uppercased(),
            "z\(property.lowercased())",
            "Z\(property.uppercased())",
            "cd_\(property.lowercased())"
        ]
    }

    private static func recurrenceRuleFromColumns(
        storageVersion: Int?,
        kindRawValue: String?,
        interval: Int?,
        timeOfDayHour: Int?,
        timeOfDayMinute: Int?,
        timeRangeStartHour: Int?,
        timeRangeStartMinute: Int?,
        timeRangeEndHour: Int?,
        timeRangeEndMinute: Int?,
        weekday: Int?,
        dayOfMonth: Int?
    ) -> RoutineRecurrenceRule? {
        guard storageVersion != nil
                || kindRawValue != nil
                || timeOfDayHour != nil
                || timeOfDayMinute != nil
                || timeRangeStartHour != nil
                || timeRangeStartMinute != nil
                || timeRangeEndHour != nil
                || timeRangeEndMinute != nil
                || weekday != nil
                || dayOfMonth != nil else {
            return nil
        }

        let kind = kindRawValue.flatMap(RoutineRecurrenceRule.Kind.init(rawValue:)) ?? .intervalDays
        let exactTime = timeOfDay(hour: timeOfDayHour, minute: timeOfDayMinute)
        let range = timeRange(
            startHour: timeRangeStartHour,
            startMinute: timeRangeStartMinute,
            endHour: timeRangeEndHour,
            endMinute: timeRangeEndMinute
        )

        switch kind {
        case .intervalDays:
            return .interval(
                days: max(interval ?? 1, 1),
                at: exactTime,
                timeRange: range
            )
        case .dailyTime:
            return RoutineRecurrenceRule(
                kind: .dailyTime,
                timeOfDay: exactTime,
                timeRange: range
            )
        case .weekly:
            return .weekly(
                on: weekday ?? Calendar.current.firstWeekday,
                at: exactTime,
                timeRange: range
            )
        case .monthlyDay:
            return .monthly(
                on: dayOfMonth ?? Calendar.current.component(.day, from: Date()),
                at: exactTime,
                timeRange: range
            )
        }
    }

    private static func timeOfDay(hour: Int?, minute: Int?) -> RoutineTimeOfDay? {
        guard let hour, let minute else { return nil }
        return RoutineTimeOfDay(hour: hour, minute: minute)
    }

    private static func timeRange(
        startHour: Int?,
        startMinute: Int?,
        endHour: Int?,
        endMinute: Int?
    ) -> RoutineTimeRange? {
        guard let start = timeOfDay(hour: startHour, minute: startMinute),
              let end = timeOfDay(hour: endHour, minute: endMinute) else {
            return nil
        }
        return RoutineTimeRange(start: start, end: end)
    }
}
