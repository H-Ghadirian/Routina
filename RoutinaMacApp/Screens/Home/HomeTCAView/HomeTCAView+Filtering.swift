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
                selectedGoalFilter: effectiveSelectedGoalFilter,
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
            matchesCurrentTaskListMode: { (task: HomeFeature.RoutineDisplay) in
                switch taskListMode {
                case .all:
                    return true
                case .routines:
                    return !task.isOneOffTask
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
        let signature = HomeMacTaskListPresentationSignature(
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            routineDisplaysRevision: store.routineDisplaysRevision,
            showArchivedTasks: store.showArchivedTasks,
            separateDailyRoutinesInTaskList: separatesDailyRoutinesInTaskList,
            showTomorrowSection: showsTomorrowInTaskList,
            separateTodosAndRoutinesInTagSections: separatesTodosAndRoutinesInTagTaskListSections,
            emptyState: emptyState,
            taskListMode: store.taskListMode,
            selectedFilter: store.selectedFilter,
            advancedQuery: store.advancedQuery,
            selectedManualPlaceFilterID: store.selectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            selectedTodoStateFilter: store.selectedTodoStateFilter,
            selectedPressureFilter: store.selectedPressureFilter,
            selectedGoalFilter: effectiveSelectedGoalFilter,
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
            calendar: calendar,
            referenceDate: referenceDate,
            routineTasks: store.routineTasks
        )

        return macTaskListPresentationCache.presentation(for: signature) {
            HomeTaskListPresentation.sidebar(
                filtering: taskListFiltering(referenceDate: referenceDate),
                routineDisplays: routineDisplays,
                awayRoutineDisplays: awayRoutineDisplays,
                archivedRoutineDisplays: archivedRoutineDisplays,
                showArchivedTasks: store.showArchivedTasks,
                separateDailyRoutinesInTaskList: separatesDailyRoutinesInTaskList,
                showTomorrowSection: showsTomorrowInTaskList,
                separateTodosAndRoutinesInTagSections: separatesTodosAndRoutinesInTagTaskListSections,
                emptyState: emptyState
            )
        }
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

@MainActor
final class HomeMacTaskListPresentationCache: ObservableObject {
    private var cachedSignature: HomeMacTaskListPresentationSignature?
    private var cachedPresentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>?

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
        return presentation
    }
}

struct HomeMacTaskListPresentationSignature: Equatable {
    let routineDisplays: HomeMacTaskListDisplayCollectionSignature
    let awayRoutineDisplays: HomeMacTaskListDisplayCollectionSignature
    let archivedRoutineDisplays: HomeMacTaskListDisplayCollectionSignature
    let showArchivedTasks: Bool
    let separateDailyRoutinesInTaskList: Bool
    let showTomorrowSection: Bool
    let separateTodosAndRoutinesInTagSections: Bool
    let emptyState: HomeTaskListEmptyState
    let taskListMode: HomeFeature.TaskListMode
    let selectedFilter: RoutineListFilter
    let advancedQuery: String
    let selectedManualPlaceFilterID: UUID?
    let selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let selectedTodoStateFilter: TodoState?
    let selectedPressureFilter: RoutineTaskPressure?
    let selectedGoalFilter: HomeTaskGoalFilter
    let selectedMediaFilter: TaskMediaFilter
    let hideAssumedDoneTasks: Bool
    let taskListViewMode: HomeTaskListViewMode
    let taskListSortOrder: HomeTaskListSortOrder
    let createdDateFilter: HomeTaskCreatedDateFilter
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let searchText: String
    let routineListSectioningMode: RoutineListSectioningMode
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZoneIdentifier: String
    let calendarFirstWeekday: Int
    let calendarMinimumDaysInFirstWeek: Int
    let referenceDate: Date
    let relationshipTasks: [HomeMacTaskListRelationshipTaskSignature]

    init(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay],
        routineDisplaysRevision: Int,
        showArchivedTasks: Bool,
        separateDailyRoutinesInTaskList: Bool,
        showTomorrowSection: Bool,
        separateTodosAndRoutinesInTagSections: Bool,
        emptyState: HomeTaskListEmptyState,
        taskListMode: HomeFeature.TaskListMode,
        selectedFilter: RoutineListFilter,
        advancedQuery: String,
        selectedManualPlaceFilterID: UUID?,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        selectedTodoStateFilter: TodoState?,
        selectedPressureFilter: RoutineTaskPressure?,
        selectedGoalFilter: HomeTaskGoalFilter,
        selectedMediaFilter: TaskMediaFilter,
        hideAssumedDoneTasks: Bool,
        taskListViewMode: HomeTaskListViewMode,
        taskListSortOrder: HomeTaskListSortOrder,
        createdDateFilter: HomeTaskCreatedDateFilter,
        selectedTags: Set<String>,
        includeTagMatchMode: RoutineTagMatchMode,
        excludedTags: Set<String>,
        excludeTagMatchMode: RoutineTagMatchMode,
        searchText: String,
        routineListSectioningMode: RoutineListSectioningMode,
        calendar: Calendar,
        referenceDate: Date,
        routineTasks: [RoutineTask]
    ) {
        self.routineDisplays = HomeMacTaskListDisplayCollectionSignature(
            routineDisplays,
            revision: routineDisplaysRevision
        )
        self.awayRoutineDisplays = HomeMacTaskListDisplayCollectionSignature(
            awayRoutineDisplays,
            revision: routineDisplaysRevision
        )
        self.archivedRoutineDisplays = HomeMacTaskListDisplayCollectionSignature(
            archivedRoutineDisplays,
            revision: routineDisplaysRevision
        )
        self.showArchivedTasks = showArchivedTasks
        self.separateDailyRoutinesInTaskList = separateDailyRoutinesInTaskList
        self.showTomorrowSection = showTomorrowSection
        self.separateTodosAndRoutinesInTagSections = separateTodosAndRoutinesInTagSections
        self.emptyState = emptyState
        self.taskListMode = taskListMode
        self.selectedFilter = selectedFilter
        self.advancedQuery = advancedQuery
        self.selectedManualPlaceFilterID = selectedManualPlaceFilterID
        self.selectedImportanceUrgencyFilter = selectedImportanceUrgencyFilter
        self.selectedTodoStateFilter = selectedTodoStateFilter
        self.selectedPressureFilter = selectedPressureFilter
        self.selectedGoalFilter = selectedGoalFilter
        self.selectedMediaFilter = selectedMediaFilter
        self.hideAssumedDoneTasks = hideAssumedDoneTasks
        self.taskListViewMode = taskListViewMode
        self.taskListSortOrder = taskListSortOrder
        self.createdDateFilter = createdDateFilter
        self.selectedTags = selectedTags
        self.includeTagMatchMode = includeTagMatchMode
        self.excludedTags = excludedTags
        self.excludeTagMatchMode = excludeTagMatchMode
        self.searchText = searchText
        self.routineListSectioningMode = routineListSectioningMode
        self.calendarIdentifier = calendar.identifier
        self.calendarTimeZoneIdentifier = calendar.timeZone.identifier
        self.calendarFirstWeekday = calendar.firstWeekday
        self.calendarMinimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        self.referenceDate = referenceDate
        if taskListViewMode == .actionable {
            relationshipTasks = routineTasks.map(HomeMacTaskListRelationshipTaskSignature.init(task:))
                .sorted { $0.id.uuidString < $1.id.uuidString }
        } else {
            relationshipTasks = []
        }
    }

    static func referenceMinute(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .minute, for: date)?.start ?? date
    }
}

struct HomeMacTaskListDisplayCollectionSignature: Equatable {
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

struct HomeMacTaskListRelationshipTaskSignature: Equatable {
    let id: UUID
    let relationshipsStorage: String
    let scheduleModeRawValue: String
    let recurrenceStorageVersion: Int16
    let recurrenceKindRawValue: String
    let recurrenceTimeOfDayHour: Int?
    let recurrenceTimeOfDayMinute: Int?
    let recurrenceTimeRangeStartHour: Int?
    let recurrenceTimeRangeStartMinute: Int?
    let recurrenceTimeRangeEndHour: Int?
    let recurrenceTimeRangeEndMinute: Int?
    let recurrenceWeekday: Int?
    let recurrenceDayOfMonth: Int?
    let recurrenceRuleStorage: String
    let interval: Int16
    let lastDone: Date?
    let canceledAt: Date?
    let deadline: Date?
    let availabilityStartDate: Date?
    let scheduleAnchor: Date?
    let pausedAt: Date?
    let snoozedUntil: Date?
    let stepsStorage: String
    let completedStepCount: Int16
    let checklistItemsStorage: String
    let completedChecklistItemIDsStorage: String
    let completedChecklistProgressStartedAt: Date?
    let createdAt: Date?
    let autoAssumeDailyDone: Bool
    let autoAssumeDoneTimeOfDayHour: Int?
    let autoAssumeDoneTimeOfDayMinute: Int?

    init(task: RoutineTask) {
        id = task.id
        relationshipsStorage = task.relationshipsStorage
        scheduleModeRawValue = task.scheduleModeRawValue
        recurrenceStorageVersion = task.recurrenceStorageVersion
        recurrenceKindRawValue = task.recurrenceKindRawValue
        recurrenceTimeOfDayHour = task.recurrenceTimeOfDayHour
        recurrenceTimeOfDayMinute = task.recurrenceTimeOfDayMinute
        recurrenceTimeRangeStartHour = task.recurrenceTimeRangeStartHour
        recurrenceTimeRangeStartMinute = task.recurrenceTimeRangeStartMinute
        recurrenceTimeRangeEndHour = task.recurrenceTimeRangeEndHour
        recurrenceTimeRangeEndMinute = task.recurrenceTimeRangeEndMinute
        recurrenceWeekday = task.recurrenceWeekday
        recurrenceDayOfMonth = task.recurrenceDayOfMonth
        recurrenceRuleStorage = task.recurrenceRuleStorage
        interval = task.interval
        lastDone = task.lastDone
        canceledAt = task.canceledAt
        deadline = task.deadline
        availabilityStartDate = task.availabilityStartDate
        scheduleAnchor = task.scheduleAnchor
        pausedAt = task.pausedAt
        snoozedUntil = task.snoozedUntil
        stepsStorage = task.stepsStorage
        completedStepCount = task.completedStepCount
        checklistItemsStorage = task.checklistItemsStorage
        completedChecklistItemIDsStorage = task.completedChecklistItemIDsStorage
        completedChecklistProgressStartedAt = task.completedChecklistProgressStartedAt
        createdAt = task.createdAt
        autoAssumeDailyDone = task.autoAssumeDailyDone
        autoAssumeDoneTimeOfDayHour = task.autoAssumeDoneTimeOfDayHour
        autoAssumeDoneTimeOfDayMinute = task.autoAssumeDoneTimeOfDayMinute
    }
}
