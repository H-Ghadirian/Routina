import Foundation

enum StatsSummaryTaskListKind: String, Equatable {
    case activityOverview = "stats.hero.activities"
    case dailyAverage = "stats.summary.dailyAverage"
    case bestDay = "stats.summary.bestDay"
    case focusTime = "stats.summary.focusTime"
    case focusAverage = "stats.summary.focusAverage"
    case totalDones = "stats.summary.totalDones"
    case assumedDones = "stats.summary.assumedDones"
    case assumedEstimatedTime = "stats.summary.assumedEstimatedTime"
    case totalCancels = "stats.summary.totalCancels"
    case totalMissed = "stats.summary.totalMissed"
    case routineCount = "stats.summary.routineCount"
    case todoCount = "stats.summary.todoCount"
    case activeItems = "stats.summary.activeRoutines"
    case archivedItems = "stats.summary.archivedRoutines"

    init?(summaryAccessibilityIdentifier: String) {
        self.init(rawValue: summaryAccessibilityIdentifier)
    }
}

struct StatsSummaryTaskListRow: Equatable, Identifiable {
    let id: String
    let emoji: String?
    let systemImage: String
    let title: String
    let detail: String
    let value: String?
}

struct StatsSummaryTaskListPresentation: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let rows: [StatsSummaryTaskListRow]
}

struct StatsAssumedCompletionTaskSummary: Equatable {
    let taskID: UUID
    let occurrenceCount: Int
    let estimatedMinutes: Int
}

enum StatsAssumedCompletionTaskSummaryBuilder {
    static func summaries(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        selectedRange: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> [StatsAssumedCompletionTaskSummary] {
        let endDay = calendar.startOfDay(for: selectedRange.referenceDate(relativeTo: referenceDate))
        let startDay = selectedRange.startDate(relativeTo: referenceDate, calendar: calendar)
        let logsByTaskID = Dictionary(grouping: logs, by: \.taskID)

        return tasks.compactMap { task in
            let taskLogs = logsByTaskID[task.id, default: []]
            var occurrenceCount = 0
            var day = startDay

            while day <= endDay {
                if RoutineAssumedCompletion.isAssumedDone(
                    for: task,
                    on: day,
                    referenceDate: referenceDate,
                    logs: taskLogs,
                    calendar: calendar
                ) {
                    occurrenceCount += 1
                }

                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                    break
                }
                day = nextDay
            }

            guard occurrenceCount > 0 else { return nil }
            return StatsAssumedCompletionTaskSummary(
                taskID: task.id,
                occurrenceCount: occurrenceCount,
                estimatedMinutes: occurrenceCount * (task.estimatedDurationMinutes ?? 0)
            )
        }
    }
}

extension StatsSummaryTaskListPresentationBuilder {
    static func dateIsInRange(
        _ date: Date?,
        selectedRange: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let date else { return false }
        let startDay = selectedRange.startDate(relativeTo: referenceDate, calendar: calendar)
        let endDay = calendar.startOfDay(for: selectedRange.referenceDate(relativeTo: referenceDate))
        let day = calendar.startOfDay(for: date)
        return day >= startDay && day <= endDay
    }

    static func taskCountSubtitle(_ count: Int, label: String) -> String {
        "\(count.formatted()) \(count == 1 ? label : pluralized(label)) matching current Stats filters"
    }

    static func taskCountText(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "task" : "tasks")"
    }

    static func taskTitleSort(_ lhs: RoutineTask, _ rhs: RoutineTask) -> Bool {
        displayTitle(for: lhs).localizedCaseInsensitiveCompare(displayTitle(for: rhs)) == .orderedAscending
    }

    static func rankedRowSort<Value: Comparable>(
        _ lhs: (StatsSummaryTaskListRow, Value),
        _ rhs: (StatsSummaryTaskListRow, Value)
    ) -> Bool {
        if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
        return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
    }

    static func taskDetail(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        if task.isArchived(referenceDate: referenceDate, calendar: calendar) {
            return task.isPaused(referenceDate: referenceDate)
                ? "Paused \(taskTypeLabel(for: task).lowercased())"
                : "Snoozed \(taskTypeLabel(for: task).lowercased())"
        }
        return taskTypeLabel(for: task)
    }

    static func taskTypeLabel(for task: RoutineTask) -> String {
        task.scheduleMode.taskType == .routine ? "Repeating task" : "One-time task"
    }

    static func displayTitle(for task: RoutineTask) -> String {
        RoutineTask.trimmedName(task.name) ?? "Untitled task"
    }

    static func displayEmoji(for task: RoutineTask) -> String? {
        guard let emoji = task.emoji?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty else {
            return nil
        }
        return emoji
    }

    static func durationText(minutes: Int) -> String {
        durationText(seconds: TimeInterval(minutes * 60))
    }

    static func durationText(seconds: TimeInterval) -> String {
        FocusSessionFormatting.compactDurationText(seconds: seconds)
    }

    static func pluralized(_ label: String) -> String {
        if label.hasSuffix("task") || label.hasSuffix("item") || label.hasSuffix("occurrence") {
            return "\(label)s"
        }
        return label
    }
}
