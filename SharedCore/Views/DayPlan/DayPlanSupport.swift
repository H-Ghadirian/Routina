import Foundation

enum DayPlanTaskSorting {
    static func availableTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks
            .filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }

                if lhs.isOneOffTask != rhs.isOneOffTask {
                    return lhs.isOneOffTask
                }

                let lhsDeadline = lhs.deadline ?? .distantFuture
                let rhsDeadline = rhs.deadline ?? .distantFuture
                if lhsDeadline != rhsDeadline {
                    return lhsDeadline < rhsDeadline
                }

                return title(for: lhs).localizedCaseInsensitiveCompare(title(for: rhs)) == .orderedAscending
            }
    }

    static func filteredTasks(from tasks: [RoutineTask], query: String) -> [RoutineTask] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tasks }

        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return tasks.filter { task in
            let searchableText = ([title(for: task), task.emoji ?? ""] + task.tags)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return searchableText.contains(normalizedQuery)
        }
    }

    static func title(for task: RoutineTask) -> String {
        let trimmed = RoutineTask.trimmedName(task.name) ?? ""
        return trimmed.isEmpty ? "Untitled task" : trimmed
    }
}

enum DayPlanUnplannedCompletedTasks {
    static func count(
        on date: Date,
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> Int {
        taskIDs(
            on: date,
            taskIDs: tasks.map(\.id),
            lastDoneForTaskID: Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.lastDone) }),
            logs: logs,
            plannedBlocks: plannedBlocks,
            calendar: calendar
        )
        .count
    }

    static func tasks(
        on date: Date,
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> [RoutineTask] {
        let matchingIDs = taskIDs(
            on: date,
            taskIDs: tasks.map(\.id),
            lastDoneForTaskID: Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.lastDone) }),
            logs: logs,
            plannedBlocks: plannedBlocks,
            calendar: calendar
        )

        return tasks
            .filter { matchingIDs.contains($0.id) && !$0.isCanceledOneOff }
            .sorted { lhs, rhs in
                let lhsDate = latestCompletionDate(for: lhs.id, fallbackLastDone: lhs.lastDone, logs: logs, on: date, calendar: calendar) ?? .distantPast
                let rhsDate = latestCompletionDate(for: rhs.id, fallbackLastDone: rhs.lastDone, logs: logs, on: date, calendar: calendar) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return DayPlanTaskSorting.title(for: lhs).localizedCaseInsensitiveCompare(DayPlanTaskSorting.title(for: rhs)) == .orderedAscending
            }
    }

    static func taskIDs(
        on date: Date,
        taskIDs: [UUID],
        lastDoneForTaskID: [UUID: Date?],
        logs: [RoutineLog],
        plannedBlocks: [DayPlanBlock],
        calendar: Calendar
    ) -> Set<UUID> {
        let knownTaskIDs = Set(taskIDs)
        var completedIDs = Set<UUID>()

        for log in logs {
            guard knownTaskIDs.contains(log.taskID),
                  log.kind == .completed,
                  let timestamp = log.timestamp,
                  calendar.isDate(timestamp, inSameDayAs: date)
            else { continue }
            completedIDs.insert(log.taskID)
        }

        for (taskID, lastDone) in lastDoneForTaskID {
            guard knownTaskIDs.contains(taskID),
                  let lastDone,
                  calendar.isDate(lastDone, inSameDayAs: date)
            else { continue }
            completedIDs.insert(taskID)
        }

        completedIDs.subtract(Set(plannedBlocks.map(\.taskID)))
        return completedIDs
    }

    private static func latestCompletionDate(
        for taskID: UUID,
        fallbackLastDone: Date?,
        logs: [RoutineLog],
        on date: Date,
        calendar: Calendar
    ) -> Date? {
        let logDate = logs
            .filter { log in
                guard log.taskID == taskID,
                      log.kind == .completed,
                      let timestamp = log.timestamp
                else { return false }
                return calendar.isDate(timestamp, inSameDayAs: date)
            }
            .compactMap(\.timestamp)
            .max()

        guard let fallbackLastDone,
              calendar.isDate(fallbackLastDone, inSameDayAs: date)
        else {
            return logDate
        }

        return max(logDate ?? fallbackLastDone, fallbackLastDone)
    }
}

enum DayPlanFormatting {
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    static func hourText(for hour: Int, on date: Date, calendar: Calendar) -> String {
        timeText(for: hour * 60, on: date, calendar: calendar)
    }

    static func timeText(for minute: Int, on date: Date, calendar: Calendar) -> String {
        let startOfDay = calendar.startOfDay(for: date)
        let clampedMinute = min(max(minute, 0), DayPlanBlock.minutesPerDay)
        let time = calendar.date(byAdding: .minute, value: clampedMinute, to: startOfDay) ?? startOfDay
        return time.formatted(date: .omitted, time: .shortened)
    }
}
