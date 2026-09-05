import Foundation

enum TaskDetailCompletionStatusPillPhase: Equatable {
    case assumed
    case confirmed
}

struct TaskDetailMissedOccurrenceReview {
    let occurrence: Date
    let nextOccurrence: Date?
    let timeRange: RoutineTimeRange?
}

struct TaskDetailOccurrencePresentation: Equatable, Identifiable {
    enum Status: Equatable {
        case done
        case missed
        case canceled
        case due
        case upcoming
    }

    private struct ItemContext {
        let task: RoutineTask
        let defaultSelection: Date?
        let referenceDate: Date
        let logs: [RoutineLog]
        let due: Date
        let calendar: Calendar
    }

    var id: Date { occurrence }

    let occurrence: Date
    let status: Status
    let isSelected: Bool
    let resolutionTimestamp: Date?
    let hasRecordedResolution: Bool
    let canComplete: Bool
    let canMarkMissed: Bool
    let canCancel: Bool
    let canClearResolution: Bool

    static func items(
        for task: RoutineTask,
        on selectedDay: Date,
        selectedOccurrence: Date?,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar = .current
    ) -> [Self] {
        let items = allItems(
            for: task,
            on: selectedDay,
            selectedOccurrence: selectedOccurrence,
            referenceDate: referenceDate,
            logs: logs,
            calendar: calendar
        )
        return items.count > 1 ? items : []
    }

    static func allItems(
        for task: RoutineTask,
        on selectedDay: Date,
        selectedOccurrence: Date?,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar = .current
    ) -> [Self] {
        guard task.usesEffectiveRoutineCadence,
            !task.isChecklistDriven,
            !task.hasSequentialSteps,
            !task.isMultiDayRoutine
        else {
            return []
        }

        let occurrences = RoutineDateMath.scheduledOccurrences(
            for: task,
            on: selectedDay,
            calendar: calendar
        )
        guard !occurrences.isEmpty else { return [] }

        let defaultSelection =
            selectedOccurrence
            ?? RoutineDateMath.completionTargetDate(
                for: task,
                selectedDay: selectedDay,
                referenceDate: referenceDate,
                calendar: calendar
            )
            ?? occurrences.first
        let context = ItemContext(
            task: task,
            defaultSelection: defaultSelection,
            referenceDate: referenceDate,
            logs: logs,
            due: RoutineDateMath.dueDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            calendar: calendar
        )
        return occurrences.map { item(for: $0, context: context) }
    }

    private static func item(for occurrence: Date, context: ItemContext) -> Self {
        let matchingLog = matchingResolutionLog(for: occurrence, context: context)
        let isDone =
            matchingLog?.kind.resolvesDoneDate == true
            || context.task.lastDone.map {
                RoutineOccurrenceIdentity.matches(
                    $0,
                    occurrence,
                    for: context.task,
                    calendar: context.calendar
                )
            } == true
        let isCanceled = matchingLog?.kind == .canceled
        let hasRecordedMiss = matchingLog?.kind == .missed
        let isMissedByTime = RoutineDateMath.isScheduledOccurrenceMissed(
            occurrence,
            for: context.task,
            referenceDate: context.referenceDate,
            calendar: context.calendar
        )
        let hasRecordedResolution = matchingLog != nil

        return Self(
            occurrence: occurrence,
            status: status(
                for: occurrence,
                isDone: isDone,
                isCanceled: isCanceled,
                hasRecordedMiss: hasRecordedMiss,
                isMissedByTime: isMissedByTime,
                referenceDate: context.referenceDate
            ),
            isSelected: context.defaultSelection.map {
                RoutineOccurrenceIdentity.matches(
                    $0,
                    occurrence,
                    for: context.task,
                    calendar: context.calendar
                )
            } == true,
            resolutionTimestamp: matchingLog?.timestamp,
            hasRecordedResolution: hasRecordedResolution,
            canComplete: canComplete(
                occurrence,
                isDone: isDone,
                isCanceled: isCanceled,
                hasRecordedMiss: hasRecordedMiss,
                isMissedByTime: isMissedByTime,
                context: context
            ),
            canMarkMissed: !context.task.isArchived(
                referenceDate: context.referenceDate,
                calendar: context.calendar
            )
                && isMissedByTime
                && !hasRecordedResolution,
            canCancel: RoutineDateMath.usesExactTimedOccurrences(for: context.task)
                && !context.task.isArchived(
                    referenceDate: context.referenceDate,
                    calendar: context.calendar
                )
                && occurrence <= context.referenceDate
                && !isDone
                && !isCanceled,
            canClearResolution: hasRecordedResolution
        )
    }

    private static func matchingResolutionLog(
        for occurrence: Date,
        context: ItemContext
    ) -> RoutineLog? {
        context.logs.first { log in
            guard let timestamp = log.timestamp else { return false }
            guard log.kind.resolvesDoneDate || log.kind == .missed || log.kind == .canceled else {
                return false
            }
            return RoutineOccurrenceIdentity.matches(
                timestamp,
                occurrence,
                for: context.task,
                calendar: context.calendar
            )
        }
    }

    private static func status(
        for occurrence: Date,
        isDone: Bool,
        isCanceled: Bool,
        hasRecordedMiss: Bool,
        isMissedByTime: Bool,
        referenceDate: Date
    ) -> Status {
        if isDone { return .done }
        if isCanceled { return .canceled }
        if hasRecordedMiss || isMissedByTime { return .missed }
        if occurrence <= referenceDate { return .due }
        return .upcoming
    }

    private static func canComplete(
        _ occurrence: Date,
        isDone: Bool,
        isCanceled: Bool,
        hasRecordedMiss: Bool,
        isMissedByTime: Bool,
        context: ItemContext
    ) -> Bool {
        if isDone
            || context.task.isArchived(
                referenceDate: context.referenceDate,
                calendar: context.calendar
            )
        {
            return false
        }
        if RoutineDateMath.usesExactTimedOccurrences(for: context.task) {
            return occurrence <= context.referenceDate
                && (hasRecordedMiss
                    || isCanceled
                    || isMissedByTime
                    || RoutineDateMath.canMarkDone(
                        for: context.task,
                        referenceDate: occurrence,
                        calendar: context.calendar,
                        ignoreArchiveAtReferenceDate: true
                    ))
        }
        return occurrence <= context.referenceDate
            && RoutineOccurrenceIdentity.matches(
                context.due,
                occurrence,
                for: context.task,
                calendar: context.calendar
            )
    }
}
