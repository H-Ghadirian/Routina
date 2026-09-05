import Foundation

extension RoutineTask {
    var scheduleMode: RoutineScheduleMode {
        get { RoutineScheduleMode(rawValue: scheduleModeRawValue) ?? .fixedInterval }
        set {
            scheduleModeRawValue = newValue.rawValue
            if newValue != .oneOff {
                deadline = nil
                availabilityStartDate = nil
                availabilityEndDate = nil
            }
            if newValue.taskType == .todo {
                routineDurationMode = .oneDay
            }
            if hasChecklistItems {
                checklistItemsStorage = RoutineChecklistItemStorage.serialize(
                    RoutineChecklistItem.sanitized(checklistItems, for: newValue)
                )
            }
            sanitizeChecklistProgress()
        }
    }

    var routineDurationMode: RoutineDurationMode {
        get {
            guard scheduleMode.taskType != .todo else { return .oneDay }
            return RoutineDurationMode(rawValue: routineDurationModeRawValue) ?? .oneDay
        }
        set {
            routineDurationModeRawValue =
                scheduleMode.taskType == .todo
                ? RoutineDurationMode.oneDay.rawValue
                : newValue.rawValue
        }
    }

    var isMultiDayRoutine: Bool {
        scheduleMode.taskType != .todo && routineDurationMode == .multiDay
    }

    var usesOngoingLifecycle: Bool {
        isSoftIntervalRoutine || isMultiDayRoutine
    }

    var recurrenceRule: RoutineRecurrenceRule {
        get {
            if let storedRule = RoutineRecurrenceRuleStorage.deserialize(recurrenceRuleStorage),
                storedRule.requiresStructuredStorage
            {
                return storedRule
            }
            if recurrenceStorageVersion >= Self.currentRecurrenceStorageVersion {
                return recurrenceRuleFromColumns
            }
            return RoutineRecurrenceRuleStorage.deserialize(recurrenceRuleStorage)
                ?? recurrenceRuleFromColumns
        }
        set {
            let normalizedRule: RoutineRecurrenceRule
            switch scheduleMode.taskType {
            case .routine:
                normalizedRule = newValue
            case .todo:
                normalizedRule = RoutineRecurrenceRule.interval(
                    days: 1,
                    at: newValue.timeOfDay,
                    timeRange: newValue.timeRange
                )
            }
            storeRecurrenceRuleInColumns(normalizedRule)
            if normalizedRule.timeRange == nil {
                recurrenceTimeRangeRole = .availability
            }
        }
    }

    var recurrenceTimeRangeRole: RoutineTimeRangeRole {
        get { RoutineTimeRangeRole(rawValue: recurrenceTimeRangeRoleRawValue) ?? .availability }
        set { recurrenceTimeRangeRoleRawValue = newValue.rawValue }
    }

    func replaceRelationships(_ updatedRelationships: [RoutineTaskRelationship]) {
        relationshipsStorage = RoutineTaskRelationshipStorage.serialize(updatedRelationships, ownerID: id)
    }

    @discardableResult
    func migrateLegacyRecurrenceRuleStorageIfNeeded() -> Bool {
        guard recurrenceStorageVersion < Self.currentRecurrenceStorageVersion else { return false }
        let legacyRule =
            RoutineRecurrenceRuleStorage.deserialize(recurrenceRuleStorage)
            ?? .interval(days: max(Int(interval), 1))
        storeRecurrenceRuleInColumns(legacyRule)
        return true
    }

    private static var currentRecurrenceStorageVersion: Int16 { 1 }

    private var recurrenceRuleFromColumns: RoutineRecurrenceRule {
        let kind = RoutineRecurrenceRule.Kind(rawValue: recurrenceKindRawValue) ?? .intervalDays
        let exactTime = recurrenceTimeOfDay
        let timeRange = recurrenceTimeRange

        switch kind {
        case .intervalDays:
            return .interval(
                days: max(Int(interval), 1),
                at: exactTime,
                timeRange: timeRange
            )
        case .dailyTime:
            return RoutineRecurrenceRule(
                kind: .dailyTime,
                timeOfDay: exactTime,
                timeRange: timeRange
            )
        case .weekly:
            return .weekly(
                on: recurrenceWeekday ?? Calendar.current.firstWeekday,
                at: exactTime,
                timeRange: timeRange
            )
        case .monthlyDay:
            return .monthly(
                on: recurrenceDayOfMonth ?? Calendar.current.component(.day, from: Date()),
                at: exactTime,
                timeRange: timeRange
            )
        }
    }

    private var recurrenceTimeOfDay: RoutineTimeOfDay? {
        guard let hour = recurrenceTimeOfDayHour,
            let minute = recurrenceTimeOfDayMinute
        else {
            return nil
        }
        return RoutineTimeOfDay(hour: hour, minute: minute)
    }

    private var recurrenceTimeRange: RoutineTimeRange? {
        guard let startHour = recurrenceTimeRangeStartHour,
            let startMinute = recurrenceTimeRangeStartMinute,
            let endHour = recurrenceTimeRangeEndHour,
            let endMinute = recurrenceTimeRangeEndMinute
        else {
            return nil
        }
        return RoutineTimeRange(
            start: RoutineTimeOfDay(hour: startHour, minute: startMinute),
            end: RoutineTimeOfDay(hour: endHour, minute: endMinute)
        )
    }

    func storeRecurrenceRuleInColumns(_ recurrenceRule: RoutineRecurrenceRule) {
        recurrenceStorageVersion = Self.currentRecurrenceStorageVersion
        recurrenceKindRawValue = recurrenceRule.kind.rawValue
        interval = Int16(clamping: scheduleMode.usesRoutineCadence ? recurrenceRule.approximateIntervalDays : 1)
        recurrenceTimeOfDayHour = recurrenceRule.timeOfDay?.hour
        recurrenceTimeOfDayMinute = recurrenceRule.timeOfDay?.minute
        recurrenceTimeRangeStartHour = recurrenceRule.timeRange?.start.hour
        recurrenceTimeRangeStartMinute = recurrenceRule.timeRange?.start.minute
        recurrenceTimeRangeEndHour = recurrenceRule.timeRange?.end.hour
        recurrenceTimeRangeEndMinute = recurrenceRule.timeRange?.end.minute
        recurrenceWeekday = recurrenceRule.weekday
        recurrenceDayOfMonth = recurrenceRule.dayOfMonth
        recurrenceRuleStorage =
            recurrenceRule.requiresStructuredStorage
            ? RoutineRecurrenceRuleStorage.serialize(recurrenceRule)
            : ""
    }
}
