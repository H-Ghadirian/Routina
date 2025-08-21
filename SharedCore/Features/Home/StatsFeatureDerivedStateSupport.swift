import Foundation

struct StatsFeatureMetrics: Equatable {
    var chartPoints: [DoneChartPoint] = []
    var createdChartPoints: [DoneChartPoint] = []
    var focusChartPoints: [FocusDurationChartPoint] = []
    var tagUsagePoints: [TagUsageChartPoint] = []
    var totalDoneCount: Int = 0
    var totalCanceledCount: Int = 0
    var createdTotalCount: Int = 0
    var totalFocusSeconds: TimeInterval = 0
    var averageFocusSecondsPerDay: TimeInterval = 0
    var activeRoutineCount: Int = 0
    var archivedRoutineCount: Int = 0
    var totalCount: Int = 0
    var averagePerDay: Double = 0
    var createdAveragePerDay: Double = 0
    var highlightedBusiestDay: DoneChartPoint?
    var highlightedCreatedDay: DoneChartPoint?
    var highlightedFocusDay: FocusDurationChartPoint?
    var activeDayCount: Int = 0
    var createdActiveDayCount: Int = 0
    var focusActiveDayCount: Int = 0
    var chartUpperBound: Double = 1
    var createdChartUpperBound: Double = 1
    var focusChartUpperBound: Double = 1
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
        let query = HomeTaskAdvancedQuery<StatsTaskQueryDisplay>(advancedQuery)
        let queryMetrics = HomeTaskListMetrics<StatsTaskQueryDisplay>(
            configuration: HomeTaskListFilteringConfiguration(
                selectedFilter: .all,
                advancedQuery: "",
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil,
                selectedPressureFilter: nil,
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
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter
        )
        let tasksMatchingQuery = queryMatchedTasks(
            tasks: tasks,
            taskTypeFilter: taskTypeFilter,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
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
        let filteredFocusSessions = focusSessions.filter { filteredTaskIDs.contains($0.taskID) }
        let createdChartFilteredTasks: [RoutineTask]
        if let createdChartTaskTypeFilter {
            let tasksMatchingCreatedQuery = queryMatchedTasks(
                tasks: tasks,
                taskTypeFilter: createdChartTaskTypeFilter,
                selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
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
        let createdDates = createdChartFilteredTasks.compactMap(\.createdAt)
        let earliestActivityDate = [
            filteredTasks.compactMap(\.createdAt).min(),
            createdChartFilteredTasks.compactMap(\.createdAt).min(),
            filteredLogs.compactMap(\.timestamp).min(),
            filteredFocusSessions.compactMap(\.startedAt).min()
        ].compactMap { $0 }.min()

        let chartPoints: [DoneChartPoint] = RoutineCompletionStats.points(
            for: selectedRange,
            timestamps: completionDates,
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
            earliestActivityDate: earliestActivityDate,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let tagUsagePoints = RoutineCompletionStats.tagUsagePoints(
            tasks: filteredTasks,
            logs: filteredLogs,
            chartPoints: chartPoints,
            tagColors: tagColors,
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
        let archiveCounts = taskArchiveCounts(
            filteredTasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let sparklinePoints = sampledSparklinePoints(
            from: chartPoints,
            for: selectedRange
        )
        let maxCount = chartPoints.map(\.count).max() ?? 0
        let maxCreatedCount = createdChartPoints.map(\.count).max() ?? 0
        let maxFocusMinutes = focusChartPoints.map(\.minutes).max() ?? 0

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
                createdChartPoints: createdChartPoints,
                focusChartPoints: focusChartPoints,
                tagUsagePoints: tagUsagePoints,
                totalDoneCount: completionDates.count,
                totalCanceledCount: canceledDates.count,
                createdTotalCount: createdTotalCount,
                totalFocusSeconds: totalFocusSeconds,
                averageFocusSecondsPerDay: averageFocusSecondsPerDay,
                activeRoutineCount: archiveCounts.active,
                archivedRoutineCount: archiveCounts.archived,
                totalCount: totalCount,
                averagePerDay: averagePerDay,
                createdAveragePerDay: createdAveragePerDay,
                highlightedBusiestDay: (busiestDay?.count ?? 0) > 0 ? busiestDay : nil,
                highlightedCreatedDay: (busiestCreatedDay?.count ?? 0) > 0 ? busiestCreatedDay : nil,
                highlightedFocusDay: (busiestFocusDay?.seconds ?? 0) > 0 ? busiestFocusDay : nil,
                activeDayCount: chartPoints.filter { $0.count > 0 }.count,
                createdActiveDayCount: createdChartPoints.filter { $0.count > 0 }.count,
                focusActiveDayCount: focusChartPoints.filter { $0.seconds > 0 }.count,
                chartUpperBound: Double(max(maxCount, Int(ceil(averagePerDay))) + 1),
                createdChartUpperBound: Double(max(maxCreatedCount, Int(ceil(createdAveragePerDay))) + 1),
                focusChartUpperBound: max(10, ceil(max(maxFocusMinutes, averageFocusSecondsPerDay / 60)) + 5),
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
        tasks.filter { task in
            switch taskTypeFilter {
            case .all:
                return true
            case .routines:
                return !task.isOneOffTask
            case .todos:
                return task.isOneOffTask
            }
        }.filter { task in
            HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
                selectedImportanceUrgencyFilter,
                importance: task.importance,
                urgency: task.urgency
            )
        }
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
        for range: DoneChartRange
    ) -> [DoneChartPoint] {
        let targetCount: Int

        switch range {
        case .today:
            targetCount = 1
        case .week:
            targetCount = 7
        case .month:
            targetCount = 15
        case .year:
            targetCount = 24
        }

        guard chartPoints.count > targetCount, targetCount > 1 else {
            return chartPoints
        }

        let step = Double(chartPoints.count - 1) / Double(targetCount - 1)

        return (0..<targetCount).map { index in
            let pointIndex = min(Int((Double(index) * step).rounded()), chartPoints.count - 1)
            return chartPoints[pointIndex]
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
}

private struct StatsTaskQueryDisplay: HomeTaskListDisplay {
    let taskID: UUID
    let name: String
    let emoji: String
    let notes: String?
    let placeID: UUID?
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
        let dueDate = RoutineDateMath.dueDate(for: task, referenceDate: referenceDate, calendar: calendar)

        self.taskID = task.id
        self.name = task.name ?? "Untitled"
        self.emoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "•"
        self.notes = CalendarTaskImportSupport.displayNotes(from: task.notes)
        self.placeID = task.placeID
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
