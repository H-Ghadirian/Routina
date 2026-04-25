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
                taskListViewMode: store.taskListViewMode,
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

    func macTaskListPresentation(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> HomeTaskListPresentation<HomeFeature.RoutineDisplay> {
        HomeTaskListPresentation.sidebar(
            filtering: taskListFiltering(),
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            emptyState: HomeTaskListEmptyState(
                title: emptyTaskListTitle,
                message: emptyTaskListMessage,
                systemImage: "magnifyingglass"
            )
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
        if task.isPaused {
            return .teal
        }
        if case .away = task.locationAvailability {
            return .blue
        }
        if task.isInProgress {
            return .orange
        }
        if task.isOneOffTask {
            return task.isCompletedOneOff ? .green : (task.isCanceledOneOff ? .orange : .blue)
        }
        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return .orange
        }
        if task.recurrenceRule.isFixedCalendar {
            let urgency = urgencyLevel(for: task)
            switch urgency {
            case 3:
                return .red
            case 2, 1:
                return .orange
            default:
                return .green
            }
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    func rowIconBackgroundColor(for task: HomeFeature.RoutineDisplay) -> Color {
        urgencyColor(for: task).opacity(task.isDoneToday ? 0.22 : 0.14)
    }
}
