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
    func goalFilterShowsTasksWithLinkedGoals() {
        let tasks = [
            TestTaskDisplay(name: "No goal"),
            TestTaskDisplay(name: "Launch goal", goalTitles: ["Launch"]),
            TestTaskDisplay(name: "Blank goal", goalTitles: ["   "])
        ]

        let result = makeFiltering(selectedGoalFilter: .withGoal)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Launch goal"])
    }

    @Test
    func goalFilterShowsTasksWithoutLinkedGoals() {
        let tasks = [
            TestTaskDisplay(name: "No goal"),
            TestTaskDisplay(name: "Launch goal", goalTitles: ["Launch"]),
            TestTaskDisplay(name: "Blank goal", goalTitles: ["   "])
        ]

        let result = makeFiltering(selectedGoalFilter: .withoutGoal)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Blank goal", "No goal"])
    }

    @Test
    func mediaFilterShowsTasksWithImagesFilesOrAnyMedia() {
        let tasks = [
            TestTaskDisplay(name: "No media"),
            TestTaskDisplay(name: "Design reference", hasImage: true),
            TestTaskDisplay(name: "Brief attachment", hasFileAttachment: true),
            TestTaskDisplay(name: "Annotated spec", hasImage: true, hasFileAttachment: true)
        ]

        let anyMediaResult = makeFiltering(selectedMediaFilter: .anyMedia)
            .filteredTasks(tasks)
        let imageResult = makeFiltering(selectedMediaFilter: .withImage)
            .filteredTasks(tasks)
        let fileResult = makeFiltering(selectedMediaFilter: .withFile)
            .filteredTasks(tasks)

        #expect(Set(anyMediaResult.map(\.name)) == ["Design reference", "Brief attachment", "Annotated spec"])
        #expect(Set(imageResult.map(\.name)) == ["Design reference", "Annotated spec"])
        #expect(Set(fileResult.map(\.name)) == ["Brief attachment", "Annotated spec"])
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
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let tasks = [
            TestTaskDisplay(
                name: "Missed",
                recurrenceRule: .weekly(on: 4, at: RoutineTimeOfDay(hour: 18, minute: 30)),
                dueDate: referenceDate.addingTimeInterval(86_400),
                daysUntilDue: 1,
                hasMissedExactTimedOccurrence: true
            ),
            TestTaskDisplay(name: "Overdue", daysUntilDue: -2),
            TestTaskDisplay(name: "Due Today", daysUntilDue: 0),
            TestTaskDisplay(name: "On Track", daysUntilDue: 4),
            TestTaskDisplay(name: "Done Today", daysUntilDue: 4, isDoneToday: true)
        ]

        let sections = makeFiltering().groupedRoutineSections(from: tasks)

        #expect(sections.map(\.title) == ["Missed", "Overdue", "Due Soon", "On Track", "Done Today"])
        #expect(sections.map { $0.tasks.map(\.name) } == [["Missed"], ["Overdue"], ["Due Today"], ["On Track"], ["Done Today"]])
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
    func manualOrderWinsOverCreatedSortWithinRegularSection() {
        let sectionKey = "onTrack"
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_710_000_000)
        let tasks = [
            TestTaskDisplay(
                name: "Manual bottom",
                createdAt: newerDate,
                daysUntilDue: 4,
                manualSectionOrders: [sectionKey: 1]
            ),
            TestTaskDisplay(
                name: "Manual top",
                createdAt: olderDate,
                daysUntilDue: 4,
                manualSectionOrders: [sectionKey: 0]
            )
        ]

        let result = makeFiltering(taskListSortOrder: .createdNewestFirst)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Manual top", "Manual bottom"])
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
    func iOSPresentationSeparatesDailyRoutinesBeforeStatusBuckets() {
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: -1),
                TestTaskDisplay(name: "Daily Done", recurrenceRule: .daily(at: .defaultValue), daysUntilDue: 0, isDoneToday: true)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [TestTaskDisplay(name: "Archived")],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.kind) == [.daily, .regular, .archived])
        #expect(presentation.sections.map(\.title) == ["Daily Routines", "On Track", "Archived"])
        #expect(presentation.sections.map { $0.tasks.map(\.name) } == [["Daily", "Daily Done"], ["Weekly"], ["Archived"]])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 2, 3])
    }

    @Test
    func iOSPresentationCanHideArchivedSection() {
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(),
            routineDisplays: [TestTaskDisplay(name: "Active", daysUntilDue: 4)],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [TestTaskDisplay(name: "Archived")],
            hideUnavailableRoutines: false,
            showArchivedTasks: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.title) == ["On Track"])
        #expect(presentation.visibleTaskCount == 1)
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

    @Test
    func sidebarPresentationSeparatesDailyRoutinesAndBuildsMoveContext() {
        let dailyID = UUID()
        let regularID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(taskID: regularID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(taskID: dailyID, name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: 0)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.daily, .regular])
        #expect(presentation.sections.map(\.title) == ["Daily Routines", "On Track"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1])
        #expect(presentation.sections.compactMap(\.moveContext?.sectionKey) == ["daily", "onTrack"])
        #expect(presentation.sections.compactMap(\.moveContext?.orderedTaskIDs.first) == [dailyID, regularID])
    }

    @Test
    func sidebarPresentationCanHideArchivedSectionAndArchivedPinnedTasks() {
        let pinnedID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [
                TestTaskDisplay(taskID: pinnedID, name: "Pinned Archived", isPinned: true),
                TestTaskDisplay(name: "Archived")
            ],
            showArchivedTasks: false,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.isEmpty)
        #expect(presentation.visibleTaskCount == 0)
    }

    @Test
    func sidebarVisibleTaskCountMatchesPresentationWithoutBuildingSections() {
        let filtering = makeFiltering(searchText: "match")
        let activeDisplays = [
            TestTaskDisplay(name: "match active", daysUntilDue: 4),
            TestTaskDisplay(name: "match pinned", isPinned: true),
            TestTaskDisplay(name: "hidden active")
        ]
        let awayDisplays = [
            TestTaskDisplay(name: "match away", daysUntilDue: 4),
            TestTaskDisplay(name: "hidden away")
        ]
        let archivedDisplays = [
            TestTaskDisplay(name: "match archived"),
            TestTaskDisplay(name: "match archived pinned", isPinned: true),
            TestTaskDisplay(name: "hidden archived")
        ]

        let visiblePresentation = HomeTaskListPresentation.sidebar(
            filtering: filtering,
            routineDisplays: activeDisplays,
            awayRoutineDisplays: awayDisplays,
            archivedRoutineDisplays: archivedDisplays,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )
        let hiddenArchivedPresentation = HomeTaskListPresentation.sidebar(
            filtering: filtering,
            routineDisplays: activeDisplays,
            awayRoutineDisplays: awayDisplays,
            archivedRoutineDisplays: archivedDisplays,
            showArchivedTasks: false,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(filtering.sidebarVisibleTaskCount(
            activeDisplays: activeDisplays,
            awayDisplays: awayDisplays,
            archivedDisplays: archivedDisplays
        ) == visiblePresentation.visibleTaskCount)
        #expect(filtering.sidebarVisibleTaskCount(
            activeDisplays: activeDisplays,
            awayDisplays: awayDisplays,
            archivedDisplays: archivedDisplays,
            showArchivedTasks: false
        ) == hiddenArchivedPresentation.visibleTaskCount)
    }

    @Test
    func rowMetadataCanHideRoutineCompletionCount() {
        let task = TestTaskDisplay(
            name: "Read",
            recurrenceRule: .daily(at: .defaultValue),
            doneCount: 42
        )
        let filtering = makeFiltering()

        let visiblePresenter = HomeRoutineDisplayMetadataPresenter(
            filtering: filtering,
            showPersianDates: false,
            badgeMode: .complete
        )
        let hiddenPresenter = HomeRoutineDisplayMetadataPresenter(
            filtering: filtering,
            showPersianDates: false,
            badgeMode: .complete,
            showsRoutineCompletionCount: false
        )

        let visibleMetadata = visiblePresenter.rowMetadataText(for: task)
        let hiddenMetadata = hiddenPresenter.rowMetadataText(for: task)

        #expect(visibleMetadata?.contains("42 completions") == true)
        #expect(hiddenMetadata?.contains("42") == false)
        #expect(hiddenMetadata?.contains("completions") == false)
        #expect(hiddenMetadata?.contains("Never completed") == true)
    }

    @Test
    func rowMetadataRespectsHiddenFields() {
        let task = TestTaskDisplay(
            name: "Read",
            steps: ["Open book"],
            recurrenceRule: .daily(at: .defaultValue),
            priority: .medium,
            pressure: .high,
            nextStepTitle: "Open book",
            doneCount: 3
        )
        let filtering = makeFiltering()

        let presenter = HomeRoutineDisplayMetadataPresenter(
            filtering: filtering,
            showPersianDates: false,
            badgeMode: .complete,
            rowVisibility: HomeTaskRowVisibility(
                hiddenFields: [.priority, .pressure, .progress, .steps]
            )
        )

        let metadata = presenter.rowMetadataText(for: task)

        #expect(metadata == "Every day at 20:00")
    }

    @Test
    func taskRowVisibilityRoundTripsHiddenFields() {
        let visibility = HomeTaskRowVisibility(hiddenFields: [.tags, .icon, .colorBadge, .pressure])
        let rawValue = visibility.storageRawValue

        #expect(rawValue == "icon,colorBadge,pressure,tags")
        #expect(HomeTaskRowVisibility(storageRawValue: rawValue) == visibility)
        #expect(HomeTaskRowVisibility(storageRawValue: nil) == .defaultValue)
    }

    @Test
    func rowColorAndColorBadgeVisibilityAreIndependent() {
        let hiddenRowColor = HomeTaskRowVisibility(hiddenFields: [.rowColor])
        let hiddenColorBadge = HomeTaskRowVisibility(hiddenFields: [.colorBadge])

        #expect(!hiddenRowColor.shows(.rowColor))
        #expect(hiddenRowColor.shows(.colorBadge))
        #expect(hiddenColorBadge.shows(.rowColor))
        #expect(!hiddenColorBadge.shows(.colorBadge))
    }
}

private func makeFiltering(
    selectedFilter: RoutineListFilter = .all,
    selectedManualPlaceFilterID: UUID? = nil,
    selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
    selectedTodoStateFilter: TodoState? = nil,
    selectedPressureFilter: RoutineTaskPressure? = nil,
    selectedGoalFilter: HomeTaskGoalFilter = .all,
    selectedMediaFilter: TaskMediaFilter = .all,
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
            selectedGoalFilter: selectedGoalFilter,
            selectedMediaFilter: selectedMediaFilter,
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

private struct TestTaskDisplay: HomeRoutineMetadataDisplay, Equatable {
    var taskID: UUID = UUID()
    var name: String
    var emoji: String = "✅"
    var notes: String?
    var hasImage: Bool = false
    var hasFileAttachment: Bool = false
    var placeID: UUID?
    var placeName: String?
    var locationAvailability: RoutineLocationAvailability = .unrestricted
    var tags: [String] = []
    var goalTitles: [String] = []
    var steps: [String] = []
    var interval: Int = 7
    var recurrenceRule: RoutineRecurrenceRule = .interval(days: 7)
    var scheduleMode: RoutineScheduleMode = .fixedInterval
    var createdAt: Date?
    var lastDone: Date?
    var canceledAt: Date?
    var dueDate: Date?
    var priority: RoutineTaskPriority = .none
    var importance: RoutineTaskImportance = .level2
    var urgency: RoutineTaskUrgency = .level2
    var pressure: RoutineTaskPressure = .none
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var pinnedAt: Date?
    var daysUntilDue: Int = 7
    var hasMissedExactTimedOccurrence: Bool = false
    var isOneOffTask: Bool = false
    var isCompletedOneOff: Bool = false
    var isCanceledOneOff: Bool = false
    var isDoneToday: Bool = false
    var isAssumedDoneToday: Bool = false
    var isPaused: Bool = false
    var isSnoozed: Bool = false
    var isPinned: Bool = false
    var isSoftIntervalRoutine: Bool = false
    var isOngoing: Bool = false
    var ongoingSince: Date?
    var hasPassedSoftThreshold: Bool = false
    var completedStepCount: Int = 0
    var isInProgress: Bool = false
    var nextStepTitle: String?
    var checklistItemCount: Int = 0
    var completedChecklistItemCount: Int = 0
    var dueChecklistItemCount: Int = 0
    var nextPendingChecklistItemTitle: String?
    var nextDueChecklistItemTitle: String?
    var doneCount: Int = 0
    var manualSectionOrders: [String: Int] = [:]
    var todoState: TodoState?
}
