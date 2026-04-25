import Foundation

struct HomeTaskListPredicate<Display: HomeTaskListDisplay> {
    var configuration: HomeTaskListFilteringConfiguration
    var metrics: HomeTaskListMetrics<Display>
    var matchesCurrentTaskListMode: (Display) -> Bool

    func matchesVisibleTask(_ task: Display) -> Bool {
        matchesCurrentTaskListMode(task)
            && matchesSearch(task)
            && matchesFilter(task)
            && matchesTaskListViewMode(task)
            && matchesManualPlaceFilter(task)
            && matchesTodoStateFilter(task)
            && matchesImportanceUrgencyFilter(task)
            && matchesSelectedTags(task)
            && matchesExcludedTags(task)
    }

    func matchesArchivedTask(_ task: Display, includePinned: Bool) -> Bool {
        matchesCurrentTaskListMode(task)
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
            && (includePinned || !task.isPinned)
            && matchesTaskListViewMode(task)
            && matchesSearch(task)
            && matchesManualPlaceFilter(task)
            && matchesTodoStateFilter(task)
            && matchesImportanceUrgencyFilter(task)
            && matchesSelectedTags(task)
            && matchesExcludedTags(task)
    }

    func matchesSearch(_ task: Display) -> Bool {
        let trimmedSearch = configuration.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return task.name.localizedCaseInsensitiveContains(trimmedSearch)
            || task.emoji.localizedCaseInsensitiveContains(trimmedSearch)
            || (task.notes?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || (task.placeName?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || RoutineTag.matchesQuery(trimmedSearch, in: task.tags)
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
        return task.placeID == selectedManualPlaceFilterID
    }

    func matchesTodoStateFilter(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesTodoStateFilter(
            configuration.selectedTodoStateFilter,
            isOneOffTask: task.isOneOffTask,
            todoState: task.todoState
        )
    }

    func matchesTaskListViewMode(_ task: Display) -> Bool {
        switch configuration.taskListViewMode {
        case .all:
            return true
        case .actionable:
            return !HomeDisplayFilterSupport.hasActiveRelationshipBlocker(
                taskID: task.taskID,
                tasks: configuration.routineTasks,
                referenceDate: configuration.referenceDate,
                calendar: configuration.calendar
            )
        }
    }

    private func matchesImportanceUrgencyFilter(_ task: Display) -> Bool {
        HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            configuration.selectedImportanceUrgencyFilter,
            importance: task.importance,
            urgency: task.urgency
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
}
