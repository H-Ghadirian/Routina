import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct HomeTaskListFilteringTests {
    @Test
    func filteredTasksAppliesSearchTagsPlaceAndImportanceFilters() {
        let placeID = UUID()
        let tasks = [
            TestTaskDisplay(name: "Write launch plan", placeID: placeID, tags: ["Work", "Focus"], importance: .level3, urgency: .level3),
            TestTaskDisplay(name: "Write grocery list", placeID: UUID(), tags: ["Home"], importance: .level2, urgency: .level2),
            TestTaskDisplay(name: "Plan admin backlog", placeID: placeID, tags: ["Admin"], importance: .level4, urgency: .level4)
        ]

        let result = makeFiltering(
            selectedManualPlaceFilterID: placeID,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell(importance: .level3, urgency: .level3),
            selectedTags: ["Work"],
            searchText: "plan"
        )
        .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Write launch plan"])
    }

    @Test
    func actionableFilterHidesTasksWithUnfinishedBlockers() {
        let blockedTaskID = UUID()
        let blockerID = UUID()
        let blockedTask = RoutineTask(
            id: blockedTaskID,
            name: "Submit report",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)]
        )
        let blocker = RoutineTask(id: blockerID, name: "Draft report")
        let displays = [
            TestTaskDisplay(taskID: blockedTaskID, name: "Submit report"),
            TestTaskDisplay(taskID: blockerID, name: "Draft report")
        ]

        let result = makeFiltering(
            taskListViewMode: .actionable,
            routineTasks: [blockedTask, blocker]
        )
        .filteredTasks(displays)

        #expect(result.map(\.name) == ["Draft report"])
    }

    @Test
    func pressureFilterShowsTasksWithSelectedPressureLevel() {
        let tasks = [
            TestTaskDisplay(name: "Low pressure", pressure: .low),
            TestTaskDisplay(name: "No pressure", pressure: .none),
            TestTaskDisplay(name: "High pressure", pressure: .high)
        ]

        let result = makeFiltering(selectedPressureFilter: .low)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Low pressure"])
    }

    @Test
    func pressureNoneFilterShowsTasksWithNoPressure() {
        let tasks = [
            TestTaskDisplay(name: "Low pressure", pressure: .low),
            TestTaskDisplay(name: "No pressure", pressure: .none),
            TestTaskDisplay(name: "High pressure", pressure: .high)
        ]

        let result = makeFiltering(selectedPressureFilter: RoutineTaskPressure.none)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["No pressure"])
    }

    @Test
    func advancedQueryMatchesFieldedTermsAndExclusions() {
        let tasks = [
            TestTaskDisplay(name: "Draft launch plan", placeName: "Office", tags: ["Work"], isOneOffTask: true, todoState: .ready),
            TestTaskDisplay(name: "File receipts", placeName: "Home", tags: ["Admin"], isOneOffTask: true, todoState: .done),
            TestTaskDisplay(name: "Water plants", placeName: "Home", tags: ["Home"], isOneOffTask: false)
        ]

        let result = makeFiltering(advancedQuery: "type:todo place:office -is:done tag:work")
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Draft launch plan"])
    }

    @Test
    func advancedQueryMatchesQuotedTextAndLevels() {
        let tasks = [
            TestTaskDisplay(name: "Write launch plan", importance: .level3, urgency: .level2),
            TestTaskDisplay(name: "Launch checklist", importance: .level2, urgency: .level4)
        ]

        let result = makeFiltering(advancedQuery: "\"launch plan\" importance:l3")
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Write launch plan"])
    }

    @Test
    func advancedQuerySupportsOrderedComparisons() {
        let tasks = [
            TestTaskDisplay(name: "Low pressure", importance: .level2, pressure: .low),
            TestTaskDisplay(name: "Medium pressure", importance: .level3, pressure: .medium),
            TestTaskDisplay(name: "High pressure", importance: .level4, pressure: .high)
        ]

        let pressureResult = makeFiltering(advancedQuery: "pressure:>low")
            .filteredTasks(tasks)
        let importanceResult = makeFiltering(advancedQuery: "importance:>=l3")
            .filteredTasks(tasks)

        #expect(Set(pressureResult.map(\.name)) == ["Medium pressure", "High pressure"])
        #expect(Set(importanceResult.map(\.name)) == ["Medium pressure", "High pressure"])
    }

    @Test
    func advancedQuerySupportsExplicitAndOrOperators() {
        let tasks = [
            TestTaskDisplay(name: "Office todo", placeName: "Office", pressure: .low, isOneOffTask: true),
            TestTaskDisplay(name: "Home high pressure", placeName: "Home", pressure: .high, isOneOffTask: false),
            TestTaskDisplay(name: "Home low pressure", placeName: "Home", pressure: .low, isOneOffTask: false)
        ]

        let andResult = makeFiltering(advancedQuery: "type:todo AND place:office")
            .filteredTasks(tasks)
        let orResult = makeFiltering(advancedQuery: "place:office OR pressure:high")
            .filteredTasks(tasks)

        #expect(andResult.map { $0.name } == ["Office todo"])
        #expect(Set(orResult.map { $0.name }) == ["Office todo", "Home high pressure"])
    }

    @Test
    func groupedRoutineSectionsBuildsExpectedStatusBuckets() {
        let tasks = [
            TestTaskDisplay(name: "Overdue", daysUntilDue: -2),
            TestTaskDisplay(name: "Due Today", daysUntilDue: 0),
            TestTaskDisplay(name: "On Track", daysUntilDue: 4),
            TestTaskDisplay(name: "Done Today", daysUntilDue: 4, isDoneToday: true)
        ]

        let sections = makeFiltering().groupedRoutineSections(from: tasks)

        #expect(sections.map(\.title) == ["Overdue", "Due Soon", "On Track", "Done Today"])
        #expect(sections.map { $0.tasks.map(\.name) } == [["Overdue"], ["Due Today"], ["On Track"], ["Done Today"]])
    }

    @Test
    func manualOrderSortsWithinTheResolvedSection() {
        let sectionKey = HomeTaskListFiltering<TestTaskDisplay>.pinnedManualOrderSectionKey
        let tasks = [
            TestTaskDisplay(name: "Later", isPinned: true, manualSectionOrders: [sectionKey: 2]),
            TestTaskDisplay(name: "Sooner", isPinned: true, manualSectionOrders: [sectionKey: 1])
        ]

        let result = makeFiltering().filteredPinnedTasks(
            activeDisplays: tasks,
            awayDisplays: [],
            archivedDisplays: []
        )

        #expect(result.map(\.name) == ["Sooner", "Later"])
    }

    @Test
    func creationDateSortOrdersNewestAndOldestFirst() {
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_710_000_000)
        let tasks = [
            TestTaskDisplay(name: "Older", createdAt: olderDate, daysUntilDue: 4),
            TestTaskDisplay(name: "Missing", createdAt: nil, daysUntilDue: 4),
            TestTaskDisplay(name: "Newer", createdAt: newerDate, daysUntilDue: 4)
        ]

        let newestFirst = makeFiltering(taskListSortOrder: .createdNewestFirst)
            .filteredTasks(tasks)
        let oldestFirst = makeFiltering(taskListSortOrder: .createdOldestFirst)
            .filteredTasks(tasks)

        #expect(newestFirst.map(\.name) == ["Newer", "Older", "Missing"])
        #expect(oldestFirst.map(\.name) == ["Older", "Newer", "Missing"])
    }

    @Test
    func createdDateFilterMatchesTodayAndRecentWindows() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let calendar = makeTestCalendar()
        let today = referenceDate
        let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDate)!
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: referenceDate)!
        let eightDaysAgo = calendar.date(byAdding: .day, value: -8, to: referenceDate)!
        let tasks = [
            TestTaskDisplay(name: "Today", createdAt: today, daysUntilDue: 4),
            TestTaskDisplay(name: "Yesterday", createdAt: yesterday, daysUntilDue: 4),
            TestTaskDisplay(name: "Six Days Ago", createdAt: sixDaysAgo, daysUntilDue: 4),
            TestTaskDisplay(name: "Eight Days Ago", createdAt: eightDaysAgo, daysUntilDue: 4),
            TestTaskDisplay(name: "Missing", createdAt: nil, daysUntilDue: 4)
        ]

        let todayResult = makeFiltering(createdDateFilter: .today)
            .filteredTasks(tasks)
        let last7DaysResult = makeFiltering(createdDateFilter: .last7Days)
            .filteredTasks(tasks)

        #expect(todayResult.map(\.name) == ["Today"])
        #expect(Set(last7DaysResult.map(\.name)) == ["Today", "Yesterday", "Six Days Ago"])
    }

    @Test
    func iOSPresentationBuildsVisibleSectionsAndOffsets() {
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(),
            routineDisplays: [TestTaskDisplay(name: "Active", daysUntilDue: 4)],
            awayRoutineDisplays: [TestTaskDisplay(name: "Away", daysUntilDue: 4)],
            archivedRoutineDisplays: [TestTaskDisplay(name: "Archived")],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.title) == ["On Track", "Not Here Right Now", "Archived"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1, 2])
        #expect(presentation.sections.map(\.includeMarkDone) == [true, false, true])
        #expect(presentation.visibleTaskCount == 3)
        #expect(presentation.emptyState == nil)
    }

    @Test
    func iOSPresentationReportsHiddenUnavailableEmptyState() {
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(),
            routineDisplays: [],
            awayRoutineDisplays: [TestTaskDisplay(name: "Away")],
            archivedRoutineDisplays: [],
            hideUnavailableRoutines: true,
            taskListKind: .routines
        )

        #expect(presentation.sections.isEmpty)
        #expect(presentation.hiddenUnavailableTaskCount == 1)
        #expect(presentation.emptyState == HomeTaskListEmptyState(
            title: "No routines available here",
            message: "1 routines are hidden because you are away from their saved place.",
            systemImage: "location.slash"
        ))
    }

    @Test
    func sidebarPresentationBuildsMoveContextsAndOffsets() {
        let pinnedID = UUID()
        let regularID = UUID()
        let archivedID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(taskID: regularID, name: "Regular", daysUntilDue: 4),
                TestTaskDisplay(taskID: pinnedID, name: "Pinned", isPinned: true)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [TestTaskDisplay(taskID: archivedID, name: "Archived")],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Pinned", "On Track", "Archived"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1, 2])
        #expect(presentation.sections.compactMap(\.moveContext?.sectionKey) == ["pinned", "onTrack", "archived"])
        #expect(presentation.sections.compactMap(\.moveContext?.orderedTaskIDs.first) == [pinnedID, regularID, archivedID])
        #expect(presentation.visibleTaskCount == 3)
        #expect(presentation.emptyState == nil)
    }
}

private func makeFiltering(
    selectedFilter: RoutineListFilter = .all,
    selectedManualPlaceFilterID: UUID? = nil,
    selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
    selectedTodoStateFilter: TodoState? = nil,
    selectedPressureFilter: RoutineTaskPressure? = nil,
    taskListViewMode: HomeTaskListViewMode = .all,
    taskListSortOrder: HomeTaskListSortOrder = .smart,
    createdDateFilter: HomeTaskCreatedDateFilter = .all,
    advancedQuery: String = "",
    selectedTags: Set<String> = [],
    includeTagMatchMode: RoutineTagMatchMode = .all,
    excludedTags: Set<String> = [],
    excludeTagMatchMode: RoutineTagMatchMode = .any,
    searchText: String = "",
    routineListSectioningMode: RoutineListSectioningMode = .status,
    routineTasks: [RoutineTask] = []
) -> HomeTaskListFiltering<TestTaskDisplay> {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

    return HomeTaskListFiltering(
        configuration: HomeTaskListFilteringConfiguration(
            selectedFilter: selectedFilter,
            advancedQuery: advancedQuery,
            selectedManualPlaceFilterID: selectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
            selectedTodoStateFilter: selectedTodoStateFilter,
            selectedPressureFilter: selectedPressureFilter,
            taskListViewMode: taskListViewMode,
            taskListSortOrder: taskListSortOrder,
            createdDateFilter: createdDateFilter,
            selectedTags: selectedTags,
            includeTagMatchMode: includeTagMatchMode,
            excludedTags: excludedTags,
            excludeTagMatchMode: excludeTagMatchMode,
            searchText: searchText,
            routineListSectioningMode: routineListSectioningMode,
            routineTasks: routineTasks,
            referenceDate: Date(timeIntervalSince1970: 1_714_608_000),
            calendar: calendar
        ),
        matchesCurrentTaskListMode: { _ in true }
    )
}

private struct TestTaskDisplay: HomeTaskListDisplay, Equatable {
    var taskID: UUID = UUID()
    var name: String
    var emoji: String = "✅"
    var notes: String?
    var placeID: UUID?
    var placeName: String?
    var tags: [String] = []
    var goalTitles: [String] = []
    var interval: Int = 7
    var recurrenceRule: RoutineRecurrenceRule = .interval(days: 7)
    var scheduleMode: RoutineScheduleMode = .fixedInterval
    var createdAt: Date?
    var lastDone: Date?
    var dueDate: Date?
    var priority: RoutineTaskPriority = .none
    var importance: RoutineTaskImportance = .level2
    var urgency: RoutineTaskUrgency = .level2
    var pressure: RoutineTaskPressure = .none
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var pinnedAt: Date?
    var daysUntilDue: Int = 7
    var isOneOffTask: Bool = false
    var isCompletedOneOff: Bool = false
    var isCanceledOneOff: Bool = false
    var isDoneToday: Bool = false
    var isPaused: Bool = false
    var isPinned: Bool = false
    var isInProgress: Bool = false
    var completedChecklistItemCount: Int = 0
    var manualSectionOrders: [String: Int] = [:]
    var todoState: TodoState?
}
