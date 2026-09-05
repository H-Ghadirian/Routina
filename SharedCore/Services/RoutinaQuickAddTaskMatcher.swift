import Foundation

enum RoutinaQuickAddTaskMatcher {
    static func todaySummary(
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        let activeTasks = tasks.filter { task in
            !task.isArchived(referenceDate: referenceDate, calendar: calendar)
                && !task.isCompletedOneOff
                && !task.isCanceledOneOff
        }
        let dueTasks = activeTasks.filter { task in
            !task.isSoftIntervalRoutine
                && RoutineDateMath.daysUntilDue(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) <= 0
        }
        let overdueCount = dueTasks.filter { task in
            RoutineDateMath.daysUntilDue(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) < 0
        }.count

        guard !dueTasks.isEmpty else {
            return "Nothing is due today in Routina."
        }

        let names =
            dueTasks
            .sorted {
                task(
                    $0,
                    ranksBefore: $1,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
            .prefix(3)
            .map(\.displayNameForQuickAdd)
            .joined(separator: ", ")
        let overdueText = overdueCount > 0 ? " \(overdueCount) overdue." : ""
        return "\(dueTasks.count) due today.\(overdueText) Top items: \(names)."
    }

    static func bestTaskMatch(
        named taskName: String?,
        in tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> RoutineTask? {
        if let namedMatch = namedTaskMatch(taskName, in: tasks) {
            return namedMatch
        }

        return
            tasks
            .filter { task in
                !task.isChecklistCompletionRoutine
                    && RoutineDateMath.canMarkDone(
                        for: task,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                    && !task.isCompletedOneOff
                    && !task.isCanceledOneOff
            }
            .min {
                task(
                    $0,
                    ranksBefore: $1,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
    }

    static func focusTaskMatch(
        named taskName: String?,
        in tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> RoutineTask? {
        if let namedMatch = namedTaskMatch(taskName, in: tasks),
            !namedMatch.isArchived(referenceDate: referenceDate, calendar: calendar),
            !namedMatch.isCompletedOneOff,
            !namedMatch.isCanceledOneOff
        {
            return namedMatch
        }

        let candidates = tasks.filter { task in
            !task.isArchived(referenceDate: referenceDate, calendar: calendar)
                && !task.isCompletedOneOff
                && !task.isCanceledOneOff
        }

        return
            candidates
            .filter(\.focusModeEnabled)
            .min {
                task(
                    $0,
                    ranksBefore: $1,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
            ?? candidates.min {
                task(
                    $0,
                    ranksBefore: $1,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
    }

    private static func namedTaskMatch(
        _ taskName: String?,
        in tasks: [RoutineTask]
    ) -> RoutineTask? {
        guard let taskName,
            let normalizedQuery = RoutineTask.normalizedName(taskName)
        else {
            return nil
        }

        let activeTasks = tasks.filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
        if let exact = activeTasks.first(where: {
            RoutineTask.normalizedName($0.name) == normalizedQuery
        }) {
            return exact
        }

        return activeTasks.first { task in
            guard let normalizedName = RoutineTask.normalizedName(task.name) else { return false }
            return normalizedName.contains(normalizedQuery)
        }
    }

    private static func task(
        _ lhs: RoutineTask,
        ranksBefore rhs: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let lhsDueDays = RoutineDateMath.daysUntilDue(
            for: lhs,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let rhsDueDays = RoutineDateMath.daysUntilDue(
            for: rhs,
            referenceDate: referenceDate,
            calendar: calendar
        )
        if lhsDueDays != rhsDueDays {
            return lhsDueDays < rhsDueDays
        }

        let lhsPriorityRank = -lhs.priority.sortOrder
        let rhsPriorityRank = -rhs.priority.sortOrder
        if lhsPriorityRank != rhsPriorityRank {
            return lhsPriorityRank < rhsPriorityRank
        }

        return lhs.displayNameForQuickAdd < rhs.displayNameForQuickAdd
    }
}

extension RoutineTask {
    var displayNameForQuickAdd: String {
        RoutineTask.trimmedName(name).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled task"
    }
}
