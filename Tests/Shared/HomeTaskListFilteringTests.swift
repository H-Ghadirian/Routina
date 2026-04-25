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
}

private func makeFiltering(
    selectedFilter: RoutineListFilter = .all,
    selectedManualPlaceFilterID: UUID? = nil,
    selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
    selectedTodoStateFilter: TodoState? = nil,
    taskListViewMode: HomeTaskListViewMode = .all,
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
            selectedManualPlaceFilterID: selectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
            selectedTodoStateFilter: selectedTodoStateFilter,
            taskListViewMode: taskListViewMode,
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
    var interval: Int = 7
    var recurrenceRule: RoutineRecurrenceRule = .interval(days: 7)
    var scheduleMode: RoutineScheduleMode = .fixedInterval
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
