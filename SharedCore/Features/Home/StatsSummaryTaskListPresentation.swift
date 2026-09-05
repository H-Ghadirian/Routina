import Foundation

enum StatsSummaryTaskListPresentationBuilder {
    static func build(
        kind: StatsSummaryTaskListKind,
        cardTitle: String,
        tasks: [RoutineTask],
        filteredTaskIDs: Set<UUID>,
        logs: [RoutineLog],
        metrics: StatsFeatureMetrics,
        selectedRange: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> StatsSummaryTaskListPresentation {
        let filteredTasks = tasks.filter { filteredTaskIDs.contains($0.id) }
        let tasksByID = Dictionary(uniqueKeysWithValues: filteredTasks.map { ($0.id, $0) })

        switch kind {
        case .routineCount:
            let matchingTasks = filteredTasks.filter { $0.scheduleMode.taskType == .routine }
            return taskCollectionPresentation(
                kind: kind,
                cardTitle: cardTitle,
                tasks: matchingTasks,
                subtitle: taskCountSubtitle(matchingTasks.count, label: "repeating task"),
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .todoCount:
            let matchingTasks = filteredTasks.filter {
                $0.isOneOffTask && !$0.isCompletedOneOff && !$0.isCanceledOneOff
            }
            return taskCollectionPresentation(
                kind: kind,
                cardTitle: cardTitle,
                tasks: matchingTasks,
                subtitle: taskCountSubtitle(matchingTasks.count, label: "open one-time task"),
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .activeItems:
            let matchingTasks = filteredTasks.filter {
                !$0.isArchived(referenceDate: referenceDate, calendar: calendar)
            }
            return taskCollectionPresentation(
                kind: kind,
                cardTitle: cardTitle,
                tasks: matchingTasks,
                subtitle: taskCountSubtitle(matchingTasks.count, label: "active item"),
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .archivedItems:
            let matchingTasks = filteredTasks.filter {
                $0.isArchived(referenceDate: referenceDate, calendar: calendar)
            }
            return taskCollectionPresentation(
                kind: kind,
                cardTitle: cardTitle,
                tasks: matchingTasks,
                subtitle: taskCountSubtitle(matchingTasks.count, label: "archived item"),
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .activityOverview, .dailyAverage:
            return activityPresentation(
                kind: kind,
                cardTitle: cardTitle,
                tasksByID: tasksByID,
                logs: logs,
                filteredTaskIDs: filteredTaskIDs,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .bestDay:
            return activityPresentation(
                kind: kind,
                cardTitle: cardTitle,
                tasksByID: tasksByID,
                logs: logs,
                filteredTaskIDs: filteredTaskIDs,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar,
                onlyOn: metrics.highlightedBusiestDay?.date
            )

        case .totalDones:
            return outcomePresentation(
                kind: kind,
                cardTitle: cardTitle,
                logKind: .completed,
                outcomeLabel: "recorded completion",
                tasksByID: tasksByID,
                logs: logs,
                filteredTaskIDs: filteredTaskIDs,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .totalCancels:
            return outcomePresentation(
                kind: kind,
                cardTitle: cardTitle,
                logKind: .canceled,
                outcomeLabel: "canceled occurrence",
                tasksByID: tasksByID,
                logs: logs,
                filteredTaskIDs: filteredTaskIDs,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .totalMissed:
            return outcomePresentation(
                kind: kind,
                cardTitle: cardTitle,
                logKind: .missed,
                outcomeLabel: "missed occurrence",
                tasksByID: tasksByID,
                logs: logs,
                filteredTaskIDs: filteredTaskIDs,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .assumedDones, .assumedEstimatedTime:
            return assumedPresentation(
                kind: kind,
                cardTitle: cardTitle,
                filteredTasks: filteredTasks,
                logs: logs.filter { filteredTaskIDs.contains($0.taskID) },
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )

        case .focusTime, .focusAverage:
            return focusPresentation(
                kind: kind,
                cardTitle: cardTitle,
                tasksByID: tasksByID,
                metrics: metrics,
                selectedRange: selectedRange
            )
        }
    }

    private static func activityPresentation(
        kind: StatsSummaryTaskListKind,
        cardTitle: String,
        tasksByID: [UUID: RoutineTask],
        logs: [RoutineLog],
        filteredTaskIDs: Set<UUID>,
        selectedRange: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar,
        onlyOn selectedDay: Date? = nil
    ) -> StatsSummaryTaskListPresentation {
        let matchingLogs = logs.filter { log in
            guard log.kind == .completed || log.kind == .canceled || log.kind == .missed else {
                return false
            }
            guard filteredTaskIDs.contains(log.taskID) else { return false }
            if let selectedDay {
                guard let timestamp = log.timestamp else { return false }
                return calendar.isDate(timestamp, inSameDayAs: selectedDay)
            }
            return dateIsInRange(
                log.timestamp,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let countsByTaskID = matchingLogs.reduce(into: [UUID: OutcomeCounts]()) { counts, log in
            var taskCounts = counts[log.taskID, default: OutcomeCounts()]
            switch log.kind {
            case .completed:
                taskCounts.done += 1
            case .canceled:
                taskCounts.canceled += 1
            case .missed:
                taskCounts.missed += 1
            case .fulfilled:
                break
            }
            counts[log.taskID] = taskCounts
        }
        let rows = countsByTaskID.compactMap { taskID, counts -> (StatsSummaryTaskListRow, Int)? in
            guard let task = tasksByID[taskID] else { return nil }
            return (
                StatsSummaryTaskListRow(
                    id: "task-\(taskID.uuidString)",
                    emoji: displayEmoji(for: task),
                    systemImage: "checklist",
                    title: displayTitle(for: task),
                    detail: counts.detail,
                    value: "\(counts.total.formatted())×"
                ),
                counts.total
            )
        }
        .sorted(by: rankedRowSort)
        .map(\.0)
        let activityCount = matchingLogs.count
        let period =
            selectedDay.map {
                $0.formatted(date: .abbreviated, time: .omitted)
            } ?? selectedRange.periodDescription

        return StatsSummaryTaskListPresentation(
            id: kind.rawValue,
            title: cardTitle,
            subtitle:
                "\(activityCount.formatted()) \(activityCount == 1 ? "activity" : "activities") across \(taskCountText(rows.count)) · \(period)",
            rows: rows
        )
    }

    private static func taskCollectionPresentation(
        kind: StatsSummaryTaskListKind,
        cardTitle: String,
        tasks: [RoutineTask],
        subtitle: String,
        referenceDate: Date,
        calendar: Calendar
    ) -> StatsSummaryTaskListPresentation {
        let rows =
            tasks
            .sorted(by: taskTitleSort)
            .map { task in
                StatsSummaryTaskListRow(
                    id: "task-\(task.id.uuidString)",
                    emoji: displayEmoji(for: task),
                    systemImage: "checklist",
                    title: displayTitle(for: task),
                    detail: taskDetail(
                        for: task,
                        referenceDate: referenceDate,
                        calendar: calendar
                    ),
                    value: nil
                )
            }

        return StatsSummaryTaskListPresentation(
            id: kind.rawValue,
            title: cardTitle,
            subtitle: subtitle,
            rows: rows
        )
    }

    private static func outcomePresentation(
        kind: StatsSummaryTaskListKind,
        cardTitle: String,
        logKind: RoutineLogKind,
        outcomeLabel: String,
        tasksByID: [UUID: RoutineTask],
        logs: [RoutineLog],
        filteredTaskIDs: Set<UUID>,
        selectedRange: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> StatsSummaryTaskListPresentation {
        let matchingLogs = logs.filter { log in
            log.kind == logKind
                && filteredTaskIDs.contains(log.taskID)
                && dateIsInRange(
                    log.timestamp,
                    selectedRange: selectedRange,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
        }
        let countsByTaskID = matchingLogs.reduce(into: [UUID: Int]()) { counts, log in
            counts[log.taskID, default: 0] += 1
        }
        let rows = countsByTaskID.compactMap { taskID, count -> (StatsSummaryTaskListRow, Int)? in
            guard let task = tasksByID[taskID] else { return nil }
            return (
                StatsSummaryTaskListRow(
                    id: "task-\(taskID.uuidString)",
                    emoji: displayEmoji(for: task),
                    systemImage: "checklist",
                    title: displayTitle(for: task),
                    detail: taskTypeLabel(for: task),
                    value: "\(count.formatted())×"
                ),
                count
            )
        }
        .sorted(by: rankedRowSort)
        .map(\.0)
        let occurrenceCount = matchingLogs.count
        let occurrenceNoun = occurrenceCount == 1 ? outcomeLabel : pluralized(outcomeLabel)

        return StatsSummaryTaskListPresentation(
            id: kind.rawValue,
            title: cardTitle,
            subtitle:
                "\(occurrenceCount.formatted()) \(occurrenceNoun) across \(taskCountText(rows.count)) · \(selectedRange.periodDescription)",
            rows: rows
        )
    }

    private static func assumedPresentation(
        kind: StatsSummaryTaskListKind,
        cardTitle: String,
        filteredTasks: [RoutineTask],
        logs: [RoutineLog],
        selectedRange: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> StatsSummaryTaskListPresentation {
        let tasksByID = Dictionary(uniqueKeysWithValues: filteredTasks.map { ($0.id, $0) })
        let summaries = StatsAssumedCompletionTaskSummaryBuilder.summaries(
            tasks: filteredTasks,
            logs: logs,
            selectedRange: selectedRange,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let visibleSummaries =
            kind == .assumedEstimatedTime
            ? summaries.filter { $0.estimatedMinutes > 0 }
            : summaries
        let rows = visibleSummaries.compactMap { summary -> (StatsSummaryTaskListRow, Int)? in
            guard let task = tasksByID[summary.taskID] else { return nil }
            let value =
                kind == .assumedEstimatedTime
                ? durationText(minutes: summary.estimatedMinutes)
                : "\(summary.occurrenceCount.formatted())×"
            let detail =
                kind == .assumedEstimatedTime
                ? "\(summary.occurrenceCount.formatted()) assumed \(summary.occurrenceCount == 1 ? "occurrence" : "occurrences")"
                : taskTypeLabel(for: task)
            return (
                StatsSummaryTaskListRow(
                    id: "task-\(task.id.uuidString)",
                    emoji: displayEmoji(for: task),
                    systemImage: "calendar.badge.checkmark",
                    title: displayTitle(for: task),
                    detail: detail,
                    value: value
                ),
                kind == .assumedEstimatedTime
                    ? summary.estimatedMinutes
                    : summary.occurrenceCount
            )
        }
        .sorted(by: rankedRowSort)
        .map(\.0)
        let occurrenceCount = summaries.reduce(0) { $0 + $1.occurrenceCount }
        let totalMinutes = summaries.reduce(0) { $0 + $1.estimatedMinutes }
        let subtitle: String
        if kind == .assumedEstimatedTime {
            subtitle = "\(durationText(minutes: totalMinutes)) across \(taskCountText(rows.count)) · \(selectedRange.periodDescription)"
        } else {
            subtitle =
                "\(occurrenceCount.formatted()) assumed \(occurrenceCount == 1 ? "occurrence" : "occurrences") across \(taskCountText(rows.count)) · \(selectedRange.periodDescription)"
        }

        return StatsSummaryTaskListPresentation(
            id: kind.rawValue,
            title: cardTitle,
            subtitle: subtitle,
            rows: rows
        )
    }

    private static func focusPresentation(
        kind: StatsSummaryTaskListKind,
        cardTitle: String,
        tasksByID: [UUID: RoutineTask],
        metrics: StatsFeatureMetrics,
        selectedRange: DoneChartRange
    ) -> StatsSummaryTaskListPresentation {
        var contributionsByID: [String: FocusDurationContribution] = [:]

        for point in metrics.focusChartPoints {
            for contribution in point.contributions {
                let key = contribution.id
                if let current = contributionsByID[key] {
                    contributionsByID[key] = FocusDurationContribution(
                        taskID: current.taskID,
                        title: current.title,
                        seconds: current.seconds + contribution.seconds,
                        sessionCount: current.sessionCount + contribution.sessionCount
                    )
                } else {
                    contributionsByID[key] = contribution
                }
            }
        }

        let rows = contributionsByID.values.map { contribution -> (StatsSummaryTaskListRow, TimeInterval) in
            let task = contribution.taskID.flatMap { tasksByID[$0] }
            return (
                StatsSummaryTaskListRow(
                    id: "focus-\(contribution.id)",
                    emoji: task.flatMap(displayEmoji),
                    systemImage: contribution.taskID == nil ? "timer" : "checklist",
                    title: task.map(displayTitle) ?? contribution.title,
                    detail: "\(contribution.sessionCount.formatted()) focus \(contribution.sessionCount == 1 ? "session" : "sessions")",
                    value: durationText(seconds: contribution.seconds)
                ),
                contribution.seconds
            )
        }
        .sorted(by: rankedRowSort)
        .map(\.0)

        let totalDuration = durationText(seconds: metrics.totalFocusSeconds)
        let durationSummary = kind == .focusAverage ? "\(totalDuration) total" : totalDuration

        return StatsSummaryTaskListPresentation(
            id: kind.rawValue,
            title: cardTitle,
            subtitle:
                "\(durationSummary) across \(rows.count.formatted()) focus \(rows.count == 1 ? "source" : "sources") · \(selectedRange.periodDescription)",
            rows: rows
        )
    }

    private struct OutcomeCounts {
        var done = 0
        var canceled = 0
        var missed = 0

        var total: Int { done + canceled + missed }

        var detail: String {
            var parts: [String] = []
            if done > 0 { parts.append("\(done.formatted()) done") }
            if canceled > 0 { parts.append("\(canceled.formatted()) canceled") }
            if missed > 0 { parts.append("\(missed.formatted()) missed") }
            return parts.joined(separator: " · ")
        }
    }
}
