import Foundation

struct StatsFeatureMetrics: Equatable {
    var chartPoints: [DoneChartPoint] = []
    var outcomeMixChartPoints: [OutcomeMixChartPoint] = []
    var createdChartPoints: [DoneChartPoint] = []
    var focusChartPoints: [FocusDurationChartPoint] = []
    var focusWorkChartPoints: [FocusWorkChartPoint] = []
    var hourlyActivityChartPoints: [HourlyActivityChartPoint] = []
    var estimateActualChartPoints: [EstimateActualChartPoint] = []
    var focusWeekdayAveragePoints: [FocusWeekdayAverageChartPoint] = []
    var goalProgressChartPoints: [GoalProgressChartPoint] = []
    var tagUsagePoints: [TagUsageChartPoint] = []
    var totalDoneCount: Int = 0
    var totalCanceledCount: Int = 0
    var totalMissedCount: Int = 0
    var createdTotalCount: Int = 0
    var totalFocusSeconds: TimeInterval = 0
    var averageFocusSecondsPerDay: TimeInterval = 0
    var emotionLogCount: Int = 0
    var emotionActiveDayCount: Int = 0
    var averageEmotionIntensity: Double = 0
    var emotionTrendChartPoints: [EmotionTrendChartPoint] = []
    var noteCount: Int = 0
    var noteWithMediaCount: Int = 0
    var eventCount: Int = 0
    var eventActiveDayCount: Int = 0
    var sleepSessionCount: Int = 0
    var completedSleepSessionCount: Int = 0
    var totalSleepSeconds: TimeInterval = 0
    var sleepActiveDayCount: Int = 0
    var awaySessionCount: Int = 0
    var completedAwaySessionCount: Int = 0
    var endedEarlyAwaySessionCount: Int = 0
    var totalAwaySeconds: TimeInterval = 0
    var awayActiveDayCount: Int = 0
    var activeGoalCount: Int = 0
    var archivedGoalCount: Int = 0
    var goalsCreatedCount: Int = 0
    var routineCount: Int = 0
    var openTodoCount: Int = 0
    var activeRoutineCount: Int = 0
    var archivedRoutineCount: Int = 0
    var totalCount: Int = 0
    var averagePerDay: Double = 0
    var createdAveragePerDay: Double = 0
    var highlightedBusiestDay: DoneChartPoint?
    var highlightedCreatedDay: DoneChartPoint?
    var highlightedFocusDay: FocusDurationChartPoint?
    var highlightedFocusWeekdayAverage: FocusWeekdayAverageChartPoint?
    var activeDayCount: Int = 0
    var createdActiveDayCount: Int = 0
    var focusActiveDayCount: Int = 0
    var chartUpperBound: Double = 1
    var createdChartUpperBound: Double = 1
    var focusChartUpperBound: Double = 1
    var focusWeekdayAverageUpperBound: Double = 1
    var sparklinePoints: [DoneChartPoint] = []
    var sparklineMaxCount: Int = 1
    var xAxisDates: [Date] = []
}

struct StatsFeatureDerivedState: Equatable {
    var availableTags: [String] = []
    var selectedTags: Set<String> = []
    var excludedTags: Set<String> = []
    var tagSummaries: [RoutineTagSummary] = []
    var availableExcludeTags: [String] = []
    var taskCountForSelectedTypeFilter: Int = 0
    var filteredTaskCount: Int = 0
    var metrics = StatsFeatureMetrics()
}

enum StatsFeatureDerivedStateBuilder {
    static func build(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        sprintFocusSessions: [SprintFocusSessionRecord] = [],
        boardSprints: [BoardSprintRecord] = [],
        sleepSessions: [SleepSession] = [],
        awaySessions: [AwaySession] = [],
        emotionLogs: [EmotionLog] = [],
        notes: [RoutineNote] = [],
        events: [RoutineEvent] = [],
        noteAttachmentNoteIDs: Set<UUID> = [],
        goals: [RoutineGoal] = [],
        selectedRange: DoneChartRange,
        taskTypeFilter: StatsTaskTypeFilter,
        createdChartTaskTypeFilter: StatsTaskTypeFilter? = nil,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        advancedQuery: String,
        selectedTags: Set<String>,
        includeTagMatchMode: RoutineTagMatchMode,
        excludedTags: Set<String>,
        excludeTagMatchMode: RoutineTagMatchMode,
        tagColors: [String: String],
        referenceDate: Date,
        calendar: Calendar
    ) -> StatsFeatureDerivedState {
        let normalizedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.normalized(selectedImportanceUrgencyFilter)
        let query = HomeTaskAdvancedQuery<StatsTaskQueryDisplay>(advancedQuery)
        let queryMetrics = HomeTaskListMetrics<StatsTaskQueryDisplay>(
            configuration: HomeTaskListFilteringConfiguration(
                selectedFilter: .all,
                advancedQuery: "",
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil,
                selectedPressureFilter: nil,
                selectedGoalFilter: .all,
                selectedMediaFilter: .all,
                taskListViewMode: .all,
                taskListSortOrder: .smart,
                createdDateFilter: .all,
                selectedTags: [],
                includeTagMatchMode: .all,
                excludedTags: [],
                excludeTagMatchMode: .any,
                searchText: "",
                routineListSectioningMode: .status,
                routineTasks: tasks,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
        let tasksMatchingTaskTypeAndMatrixFilters = taskTypeAndMatrixFilteredTasks(
            tasks: tasks,
            taskTypeFilter: taskTypeFilter,
            selectedImportanceUrgencyFilter: normalizedImportanceUrgencyFilter
        )
        let tasksMatchingQuery = queryMatchedTasks(
            tasks: tasks,
            taskTypeFilter: taskTypeFilter,
            selectedImportanceUrgencyFilter: normalizedImportanceUrgencyFilter,
            query: query,
            queryMetrics: queryMetrics,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let availableTags = RoutineTag.allTags(from: tasksMatchingQuery.map(\.tags))
        let sanitizedSelectedTags = selectedTags.filter { RoutineTag.contains($0, in: availableTags) }
        let availableExcludeTags = availableTags.filter { tag in
            !sanitizedSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
        let sanitizedExcludedTags = excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }
        let sidebarAvailableExcludeTags = RoutineTag.allTags(
            from: tasksMatchingTaskTypeAndMatrixFilters.filter { task in
                HomeDisplayFilterSupport.matchesSelectedTags(
                    sanitizedSelectedTags,
                    mode: includeTagMatchMode,
                    in: task.tags
                )
            }.map(\.tags)
        ).filter { tag in
            !sanitizedSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
        let tagSummaries = RoutineTagColors.applying(
            tagColors,
            to: RoutineTag.summaries(from: tasksMatchingTaskTypeAndMatrixFilters)
        )
        let filteredTasks = tagFilteredTasks(
            tasksMatchingQuery,
            selectedTags: sanitizedSelectedTags,
            includeTagMatchMode: includeTagMatchMode,
            excludedTags: sanitizedExcludedTags,
            excludeTagMatchMode: excludeTagMatchMode
        )
        let filteredTaskIDs = Set(filteredTasks.map(\.id))
        let filteredLogs = logs.filter { filteredTaskIDs.contains($0.taskID) }
        let filteredFocusSessions = focusSessions.filter {
            $0.isUnassigned || filteredTaskIDs.contains($0.taskID)
        }
        let createdChartFilteredTasks: [RoutineTask]
        if let createdChartTaskTypeFilter {
            let tasksMatchingCreatedQuery = queryMatchedTasks(
                tasks: tasks,
                taskTypeFilter: createdChartTaskTypeFilter,
                selectedImportanceUrgencyFilter: normalizedImportanceUrgencyFilter,
                query: query,
                queryMetrics: queryMetrics,
                referenceDate: referenceDate,
                calendar: calendar
            )
            createdChartFilteredTasks = tagFilteredTasks(
                tasksMatchingCreatedQuery,
                selectedTags: sanitizedSelectedTags,
                includeTagMatchMode: includeTagMatchMode,
                excludedTags: sanitizedExcludedTags,
                excludeTagMatchMode: excludeTagMatchMode
            )
        } else {
            createdChartFilteredTasks = []
        }

        let completionDates = filteredLogs
            .filter { $0.kind == .completed }
            .compactMap(\.timestamp)
        let canceledDates = filteredLogs
            .filter { $0.kind == .canceled }
            .compactMap(\.timestamp)
        let missedDates = filteredLogs
            .filter { $0.kind == .missed }
            .compactMap(\.timestamp)
        let activityDates = completionDates + canceledDates + missedDates
        let createdDates = createdChartFilteredTasks.compactMap(\.createdAt)
        let emotionLogsInRange = emotionLogs.filter { emotion in
            dateIsInRange(
                emotion.createdAt,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let notesInRange = notes.filter { note in
            dateIsInRange(
                note.createdAt,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let eventsInRange = events.filter { event in
            dateIsInRange(
                event.startedAt ?? event.createdAt,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let sleepSessionsInRange = sleepSessions.filter { session in
            dateIsInRange(
                session.startedAt,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let awaySessionsInRange = awaySessions.filter { session in
            dateIsInRange(
                session.startedAt ?? session.createdAt,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let goalsCreatedInRange = goals.filter { goal in
            dateIsInRange(
                goal.createdAt,
                selectedRange: selectedRange,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let earliestActivityDate = [
            filteredTasks.compactMap(\.createdAt).min(),
            createdChartFilteredTasks.compactMap(\.createdAt).min(),
            filteredLogs.compactMap(\.timestamp).min(),
            filteredFocusSessions.compactMap(\.startedAt).min(),
            sprintFocusSessions.map(\.startedAt).min(),
            awaySessions.compactMap(\.startedAt).min()
        ].compactMap { $0 }.min()

        let chartPoints: [DoneChartPoint] = RoutineCompletionStats.points(
            for: selectedRange,
            timestamps: activityDates,
            earliestActivityDate: earliestActivityDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let outcomeMixChartPoints = RoutineCompletionStats.outcomePoints(
            for: selectedRange,
            logs: filteredLogs,
            earliestActivityDate: earliestActivityDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let createdChartPoints: [DoneChartPoint]
        if createdChartTaskTypeFilter == nil {
            createdChartPoints = []
        } else {
            createdChartPoints = RoutineCompletionStats.points(
                for: selectedRange,
                timestamps: createdDates,
                earliestActivityDate: earliestActivityDate,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        let focusChartPoints: [FocusDurationChartPoint] = FocusDurationStats.points(
            for: selectedRange,
            sessions: filteredFocusSessions,
            sprintSessions: sprintFocusSessions,
            tasks: filteredTasks,
            boardSprints: boardSprints,
            earliestActivityDate: earliestActivityDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let focusWorkChartPoints = FocusWorkStats.points(
            outcomePoints: outcomeMixChartPoints,
            focusPoints: focusChartPoints
        )
        let hourlyActivityChartPoints = HourlyActivityStats.points(
            tasks: filteredTasks,
            logs: filteredLogs,
            focusSessions: filteredFocusSessions,
            selectedRange: selectedRange,
            earliestActivityDate: earliestActivityDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let estimateActualChartPoints = EstimateActualStats.points(
            tasks: filteredTasks,
            logs: filteredLogs,
            outcomePoints: outcomeMixChartPoints,
            calendar: calendar
        )
        let tagUsagePoints = RoutineCompletionStats.tagUsagePoints(
            tasks: filteredTasks,
            logs: filteredLogs,
            chartPoints: chartPoints,
            tagColors: tagColors,
            calendar: calendar
        )
        let goalProgressChartPoints = GoalProgressStats.points(
            goals: goals,
            tasks: filteredTasks,
            logs: filteredLogs,
            focusSessions: filteredFocusSessions,
            outcomePoints: outcomeMixChartPoints,
            calendar: calendar
        )
        let totalCount = RoutineCompletionStats.totalCount(in: chartPoints)
        let averagePerDay = RoutineCompletionStats.averageCount(in: chartPoints)
        let busiestDay = RoutineCompletionStats.busiestDay(in: chartPoints)
        let createdTotalCount = RoutineCompletionStats.totalCount(in: createdChartPoints)
        let createdAveragePerDay = RoutineCompletionStats.averageCount(in: createdChartPoints)
        let busiestCreatedDay = RoutineCompletionStats.busiestDay(in: createdChartPoints)
        let totalFocusSeconds = FocusDurationStats.totalSeconds(in: focusChartPoints)
        let averageFocusSecondsPerDay = FocusDurationStats.averageSeconds(in: focusChartPoints)
        let busiestFocusDay = FocusDurationStats.busiestDay(in: focusChartPoints)
        let focusWeekdayAveragePoints = FocusDurationStats.weekdayAveragePoints(
            from: focusChartPoints,
            calendar: calendar
        )
        let strongestFocusWeekdayAverage = FocusDurationStats.strongestWeekdayAverage(
            in: focusWeekdayAveragePoints
        )
        let emotionActiveDayCount = Set(
            emotionLogsInRange
                .compactMap(\.createdAt)
                .map { calendar.startOfDay(for: $0) }
        ).count
        let averageEmotionIntensity = emotionLogsInRange.isEmpty
            ? 0
            : Double(emotionLogsInRange.reduce(0) { $0 + $1.clampedIntensity }) / Double(emotionLogsInRange.count)
        let emotionTrendChartPoints = EmotionTrendStats.points(
            emotionLogs: emotionLogsInRange,
            calendar: calendar
        )
        let noteWithMediaCount = notesInRange.filter {
            $0.hasImage || $0.hasVoiceNote || noteAttachmentNoteIDs.contains($0.id)
        }.count
        let eventActiveDayCount = Set(
            eventsInRange
                .compactMap { $0.startedAt ?? $0.createdAt }
                .map { calendar.startOfDay(for: $0) }
        ).count
        let totalSleepSeconds = sleepSessionsInRange.reduce(0) { total, session in
            total + session.durationSeconds(referenceDate: referenceDate)
        }
        let sleepActiveDayCount = Set(
            sleepSessionsInRange
                .compactMap(\.startedAt)
                .map { calendar.startOfDay(for: $0) }
        ).count
        let completedSleepSessionCount = sleepSessionsInRange.filter { !$0.isActive }.count
        let totalAwaySeconds = awaySessionsInRange.reduce(0) { total, session in
            total + session.durationSeconds(referenceDate: referenceDate)
        }
        let awayActiveDayCount = Set(
            awaySessionsInRange
                .compactMap(\.startedAt)
                .map { calendar.startOfDay(for: $0) }
        ).count
        let completedAwaySessionCount = awaySessionsInRange.filter { $0.state == .completed }.count
        let endedEarlyAwaySessionCount = awaySessionsInRange.filter { $0.state == .endedEarly }.count
        let activeGoalCount = goals.filter { $0.status == .active }.count
        let archivedGoalCount = goals.filter { $0.status == .archived }.count
        let routineCount = filteredTasks.filter { !$0.isOneOffTask }.count
        let openTodoCount = filteredTasks.filter {
            $0.isOneOffTask && !$0.isCompletedOneOff && !$0.isCanceledOneOff
        }.count
        let archiveCounts = taskArchiveCounts(
            filteredTasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let sparklinePoints = sampledSparklinePoints(
            from: chartPoints,
            for: selectedRange,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let maxCount = chartPoints.map(\.count).max() ?? 0
        let maxCreatedCount = createdChartPoints.map(\.count).max() ?? 0
        let maxFocusMinutes = focusChartPoints.map(\.minutes).max() ?? 0
        let maxFocusWeekdayAverageMinutes = focusWeekdayAveragePoints.map(\.minutes).max() ?? 0

        return StatsFeatureDerivedState(
            availableTags: availableTags,
            selectedTags: sanitizedSelectedTags,
            excludedTags: sanitizedExcludedTags,
            tagSummaries: tagSummaries,
            availableExcludeTags: sidebarAvailableExcludeTags,
            taskCountForSelectedTypeFilter: tasksMatchingTaskTypeAndMatrixFilters.count,
            filteredTaskCount: filteredTasks.count,
            metrics: StatsFeatureMetrics(
                chartPoints: chartPoints,
                outcomeMixChartPoints: outcomeMixChartPoints,
                createdChartPoints: createdChartPoints,
                focusChartPoints: focusChartPoints,
                focusWorkChartPoints: focusWorkChartPoints,
                hourlyActivityChartPoints: hourlyActivityChartPoints,
                estimateActualChartPoints: estimateActualChartPoints,
                focusWeekdayAveragePoints: focusWeekdayAveragePoints,
                goalProgressChartPoints: goalProgressChartPoints,
                tagUsagePoints: tagUsagePoints,
                totalDoneCount: completionDates.count,
                totalCanceledCount: canceledDates.count,
                totalMissedCount: missedDates.count,
                createdTotalCount: createdTotalCount,
                totalFocusSeconds: totalFocusSeconds,
                averageFocusSecondsPerDay: averageFocusSecondsPerDay,
                emotionLogCount: emotionLogsInRange.count,
                emotionActiveDayCount: emotionActiveDayCount,
                averageEmotionIntensity: averageEmotionIntensity,
                emotionTrendChartPoints: emotionTrendChartPoints,
                noteCount: notesInRange.count,
                noteWithMediaCount: noteWithMediaCount,
                eventCount: eventsInRange.count,
                eventActiveDayCount: eventActiveDayCount,
                sleepSessionCount: sleepSessionsInRange.count,
                completedSleepSessionCount: completedSleepSessionCount,
                totalSleepSeconds: totalSleepSeconds,
                sleepActiveDayCount: sleepActiveDayCount,
                awaySessionCount: awaySessionsInRange.count,
                completedAwaySessionCount: completedAwaySessionCount,
                endedEarlyAwaySessionCount: endedEarlyAwaySessionCount,
                totalAwaySeconds: totalAwaySeconds,
                awayActiveDayCount: awayActiveDayCount,
                activeGoalCount: activeGoalCount,
                archivedGoalCount: archivedGoalCount,
                goalsCreatedCount: goalsCreatedInRange.count,
                routineCount: routineCount,
                openTodoCount: openTodoCount,
                activeRoutineCount: archiveCounts.active,
                archivedRoutineCount: archiveCounts.archived,
                totalCount: totalCount,
                averagePerDay: averagePerDay,
                createdAveragePerDay: createdAveragePerDay,
                highlightedBusiestDay: (busiestDay?.count ?? 0) > 0 ? busiestDay : nil,
                highlightedCreatedDay: (busiestCreatedDay?.count ?? 0) > 0 ? busiestCreatedDay : nil,
                highlightedFocusDay: (busiestFocusDay?.seconds ?? 0) > 0 ? busiestFocusDay : nil,
                highlightedFocusWeekdayAverage: (strongestFocusWeekdayAverage?.seconds ?? 0) > 0
                    ? strongestFocusWeekdayAverage
                    : nil,
                activeDayCount: chartPoints.filter { $0.count > 0 }.count,
                createdActiveDayCount: createdChartPoints.filter { $0.count > 0 }.count,
                focusActiveDayCount: focusChartPoints.filter { $0.seconds > 0 }.count,
                chartUpperBound: Double(max(maxCount, Int(ceil(averagePerDay))) + 1),
                createdChartUpperBound: Double(max(maxCreatedCount, Int(ceil(createdAveragePerDay))) + 1),
                focusChartUpperBound: max(10, ceil(max(maxFocusMinutes, averageFocusSecondsPerDay / 60)) + 5),
                focusWeekdayAverageUpperBound: max(10, ceil(maxFocusWeekdayAverageMinutes) + 5),
                sparklinePoints: sparklinePoints,
                sparklineMaxCount: max(sparklinePoints.map(\.count).max() ?? 0, 1),
                xAxisDates: makeXAxisDates(from: chartPoints, for: selectedRange, calendar: calendar)
            )
        )
    }

    private static func taskTypeAndMatrixFilteredTasks(
        tasks: [RoutineTask],
        taskTypeFilter: StatsTaskTypeFilter,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    ) -> [RoutineTask] {
        StatsTaskTypeMatrixFilterSupport.filteredTasks(
            tasks,
            taskTypeFilter: taskTypeFilter,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter
        )
    }

    private static func queryMatchedTasks(
        tasks: [RoutineTask],
        taskTypeFilter: StatsTaskTypeFilter,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        query: HomeTaskAdvancedQuery<StatsTaskQueryDisplay>,
        queryMetrics: HomeTaskListMetrics<StatsTaskQueryDisplay>,
        referenceDate: Date,
        calendar: Calendar
    ) -> [RoutineTask] {
        let tasksMatchingMatrixFilter = taskTypeAndMatrixFilteredTasks(
            tasks: tasks,
            taskTypeFilter: taskTypeFilter,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter
        )

        guard !query.isEmpty else {
            return tasksMatchingMatrixFilter
        }

        let queryDisplays = tasksMatchingMatrixFilter.map {
            StatsTaskQueryDisplay(task: $0, referenceDate: referenceDate, calendar: calendar)
        }
        let queryMatchedTaskIDs = Set(queryDisplays.filter { query.matches($0, metrics: queryMetrics) }.map(\.taskID))

        return tasksMatchingMatrixFilter.filter { queryMatchedTaskIDs.contains($0.id) }
    }

    private static func tagFilteredTasks(
        _ tasks: [RoutineTask],
        selectedTags: Set<String>,
        includeTagMatchMode: RoutineTagMatchMode,
        excludedTags: Set<String>,
        excludeTagMatchMode: RoutineTagMatchMode
    ) -> [RoutineTask] {
        let includeFilteredTasks = tasks.filter { task in
            HomeDisplayFilterSupport.matchesSelectedTags(
                selectedTags,
                mode: includeTagMatchMode,
                in: task.tags
            )
        }

        return includeFilteredTasks.filter { task in
            HomeDisplayFilterSupport.matchesExcludedTags(
                excludedTags,
                mode: excludeTagMatchMode,
                in: task.tags
            )
        }
    }

    private static func taskArchiveCounts(
        _ tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> (active: Int, archived: Int) {
        tasks.reduce(into: (active: 0, archived: 0)) { counts, task in
            if task.isArchived(referenceDate: referenceDate, calendar: calendar) {
                counts.archived += 1
            } else {
                counts.active += 1
            }
        }
    }

    private static func sampledSparklinePoints(
        from chartPoints: [DoneChartPoint],
        for range: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> [DoneChartPoint] {
        switch range {
        case .today, .week:
            return chartPoints
        case .month:
            return bucketedSparklinePoints(from: chartPoints, bucketSize: 7)
        case .year:
            return monthlySparklinePoints(
                from: chartPoints,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    private static func bucketedSparklinePoints(
        from chartPoints: [DoneChartPoint],
        bucketSize: Int
    ) -> [DoneChartPoint] {
        guard chartPoints.count > bucketSize, bucketSize > 1 else {
            return chartPoints
        }

        return stride(from: 0, to: chartPoints.count, by: bucketSize).map { startIndex in
            let endIndex = min(startIndex + bucketSize, chartPoints.count)
            let bucket = chartPoints[startIndex..<endIndex]

            return DoneChartPoint(
                date: bucket.first?.date ?? chartPoints[startIndex].date,
                count: bucket.reduce(0) { $0 + $1.count }
            )
        }
    }

    private static func monthlySparklinePoints(
        from chartPoints: [DoneChartPoint],
        referenceDate: Date,
        calendar: Calendar
    ) -> [DoneChartPoint] {
        var countsByMonth: [Date: Int] = [:]

        for point in chartPoints {
            let monthStart = calendar.dateInterval(of: .month, for: point.date)?.start
                ?? calendar.startOfDay(for: point.date)
            countsByMonth[monthStart, default: 0] += point.count
        }

        let endMonth = calendar.dateInterval(of: .month, for: referenceDate)?.start
            ?? calendar.startOfDay(for: referenceDate)
        let startMonth = calendar.date(byAdding: .month, value: -11, to: endMonth) ?? endMonth
        let monthOrder = (0..<12).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: startMonth)
        }

        return monthOrder.map { monthStart in
            DoneChartPoint(
                date: monthStart,
                count: countsByMonth[monthStart, default: 0]
            )
        }
    }

    private static func makeXAxisDates(
        from chartPoints: [DoneChartPoint],
        for range: DoneChartRange,
        calendar: Calendar
    ) -> [Date] {
        switch range {
        case .today:
            return chartPoints.map(\.date)

        case .week:
            return chartPoints.map(\.date)

        case .month:
            return chartPoints.enumerated().compactMap { index, point in
                if index == 0 || index == chartPoints.count - 1 || index.isMultiple(of: 5) {
                    return point.date
                }
                return nil
            }

        case .year:
            let firstDate = chartPoints.first?.date
            let lastDate = chartPoints.last?.date

            return chartPoints.compactMap { point in
                let day = calendar.component(.day, from: point.date)
                if point.date == firstDate || point.date == lastDate || day == 1 {
                    return point.date
                }
                return nil
            }
        }
    }

    private static func dateIsInRange(
        _ date: Date?,
        selectedRange: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let date else { return false }
        let endDate = calendar.startOfDay(for: referenceDate)
        guard let startDate = calendar.date(
            byAdding: .day,
            value: -(selectedRange.trailingDayCount - 1),
            to: endDate
        ) else {
            return false
        }
        let day = calendar.startOfDay(for: date)

        return day >= startDate && day <= endDate
    }
}

private struct StatsTaskQueryDisplay: HomeTaskListDisplay {
    let taskID: UUID
    let name: String
    let emoji: String
    let notes: String?
    let placeID: UUID?
    let placeIDs: [UUID]
    let placeName: String?
    let tags: [String]
    let goalTitles: [String]
    let interval: Int
    let recurrenceRule: RoutineRecurrenceRule
    let scheduleMode: RoutineScheduleMode
    let createdAt: Date?
    let lastDone: Date?
    let dueDate: Date?
    let priority: RoutineTaskPriority
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let pressure: RoutineTaskPressure
    let scheduleAnchor: Date?
    let pausedAt: Date?
    let pinnedAt: Date?
    let daysUntilDue: Int
    let hasMissedExactTimedOccurrence: Bool
    let isOneOffTask: Bool
    let isCompletedOneOff: Bool
    let isCanceledOneOff: Bool
    let isDoneToday: Bool
    let isPaused: Bool
    let isPinned: Bool
    let isInProgress: Bool
    let completedChecklistItemCount: Int
    let manualSectionOrders: [String: Int]
    let todoState: TodoState?

    init(task: RoutineTask, referenceDate: Date, calendar: Calendar) {
        let dueDate = RoutineDateMath.upcomingDueDate(for: task, referenceDate: referenceDate, calendar: calendar)

        self.taskID = task.id
        self.name = task.name ?? "Untitled"
        self.emoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "•"
        self.notes = CalendarTaskImportSupport.displayNotes(from: task.notes)
        self.placeID = task.placeID
        self.placeIDs = task.placeIDs
        self.placeName = nil
        self.tags = task.tags
        self.goalTitles = []
        self.interval = Int(task.interval)
        self.recurrenceRule = task.recurrenceRule
        self.scheduleMode = task.scheduleMode
        self.createdAt = task.createdAt
        self.lastDone = task.lastDone
        self.dueDate = dueDate
        self.priority = task.priority
        self.importance = task.importance
        self.urgency = task.urgency
        self.pressure = task.pressure
        self.scheduleAnchor = task.scheduleAnchor
        self.pausedAt = task.pausedAt
        self.pinnedAt = task.pinnedAt
        self.daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0
        self.hasMissedExactTimedOccurrence = RoutineDateMath.missedExactTimedOccurrenceDate(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) != nil
        self.isOneOffTask = task.isOneOffTask
        self.isCompletedOneOff = task.isCompletedOneOff
        self.isCanceledOneOff = task.isCanceledOneOff
        self.isDoneToday = task.lastDone.map { calendar.isDate($0, inSameDayAs: referenceDate) } ?? false
        self.isPaused = task.isPaused
        self.isPinned = task.isPinned
        self.isInProgress = task.isInProgress
        self.completedChecklistItemCount = task.completedChecklistItemCount
        self.manualSectionOrders = task.manualSectionOrders
        self.todoState = task.todoState
    }
}
