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
        let otherPlaceID = UUID()
        let tasks = [
            TestTaskDisplay(name: "Write launch plan", placeID: placeID, placeIDs: [placeID], tags: ["Work", "Focus"], importance: .level3, urgency: .level3),
            TestTaskDisplay(name: "Write grocery list", placeID: otherPlaceID, placeIDs: [otherPlaceID], tags: ["Home"], importance: .level2, urgency: .level2),
            TestTaskDisplay(name: "Plan admin backlog", placeID: placeID, placeIDs: [placeID], tags: ["Admin"], importance: .level4, urgency: .level4)
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
    func placeFilterMatchesAnyLinkedPlace() {
        let homeID = UUID()
        let gymID = UUID()
        let tasks = [
            TestTaskDisplay(name: "Stretch", placeID: homeID, placeIDs: [homeID, gymID]),
            TestTaskDisplay(name: "Read", placeID: homeID, placeIDs: [homeID])
        ]

        let result = makeFiltering(selectedManualPlaceFilterID: gymID)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Stretch"])
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
    func assumedDoneFilterHidesAssumedRowsByDefault() {
        let tasks = [
            TestTaskDisplay(name: "Morning pages", isAssumedDoneToday: true),
            TestTaskDisplay(name: "Read chapter")
        ]

        let defaultResult = makeFiltering()
            .filteredTasks(tasks)
        let visibleResult = makeFiltering(hideAssumedDoneTasks: false)
            .filteredTasks(tasks)

        #expect(defaultResult.map(\.name) == ["Read chapter"])
        #expect(Set(visibleResult.map(\.name)) == ["Morning pages", "Read chapter"])
    }

    @Test
    func filteredPlannedTodayTasksMatchesReferenceDate() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let tasks = [
            TestTaskDisplay(name: "Plan today", plannedDate: referenceDate.addingTimeInterval(12 * 60 * 60)),
            TestTaskDisplay(name: "Plan tomorrow", plannedDate: referenceDate.addingTimeInterval(24 * 60 * 60)),
            TestTaskDisplay(
                name: "Daily planned today",
                recurrenceRule: .interval(days: 1),
                plannedDate: referenceDate.addingTimeInterval(12 * 60 * 60)
            ),
            TestTaskDisplay(name: "Unplanned")
        ]

        let result = makeFiltering()
            .filteredPlannedTodayTasks(tasks)

        #expect(result.map(\.name) == ["Plan today"])
    }

    @Test
    func presentationKeepsDailyRoutineOutOfPlannedTodaySection() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let dailyID = UUID()
        let weeklyID = UUID()
        let daily = TestTaskDisplay(
            taskID: dailyID,
            name: "Daily routine",
            recurrenceRule: .interval(days: 1),
            plannedDate: referenceDate
        )
        let weekly = TestTaskDisplay(
            taskID: weeklyID,
            name: "Weekly routine",
            recurrenceRule: .interval(days: 7)
        )

        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(),
            routineDisplays: [daily, weekly],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.kind) == [.daily, .regular])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [dailyID])
        #expect(presentation.sections.flatMap(\.tasks).filter { $0.taskID == dailyID }.count == 1)
    }

    @Test
    func presentationTreatsChecklistDrivenRoutineAsDailyOnlyWithDailyRunoutItem() {
        let dailyRunoutID = UUID()
        let weeklyRunoutID = UUID()
        let dailyRunout = TestTaskDisplay(
            taskID: dailyRunoutID,
            name: "Daily runout",
            tags: ["Pantry"],
            recurrenceRule: .interval(days: 1),
            scheduleMode: .derivedFromChecklist,
            hasDailyRunoutChecklistItem: true
        )
        let weeklyRunout = TestTaskDisplay(
            taskID: weeklyRunoutID,
            name: "Weekly runout",
            tags: ["Pantry"],
            recurrenceRule: .interval(days: 1),
            scheduleMode: .derivedFromChecklist,
            hasDailyRunoutChecklistItem: false
        )

        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [dailyRunout, weeklyRunout],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.kind) == [.daily, .tag])
        #expect(presentation.sections.map(\.title) == ["Daily Routines", "#Pantry"])
        #expect(presentation.sections.map { $0.tasks.map(\.taskID) } == [[dailyRunoutID], [weeklyRunoutID]])
    }

    @Test
    func presentationShowsPlannedTodaySectionWithoutDuplicatingRows() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let plannedID = UUID()
        let regularID = UUID()
        let planned = TestTaskDisplay(
            taskID: plannedID,
            name: "Plan today",
            plannedDate: referenceDate
        )
        let regular = TestTaskDisplay(
            taskID: regularID,
            name: "Regular task"
        )

        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(routineListSectioningMode: .none),
            routineDisplays: [planned, regular],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .regular])
        #expect(presentation.sections.first?.title == "Plan to do today")
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [plannedID])
        #expect(presentation.sections.flatMap(\.tasks).filter { $0.taskID == plannedID }.count == 1)
    }

    @Test
    func presentationClaimsEachTaskIDOnceAcrossSourceBuckets() {
        let taskID = UUID()
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(taskID: taskID, name: "Active source", daysUntilDue: 4)
            ],
            awayRoutineDisplays: [
                TestTaskDisplay(taskID: taskID, name: "Away source", daysUntilDue: 4)
            ],
            archivedRoutineDisplays: [
                TestTaskDisplay(taskID: taskID, name: "Archived source", daysUntilDue: 4)
            ],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.visibleTaskCount == 1)
        #expect(presentation.sections.flatMap(\.tasks).map(\.taskID) == [taskID])
        #expect(presentation.sections.flatMap(\.tasks).map(\.name) == ["Active source"])
    }

    @Test
    func presentationIDsComeFromStableKeysNotVisibleTitles() {
        let section = HomeTaskListPresentationSection<TestTaskDisplay>(
            kind: .regular,
            identityKey: "onTrack",
            title: "Visible title",
            tasks: [TestTaskDisplay(name: "Task")],
            rowNumberOffset: 0,
            includeMarkDone: true,
            moveContext: nil
        )
        let renamedSection = HomeTaskListPresentationSection<TestTaskDisplay>(
            kind: .regular,
            identityKey: "onTrack",
            title: "Renamed visible title",
            tasks: [TestTaskDisplay(name: "Task")],
            rowNumberOffset: 0,
            includeMarkDone: true,
            moveContext: nil
        )

        #expect(section.id == "regular:onTrack")
        #expect(renamedSection.id == section.id)
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

        #expect(sections.map(\.identityKey) == ["missed", "overdue", "dueSoon", "onTrack", "doneToday"])
        #expect(sections.map(\.title) == ["Missed", "Overdue", "Due Soon", "On Track", "Done Today"])
        #expect(sections.map { $0.tasks.map(\.name) } == [["Missed"], ["Overdue"], ["Due Today"], ["On Track"], ["Done Today"]])
    }

    @Test
    func groupedRoutineSectionsKeepsOverdueTaskOutOfDoneTodayBucket() {
        let task = TestTaskDisplay(
            name: "Runout routine",
            daysUntilDue: -1,
            isDoneToday: true
        )

        let sections = makeFiltering().groupedRoutineSections(from: [task])

        #expect(sections.map(\.title) == ["Overdue"])
        #expect(sections.map(\.identityKey) == ["overdue"])
        #expect(sections.flatMap(\.tasks).map(\.name) == ["Runout routine"])
    }

    @Test
    func deadlineSectionsUseStableDateKeys() {
        let sections = makeFiltering(routineListSectioningMode: .deadlineDate)
            .groupedRoutineSections(from: [
                TestTaskDisplay(name: "Monday task", daysUntilDue: 4)
            ])

        #expect(sections.map(\.identityKey) == ["deadline:2024-05-06"])
    }

    @Test
    func groupedRoutineSectionsCanGroupByPrimaryTag() {
        let tasks = [
            TestTaskDisplay(name: "Pay rent", tags: ["Admin"]),
            TestTaskDisplay(name: "Buy milk", tags: ["Errand"]),
            TestTaskDisplay(name: "File docs", tags: ["Admin", "Paperwork"]),
            TestTaskDisplay(name: "Loose")
        ]

        let sections = makeFiltering(routineListSectioningMode: .tags)
            .groupedRoutineSections(from: tasks)

        #expect(sections.map(\.title) == ["#Admin", "#Errand", "No Tags"])
        #expect(sections.map { $0.tasks.map(\.name) } == [["File docs", "Pay rent"], ["Buy milk"], ["Loose"]])
    }

    @Test
    func groupedRoutineSectionsCanUseOneUngroupedSection() {
        let tasks = [
            TestTaskDisplay(name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
            TestTaskDisplay(name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: 4),
            TestTaskDisplay(name: "Todo", daysUntilDue: 4, isOneOffTask: true)
        ]

        let sections = makeFiltering(routineListSectioningMode: .none)
            .groupedRoutineSections(from: tasks)

        #expect(sections.map(\.title) == ["Tasks"])
        #expect(sections.map { $0.tasks.map(\.name) } == [["Daily", "Todo", "Weekly"]])
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
    func iOSPresentationTagGroupingKeepsDailyRoutinesSeparate() {
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [
                TestTaskDisplay(name: "Weekly Focus", tags: ["Focus"], recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(name: "Daily Focus", tags: ["Focus"], recurrenceRule: .interval(days: 1), daysUntilDue: 4),
                TestTaskDisplay(name: "Todo Errand", tags: ["Errand"], daysUntilDue: 4, isOneOffTask: true)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.kind) == [.daily, .tag, .tag])
        #expect(presentation.sections.map(\.title) == ["Daily Routines", "#Errand", "#Focus"])
        #expect(presentation.sections.map { $0.tasks.map(\.name) } == [["Daily Focus"], ["Todo Errand"], ["Weekly Focus"]])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1, 2])
    }

    @Test
    func iOSPresentationNoneGroupingKeepsDailyRoutinesSeparate() {
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(routineListSectioningMode: .none),
            routineDisplays: [
                TestTaskDisplay(name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: 4),
                TestTaskDisplay(name: "Todo", daysUntilDue: 4, isOneOffTask: true)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.kind) == [.daily, .regular])
        #expect(presentation.sections.map(\.title) == ["Daily Routines", "Tasks"])
        #expect(presentation.sections.map { $0.tasks.map(\.name) } == [["Daily"], ["Todo", "Weekly"]])
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
            message: "1 routines are hidden because you are away from their matching places.",
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
    func sidebarPresentationMergesDailyRoutinesIntoPlanTodayByDefault() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let plannedID = UUID()
        let dailyID = UUID()
        let regularID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(taskID: regularID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(taskID: dailyID, name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: 0),
                TestTaskDisplay(taskID: plannedID, name: "Plan today", plannedDate: referenceDate)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let planSection = presentation.sections.first
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .regular])
        #expect(presentation.sections.map(\.title) == ["Plan to do today", "On Track"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 2])
        #expect(planSection?.tasks.map(\.taskID) == [plannedID, dailyID])
        #expect(planSection?.taskGroups.map(\.title) == [nil, nil])
        #expect(planSection?.taskGroups.map(\.isCollapsible) == [false, false])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["plannedToday", "daily"])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [[plannedID], [dailyID]])
    }

    @Test
    func sidebarPresentationNestsDailyRoutinesUnderPlanTodayAndBuildsMoveContext() {
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
            separateDailyRoutinesInTaskList: true,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .regular])
        #expect(presentation.sections.map(\.title) == ["Plan to do today", "On Track"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1])
        #expect(presentation.sections.first?.taskGroups.map(\.title) == [String?("Daily Routines")])
        #expect(presentation.sections.first?.taskGroups.map(\.isCollapsible) == [true])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["daily"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs.first) == [dailyID])
        #expect(presentation.sections.dropFirst().compactMap(\.moveContext?.sectionKey) == ["onTrack"])
        #expect(presentation.sections.dropFirst().compactMap(\.moveContext?.orderedTaskIDs.first) == [regularID])
    }

    @Test
    func sidebarPresentationNestsDailyRoutinesInsidePlanTodayWithPlannedTasks() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let plannedID = UUID()
        let dailyID = UUID()
        let regularID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(taskID: regularID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(taskID: dailyID, name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: 0),
                TestTaskDisplay(taskID: plannedID, name: "Plan today", plannedDate: referenceDate)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            separateDailyRoutinesInTaskList: true,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let planSection = presentation.sections.first
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .regular])
        #expect(presentation.sections.map(\.title) == ["Plan to do today", "On Track"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 2])
        #expect(planSection?.tasks.map(\.taskID) == [plannedID, dailyID])
        #expect(planSection?.taskGroups.map(\.title) == [nil, String?("Daily Routines")])
        #expect(planSection?.taskGroups.map(\.isCollapsible) == [false, true])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["plannedToday", "daily"])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [[plannedID], [dailyID]])
    }

    @Test
    func sidebarPresentationKeepsInProgressPlannedTaskInPlanToday() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let plannedID = UUID()
        let tagID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: plannedID,
                    name: "Fix livestream preview alignment",
                    tags: ["HSE"],
                    plannedDate: referenceDate,
                    isInProgress: true
                ),
                TestTaskDisplay(
                    taskID: tagID,
                    name: "Join HSE AI data protection",
                    tags: ["HSE"]
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .tag])
        #expect(presentation.sections.map(\.title) == ["Plan to do today", "#HSE"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [plannedID])
        #expect(presentation.sections.last?.tasks.map(\.taskID) == [tagID])
    }

    @Test
    func sidebarPresentationTagGroupingBuildsTagMoveContexts() {
        let adminID = UUID()
        let focusID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [
                TestTaskDisplay(taskID: focusID, name: "Focus", tags: ["Focus"], recurrenceRule: .interval(days: 1), daysUntilDue: 4),
                TestTaskDisplay(taskID: adminID, name: "Admin", tags: ["Admin"], daysUntilDue: 4)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            separateDailyRoutinesInTaskList: true,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .tag])
        #expect(presentation.sections.map(\.title) == ["Plan to do today", "#Admin"])
        #expect(presentation.sections.first?.taskGroups.map(\.title) == [String?("Daily Routines")])
        #expect(presentation.sections.first?.taskGroups.map(\.isCollapsible) == [true])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["daily"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs.first) == [focusID])
        #expect(presentation.sections.dropFirst().compactMap(\.moveContext?.sectionKey) == ["tag:admin"])
        #expect(presentation.sections.dropFirst().compactMap(\.moveContext?.orderedTaskIDs.first) == [adminID])
    }

    @Test
    func sidebarPresentationTagGroupingMovesPlannedTodayTaskAheadOfMergedDailyRoutines() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let plannedID = UUID()
        let dailyID = UUID()
        let tagID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [
                TestTaskDisplay(taskID: dailyID, name: "Daily", tags: ["Health"], recurrenceRule: .interval(days: 1), daysUntilDue: 0),
                TestTaskDisplay(taskID: plannedID, name: "Join HSE AI data protection", tags: ["HSE"], plannedDate: referenceDate),
                TestTaskDisplay(taskID: tagID, name: "Working Hours", tags: ["HSE"])
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            separateDailyRoutinesInTaskList: false,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .tag])
        #expect(presentation.sections.map(\.title) == ["Plan to do today", "#HSE"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["plannedToday", "daily"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [plannedID, dailyID])
        #expect(presentation.sections.last?.tasks.map(\.taskID) == [tagID])
    }

    @Test
    func sidebarPresentationNoneGroupingNestsDailyRoutinesUnderPlanToday() {
        let dailyID = UUID()
        let weeklyID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .none),
            routineDisplays: [
                TestTaskDisplay(taskID: weeklyID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(taskID: dailyID, name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: 4)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            separateDailyRoutinesInTaskList: true,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .regular])
        #expect(presentation.sections.map(\.title) == ["Plan to do today", "Tasks"])
        #expect(presentation.sections.first?.taskGroups.map(\.title) == [String?("Daily Routines")])
        #expect(presentation.sections.first?.taskGroups.map(\.isCollapsible) == [true])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["daily"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [[dailyID]])
        #expect(presentation.sections.dropFirst().compactMap(\.moveContext?.sectionKey) == ["tasks"])
        #expect(presentation.sections.dropFirst().compactMap(\.moveContext?.orderedTaskIDs) == [[weeklyID]])
    }

    @Test
    func sidebarPresentationOrdersPlannedTodayTasksByPlannedManualOrder() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let firstID = UUID()
        let secondID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .none),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: firstID,
                    name: "First",
                    plannedDate: referenceDate,
                    manualSectionOrders: ["plannedToday": 1]
                ),
                TestTaskDisplay(
                    taskID: secondID,
                    name: "Second",
                    plannedDate: referenceDate,
                    manualSectionOrders: ["plannedToday": 0]
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Plan to do today"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [secondID, firstID])
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.sectionKey == "plannedToday")
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.orderedTaskIDs == [secondID, firstID])
    }

    @Test
    func sidebarPresentationNoneGroupingOrdersDailyRoutinesByDailyManualOrder() {
        let firstID = UUID()
        let secondID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .none),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: firstID,
                    name: "First",
                    recurrenceRule: .interval(days: 1),
                    daysUntilDue: 4,
                    manualSectionOrders: ["daily": 1]
                ),
                TestTaskDisplay(
                    taskID: secondID,
                    name: "Second",
                    recurrenceRule: .interval(days: 1),
                    daysUntilDue: 4,
                    manualSectionOrders: ["daily": 0]
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Plan to do today"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [secondID, firstID])
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.sectionKey == "daily")
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.orderedTaskIDs == [secondID, firstID])
    }

    @Test
    func sidebarPresentationTagGroupingOrdersDailyRoutinesByDailyManualOrder() {
        let firstID = UUID()
        let secondID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: firstID,
                    name: "First",
                    tags: ["Focus"],
                    recurrenceRule: .interval(days: 1),
                    daysUntilDue: 4,
                    manualSectionOrders: ["daily": 1, "tag:focus": 0]
                ),
                TestTaskDisplay(
                    taskID: secondID,
                    name: "Second",
                    tags: ["Focus"],
                    recurrenceRule: .interval(days: 1),
                    daysUntilDue: 4,
                    manualSectionOrders: ["daily": 0, "tag:focus": 1]
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Plan to do today"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [secondID, firstID])
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.sectionKey == "daily")
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.orderedTaskIDs == [secondID, firstID])
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
    func rowMetadataShowsGentleRoutineCadence() {
        let task = TestTaskDisplay(
            name: "Stretch",
            interval: 1,
            recurrenceRule: .interval(days: 1),
            scheduleMode: .softInterval,
            isSoftIntervalRoutine: true
        )
        let presenter = HomeRoutineDisplayMetadataPresenter(
            filtering: makeFiltering(),
            showPersianDates: false,
            badgeMode: .complete
        )

        #expect(presenter.rowMetadataText(for: task) == "Every day • 0 completions • Ready whenever")
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
    hideAssumedDoneTasks: Bool = true,
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
            hideAssumedDoneTasks: hideAssumedDoneTasks,
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
    var placeIDs: [UUID] = []
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
    var plannedDate: Date?
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
    var hasDailyRunoutChecklistItem: Bool = false
    var nextPendingChecklistItemTitle: String?
    var nextDueChecklistItemTitle: String?
    var doneCount: Int = 0
    var manualSectionOrders: [String: Int] = [:]
    var todoState: TodoState?
}
