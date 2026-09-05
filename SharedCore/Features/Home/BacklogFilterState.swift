import Foundation

enum BacklogSortOrder: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case defaultOrder = "Default"
    case dueSoonestFirst = "Due Soonest"
    case dueLatestFirst = "Due Latest"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .defaultOrder:
            return "list.bullet"
        case .dueSoonestFirst:
            return "calendar.badge.clock"
        case .dueLatestFirst:
            return "calendar"
        }
    }
}

enum BacklogDueDateFilter: String, CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case all = "All"
    case hasDueDate = "Has Due Date"
    case dueToday = "Due Today"
    case overdue = "Overdue"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "calendar"
        case .hasDueDate:
            return "calendar.badge.clock"
        case .dueToday:
            return "calendar.circle.fill"
        case .overdue:
            return "exclamationmark.circle.fill"
        }
    }

    var dependsOnCurrentDay: Bool {
        self == .dueToday || self == .overdue
    }

    func matches(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard self != .all else { return true }
        guard
            let dueDate = BacklogTaskListPresentation.sortableDueDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            )
        else {
            return false
        }

        switch self {
        case .all:
            return true
        case .hasDueDate:
            return true
        case .dueToday:
            return calendar.isDate(dueDate, inSameDayAs: referenceDate)
        case .overdue:
            return RoutineDateMath.overdueDays(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) > 0
        }
    }
}

struct BacklogFilterState: Equatable {
    var sortOrder: BacklogSortOrder = .defaultOrder
    var taskListMode: HomeTaskListMode = .all
    var selectedTodoState: TodoState?
    var createdDateFilter: HomeTaskCreatedDateFilter = .all
    var dueDateFilter: BacklogDueDateFilter = .all
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var selectedPressureFilter: RoutineTaskPressure?
    var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
    var selectedEstimationFilter: TaskEstimationFilter = .all
    var selectedMediaFilter: TaskMediaFilter = .all
    var selectedTags: Set<String> = []
    var includeTagMatchMode: RoutineTagMatchMode = .all
    var excludedTags: Set<String> = []
    var excludeTagMatchMode: RoutineTagMatchMode = .any
    var selectedFlags: Set<String> = []
    var includeFlagMatchMode: RoutineTagMatchMode = .all
    var excludedFlags: Set<String> = []
    var excludeFlagMatchMode: RoutineTagMatchMode = .any

    static let `default` = Self()

    var hasActiveFilters: Bool {
        taskListMode != .all
            || selectedTodoState != nil
            || createdDateFilter != .all
            || dueDateFilter != .all
            || selectedImportanceUrgencyFilter != nil
            || selectedPressureFilter != nil
            || selectedThinkingNeededFilter != nil
            || selectedEstimationFilter != .all
            || selectedMediaFilter != .all
            || !selectedTags.isEmpty
            || !excludedTags.isEmpty
            || !selectedFlags.isEmpty
            || !excludedFlags.isEmpty
    }

    var activeFilterCount: Int {
        var count = 0
        if taskListMode != .all { count += 1 }
        if selectedTodoState != nil { count += 1 }
        if createdDateFilter != .all { count += 1 }
        if dueDateFilter != .all { count += 1 }
        if selectedImportanceUrgencyFilter?.minimumImportance != nil { count += 1 }
        if selectedImportanceUrgencyFilter?.minimumUrgency != nil { count += 1 }
        if selectedPressureFilter != nil { count += 1 }
        if selectedThinkingNeededFilter != nil { count += 1 }
        if selectedEstimationFilter != .all { count += 1 }
        if selectedMediaFilter != .all { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        if !excludedTags.isEmpty { count += 1 }
        if !selectedFlags.isEmpty { count += 1 }
        if !excludedFlags.isEmpty { count += 1 }
        return count
    }

    var hasNonDefaultOptions: Bool {
        hasNonDefaultFilters || hasNonDefaultSortOrder
    }

    var hasNonDefaultFilters: Bool {
        self != resettingFilters()
    }

    var hasNonDefaultSortOrder: Bool {
        sortOrder != .defaultOrder
    }

    var workspaceControlSummary: WorkspaceControlSummary {
        var items: [WorkspaceControlSummaryItem] = []
        if hasNonDefaultFilters {
            let filterTitle: String
            if activeFilterCount == 0 {
                filterTitle = "Filter options"
            } else if activeFilterCount == 1 {
                filterTitle = "1 filter"
            } else {
                filterTitle = "\(activeFilterCount) filters"
            }
            items.append(.init(category: .filter, title: filterTitle))
        }
        if hasNonDefaultSortOrder {
            items.append(.init(category: .sort, title: sortOrder.title))
        }
        return WorkspaceControlSummary(items: items)
    }

    func resettingFilters() -> Self {
        var reset = Self.default
        reset.sortOrder = sortOrder
        return reset
    }

    func resettingSortOrder() -> Self {
        var reset = self
        reset.sortOrder = .defaultOrder
        return reset
    }

    func matches(
        _ task: RoutineTask,
        fileAttachmentTaskIDs: Set<UUID>,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard matchesTaskType(task),
            HomeDisplayFilterSupport.matchesTodoStateFilter(
                selectedTodoState,
                isOneOffTask: task.isOneOffTask,
                todoState: task.todoState
            ),
            matchesCreatedDate(task, referenceDate: referenceDate, calendar: calendar),
            dueDateFilter.matches(
                task,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            HomeDisplayFilterSupport.matchesThinkingNeededFilter(
                selectedThinkingNeededFilter,
                thinkingNeeded: task.thinkingNeeded
            ),
            HomeDisplayFilterSupport.matchesEstimationFilter(
                selectedEstimationFilter,
                estimatedDurationMinutes: task.estimatedDurationMinutes
            ),
            HomeDisplayFilterSupport.matchesMediaFilter(
                selectedMediaFilter,
                hasImage: task.hasImage,
                hasFileAttachment: fileAttachmentTaskIDs.contains(task.id),
                hasVoiceNote: task.hasVoiceNote
            ),
            HomeDisplayFilterSupport.matchesSelectedTags(
                selectedTags,
                mode: includeTagMatchMode,
                in: task.tags
            ),
            HomeDisplayFilterSupport.matchesExcludedTags(
                excludedTags,
                mode: excludeTagMatchMode,
                in: task.tags
            ),
            HomeDisplayFilterSupport.matchesSelectedFlags(
                selectedFlags,
                mode: includeFlagMatchMode,
                in: task.flags
            ),
            HomeDisplayFilterSupport.matchesExcludedFlags(
                excludedFlags,
                mode: excludeFlagMatchMode,
                in: task.flags
            )
        else {
            return false
        }

        let currentValues = RoutineTaskTemporalWeightResolver.effectiveWeights(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            selectedImportanceUrgencyFilter,
            importance: currentValues.importance,
            urgency: currentValues.urgency
        )
            && HomeDisplayFilterSupport.matchesMinimumPressureFilter(
                selectedPressureFilter,
                pressure: currentValues.pressure
            )
    }

    private func matchesTaskType(_ task: RoutineTask) -> Bool {
        switch taskListMode {
        case .all:
            return true
        case .routines:
            return !task.isOneOffTask
        case .todos:
            return task.isOneOffTask
        }
    }

    private func matchesCreatedDate(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        switch createdDateFilter {
        case .all:
            return true
        case .today:
            guard let createdAt = task.createdAt else { return false }
            return calendar.isDate(createdAt, inSameDayAs: referenceDate)
        case .yesterday:
            guard let createdAt = task.createdAt,
                let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate)
            else {
                return false
            }
            return calendar.isDate(createdAt, inSameDayAs: yesterday)
        case .last7Days:
            return matchesCreatedWithinDays(7, task: task, referenceDate: referenceDate, calendar: calendar)
        case .last30Days:
            return matchesCreatedWithinDays(30, task: task, referenceDate: referenceDate, calendar: calendar)
        }
    }

    private func matchesCreatedWithinDays(
        _ days: Int,
        task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard let createdAt = task.createdAt else { return false }
        let createdDay = calendar.startOfDay(for: createdAt)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        guard let lowerBound = calendar.date(byAdding: .day, value: -(days - 1), to: referenceDay) else {
            return false
        }
        return createdDay >= lowerBound && createdDay <= referenceDay
    }
}
