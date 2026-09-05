import Foundation
import SwiftUI

@MainActor
final class HomeMacTaskListPresentationCache: ObservableObject {
    private var cachedSignature: HomeMacTaskListPresentationSignature?
    private var cachedPresentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>?
    private var cachedSidebarLocationsByTaskID: [UUID: HomeMacTaskListSidebarLocationSnapshot] = [:]

    func presentation(
        for signature: HomeMacTaskListPresentationSignature,
        build: () -> HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> HomeTaskListPresentation<HomeFeature.RoutineDisplay> {
        if cachedSignature == signature, let cachedPresentation {
            return cachedPresentation
        }

        let presentation = build()
        cachedSignature = signature
        cachedPresentation = presentation
        cachedSidebarLocationsByTaskID = Self.sidebarLocations(in: presentation)
        return presentation
    }

    func sidebarLocation(for taskID: UUID) -> HomeMacTaskListSidebarLocationSnapshot? {
        cachedSidebarLocationsByTaskID[taskID]
    }

    private static func sidebarLocations(
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> [UUID: HomeMacTaskListSidebarLocationSnapshot] {
        var locations: [UUID: HomeMacTaskListSidebarLocationSnapshot] = [:]

        for section in presentation.sections {
            let groupTitlesByTaskID = sidebarGroupTitles(in: section.taskGroups)
            for task in section.tasks where locations[task.taskID] == nil {
                locations[task.taskID] = HomeMacTaskListSidebarLocationSnapshot(
                    sectionTitle: section.title,
                    sectionIdentityKey: section.identityKey,
                    groupTitles: groupTitlesByTaskID[task.taskID] ?? [],
                    taskFlags: task.flags
                )
            }
        }

        return locations
    }

    private static func sidebarGroupTitles(
        in groups: [HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>]
    ) -> [UUID: [String]] {
        var titlesByTaskID: [UUID: [String]] = [:]

        for group in groups {
            let groupTitle = group.title.map { [$0] } ?? []
            var titlesWithinGroup: [UUID: [String]] = [:]
            for task in group.tasks {
                titlesWithinGroup[task.taskID] = groupTitle
            }

            for (taskID, childTitles) in sidebarGroupTitles(in: group.childGroups) {
                titlesWithinGroup[taskID] = groupTitle + childTitles
            }

            for (taskID, titles) in titlesWithinGroup where titlesByTaskID[taskID] == nil {
                titlesByTaskID[taskID] = titles
            }
        }

        return titlesByTaskID
    }
}

struct HomeMacTaskListSidebarLocationSnapshot: Equatable {
    let sectionTitle: String
    let sectionIdentityKey: String
    let groupTitles: [String]
    let taskFlags: [String]
}

struct HomeMacTaskListPresentationSignature: Equatable {
    let routineDisplays: HomeMacTaskListCollectionSignature
    let awayRoutineDisplays: HomeMacTaskListCollectionSignature
    let archivedRoutineDisplays: HomeMacTaskListCollectionSignature
    let showArchivedTasks: Bool
    let separateDailyRoutinesInTaskList: Bool
    let showTomorrowSection: Bool
    let customSections: [HomeCustomTaskSection]
    let sectionOrderIDs: [String]
    let separateTodosAndRoutinesInTagSections: Bool
    let separateDeadlineStatusInTagSections: Bool
    let emptyState: HomeTaskListEmptyState
    let taskListMode: HomeFeature.TaskListMode
    let selectedFilter: RoutineListFilter
    let advancedQuery: String
    let selectedManualPlaceFilterID: UUID?
    let selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let selectedTodoStateFilter: TodoState?
    let selectedPressureFilter: RoutineTaskPressure?
    let selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
    let selectedGoalFilter: HomeTaskGoalFilter
    let selectedMediaFilter: TaskMediaFilter
    let selectedEstimationFilter: TaskEstimationFilter
    let hideAssumedDoneTasks: Bool
    let taskListViewMode: HomeTaskListViewMode
    let taskListSortOrder: HomeTaskListSortOrder
    let createdDateFilter: HomeTaskCreatedDateFilter
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let selectedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludedFlags: Set<String>
    let excludeFlagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let searchText: String
    let routineListSectioningMode: RoutineListSectioningMode
    let flagRules: [RoutineFlagRule]
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZoneIdentifier: String
    let calendarFirstWeekday: Int
    let calendarMinimumDaysInFirstWeek: Int
    let referenceDate: Date

    init(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay],
        routineDisplaysRevision: Int,
        showArchivedTasks: Bool,
        separateDailyRoutinesInTaskList: Bool,
        showTomorrowSection: Bool,
        customSections: [HomeCustomTaskSection],
        sectionOrderIDs: [String],
        separateTodosAndRoutinesInTagSections: Bool,
        separateDeadlineStatusInTagSections: Bool,
        emptyState: HomeTaskListEmptyState,
        taskListMode: HomeFeature.TaskListMode,
        selectedFilter: RoutineListFilter,
        advancedQuery: String,
        selectedManualPlaceFilterID: UUID?,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        selectedTodoStateFilter: TodoState?,
        selectedPressureFilter: RoutineTaskPressure?,
        selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?,
        selectedGoalFilter: HomeTaskGoalFilter,
        selectedMediaFilter: TaskMediaFilter,
        selectedEstimationFilter: TaskEstimationFilter,
        hideAssumedDoneTasks: Bool,
        taskListViewMode: HomeTaskListViewMode,
        taskListSortOrder: HomeTaskListSortOrder,
        createdDateFilter: HomeTaskCreatedDateFilter,
        selectedTags: Set<String>,
        includeTagMatchMode: RoutineTagMatchMode,
        selectedFlags: Set<String>,
        includeFlagMatchMode: RoutineTagMatchMode,
        excludedFlags: Set<String>,
        excludeFlagMatchMode: RoutineTagMatchMode,
        excludedTags: Set<String>,
        excludeTagMatchMode: RoutineTagMatchMode,
        searchText: String,
        routineListSectioningMode: RoutineListSectioningMode,
        flagRules: [RoutineFlagRule],
        calendar: Calendar,
        referenceDate: Date
    ) {
        self.routineDisplays = HomeMacTaskListCollectionSignature(
            routineDisplays,
            revision: routineDisplaysRevision
        )
        self.awayRoutineDisplays = HomeMacTaskListCollectionSignature(
            awayRoutineDisplays,
            revision: routineDisplaysRevision
        )
        self.archivedRoutineDisplays = HomeMacTaskListCollectionSignature(
            archivedRoutineDisplays,
            revision: routineDisplaysRevision
        )
        self.showArchivedTasks = showArchivedTasks
        self.separateDailyRoutinesInTaskList = separateDailyRoutinesInTaskList
        self.showTomorrowSection = showTomorrowSection
        self.customSections = HomeCustomTaskSectionStorage.sanitized(customSections)
        self.sectionOrderIDs = sectionOrderIDs
        self.separateTodosAndRoutinesInTagSections = separateTodosAndRoutinesInTagSections
        self.separateDeadlineStatusInTagSections = separateDeadlineStatusInTagSections
        self.emptyState = emptyState
        self.taskListMode = taskListMode
        self.selectedFilter = selectedFilter
        self.advancedQuery = advancedQuery
        self.selectedManualPlaceFilterID = selectedManualPlaceFilterID
        self.selectedImportanceUrgencyFilter = selectedImportanceUrgencyFilter
        self.selectedTodoStateFilter = selectedTodoStateFilter
        self.selectedPressureFilter = selectedPressureFilter
        self.selectedThinkingNeededFilter = selectedThinkingNeededFilter
        self.selectedGoalFilter = selectedGoalFilter
        self.selectedMediaFilter = selectedMediaFilter
        self.selectedEstimationFilter = selectedEstimationFilter
        self.hideAssumedDoneTasks = hideAssumedDoneTasks
        self.taskListViewMode = taskListViewMode
        self.taskListSortOrder = taskListSortOrder
        self.createdDateFilter = createdDateFilter
        self.selectedTags = selectedTags
        self.includeTagMatchMode = includeTagMatchMode
        self.selectedFlags = selectedFlags
        self.includeFlagMatchMode = includeFlagMatchMode
        self.excludedFlags = excludedFlags
        self.excludeFlagMatchMode = excludeFlagMatchMode
        self.excludedTags = excludedTags
        self.excludeTagMatchMode = excludeTagMatchMode
        self.searchText = searchText
        self.routineListSectioningMode = routineListSectioningMode
        self.flagRules = RoutineFlagRules.sanitized(flagRules)
        self.calendarIdentifier = calendar.identifier
        self.calendarTimeZoneIdentifier = calendar.timeZone.identifier
        self.calendarFirstWeekday = calendar.firstWeekday
        self.calendarMinimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        self.referenceDate = referenceDate
    }

    static func referenceMinute(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .minute, for: date)?.start ?? date
    }
}

struct HomeMacTaskListCollectionSignature: Equatable {
    let revision: Int
    let count: Int
    let firstTaskID: UUID?
    let lastTaskID: UUID?

    init(_ displays: [HomeFeature.RoutineDisplay], revision: Int) {
        self.revision = revision
        count = displays.count
        firstTaskID = displays.first?.taskID
        lastTaskID = displays.last?.taskID
    }
}
