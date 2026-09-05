import Foundation

enum RoutineTaskTemporalWeightResolver {
    static func supportsTemporalWeight(
        scheduleMode: RoutineScheduleMode,
        cadenceEnabled: Bool
    ) -> Bool {
        scheduleMode.taskType == .routine
            && scheduleMode.scheduleBehavior == .fixed
            && scheduleMode.usesRoutineCadence
            && cadenceEnabled
    }

    static func supportsTemporalWeight(_ task: RoutineTask) -> Bool {
        supportsTemporalWeight(
            scheduleMode: task.scheduleMode,
            cadenceEnabled: task.cadenceEnabled
        )
    }

    static func maximumBeforeDueDays(for recurrenceRule: RoutineRecurrenceRule) -> Int? {
        guard recurrenceRule.advanced == nil,
            recurrenceRule.kind == .intervalDays
        else {
            return nil
        }
        return min(
            max(recurrenceRule.approximateIntervalDays, 1),
            RoutineTaskTemporalWeightRule.maximumTransitionDays
        )
    }

    static func sanitizedRule(
        _ rule: RoutineTaskTemporalWeightRule?,
        scheduleMode: RoutineScheduleMode,
        cadenceEnabled: Bool,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> RoutineTaskTemporalWeightRule? {
        guard
            supportsTemporalWeight(
                scheduleMode: scheduleMode,
                cadenceEnabled: cadenceEnabled
            )
        else {
            return nil
        }
        return rule?.sanitized(
            baseImportance: importance,
            baseUrgency: urgency,
            basePressure: pressure,
            maximumBeforeDueDays: maximumBeforeDueDays
        )
    }

    static func sanitizedRule(
        _ rule: RoutineTaskTemporalWeightRule?,
        for task: RoutineTask
    ) -> RoutineTaskTemporalWeightRule? {
        sanitizedRule(
            rule,
            scheduleMode: task.scheduleMode,
            cadenceEnabled: task.cadenceEnabled,
            importance: task.importance,
            urgency: task.urgency,
            pressure: task.pressure,
            maximumBeforeDueDays: maximumBeforeDueDays(for: task.recurrenceRule)
        )
    }

    static func effectiveWeights(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineTaskEffectiveWeights {
        guard supportsTemporalWeight(task),
            let rule = sanitizedRule(task.temporalWeightRule, for: task)
        else {
            return RoutineTaskEffectiveWeights(
                importance: task.importance,
                urgency: task.urgency,
                pressure: task.pressure,
                progress: 0
            )
        }

        let daysUntilDue = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard daysUntilDue != Int.max else {
            return RoutineTaskEffectiveWeights(
                importance: task.importance,
                urgency: task.urgency,
                pressure: task.pressure,
                progress: 0
            )
        }

        let importance = effectiveValue(
            base: task.importance,
            policy: rule.importance,
            daysUntilDue: daysUntilDue,
            values: RoutineTaskImportance.allCases
        )
        let urgency = effectiveValue(
            base: task.urgency,
            policy: rule.urgency,
            daysUntilDue: daysUntilDue,
            values: RoutineTaskUrgency.allCases
        )
        let pressure = effectiveValue(
            base: task.pressure,
            policy: rule.pressure,
            daysUntilDue: daysUntilDue,
            values: RoutineTaskPressure.allCases
        )

        return RoutineTaskEffectiveWeights(
            importance: importance.value,
            urgency: urgency.value,
            pressure: pressure.value,
            progress: max(importance.progress, urgency.progress, pressure.progress)
        )
    }

    static func timingLabel(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard supportsTemporalWeight(task), task.temporalWeightRule != nil else { return nil }
        let days = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard days != Int.max else { return nil }
        switch days {
        case ..<0: return abs(days) == 1 ? "1 day overdue" : "\(abs(days)) days overdue"
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        default: return "Due in \(days) days"
        }
    }

    private static func effectiveValue<Value>(
        base: Value,
        policy: RoutineTaskTemporalWeightPolicy<Value>?,
        daysUntilDue: Int,
        values: [Value]
    ) -> (value: Value, progress: Double)
    where Value: Codable & Equatable & Sendable {
        guard let policy,
            let baseIndex = values.firstIndex(of: base),
            let targetIndex = values.firstIndex(of: policy.target),
            targetIndex > baseIndex
        else {
            return (base, 0)
        }

        let distance = targetIndex - baseIndex
        switch policy.timing {
        case .onDueDate:
            return daysUntilDue <= 0 ? (policy.target, 1) : (base, 0)

        case .gradualBeforeDue:
            let leadDays = min(
                max(policy.days, 1),
                RoutineTaskTemporalWeightRule.maximumTransitionDays
            )
            let progress: Double
            if daysUntilDue <= 0 {
                progress = 1
            } else if daysUntilDue >= leadDays {
                progress = 0
            } else {
                progress = Double(leadDays - daysUntilDue) / Double(leadDays)
            }
            return (
                interpolated(
                    base: base,
                    target: policy.target,
                    progress: progress,
                    values: values
                ),
                progress
            )

        case .gradualWhileOverdue:
            guard daysUntilDue < 0 else { return (base, 0) }
            let intervalDays = min(
                max(policy.days, 1),
                RoutineTaskTemporalWeightRule.maximumTransitionDays
            )
            let levels = min(abs(daysUntilDue) / intervalDays, distance)
            guard levels > 0 else { return (base, 0) }
            return (
                values[min(baseIndex + levels, targetIndex)],
                Double(levels) / Double(distance)
            )
        }
    }

    private static func interpolated<Value>(
        base: Value,
        target: Value,
        progress: Double,
        values: [Value]
    ) -> Value where Value: Equatable {
        guard let baseIndex = values.firstIndex(of: base),
            let targetIndex = values.firstIndex(of: target),
            targetIndex > baseIndex,
            progress > 0
        else {
            return base
        }
        let distance = targetIndex - baseIndex
        let clampedProgress = min(max(progress, 0), 1)
        let proposedLevels = Int(ceil(Double(distance) * clampedProgress))
        let advancedLevels =
            clampedProgress >= 1
            ? distance
            : min(proposedLevels, max(distance - 1, 0))
        return values[min(baseIndex + advancedLevels, targetIndex)]
    }
}

enum RoutineTaskTemporalWeightPresentation {
    static func targetSummary(
        rule: RoutineTaskTemporalWeightRule?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> String? {
        guard
            let rule = rule?.sanitized(
                baseImportance: importance,
                baseUrgency: urgency,
                basePressure: pressure,
                maximumBeforeDueDays: maximumBeforeDueDays
            )
        else {
            return nil
        }

        var parts: [String] = []
        if let policy = rule.importance {
            parts.append(
                metricSummary(
                    title: "Importance",
                    base: importance.title,
                    target: policy.target.title,
                    policy: policy
                ))
        }
        if let policy = rule.urgency {
            parts.append(
                metricSummary(
                    title: "Urgency",
                    base: urgency.title,
                    target: policy.target.title,
                    policy: policy
                ))
        }
        if let policy = rule.pressure {
            parts.append(
                metricSummary(
                    title: "Pressure",
                    base: pressure.title,
                    target: policy.target.title,
                    policy: policy
                ))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    static func metricSummaries(
        rule: RoutineTaskTemporalWeightRule?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure,
        maximumBeforeDueDays: Int? = nil
    ) -> [String] {
        guard
            let summary = targetSummary(
                rule: rule,
                importance: importance,
                urgency: urgency,
                pressure: pressure,
                maximumBeforeDueDays: maximumBeforeDueDays
            )
        else {
            return []
        }
        return summary.components(separatedBy: " • ")
    }

    static func nowSummary(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard RoutineTaskTemporalWeightResolver.supportsTemporalWeight(task),
            task.temporalWeightRule != nil
        else {
            return nil
        }
        let weights = RoutineTaskTemporalWeightResolver.effectiveWeights(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return "Now: Importance \(weights.importance.title) • Urgency \(weights.urgency.title) • Pressure \(weights.pressure.title)"
    }

    static func baseSummary(
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency,
        pressure: RoutineTaskPressure
    ) -> String {
        "After completion: Importance \(importance.title) • Urgency \(urgency.title) • Pressure \(pressure.title)"
    }

    private static func metricSummary<Value>(
        title: String,
        base: String,
        target: String,
        policy: RoutineTaskTemporalWeightPolicy<Value>
    ) -> String where Value: Codable & Equatable & Sendable {
        switch policy.timing {
        case .onDueDate:
            return "\(title) \(base) -> \(target) on due date"
        case .gradualBeforeDue:
            return "\(title) \(base) -> \(target) over \(dayCount(policy.days)) before due"
        case .gradualWhileOverdue:
            return "\(title) \(base) -> \(target), one level every \(dayCount(policy.days)) overdue"
        }
    }

    private static func dayCount(_ days: Int) -> String {
        "\(days) \(days == 1 ? "day" : "days")"
    }
}
