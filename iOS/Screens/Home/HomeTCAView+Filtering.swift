import Foundation
import SwiftUI

extension HomeTCAView {
    func taskListFiltering(
        referenceDate: Date = Date()
    ) -> HomeTaskListFiltering<HomeFeature.RoutineDisplay> {
        HomeTaskListFiltering(
            configuration: HomeTaskListFilteringConfiguration(
                selectedFilter: store.selectedFilter,
                advancedQuery: store.advancedQuery,
                selectedManualPlaceFilterID: store.selectedManualPlaceFilterID,
                selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
                selectedTodoStateFilter: store.selectedTodoStateFilter,
                selectedPressureFilter: store.selectedPressureFilter,
                selectedGoalFilter: store.selectedGoalFilter,
                selectedMediaFilter: store.selectedMediaFilter,
                hideAssumedDoneTasks: store.hideAssumedDoneTasks,
                taskListViewMode: store.taskListViewMode,
                taskListSortOrder: store.taskListSortOrder,
                createdDateFilter: store.createdDateFilter,
                selectedTags: store.selectedTags,
                includeTagMatchMode: store.includeTagMatchMode,
                excludedTags: store.excludedTags,
                excludeTagMatchMode: store.excludeTagMatchMode,
                searchText: searchTextBinding.wrappedValue,
                routineListSectioningMode: routineListSectioningMode,
                routineTasks: store.routineTasks,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            matchesCurrentTaskListMode: { task in
                matchesCurrentTaskListMode(task)
            }
        )
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
