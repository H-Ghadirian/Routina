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
                selectedFlags: store.selectedFlags,
                includeFlagMatchMode: store.includeFlagMatchMode,
                excludedTags: store.excludedTags,
                excludeTagMatchMode: store.excludeTagMatchMode,
                searchText: macSearchPresentationText,
                routineListSectioningMode: routineListSectioningMode,
                separateDeadlineStatusInTagSections: separatesDeadlineStatusInTagTaskListSections,
                flagRules: store.flagRules,
                routineTasks: store.routineTasks,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            matchesCurrentTaskListMode: { (task: HomeFeature.RoutineDisplay) in
                switch taskListMode {
                case .all:
                    return true
                case .routines:
                    return task.scheduleMode.taskType == .routine
                        || task.scheduleMode.taskType == .record
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
            selectedFlags: store.selectedFlags,
            includeFlagMatchMode: store.includeFlagMatchMode,
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
        let sourceDisplays = macSearchFallbackSourceDisplays(
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            showArchivedTasks: showArchivedTasks
        )
        let presentationWithFlagRuleResults = presentation.appendingFlagRuleRevealResults(
            from: sourceDisplays,
            filtering: filtering
        )

        let trimmedSearchText = macSearchPresentationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
        return presentationWithFlagRuleResults
        }

        return presentationWithFlagRuleResults.addingSearchFallbackResults(
            from: sourceDisplays,
            filtering: filtering
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

        let backlogSectionIDs = Set(
            customTaskSections
                .filter { $0.surface == .backlog }
                .map(\.id)
        )

        return sourceDisplays.filter { task in
            guard !(task.customTaskSectionID.map(backlogSectionIDs.contains) ?? false) else {
                return false
            }
            return seenTaskIDs.insert(task.taskID).inserted
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
    let routineDisplays: HomeMacTaskListDisplayCollectionSignature
    let awayRoutineDisplays: HomeMacTaskListDisplayCollectionSignature
    let archivedRoutineDisplays: HomeMacTaskListDisplayCollectionSignature
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
        excludedTags: Set<String>,
        excludeTagMatchMode: RoutineTagMatchMode,
        searchText: String,
        routineListSectioningMode: RoutineListSectioningMode,
        flagRules: [RoutineFlagRule],
        calendar: Calendar,
        referenceDate: Date
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
