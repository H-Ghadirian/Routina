import Foundation

struct DayPlanDoneTaskOccurrence: Equatable {
    var source: DayPlanTimelineActivitySource
    var completedAt: Date
    var durationMinutes: Int
    var hasSpecificTime: Bool = true
}

struct DayPlanDayTaskListItem: Identifiable, Equatable {
    enum Section: String, CaseIterable, Equatable {
        case planned
        case assumedDone
        case confirmedAssumedDone
        case done

        var title: String {
            switch self {
            case .planned:
                return "Planned tasks"
            case .assumedDone:
                return "Assumed done"
            case .confirmedAssumedDone:
                return "Confirmed assumed done"
            case .done:
                return "Done"
            }
        }

        var isRecordedCompletion: Bool {
            self == .confirmedAssumedDone || self == .done
        }
    }

    enum Placement: Equatable {
        case anyTime
        case allDay
        case durationOnly(durationMinutes: Int)
        case timed(startMinute: Int, durationMinutes: Int)
    }

    var id: String
    var taskID: UUID
    var blockID: UUID?
    var title: String
    var emoji: String?
    var section: Section = .planned
    var placement: Placement
    var doneOccurrence: DayPlanDoneTaskOccurrence?
    var plannedCompletionDate: Date?
}

struct DayPlanDoneTaskWorkTiming: Equatable {
    var startMinute: Int
    var durationMinutes: Int
}

extension DayPlanDoneTaskOccurrence {
    func workTiming(calendar: Calendar) -> DayPlanDoneTaskWorkTiming {
        let durationMinutes = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: 0,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        let completionComponents = calendar.dateComponents(
            [.hour, .minute],
            from: completedAt
        )
        let completionMinute =
            ((completionComponents.hour ?? 0) * 60)
            + (completionComponents.minute ?? 0)
        let startMinute = DayPlanBlock.clampedStartMinute(
            max(0, completionMinute - durationMinutes)
        )
        return DayPlanDoneTaskWorkTiming(
            startMinute: startMinute,
            durationMinutes: DayPlanBlock.clampedDuration(
                durationMinutes,
                startMinute: hasSpecificTime ? startMinute : 0,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
        )
    }
}

struct DayPlanDayTaskCounts: Equatable {
    var planned: Int = 0
    var assumedDone: Int = 0
    var confirmedAssumedDone: Int = 0
    var done: Int = 0

    var total: Int {
        planned + assumedDone + confirmedAssumedDone + done
    }

    init(
        planned: Int = 0,
        assumedDone: Int = 0,
        confirmedAssumedDone: Int = 0,
        done: Int = 0
    ) {
        self.planned = planned
        self.assumedDone = assumedDone
        self.confirmedAssumedDone = confirmedAssumedDone
        self.done = done
    }

    init(items: [DayPlanDayTaskListItem]) {
        for item in items {
            switch item.section {
            case .planned:
                planned += 1
            case .assumedDone:
                assumedDone += 1
            case .confirmedAssumedDone:
                confirmedAssumedDone += 1
            case .done:
                done += 1
            }
        }
    }
}

struct DayPlanDayTaskResolutionOverlay: Equatable {
    enum Resolution: Equatable {
        case completed(DayPlanDoneTaskOccurrence)
        case missed
    }

    private struct Key: Hashable {
        var taskID: UUID
        var dayKey: String
    }

    private var resolutions: [Key: Resolution] = [:]

    mutating func complete(
        _ item: DayPlanDayTaskListItem,
        on date: Date,
        completedAt: Date,
        calendar: Calendar
    ) {
        resolutions[key(for: item.taskID, on: date, calendar: calendar)] = .completed(
            DayPlanDoneTaskOccurrence(
                source: .taskLastDone,
                completedAt: completedAt,
                durationMinutes: durationMinutes(for: item.placement),
                hasSpecificTime: hasSpecificTime(for: item.placement)
            )
        )
    }

    mutating func markMissed(
        taskID: UUID,
        on date: Date,
        calendar: Calendar
    ) {
        resolutions[key(for: taskID, on: date, calendar: calendar)] = .missed
    }

    mutating func reset() {
        resolutions.removeAll(keepingCapacity: true)
    }

    func applying(
        to items: [DayPlanDayTaskListItem],
        on date: Date,
        calendar: Calendar
    ) -> [DayPlanDayTaskListItem] {
        guard !resolutions.isEmpty else { return items }
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)

        return items.compactMap { item in
            guard let resolution = resolutions[Key(taskID: item.taskID, dayKey: dayKey)]
            else {
                return item
            }

            switch resolution {
            case let .completed(doneOccurrence):
                guard item.section == .planned || item.section == .assumedDone else {
                    return item
                }
                var confirmedItem = item
                confirmedItem.section =
                    item.section == .assumedDone
                    ? .confirmedAssumedDone
                    : .done
                confirmedItem.doneOccurrence = doneOccurrence
                confirmedItem.plannedCompletionDate = nil
                return confirmedItem
            case .missed:
                return item.section == .assumedDone ? nil : item
            }
        }
    }

    private func key(
        for taskID: UUID,
        on date: Date,
        calendar: Calendar
    ) -> Key {
        Key(
            taskID: taskID,
            dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar)
        )
    }

    private func durationMinutes(for placement: DayPlanDayTaskListItem.Placement) -> Int {
        switch placement {
        case let .durationOnly(durationMinutes), let .timed(_, durationMinutes):
            return durationMinutes
        case .anyTime, .allDay:
            return 0
        }
    }

    private func hasSpecificTime(for placement: DayPlanDayTaskListItem.Placement) -> Bool {
        if case .timed = placement {
            return true
        }
        return false
    }
}

enum DayPlanPlannedTaskCompletion {
    static func completionDate(
        for task: RoutineTask,
        on selectedDay: Date,
        placement: DayPlanDayTaskListItem.Placement,
        referenceDate: Date,
        logs: [RoutineLog],
        calendar: Calendar
    ) -> Date? {
        let selectedDayStart = calendar.startOfDay(for: selectedDay)
        let referenceDayStart = calendar.startOfDay(for: referenceDate)
        guard selectedDayStart <= referenceDayStart,
            !task.hasSequentialSteps,
            !task.isChecklistCompletionRoutine,
            !task.blocksManualCompletionForIncompleteChecklist
        else {
            return nil
        }

        if RoutineDateMath.usesExactTimedOccurrences(for: task) {
            guard
                let completionDate = RoutineDateMath.completionTargetDate(
                    for: task,
                    selectedDay: selectedDayStart,
                    referenceDate: referenceDate,
                    calendar: calendar
                ),
                RoutineDateMath.canMarkSelectedExactTimedOccurrenceDone(
                    for: task,
                    completionDate: completionDate,
                    referenceDate: referenceDate,
                    logs: logs,
                    calendar: calendar
                )
            else {
                return nil
            }
            return completionDate
        }

        let scheduledTimeOfDay =
            task.isOneOffTask
            ? nil
            : task.recurrenceRule.timeRange?.start ?? task.recurrenceRule.timeOfDay
        let completionDate: Date
        if calendar.isDate(selectedDayStart, inSameDayAs: referenceDayStart) {
            completionDate = referenceDate
        } else if case let .timed(startMinute, durationMinutes) = placement {
            completionDate =
                calendar.date(
                    byAdding: .minute,
                    value: startMinute + durationMinutes,
                    to: selectedDayStart
                ) ?? selectedDayStart
        } else if let timeOfDay = scheduledTimeOfDay {
            completionDate = timeOfDay.date(on: selectedDayStart, calendar: calendar)
        } else {
            completionDate =
                calendar.date(
                    bySettingHour: 12,
                    minute: 0,
                    second: 0,
                    of: selectedDayStart
                ) ?? selectedDayStart
        }

        let isHistoricalCompletion = !calendar.isDate(
            completionDate,
            inSameDayAs: referenceDate
        )
        let canMarkDone = RoutineDateMath.canMarkDone(
            for: task,
            referenceDate: completionDate,
            calendar: calendar,
            ignoreArchiveAtReferenceDate: isHistoricalCompletion
        )
        let canCompleteEarly = RoutineDateMath.canCompleteScheduledOccurrenceEarly(
            for: task,
            completedAt: completionDate,
            calendar: calendar
        )
        return canMarkDone || canCompleteEarly ? completionDate : nil
    }
}
