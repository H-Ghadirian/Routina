import Foundation
import SwiftUI

extension HomeTCAView {
    var effectiveSelectedGoalFilter: HomeTaskGoalFilter {
        isGoalsTabEnabled ? store.selectedGoalFilter : .all
    }

    func taskListFiltering(
        referenceDate: Date = Date()
    ) -> HomeTaskListFiltering<HomeFeature.RoutineDisplay> {
        let taskListMode = store.taskListMode
        return HomeTaskListFiltering(
            configuration: HomeTaskListFilteringConfiguration(
                selectedFilter: store.selectedFilter,
                advancedQuery: store.advancedQuery,
                selectedManualPlaceFilterID: store.selectedManualPlaceFilterID,
                selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
                selectedTodoStateFilter: store.selectedTodoStateFilter,
                selectedPressureFilter: store.selectedPressureFilter,
                selectedThinkingNeededFilter: store.selectedThinkingNeededFilter,
                selectedGoalFilter: effectiveSelectedGoalFilter,
                selectedMediaFilter: store.selectedMediaFilter,
                selectedEstimationFilter: store.selectedEstimationFilter,
                hideAssumedDoneTasks: store.hideAssumedDoneTasks,
                taskListViewMode: store.taskListViewMode,
                taskListSortOrder: store.taskListSortOrder,
                createdDateFilter: store.createdDateFilter,
                selectedTags: store.selectedTags,
                includeTagMatchMode: store.includeTagMatchMode,
                selectedFlags: macSharedSelectedFlags,
                includeFlagMatchMode: macSharedIncludeFlagMatchMode,
                excludedFlags: macSharedExcludedFlags,
                excludeFlagMatchMode: macSharedExcludeFlagMatchMode,
                excludedTags: store.excludedTags,
                excludeTagMatchMode: store.excludeTagMatchMode,
                searchText: macSearchPresentationText,
                routineListSectioningMode: routineListSectioningMode,
                separateDeadlineStatusInTagSections: separatesDeadlineStatusInTagTaskListSections,
                flagRules: store.flagRules,
                routineTasks: store.routineTasks,
                referenceDate: referenceDate,
                calendar: calendar,
                taskLadderFilterValueMode: .now
            ),
            matchesCurrentTaskListMode: { (task: HomeFeature.RoutineDisplay) in
                switch taskListMode {
                case .all:
                    return true
                case .routines:
                    return task.scheduleMode.taskType == .routine
                case .todos:
                    return task.isOneOffTask
                }
            }
        )
    }

    func macTaskListPresentation(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> HomeTaskListPresentation<HomeFeature.RoutineDisplay> {
        let referenceDate = HomeMacTaskListPresentationSignature.referenceMinute(
            for: Date(),
            calendar: calendar
        )
        let emptyState = HomeTaskListEmptyState(
            title: emptyTaskListTitle,
            message: emptyTaskListMessage,
            systemImage: "magnifyingglass"
        )
        let sectionOrderIDs = HomeMacTaskListSectionOrder.decoded(
            from: macHomeTaskListSectionOrderRawValue
        )
        let signature = HomeMacTaskListPresentationSignature(
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            routineDisplaysRevision: store.routineDisplaysRevision,
            showArchivedTasks: store.showArchivedTasks,
            separateDailyRoutinesInTaskList: separatesDailyRoutinesInTaskList,
            showTomorrowSection: showsTomorrowInTaskList,
            customSections: customTaskSections,
            sectionOrderIDs: sectionOrderIDs,
            separateTodosAndRoutinesInTagSections: separatesTodosAndRoutinesInTagTaskListSections,
            separateDeadlineStatusInTagSections: separatesDeadlineStatusInTagTaskListSections,
            emptyState: emptyState,
            taskListMode: store.taskListMode,
            selectedFilter: store.selectedFilter,
            advancedQuery: store.advancedQuery,
            selectedManualPlaceFilterID: store.selectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            selectedTodoStateFilter: store.selectedTodoStateFilter,
            selectedPressureFilter: store.selectedPressureFilter,
            selectedThinkingNeededFilter: store.selectedThinkingNeededFilter,
            selectedGoalFilter: effectiveSelectedGoalFilter,
            selectedMediaFilter: store.selectedMediaFilter,
            selectedEstimationFilter: store.selectedEstimationFilter,
            hideAssumedDoneTasks: store.hideAssumedDoneTasks,
            taskListViewMode: store.taskListViewMode,
            taskListSortOrder: store.taskListSortOrder,
            createdDateFilter: store.createdDateFilter,
            selectedTags: store.selectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            selectedFlags: macSharedSelectedFlags,
            includeFlagMatchMode: macSharedIncludeFlagMatchMode,
            excludedFlags: macSharedExcludedFlags,
            excludeFlagMatchMode: macSharedExcludeFlagMatchMode,
            excludedTags: store.excludedTags,
            excludeTagMatchMode: store.excludeTagMatchMode,
            searchText: macSearchPresentationText,
            routineListSectioningMode: routineListSectioningMode,
            flagRules: store.flagRules,
            calendar: calendar,
            referenceDate: referenceDate
        )

        return macTaskListPresentationCache.presentation(for: signature) {
            let filtering = taskListFiltering(referenceDate: referenceDate)
            let presentation = HomeTaskListPresentation.sidebar(
                filtering: filtering,
                routineDisplays: routineDisplays,
                awayRoutineDisplays: awayRoutineDisplays,
                archivedRoutineDisplays: archivedRoutineDisplays,
                showArchivedTasks: store.showArchivedTasks,
                separateDailyRoutinesInTaskList: separatesDailyRoutinesInTaskList,
                showTomorrowSection: showsTomorrowInTaskList,
                customSections: customTaskSections,
                sectionOrderIDs: sectionOrderIDs,
                separateTodosAndRoutinesInTagSections: separatesTodosAndRoutinesInTagTaskListSections,
                emptyState: emptyState
            )

            return macSearchFallbackAndFlagRulePresentation(
                presentation,
                filtering: filtering,
                routineDisplays: routineDisplays,
                awayRoutineDisplays: awayRoutineDisplays,
                archivedRoutineDisplays: archivedRoutineDisplays,
                showArchivedTasks: store.showArchivedTasks
            )
        }
    }

    private func macSearchFallbackAndFlagRulePresentation(
        _ presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        filtering: HomeTaskListFiltering<HomeFeature.RoutineDisplay>,
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay],
        showArchivedTasks: Bool
    ) -> HomeTaskListPresentation<HomeFeature.RoutineDisplay> {
        let searchFallbackSourceDisplays = macSearchFallbackSourceDisplays(
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            showArchivedTasks: showArchivedTasks
        )
        let flagRuleSourceDisplays = macFlagRuleRevealSourceDisplays(
            from: searchFallbackSourceDisplays
        )
        let presentationWithFlagRuleResults = presentation.appendingFlagRuleRevealResults(
            from: flagRuleSourceDisplays,
            filtering: filtering
        )

        let trimmedSearchText = macSearchPresentationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
            return presentationWithFlagRuleResults
        }
        let backlogLocationTitlesBySectionID = macBacklogLocationTitlesBySectionID()

        return presentationWithFlagRuleResults.addingSearchFallbackResults(
            from: searchFallbackSourceDisplays,
            filtering: filtering,
            locationTitle: { task in
                task.customTaskSectionID.flatMap { backlogLocationTitlesBySectionID[$0] }
            }
        )
    }

    private func macSearchFallbackSourceDisplays(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay],
        showArchivedTasks: Bool
    ) -> [HomeFeature.RoutineDisplay] {
        var seenTaskIDs: Set<UUID> = []

        var sourceDisplays = routineDisplays + awayRoutineDisplays
        if showArchivedTasks {
            sourceDisplays += archivedRoutineDisplays
        }
        sourceDisplays += store.boardTodoDisplays

        return sourceDisplays.filter { task in
            seenTaskIDs.insert(task.taskID).inserted
        }
    }

    private func macFlagRuleRevealSourceDisplays(
        from sourceDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        let backlogSectionIDs = Set(
            customTaskSections
                .filter { $0.surface == .backlog }
                .map(\.id)
        )

        return sourceDisplays.filter { task in
            !(task.customTaskSectionID.map(backlogSectionIDs.contains) ?? false)
        }
    }

    private func macBacklogLocationTitlesBySectionID() -> [UUID: String] {
        let backlogSections = customTaskSections.filter { $0.surface == .backlog }
        return Dictionary(
            uniqueKeysWithValues: backlogSections.compactMap { section in
                guard
                    let pathTitles = HomeCustomTaskSectionStorage.pathTitles(
                        for: section.id,
                        in: backlogSections
                    )
                else {
                    return nil
                }
                return (section.id, (["Backlog"] + pathTitles).joined(separator: " › "))
            })
    }

    func filteredTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        taskListFiltering().filteredTasks(routineDisplays)
    }

    func matchesSearch(_ task: HomeFeature.RoutineDisplay) -> Bool {
        taskListFiltering().matchesSearch(task)
    }

    func matchesFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        taskListFiltering().matchesFilter(task)
    }

    func matchesManualPlaceFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        taskListFiltering().matchesManualPlaceFilter(task)
    }

    func matchesTodoStateFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        taskListFiltering().matchesTodoStateFilter(task)
    }

    func matchesTaskListViewMode(_ task: HomeFeature.RoutineDisplay) -> Bool {
        taskListFiltering().matchesTaskListViewMode(task)
    }

    func sectionDateForDeadlineGrouping(
        for task: HomeFeature.RoutineDisplay
    ) -> Date? {
        taskListFiltering().sectionDateForDeadlineGrouping(for: task)
    }

    func deadlineSectionTitle(for task: HomeFeature.RoutineDisplay) -> String {
        taskListFiltering().deadlineSectionTitle(for: task)
    }

    func formattedDeadlineSectionTitle(for date: Date) -> String {
        taskListFiltering().formattedDeadlineSectionTitle(for: date)
    }

    func isYellowUrgency(_ task: HomeFeature.RoutineDisplay) -> Bool {
        taskListFiltering().isYellowUrgency(task)
    }

    func dueInDays(for task: HomeFeature.RoutineDisplay) -> Int {
        taskListFiltering().dueInDays(for: task)
    }

    func overdueDays(for task: HomeFeature.RoutineDisplay) -> Int {
        taskListFiltering().overdueDays(for: task)
    }

    func daysSinceLastRoutine(_ task: HomeFeature.RoutineDisplay) -> Int {
        taskListFiltering().daysSinceLastRoutine(task)
    }

    func daysSinceScheduleAnchor(_ task: HomeFeature.RoutineDisplay) -> Int {
        taskListFiltering().daysSinceScheduleAnchor(task)
    }

    func urgencyColor(for task: HomeFeature.RoutineDisplay) -> Color {
        color(for: HomeRoutineRowToneResolver.tone(for: task, referenceDate: Date()))
    }

    func rowIconBackgroundColor(for task: HomeFeature.RoutineDisplay) -> Color {
        urgencyColor(for: task).opacity(task.isDoneToday ? 0.22 : 0.14)
    }

    private func color(for tone: HomeRoutineRowTone) -> Color {
        switch tone {
        case .teal: return .teal
        case .blue: return .blue
        case .orange: return .orange
        case .green: return .green
        case .red: return .red
        }
    }
}
