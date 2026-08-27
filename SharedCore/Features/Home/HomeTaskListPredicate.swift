import Foundation

struct HomeTaskListPredicate<Display: HomeTaskListDisplay> {
    var configuration: HomeTaskListFilteringConfiguration
    var metrics: HomeTaskListMetrics<Display>
    var matchesCurrentTaskListMode: (Display) -> Bool
    private let normalizedSearchQuery: String?

    init(
        configuration: HomeTaskListFilteringConfiguration,
        metrics: HomeTaskListMetrics<Display>,
        matchesCurrentTaskListMode: @escaping (Display) -> Bool
    ) {
        self.configuration = configuration
        self.metrics = metrics
        self.matchesCurrentTaskListMode = matchesCurrentTaskListMode
        self.normalizedSearchQuery = HomeTaskSearchIndex.query(configuration.searchText)
    }

    func matchesVisibleTask(_ task: Display) -> Bool {
        !Task.isCancelled
            && matchesCurrentTaskListMode(task)
            && matchesTaskListVisibilityRules(task)
            && matchesSearch(task)
            && matchesAdvancedQuery(task)
            && matchesFilter(task)
            && matchesTaskListViewMode(task)
            && matchesManualPlaceFilter(task)
            && matchesTodoStateFilter(task)
            && matchesPressureFilter(task)
            && matchesThinkingNeededFilter(task)
            && matchesGoalFilter(task)
            && matchesMediaFilter(task)
            && matchesEstimationFilter(task)
            && matchesAssumedDoneFilter(task)
            && matchesCreatedDateFilter(task)
            && matchesImportanceUrgencyFilter(task)
            && matchesSelectedTags(task)
            && matchesSelectedFlags(task)
            && matchesExcludedFlags(task)
            && matchesExcludedTags(task)
    }

    func matchesSearchFallbackTask(_ task: Display) -> Bool {
        !Task.isCancelled
            && matchesCurrentTaskListMode(task)
            && matchesSearch(task)
            && matchesAdvancedQuery(task)
            && matchesFilter(task)
            && matchesTaskListViewMode(task)
            && matchesManualPlaceFilter(task)
            && matchesTodoStateFilter(task)
            && matchesPressureFilter(task)
            && matchesThinkingNeededFilter(task)
            && matchesGoalFilter(task)
            && matchesMediaFilter(task)
            && matchesEstimationFilter(task)
            && matchesAssumedDoneFilter(task)
            && matchesCreatedDateFilter(task)
            && matchesImportanceUrgencyFilter(task)
            && matchesSelectedTags(task)
            && matchesSelectedFlags(task)
            && matchesExcludedTags(task)
    }

    func matchesArchivedTask(_ task: Display, includePinned: Bool) -> Bool {
        !Task.isCancelled
            && matchesCurrentTaskListMode(task)
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
            && (includePinned || !task.isPinned)
            && matchesTaskListVisibilityRules(task)
            && matchesTaskListViewMode(task)
            && matchesSearch(task)
            && matchesAdvancedQuery(task)
            && matchesManualPlaceFilter(task)
            && matchesTodoStateFilter(task)
            && matchesPressureFilter(task)
            && matchesThinkingNeededFilter(task)
            && matchesGoalFilter(task)
            && matchesMediaFilter(task)
            && matchesEstimationFilter(task)
            && matchesAssumedDoneFilter(task)
            && matchesCreatedDateFilter(task)
            && matchesImportanceUrgencyFilter(task)
            && matchesSelectedTags(task)
            && matchesSelectedFlags(task)
            && matchesExcludedTags(task)
    }

    func matchesSearch(_ task: Display) -> Bool {
        guard !Task.isCancelled else { return false }
        guard let normalizedSearchQuery else { return true }
        return (task.indexedSearchText ?? HomeTaskSearchIndex.make(for: task))
            .contains(normalizedSearchQuery)
    }

    func matchesTaskListVisibilityRules(_ task: Display) -> Bool {
        !RoutineFlagRules.hidesFromTaskLists(
            flags: task.flags,
            rules: configuration.flagRules
        )
    }

    func matchesFlagRuleRevealTask(_ task: Display) -> Bool {
        guard !Task.isCancelled,
              !matchesTaskListVisibilityRules(task),
              matchesSearchFallbackTask(task) else {
            return false
        }

        return normalizedSearchQuery != nil
            || !configuration.selectedFlags.isEmpty
    }

    func matchesAdvancedQuery(_ task: Display) -> Bool {
        HomeTaskAdvancedQuery(configuration.advancedQuery).matches(task, metrics: metrics)
    }

    func matchesFilter(_ task: Display) -> Bool {
        switch configuration.selectedFilter {
        case .all:
            return true
        case .due:
            return !task.isDoneToday && (metrics.urgencyLevel(for: task) > 0 || metrics.isYellowUrgency(task))
        case .onMyMind:
            return !task.isDoneToday && task.pressure != .none
        case .todos:
            return task.isOneOffTask
        case .doneToday:
            return task.isDoneToday
        }
    }

    func matchesManualPlaceFilter(_ task: Display) -> Bool {
        guard let selectedManualPlaceFilterID = configuration.selectedManualPlaceFilterID else { return true }
        return task.placeIDs.contains(selectedManualPlaceFilterID)
    }

    func matchesTodoStateFilter(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesTodoStateFilter(
            configuration.selectedTodoStateFilter,
            isOneOffTask: task.isOneOffTask,
            todoState: task.todoState
        )
    }

    func matchesPressureFilter(_ task: Display) -> Bool {
        let pressure = configuration.taskLadderFilterValueMode == .now
            ? task.currentTaskLadderPressure
            : task.pressure
        if configuration.taskLadderFilterValueMode == .now {
            return HomeDisplayFilterSupport.matchesMinimumPressureFilter(
                configuration.selectedPressureFilter,
                pressure: pressure
            )
        }
        return HomeDisplayFilterSupport.matchesPressureFilter(
            configuration.selectedPressureFilter,
            pressure: pressure
        )
    }

    func matchesThinkingNeededFilter(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesThinkingNeededFilter(
            configuration.selectedThinkingNeededFilter,
            thinkingNeeded: task.thinkingNeeded
        )
    }

    func matchesGoalFilter(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesGoalFilter(
            configuration.selectedGoalFilter,
            goalTitles: task.goalTitles
        )
    }

    func matchesMediaFilter(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesMediaFilter(
            configuration.selectedMediaFilter,
            hasImage: task.hasImage,
            hasFileAttachment: task.hasFileAttachment
        )
    }

    func matchesEstimationFilter(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesEstimationFilter(
            configuration.selectedEstimationFilter,
            estimatedDurationMinutes: task.estimatedDurationMinutes
        )
    }

    func matchesAssumedDoneFilter(_ task: Display) -> Bool {
        !configuration.hideAssumedDoneTasks || !task.isAssumedDoneToday
    }

    func matchesCreatedDateFilter(_ task: Display) -> Bool {
        switch configuration.createdDateFilter {
        case .all:
            return true
        case .today:
            guard let createdAt = task.createdAt else { return false }
            return configuration.calendar.isDate(createdAt, inSameDayAs: configuration.referenceDate)
        case .yesterday:
            guard let createdAt = task.createdAt,
                  let yesterday = configuration.calendar.date(byAdding: .day, value: -1, to: configuration.referenceDate)
            else { return false }
            return configuration.calendar.isDate(createdAt, inSameDayAs: yesterday)
        case .last7Days:
            return matchesCreatedWithinDays(7, task: task)
        case .last30Days:
            return matchesCreatedWithinDays(30, task: task)
        }
    }

    private func matchesCreatedWithinDays(_ days: Int, task: Display) -> Bool {
        guard let createdAt = task.createdAt else { return false }
        let createdDay = configuration.calendar.startOfDay(for: createdAt)
        let referenceDay = configuration.calendar.startOfDay(for: configuration.referenceDate)
        guard let lowerBound = configuration.calendar.date(byAdding: .day, value: -(days - 1), to: referenceDay) else {
            return false
        }
        return createdDay >= lowerBound && createdDay <= referenceDay
    }

    func matchesTaskListViewMode(_ task: Display) -> Bool {
        switch configuration.taskListViewMode {
        case .all:
            return true
        case .actionable:
            return !task.hasActiveRelationshipBlocker
        }
    }

    private func matchesImportanceUrgencyFilter(_ task: Display) -> Bool {
        let importance = configuration.taskLadderFilterValueMode == .now
            ? task.currentTaskLadderImportance
            : task.importance
        let urgency = configuration.taskLadderFilterValueMode == .now
            ? task.currentTaskLadderUrgency
            : task.urgency
        return HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            configuration.selectedImportanceUrgencyFilter,
            importance: importance,
            urgency: urgency
        )
    }

    private func matchesSelectedTags(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesSelectedTags(
            configuration.selectedTags,
            mode: configuration.includeTagMatchMode,
            in: task.tags
        )
    }

    private func matchesExcludedTags(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesExcludedTags(
            configuration.excludedTags,
            mode: configuration.excludeTagMatchMode,
            in: task.tags
        )
    }

    private func matchesSelectedFlags(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesSelectedFlags(
            configuration.selectedFlags,
            mode: configuration.includeFlagMatchMode,
            in: task.flags
        )
    }

    private func matchesExcludedFlags(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesExcludedFlags(
            configuration.excludedFlags,
            mode: configuration.excludeFlagMatchMode,
            in: task.flags
        )
    }
}
