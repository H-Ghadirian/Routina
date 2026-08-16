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
    func routineListSectioningModeRemovesStatusFromActiveChoices() {
        #expect(RoutineListSectioningMode.allCases == [.none, .deadlineDate, .tags])
        #expect(RoutineListSectioningMode.defaultValue == .deadlineDate)
        #expect(RoutineListSectioningMode.preferenceValue(rawValue: "status") == .deadlineDate)
    }

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
    func independentFilterAxisUpdatesPreserveTheOtherThreshold() {
        let urgencyOnly = ImportanceUrgencyFilterCell.updatingMinimumUrgency(
            .level3,
            in: nil
        )

        #expect(urgencyOnly?.minimumImportance == nil)
        #expect(urgencyOnly?.minimumUrgency == .level3)

        let both = ImportanceUrgencyFilterCell.updatingMinimumImportance(
            .level2,
            in: urgencyOnly
        )

        #expect(both?.minimumImportance == .level2)
        #expect(both?.minimumUrgency == .level3)

        let importanceOnly = ImportanceUrgencyFilterCell.updatingMinimumUrgency(
            nil,
            in: both
        )

        #expect(importanceOnly?.minimumImportance == .level2)
        #expect(importanceOnly?.minimumUrgency == nil)
        #expect(ImportanceUrgencyFilterCell.updatingMinimumImportance(nil, in: importanceOnly) == nil)
    }

    @Test
    func searchMatchesTaskDescription() {
        let tasks = [
            TestTaskDisplay(name: "Call supplier", taskDescription: "Ask about the replacement shipment"),
            TestTaskDisplay(name: "Call dentist", taskDescription: "Book a cleaning")
        ]

        let result = makeFiltering(searchText: "replacement shipment")
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Call supplier"])
    }

    @Test
    func searchIndexPreservesAllTaskMetadataMatches() {
        let task = TestTaskDisplay(
            name: "Write update",
            emoji: "📝",
            taskDescription: "Replacement shipment",
            notes: "Résumé draft",
            placeName: "North Office",
            tags: ["Deep Work"],
            flags: ["Waiting"],
            goalTitles: ["Launch Project"]
        )

        for query in [
            "write", "📝", "replacement shipment", "resume", "north office",
            "deep work", "waiting", "launch project"
        ] {
            #expect(makeFiltering(searchText: query).matchesSearch(task))
        }
        #expect(!makeFiltering(searchText: "definitely absent").matchesSearch(task))
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
        let displays = [
            TestTaskDisplay(
                taskID: blockedTaskID,
                name: "Submit report",
                hasActiveRelationshipBlocker: true
            ),
            TestTaskDisplay(taskID: blockerID, name: "Draft report")
        ]

        let result = makeFiltering(taskListViewMode: .actionable)
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
    func thinkingNeededFilterMatchesExactComplexityLevel() {
        let tasks = [
            TestTaskDisplay(name: "Easy cleaning", thinkingNeeded: .low),
            TestTaskDisplay(name: "Call lawyer", thinkingNeeded: .high),
            TestTaskDisplay(name: "Unclassified task", thinkingNeeded: .none)
        ]

        let result = makeFiltering(selectedThinkingNeededFilter: .high)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Call lawyer"])
    }

    @Test
    func thinkingNeededNoneFilterShowsUnclassifiedTasks() {
        let tasks = [
            TestTaskDisplay(name: "Low thinking", thinkingNeeded: .low),
            TestTaskDisplay(name: "Unclassified task", thinkingNeeded: .none)
        ]

        let result = makeFiltering(selectedThinkingNeededFilter: RoutineTaskThinkingNeeded.none)
            .filteredTasks(tasks)

        #expect(result.map(\.name) == ["Unclassified task"])
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
    func estimationFilterShowsTasksWithOrWithoutDurationEstimate() {
        let tasks = [
            TestTaskDisplay(name: "No estimate"),
            TestTaskDisplay(name: "Quick estimate", estimatedDurationMinutes: 15),
            TestTaskDisplay(name: "Long estimate", estimatedDurationMinutes: 90)
        ]

        let withEstimateResult = makeFiltering(selectedEstimationFilter: .withEstimate)
            .filteredTasks(tasks)
        let withoutEstimateResult = makeFiltering(selectedEstimationFilter: .withoutEstimate)
            .filteredTasks(tasks)

        #expect(Set(withEstimateResult.map(\.name)) == ["Quick estimate", "Long estimate"])
        #expect(withoutEstimateResult.map(\.name) == ["No estimate"])
    }

    @Test
    func assumedDoneRowsAreVisibleByDefaultAndCanBeHidden() {
        let tasks = [
            TestTaskDisplay(name: "Morning pages", isAssumedDoneToday: true),
            TestTaskDisplay(name: "Read chapter")
        ]

        let defaultResult = makeFiltering()
            .filteredTasks(tasks)
        let hiddenResult = makeFiltering(hideAssumedDoneTasks: true)
            .filteredTasks(tasks)

        #expect(Set(defaultResult.map(\.name)) == ["Morning pages", "Read chapter"])
        #expect(hiddenResult.map(\.name) == ["Read chapter"])
    }

    @Test
    func flagVisibilityRuleHidesOrdinaryPlacementAndSearchRevealsIt() {
        let trackingTask = TestTaskDisplay(name: "Log sleep", flags: ["Tracking"])
        let ordinaryTask = TestTaskDisplay(name: "Write plan", tags: ["Planning"])
        let rules = [RoutineFlagRule(flag: "tracking", kind: .hideFromTaskLists)]

        let ordinaryResult = makeFiltering(flagRules: rules)
            .filteredTasks([trackingTask, ordinaryTask])
        #expect(ordinaryResult.map(\.name) == ["Write plan"])

        let searchedResult = makeFiltering(
            searchText: "sleep",
            flagRules: rules
        ).flagRuleRevealTasks(from: [trackingTask, ordinaryTask])
        #expect(searchedResult.map(\.name) == ["Log sleep"])
    }

    @Test
    func flagVisibilityRuleAddsASeparateHiddenResultsSectionBesideNormalSearchResults() {
        let trackingTask = TestTaskDisplay(name: "Log sleep", flags: ["Tracking"])
        let ordinaryTask = TestTaskDisplay(name: "Sleep early")
        let filtering = makeFiltering(
            searchText: "sleep",
            flagRules: [RoutineFlagRule(flag: "Tracking", kind: .hideFromTaskLists)]
        )
        let normalSection = HomeTaskListPresentationSection(
            kind: .regular,
            title: "Future",
            tasks: [ordinaryTask],
            rowNumberOffset: 0,
            includeMarkDone: true,
            moveContext: nil
        )

        let presentation = HomeTaskListPresentation(
            sections: [normalSection],
            hiddenUnavailableTaskCount: 0,
            emptyState: nil
        ).appendingFlagRuleRevealResults(
            from: [trackingTask, ordinaryTask],
            filtering: filtering
        )

        #expect(presentation.sections.map(\.title) == ["Future", "Hidden by flag"])
        #expect(presentation.sections[1].tasks.map(\.name) == ["Log sleep"])
        #expect(presentation.sections[1].includeMarkDone == false)
    }

    @Test
    func flagFiltersMatchAllOrAnyAndExplicitlyRevealMatchingHiddenTasks() {
        let trackingTask = TestTaskDisplay(name: "Log sleep", flags: ["Tracking", "Health"])
        let focusTask = TestTaskDisplay(name: "Plan week", flags: ["Focus"])
        let unrelatedTask = TestTaskDisplay(name: "Buy groceries", flags: ["Errands"])

        let allMatching = makeFiltering(
            selectedFlags: ["tracking", "health"],
            includeFlagMatchMode: .all
        ).filteredTasks([trackingTask, focusTask, unrelatedTask])
        #expect(allMatching.map(\.name) == ["Log sleep"])

        let anyMatching = makeFiltering(
            selectedFlags: ["Tracking", "Focus"],
            includeFlagMatchMode: .any
        ).filteredTasks([trackingTask, focusTask, unrelatedTask])
        #expect(Set(anyMatching.map(\.name)) == ["Log sleep", "Plan week"])

        let hiddenTrackingRule = [RoutineFlagRule(flag: "Tracking", kind: .hideFromTaskLists)]
        let hiddenFiltering = makeFiltering(
            selectedFlags: ["Tracking"],
            flagRules: hiddenTrackingRule
        )
        #expect(hiddenFiltering.filteredTasks([trackingTask, focusTask, unrelatedTask]).isEmpty)

        let presentation = HomeTaskListPresentation(
            sections: [],
            hiddenUnavailableTaskCount: 0,
            emptyState: nil
        ).appendingFlagRuleRevealResults(
            from: [trackingTask, focusTask, unrelatedTask],
            filtering: hiddenFiltering
        )
        #expect(presentation.sections.map(\.title) == ["Hidden by flag"])
        #expect(presentation.sections[0].tasks.map(\.name) == ["Log sleep"])
        #expect(presentation.sections[0].includeMarkDone == false)
    }

    @Test
    func sidebarPresentationShowsInternalRecordRowsAsRoutines() {
        let assumedID = UUID()
        let visibleID = UUID()
        let tasks = [
            TestTaskDisplay(
                taskID: assumedID,
                name: "Brush teeth",
                recurrenceRule: .interval(days: 1),
                scheduleMode: .record,
                isDoneToday: true,
                isAssumedDoneToday: true
            ),
            TestTaskDisplay(
                taskID: visibleID,
                name: "Meals",
                recurrenceRule: .interval(days: 1)
            )
        ]

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: tasks,
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "",
                systemImage: "magnifyingglass"
            )
        )

        let sectionTitles = presentation.sections.map { $0.title }
        let todayTaskIDs = presentation.sections.first?.tasks.map { $0.taskID }
        let futureTaskIDs = presentation.sections.last?.tasks.map { $0.taskID }

        #expect(sectionTitles == ["Today", "Future"])
        #expect(todayTaskIDs == [visibleID])
        #expect(futureTaskIDs == [assumedID])
    }

    @Test
    func sidebarSearchFallbackShowsDoneDailyTaskHiddenFromNormalTodayList() {
        let mealID = UUID()
        let meal = TestTaskDisplay(
            taskID: mealID,
            name: "Meal",
            recurrenceRule: .interval(days: 1),
            isDoneToday: true
        )
        let filtering = makeFiltering(searchText: "meal")
        let emptyState = HomeTaskListEmptyState(
            title: "No matching tasks",
            message: "Try a different timeline search or filters.",
            systemImage: "magnifyingglass"
        )
        let normalPresentation = HomeTaskListPresentation.sidebar(
            filtering: filtering,
            routineDisplays: [meal],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: emptyState
        )

        #expect(normalPresentation.sections.isEmpty)
        #expect(normalPresentation.emptyState == emptyState)

        let searchPresentation = normalPresentation.addingSearchFallbackResults(
            from: [meal],
            filtering: filtering
        )

        #expect(searchPresentation.emptyState == nil)
        #expect(searchPresentation.sections.map(\.title) == ["Search Results"])
        #expect(searchPresentation.sections.flatMap(\.tasks).map(\.taskID) == [mealID])
        #expect(searchPresentation.sections.first?.includeMarkDone == false)
    }

    @Test
    func sidebarSearchFallbackAddsSuppressedMatchesBesideOrdinaryMatches() {
        let visibleID = UUID()
        let suppressedID = UUID()
        let flagHiddenID = UUID()
        let visibleTask = TestTaskDisplay(
            taskID: visibleID,
            name: "Watch WWDC videos",
            recurrenceRule: .interval(days: 1)
        )
        let suppressedTask = TestTaskDisplay(
            taskID: suppressedID,
            name: "Watch movie or series",
            recurrenceRule: .interval(days: 1),
            isDoneToday: true
        )
        let flagHiddenTask = TestTaskDisplay(
            taskID: flagHiddenID,
            name: "Watch conference recording",
            flags: ["Later"],
            recurrenceRule: .interval(days: 1)
        )
        let filtering = makeFiltering(
            searchText: "watch",
            flagRules: [RoutineFlagRule(flag: "Later", kind: .hideFromTaskLists)]
        )
        let normalPresentation = HomeTaskListPresentation.sidebar(
            filtering: filtering,
            routineDisplays: [visibleTask, suppressedTask, flagHiddenTask],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different timeline search or filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(normalPresentation.sections.flatMap(\.tasks).map(\.taskID) == [visibleID])

        let presentationWithFlagResult = normalPresentation.appendingFlagRuleRevealResults(
            from: [visibleTask, suppressedTask, flagHiddenTask],
            filtering: filtering
        )
        let searchPresentation = presentationWithFlagResult.addingSearchFallbackResults(
            from: [visibleTask, suppressedTask, flagHiddenTask],
            filtering: filtering
        )

        #expect(searchPresentation.sections.dropLast().last?.title == "Hidden by flag")
        #expect(searchPresentation.sections.last?.title == "Search Results")
        #expect(searchPresentation.sections.last?.tasks.map(\.taskID) == [suppressedID])
        #expect(searchPresentation.sections.last?.includeMarkDone == false)
        #expect(searchPresentation.visibleTaskCount == 3)
        #expect(Set(searchPresentation.sections.flatMap(\.tasks).map(\.taskID)).count == 3)
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
    func filteredPlannedTodayTasksIncludesFixedCalendarOccurrencesToday() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let tasks = [
            TestTaskDisplay(
                name: "Monday at five",
                recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 17, minute: 0)),
                dueDate: makeDate("2026-06-22T17:00:00Z"),
                daysUntilDue: 0
            ),
            TestTaskDisplay(
                name: "Twenty second",
                recurrenceRule: .monthly(on: 22),
                daysUntilDue: 0
            ),
            TestTaskDisplay(
                name: "Tuesday",
                recurrenceRule: .weekly(on: 3),
                daysUntilDue: 1
            ),
            TestTaskDisplay(
                name: "Every seven days",
                recurrenceRule: .interval(days: 7),
                daysUntilDue: 0
            ),
            TestTaskDisplay(
                name: "Daily",
                recurrenceRule: .interval(days: 1),
                daysUntilDue: 0
            )
        ]

        let result = makeFiltering(referenceDate: referenceDate)
            .filteredPlannedTodayTasks(tasks)

        #expect(Set(result.map(\.name)) == ["Monday at five", "Twenty second"])
    }

    @Test
    func filteredPlannedTodayTasksRespectsStructuredWeeklyIntervalAnchor() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        calendar.firstWeekday = 2
        let advanced = RoutineAdvancedRecurrenceRule(
            frequency: .weekly,
            interval: 2,
            startDate: makeDate("2026-07-21T11:15:00Z"),
            weekdays: [3],
            timeZoneIdentifier: "UTC",
            calendar: calendar
        )
        let task = TestTaskDisplay(
            name: "Biweekly Tuesday",
            recurrenceRule: .advanced(advanced)
        )

        let firstOccurrence = makeFiltering(referenceDate: makeDate("2026-07-21T12:00:00Z"))
            .filteredPlannedTodayTasks([task])
        let interveningTuesday = makeFiltering(referenceDate: makeDate("2026-07-28T12:00:00Z"))
            .filteredPlannedTodayTasks([task])
        let nextOccurrence = makeFiltering(referenceDate: makeDate("2026-08-04T12:00:00Z"))
            .filteredPlannedTodayTasks([task])

        #expect(firstOccurrence.map(\.name) == ["Biweekly Tuesday"])
        #expect(interveningTuesday.isEmpty)
        #expect(nextOccurrence.map(\.name) == ["Biweekly Tuesday"])
    }

    @Test
    func filteredPlannedTodayTasksExcludesCalendarOccurrenceSatisfiedEarly() {
        let referenceDate = makeDate("2026-07-27T10:00:00Z")
        let tasks = [
            TestTaskDisplay(
                name: "Rent",
                recurrenceRule: .monthly(on: 27),
                lastDone: makeDate("2026-07-26T10:00:00Z"),
                lastSatisfiedScheduledOccurrenceAt: makeDate("2026-07-27T00:00:00Z"),
                dueDate: makeDate("2026-08-27T00:00:00Z"),
                daysUntilDue: 31
            )
        ]

        let result = makeFiltering(referenceDate: referenceDate)
            .filteredPlannedTodayTasks(tasks)

        #expect(result.isEmpty)
    }

    @Test
    func filteredPlannedTodayTasksExcludesCanceledCalendarOccurrenceToday() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let tasks = [
            TestTaskDisplay(
                name: "Canceled Monday",
                recurrenceRule: .weekly(on: 2),
                daysUntilDue: 7,
                isCanceledToday: true
            ),
            TestTaskDisplay(
                name: "Active Monday",
                recurrenceRule: .weekly(on: 2),
                daysUntilDue: 0
            )
        ]

        let result = makeFiltering(referenceDate: referenceDate)
            .filteredPlannedTodayTasks(tasks)

        #expect(result.map(\.name) == ["Active Monday"])
    }

    @Test
    func filteredPlannedTodayTasksExcludesCanceledWeeklyTimeWindowToday() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let window = RoutineTimeRange(
            start: RoutineTimeOfDay(hour: 17, minute: 0),
            end: RoutineTimeOfDay(hour: 18, minute: 0)
        )
        let tasks = [
            TestTaskDisplay(
                name: "Canceled 17 to 18",
                recurrenceRule: .weekly(on: 2, timeRange: window),
                daysUntilDue: 7,
                isCanceledToday: true
            ),
            TestTaskDisplay(
                name: "Active 17 to 18",
                recurrenceRule: .weekly(on: 2, timeRange: window),
                dueDate: makeDate("2026-06-22T17:00:00Z"),
                daysUntilDue: 0
            )
        ]

        let result = makeFiltering(referenceDate: referenceDate)
            .filteredPlannedTodayTasks(tasks)

        #expect(result.map(\.name) == ["Active 17 to 18"])
    }

    @Test
    func filteredPlannedTodayTasksExcludesCompletedRows() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let tasks = [
            TestTaskDisplay(
                name: "Completed planned routine",
                plannedDate: referenceDate,
                isDoneToday: true
            ),
            TestTaskDisplay(
                name: "Completed planned todo",
                plannedDate: referenceDate,
                isOneOffTask: true,
                isCompletedOneOff: true,
                isDoneToday: true,
                todoState: .done
            ),
            TestTaskDisplay(
                name: "Active planned task",
                plannedDate: referenceDate
            )
        ]

        let result = makeFiltering(referenceDate: referenceDate)
            .filteredPlannedTodayTasks(tasks)

        #expect(result.map(\.name) == ["Active planned task"])
    }

    @Test
    func sidebarPresentationExcludesCompletedDailyRowsFromPlanToday() {
        let completedID = UUID()
        let activeID = UUID()
        let tasks = [
            TestTaskDisplay(
                taskID: completedID,
                name: "Completed daily",
                recurrenceRule: .interval(days: 1),
                isDoneToday: true
            ),
            TestTaskDisplay(
                taskID: activeID,
                name: "Active daily",
                recurrenceRule: .interval(days: 1)
            )
        ]

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: tasks,
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Today"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [activeID])
        #expect(presentation.sections.flatMap(\.tasks).contains { $0.taskID == completedID } == false)
    }

    @Test
    func sidebarPresentationKeepsCanceledCalendarOccurrenceOutOfPlanToday() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let canceledID = UUID()
        let plannedID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .tags, referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: canceledID,
                    name: "Canceled Monday",
                    tags: ["Health"],
                    recurrenceRule: .weekly(on: 2),
                    daysUntilDue: 7,
                    isCanceledToday: true
                ),
                TestTaskDisplay(
                    taskID: plannedID,
                    name: "Planned Monday",
                    tags: ["Health"],
                    recurrenceRule: .weekly(on: 2),
                    daysUntilDue: 0
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

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [plannedID])
        #expect(Set(presentation.sections.last?.tasks.map(\.taskID) ?? []) == [plannedID, canceledID])
        #expect(presentation.sections.last?.taskGroups.map(\.title) == [String?("#Health")])
    }

    @Test
    func filteredPlannedTodayTasksHonorsExplicitPlannedDateOverCalendarOccurrence() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let tomorrow = makeDate("2026-06-23T10:00:00Z")
        let tasks = [
            TestTaskDisplay(
                name: "Moved to tomorrow",
                recurrenceRule: .weekly(on: 2),
                plannedDate: tomorrow,
                daysUntilDue: 0
            )
        ]

        let result = makeFiltering(referenceDate: referenceDate)
            .filteredPlannedTodayTasks(tasks)

        #expect(result.isEmpty)
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
    func presentationShowsPlannedTodaySectionAndRetainsRegularMembership() {
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
        #expect(presentation.sections.first?.title == "Today")
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [plannedID])
        #expect(Set(presentation.sections.last?.tasks.map(\.taskID) ?? []) == [plannedID, regularID])
        #expect(presentation.sections.flatMap(\.tasks).filter { $0.taskID == plannedID }.count == 2)
    }

    @Test
    func presentationShowsPinnedPlannedTaskInPinnedAndToday() {
        let referenceDate = Date(timeIntervalSince1970: 1_714_608_000)
        let taskID = UUID()
        let presentation = HomeTaskListPresentation.iOS(
            filtering: makeFiltering(routineListSectioningMode: .none),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: taskID,
                    name: "Pinned plan",
                    plannedDate: referenceDate,
                    isPinned: true
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            hideUnavailableRoutines: false,
            taskListKind: .all
        )

        #expect(presentation.sections.map(\.kind) == [.pinned, .plannedToday])
        #expect(presentation.sections.map { $0.tasks.map(\.taskID) } == [[taskID], [taskID]])
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
    func presentationSectionDeduplicatesRepeatedGroupsAndTasks() {
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()
        let first = TestTaskDisplay(taskID: firstID, name: "Check work emails")
        let second = TestTaskDisplay(taskID: secondID, name: "Call Baba")
        let third = TestTaskDisplay(taskID: thirdID, name: "Clean inbox")
        let moveContext = HomeTaskListMoveContext(sectionKey: "dueSoon", orderedTaskIDs: [firstID, secondID])
        let duplicateMoveContext = HomeTaskListMoveContext(sectionKey: "dueSoon", orderedTaskIDs: [firstID, thirdID])

        let section = HomeTaskListPresentationSection<TestTaskDisplay>(
            kind: .future,
            identityKey: "future",
            title: "Future",
            tasks: [],
            rowNumberOffset: 0,
            includeMarkDone: true,
            moveContext: nil,
            taskGroups: [
                HomeTaskListPresentationTaskGroup(
                    kind: .regular,
                    title: "Due Soon",
                    tasks: [first, second],
                    moveContext: moveContext,
                    isCollapsible: false
                ),
                HomeTaskListPresentationTaskGroup(
                    kind: .regular,
                    title: "Due Soon",
                    tasks: [first, third],
                    moveContext: duplicateMoveContext,
                    isCollapsible: false
                )
            ]
        )

        #expect(section.taskGroups.count == 1)
        #expect(section.taskGroups.first?.tasks.map(\.taskID) == [firstID, secondID, thirdID])
        #expect(section.taskGroups.first?.moveContext?.orderedTaskIDs == [firstID, secondID, thirdID])
    }

    @Test
    func presentationMovesOnlyUserCompletedTasksIntoACollapsedCompletedGroup() {
        let activeID = UUID()
        let completedID = UUID()
        let completedOneOffID = UUID()
        let assumedDoneID = UUID()
        let section = HomeTaskListPresentationSection<TestTaskDisplay>(
            kind: .regular,
            identityKey: "onTrack",
            title: "On Track",
            tasks: [
                TestTaskDisplay(taskID: activeID, name: "Active"),
                TestTaskDisplay(taskID: completedID, name: "Completed", isDoneToday: true),
                TestTaskDisplay(
                    taskID: completedOneOffID,
                    name: "Completed one-off",
                    isOneOffTask: true,
                    isCompletedOneOff: true
                ),
                TestTaskDisplay(
                    taskID: assumedDoneID,
                    name: "Assumed done",
                    isDoneToday: true,
                    isAssumedDoneToday: true
                )
            ],
            rowNumberOffset: 0,
            includeMarkDone: true,
            moveContext: nil
        )

        #expect(section.taskGroups.map(\.title) == [nil, "Completed"])
        #expect(section.taskGroups[0].tasks.map(\.taskID) == [activeID, assumedDoneID])
        #expect(section.taskGroups[1].tasks.map(\.taskID) == [completedID, completedOneOffID])
        #expect(section.taskGroups[1].isCollapsible)
        #expect(section.taskGroups[1].isCollapsedByDefault)
        #expect(!section.taskGroups[1].usesSectionMoveContext)
        #expect(section.tasks.map(\.taskID) == [activeID, assumedDoneID, completedID, completedOneOffID])
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
    func groupedRoutineSectionsTreatsUnscheduledTodosAsOnTrack() {
        let sections = makeFiltering().groupedRoutineSections(from: [
            TestTaskDisplay(name: "Buy phone", daysUntilDue: Int.max, isOneOffTask: true)
        ])

        #expect(sections.map(\.identityKey) == ["onTrack"])
        #expect(sections.map { $0.tasks.map(\.name) } == [["Buy phone"]])
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
    func groupedRoutineSectionsCanSeparateDeadlineStatusWhenGroupingByTags() {
        let sections = makeFiltering(
            routineListSectioningMode: .tags,
            separateDeadlineStatusInTagSections: true
        )
        .groupedRoutineSections(from: [
            TestTaskDisplay(
                name: "Missed",
                tags: ["Focus"],
                daysUntilDue: 1,
                hasMissedExactTimedOccurrence: true
            ),
            TestTaskDisplay(name: "Overdue", tags: ["Focus"], daysUntilDue: -2),
            TestTaskDisplay(name: "Due Soon", tags: ["Admin"], daysUntilDue: 1),
            TestTaskDisplay(name: "Tagged", tags: ["Focus"], daysUntilDue: 4),
            TestTaskDisplay(name: "Untagged", daysUntilDue: 4),
            TestTaskDisplay(name: "Done Today", tags: ["Admin"], daysUntilDue: 4, isDoneToday: true)
        ])

        #expect(sections.map(\.identityKey) == ["missed", "overdue", "dueSoon", "tag:focus", "tag:untagged", "doneToday"])
        #expect(sections.map(\.title) == ["Missed", "Overdue", "Due Soon", "#Focus", "No Tags", "Done Today"])
        #expect(sections.map { $0.tasks.map(\.name) } == [
            ["Missed"],
            ["Overdue"],
            ["Due Soon"],
            ["Tagged"],
            ["Untagged"],
            ["Done Today"]
        ])
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

        let futureSection = presentation.sections[1]
        #expect(presentation.sections.map(\.kind) == [.pinned, .future, .archived])
        #expect(presentation.sections.map(\.title) == ["Pinned", "Future", "Archived"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1, 2])
        #expect(presentation.sections.compactMap(\.moveContext?.sectionKey) == ["pinned", "archived"])
        #expect(presentation.sections.compactMap(\.moveContext?.orderedTaskIDs.first) == [pinnedID, archivedID])
        #expect(futureSection.taskGroups.compactMap(\.moveContext?.sectionKey) == ["onTrack"])
        #expect(futureSection.taskGroups.compactMap(\.moveContext?.orderedTaskIDs.first) == [regularID])
        #expect(presentation.visibleTaskCount == 3)
        #expect(presentation.emptyState == nil)
    }

    @Test
    func sidebarPresentationLeavesBacklogAssignedTasksOffTheRadar() {
        let backlogSectionID = UUID()
        let backlogTaskID = UUID()
        let radarTaskID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: backlogTaskID,
                    name: "Deferred",
                    customTaskSectionID: backlogSectionID
                ),
                TestTaskDisplay(taskID: radarTaskID, name: "Now")
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(
                    id: backlogSectionID,
                    surface: .backlog,
                    title: "Someday",
                    createdAt: nil
                )
            ],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.flatMap(\.tasks).map(\.taskID) == [radarTaskID])
        #expect(!presentation.sections.flatMap(\.tasks).contains(where: { $0.taskID == backlogTaskID }))
    }

    @Test
    func sidebarPresentationAppliesPersistentTopLevelSectionOrderAndReindexesRows() {
        let pinnedID = UUID()
        let regularID = UUID()
        let archivedID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(taskID: regularID, name: "Regular", daysUntilDue: 4),
                TestTaskDisplay(taskID: pinnedID, name: "Pinned", isPinned: true),
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [TestTaskDisplay(taskID: archivedID, name: "Archived")],
            sectionOrderIDs: [
                "archived:archived",
                "future:future",
                "pinned:pinned",
            ],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Archived", "Future", "Pinned"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1, 2])
        #expect(presentation.sections.flatMap(\.tasks).map(\.taskID) == [
            archivedID,
            regularID,
            pinnedID,
        ])
    }

    @Test
    func sidebarPresentationDeadlineDateGroupsAreCollapsibleInsideFuture() {
        let missedID = UUID()
        let overdueID = UUID()
        let dueSoonID = UUID()
        let mondayID = UUID()
        let tuesdayID = UUID()
        let unscheduledID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .deadlineDate),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: missedID,
                    name: "Missed task",
                    daysUntilDue: 0,
                    hasMissedExactTimedOccurrence: true
                ),
                TestTaskDisplay(taskID: overdueID, name: "Overdue task", daysUntilDue: -2),
                TestTaskDisplay(taskID: dueSoonID, name: "Due soon task", daysUntilDue: 1),
                TestTaskDisplay(taskID: mondayID, name: "Monday task", daysUntilDue: 4),
                TestTaskDisplay(taskID: tuesdayID, name: "Tuesday task", daysUntilDue: 5),
                TestTaskDisplay(taskID: unscheduledID, name: "Unscheduled todo", daysUntilDue: Int.max, isOneOffTask: true)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let futureSection = presentation.sections.first
        let taskGroups = futureSection?.taskGroups ?? []
        #expect(futureSection?.kind == .future)
        #expect(Array(taskGroups.prefix(3).map(\.title)) == ["Missed", "Overdue", "Due Soon"])
        #expect(taskGroups.last?.title == "On Track")
        #expect(taskGroups.map(\.kind) == Array(repeating: .deadlineDate, count: 6))
        #expect(taskGroups.map(\.isCollapsible) == Array(repeating: true, count: 6))
        #expect(taskGroups.compactMap(\.moveContext?.sectionKey) == [
            "missed",
            "overdue",
            "dueSoon",
            "onTrack:2024-05-06",
            "onTrack:2024-05-07",
            "onTrack"
        ])
        #expect(taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [
            [missedID],
            [overdueID],
            [dueSoonID],
            [mondayID],
            [tuesdayID],
            [unscheduledID]
        ])
    }

    @Test
    func sidebarPresentationMergesDailyRoutinesIntoPlanTodayByDefault() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let plannedID = UUID()
        let dailyID = UUID()
        let scheduledID = UUID()
        let regularID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(taskID: regularID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4),
                TestTaskDisplay(taskID: dailyID, name: "Daily", recurrenceRule: .interval(days: 1), daysUntilDue: 0),
                TestTaskDisplay(
                    taskID: scheduledID,
                    name: "Monday at five",
                    recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 17, minute: 0)),
                    dueDate: makeDate("2026-06-22T17:00:00Z"),
                    daysUntilDue: 0
                ),
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
        let futureSection = presentation.sections.last
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 3])
        #expect(planSection?.tasks.map(\.taskID) == [scheduledID, plannedID, dailyID])
        #expect(planSection?.taskGroups.map(\.title) == [nil, nil])
        #expect(planSection?.taskGroups.map(\.isCollapsible) == [false, false])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["plannedToday", "daily"])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [[scheduledID, plannedID], [dailyID]])
        #expect(futureSection?.taskGroups.map(\.title) == [String?("Due Soon"), String?("On Track")])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["dueSoon", "onTrack"])
        #expect(futureSection?.taskGroups.first?.tasks.map(\.taskID) == [scheduledID])
        #expect(Set(futureSection?.taskGroups.last?.tasks.map(\.taskID) ?? []) == [plannedID, regularID])
        #expect(futureSection?.taskGroups.map(\.kind) == [.regular, .regular])
        #expect(futureSection?.taskGroups.map(\.isCollapsible) == [false, false])
        #expect(presentation.datePlannedTodayTaskIDs == [plannedID])
        #expect(!presentation.showsPlannedTodayLabel(
            for: scheduledID,
            in: presentation.sections[1]
        ))
    }

    @Test
    func sidebarPresentationKeepsEarlySatisfiedCalendarOccurrenceOnlyInFuture() {
        let referenceDate = makeDate("2026-07-27T10:00:00Z")
        let rentID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: rentID,
                    name: "Rent",
                    recurrenceRule: .monthly(on: 27),
                    lastDone: makeDate("2026-07-26T10:00:00Z"),
                    lastSatisfiedScheduledOccurrenceAt: makeDate("2026-07-27T00:00:00Z"),
                    dueDate: makeDate("2026-08-27T00:00:00Z"),
                    daysUntilDue: 31
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

        #expect(presentation.sections.map(\.kind) == [.future])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [rentID])
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

        let futureSection = presentation.sections.last
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1])
        #expect(presentation.sections.first?.taskGroups.map(\.title) == [String?("Daily Routines")])
        #expect(presentation.sections.first?.taskGroups.map(\.isCollapsible) == [true])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["daily"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs.first) == [dailyID])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["onTrack"])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs.first) == [regularID])
        #expect(futureSection?.taskGroups.map(\.kind) == [.regular])
        #expect(futureSection?.taskGroups.map(\.isCollapsible) == [false])
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
        let futureSection = presentation.sections.last
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 2])
        #expect(planSection?.tasks.map(\.taskID) == [plannedID, dailyID])
        #expect(planSection?.taskGroups.map(\.title) == [nil, String?("Daily Routines")])
        #expect(planSection?.taskGroups.map(\.isCollapsible) == [false, true])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["plannedToday", "daily"])
        #expect(planSection?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [[plannedID], [dailyID]])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["onTrack"])
        #expect(Set(futureSection?.tasks.map(\.taskID) ?? []) == [plannedID, regularID])
    }

    @Test
    func sidebarPresentationKeepsPlannedTomorrowTasksInFutureWhenToggleIsOff() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let tomorrow = makeDate("2026-06-23T10:00:00Z")
        let plannedTomorrowID = UUID()
        let regularID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(taskID: plannedTomorrowID, name: "Plan tomorrow", plannedDate: tomorrow),
                TestTaskDisplay(taskID: regularID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.future])
        #expect(presentation.sections.map(\.title) == ["Future"])
        #expect(Set(presentation.sections.first?.tasks.map(\.taskID) ?? []) == Set([plannedTomorrowID, regularID]))
    }

    @Test
    func sidebarPresentationShowsTomorrowSectionWhenEnabled() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let tomorrow = makeDate("2026-06-23T10:00:00Z")
        let plannedTodayID = UUID()
        let plannedTomorrowLaterID = UUID()
        let plannedTomorrowEarlierID = UUID()
        let scheduledTomorrowID = UUID()
        let regularID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(taskID: plannedTodayID, name: "Plan today", plannedDate: referenceDate),
                TestTaskDisplay(
                    taskID: plannedTomorrowLaterID,
                    name: "Later tomorrow",
                    plannedDate: tomorrow,
                    manualSectionOrders: ["plannedTomorrow": 1]
                ),
                TestTaskDisplay(
                    taskID: plannedTomorrowEarlierID,
                    name: "Earlier tomorrow",
                    plannedDate: tomorrow,
                    manualSectionOrders: ["plannedTomorrow": 0]
                ),
                TestTaskDisplay(
                    taskID: scheduledTomorrowID,
                    name: "Tuesday routine",
                    recurrenceRule: .weekly(on: 3),
                    daysUntilDue: 1
                ),
                TestTaskDisplay(taskID: regularID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            showTomorrowSection: true,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let tomorrowSection = presentation.sections.first { $0.kind == .plannedTomorrow }
        let futureSection = presentation.sections.last
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .plannedTomorrow, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Tomorrow", "Future"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 1, 4])
        #expect(tomorrowSection?.tasks.map(\.taskID) == [
            plannedTomorrowEarlierID,
            plannedTomorrowLaterID,
            scheduledTomorrowID
        ])
        #expect(tomorrowSection?.moveContext?.sectionKey == "plannedTomorrow")
        #expect(tomorrowSection?.moveContext?.orderedTaskIDs == [
            plannedTomorrowEarlierID,
            plannedTomorrowLaterID,
            scheduledTomorrowID
        ])
        #expect(futureSection?.kind == .future)
        #expect(Set(futureSection?.tasks.map(\.taskID) ?? []) == [
            plannedTodayID,
            plannedTomorrowLaterID,
            plannedTomorrowEarlierID,
            scheduledTomorrowID,
            regularID
        ])
    }

    @Test
    func sidebarPresentationPlansInternalRecordRowsBeforeFuture() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z") // Monday
        let tomorrow = makeDate("2026-06-23T10:00:00Z")
        let plannedTodayID = UUID()
        let trackingTodayID = UUID()
        let trackingTomorrowID = UUID()
        let dailyRunoutTrackingTomorrowID = UUID()
        let trackingFutureID = UUID()
        let regularID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: plannedTodayID,
                    name: "Plan today",
                    plannedDate: referenceDate,
                    manualSectionOrders: ["plannedToday": 0]
                ),
                TestTaskDisplay(
                    taskID: trackingTodayID,
                    name: "Plan tracking today",
                    scheduleMode: .record,
                    plannedDate: referenceDate,
                    manualSectionOrders: ["plannedToday": 1]
                ),
                TestTaskDisplay(
                    taskID: trackingTomorrowID,
                    name: "Plan tracking tomorrow",
                    scheduleMode: .recordChecklist,
                    plannedDate: tomorrow,
                    manualSectionOrders: ["plannedTomorrow": 0]
                ),
                TestTaskDisplay(
                    taskID: dailyRunoutTrackingTomorrowID,
                    name: "Plan daily runout tracking tomorrow",
                    recurrenceRule: .interval(days: 1),
                    scheduleMode: .recordDerivedFromChecklist,
                    plannedDate: tomorrow,
                    hasDailyRunoutChecklistItem: true,
                    manualSectionOrders: ["plannedTomorrow": 1]
                ),
                TestTaskDisplay(
                    taskID: trackingFutureID,
                    name: "Unplanned tracking",
                    scheduleMode: .record
                ),
                TestTaskDisplay(taskID: regularID, name: "Weekly", recurrenceRule: .interval(days: 7), daysUntilDue: 4)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            showTomorrowSection: true,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let todaySection = presentation.sections.first { $0.kind == .plannedToday }
        let tomorrowSection = presentation.sections.first { $0.kind == .plannedTomorrow }
        let futureSection = presentation.sections.last
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .plannedTomorrow, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Tomorrow", "Future"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 2, 4])
        #expect(todaySection?.tasks.map(\.taskID) == [plannedTodayID, trackingTodayID])
        #expect(tomorrowSection?.tasks.map(\.taskID) == [trackingTomorrowID, dailyRunoutTrackingTomorrowID])
        #expect(todaySection?.taskGroups.first?.moveContext?.sectionKey == "plannedToday")
        #expect(todaySection?.taskGroups.first?.moveContext?.orderedTaskIDs == [plannedTodayID, trackingTodayID])
        #expect(tomorrowSection?.moveContext?.sectionKey == "plannedTomorrow")
        #expect(tomorrowSection?.moveContext?.orderedTaskIDs == [
            trackingTomorrowID,
            dailyRunoutTrackingTomorrowID
        ])
        #expect(futureSection?.kind == .future)
        #expect(Set(futureSection?.tasks.map(\.taskID) ?? []) == [
            plannedTodayID,
            trackingTodayID,
            trackingTomorrowID,
            dailyRunoutTrackingTomorrowID,
            trackingFutureID,
            regularID
        ])
    }

    @Test
    func sidebarPresentationShowsCustomTaskSectionsForAssignedRows() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z")
        let customSectionID = UUID()
        let customSectionKey = HomeCustomTaskSectionStorage.manualOrderSectionKey(for: customSectionID)
        let plannedTodayID = UUID()
        let customLaterID = UUID()
        let customEarlierID = UUID()
        let trackingID = UUID()
        let futureID = UUID()

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(taskID: plannedTodayID, name: "Plan today", plannedDate: referenceDate),
                TestTaskDisplay(
                    taskID: customLaterID,
                    name: "Custom planned task",
                    plannedDate: referenceDate,
                    customTaskSectionID: customSectionID,
                    manualSectionOrders: [customSectionKey: 1]
                ),
                TestTaskDisplay(
                    taskID: customEarlierID,
                    name: "Custom tracking",
                    scheduleMode: .record,
                    plannedDate: referenceDate,
                    customTaskSectionID: customSectionID,
                    manualSectionOrders: [customSectionKey: 0]
                ),
                TestTaskDisplay(taskID: trackingID, name: "Default tracking", scheduleMode: .record),
                TestTaskDisplay(taskID: futureID, name: "Future", recurrenceRule: .interval(days: 7), daysUntilDue: 4)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(id: customSectionID, title: "Work", createdAt: nil)
            ],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let customSection = presentation.sections.first { $0.kind == .custom }
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .custom, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Work", "Future"])
        #expect(presentation.sections.map(\.rowNumberOffset) == [0, 3, 5])
        #expect(Set(presentation.sections[0].tasks.map(\.taskID)) == [
            plannedTodayID,
            customEarlierID,
            customLaterID
        ])
        #expect(customSection?.identityKey == customSectionKey)
        #expect(customSection?.moveContext?.sectionKey == customSectionKey)
        #expect(customSection?.tasks.map(\.taskID) == [customEarlierID, customLaterID])
        #expect(customSection?.moveContext?.orderedTaskIDs == [customEarlierID, customLaterID])
    }

    @Test
    func sidebarPresentationKeepsPausedSuperSectionAvailableForResume() throws {
        let sectionID = UUID()
        let pauseDate = makeDate("2026-08-08T09:00:00Z")
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: pauseDate),
            routineDisplays: [],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(
                    id: sectionID,
                    title: "Work",
                    createdAt: nil,
                    pausedAt: pauseDate
                )
            ],
            emptyState: HomeTaskListEmptyState(
                title: "Empty",
                message: "Empty",
                systemImage: "tray"
            )
        )

        let section = try #require(presentation.sections.first)
        #expect(presentation.sections.count == 1)
        #expect(section.kind == .custom)
        #expect(section.title == "Work")
        #expect(section.isPaused)
        #expect(section.tasks.isEmpty)
        #expect(presentation.emptyState == nil)
    }

    @Test
    func sidebarPresentationNestsSubsectionRowsInsideTheirSuperSection() throws {
        let referenceDate = makeDate("2026-06-22T10:00:00Z")
        let superSectionID = UUID()
        let subsectionID = UUID()
        let parentTaskID = UUID()
        let childTaskID = UUID()

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: parentTaskID,
                    name: "Parent row",
                    customTaskSectionID: superSectionID
                ),
                TestTaskDisplay(
                    taskID: childTaskID,
                    name: "Child row",
                    customTaskSectionID: subsectionID
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(id: superSectionID, title: "Work", createdAt: nil),
                HomeCustomTaskSection(
                    id: subsectionID,
                    parentSectionID: superSectionID,
                    title: "Project A",
                    createdAt: nil
                )
            ],
            emptyState: HomeTaskListEmptyState(
                title: "Empty",
                message: "Empty",
                systemImage: "tray"
            )
        )

        let section = try #require(presentation.sections.first)
        #expect(section.title == "Work")
        #expect(section.tasks.map(\.taskID) == [parentTaskID, childTaskID])
        #expect(section.taskGroups.map(\.title) == [nil, "Project A"])
        #expect(section.taskGroups[0].tasks.map(\.taskID) == [parentTaskID])
        #expect(section.taskGroups[1].tasks.map(\.taskID) == [childTaskID])
        #expect(
            section.taskGroups[1].moveContext?.sectionKey
                == HomeCustomTaskSectionStorage.manualOrderSectionKey(for: subsectionID)
        )
    }

    @Test
    func sidebarPresentationDoesNotRoutePlannedRowsIntoTaglessCustomSections() {
        let referenceDate = makeDate("2026-06-22T10:00:00Z")
        let customTodaySectionID = UUID()
        let dailyID = UUID()
        let plannedTodayID = UUID()
        let trackingID = UUID()
        let futureID = UUID()

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(referenceDate: referenceDate),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: dailyID,
                    name: "Daily routine",
                    interval: 1,
                    recurrenceRule: .interval(days: 1)
                ),
                TestTaskDisplay(
                    taskID: plannedTodayID,
                    name: "Planned today",
                    plannedDate: referenceDate
                ),
                TestTaskDisplay(
                    taskID: trackingID,
                    name: "Tracking",
                    scheduleMode: .record
                ),
                TestTaskDisplay(
                    taskID: futureID,
                    name: "Future",
                    recurrenceRule: .interval(days: 7),
                    daysUntilDue: 4
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(
                    id: customTodaySectionID,
                    title: "Custom Today",
                    createdAt: nil
                ),
            ],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections[0].tasks.map(\.taskID) == [plannedTodayID, dailyID])
        #expect(
            Set(presentation.sections[1].tasks.map(\.taskID))
                == [plannedTodayID, trackingID, futureID]
        )
    }

    @Test
    func sidebarPresentationAppliesCustomSectionTagRulesCaseInsensitively() {
        let tagSectionID = UUID()
        let taggedID = UUID()
        let futureID = UUID()

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: taggedID,
                    name: "Tagged task",
                    tags: ["work"]
                ),
                TestTaskDisplay(
                    taskID: futureID,
                    name: "Future",
                    tags: ["Home"],
                    recurrenceRule: .interval(days: 7),
                    daysUntilDue: 4
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(
                    id: tagSectionID,
                    title: "Work",
                    createdAt: nil,
                    rules: HomeCustomTaskSectionRules(tagNames: ["Work", "Deep Focus"])
                )
            ],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Work", "Future"])
        #expect(presentation.sections[0].tasks.map(\.taskID) == [taggedID])
        #expect(presentation.sections[1].tasks.map(\.taskID) == [futureID])
    }

    @Test
    func sidebarPresentationRequiresEveryTagForAllModeCustomSectionRules() {
        let tagSectionID = UUID()
        let bothTagsID = UUID()
        let oneTagID = UUID()

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: bothTagsID,
                    name: "Deep work",
                    tags: ["work", "Deep Focus"]
                ),
                TestTaskDisplay(
                    taskID: oneTagID,
                    name: "Ordinary work",
                    tags: ["Work"]
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(
                    id: tagSectionID,
                    title: "Deep Work",
                    createdAt: nil,
                    rules: HomeCustomTaskSectionRules(
                        tagNames: ["Work", "deep focus"],
                        tagMatchMode: .all
                    )
                )
            ],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Deep Work", "Future"])
        #expect(presentation.sections[0].tasks.map(\.taskID) == [bothTagsID])
        #expect(presentation.sections[1].tasks.map(\.taskID) == [oneTagID])
    }

    @Test
    func sidebarPresentationKeepsManualCustomAssignmentForInternalRecordRows() {
        let manualSectionID = UUID()
        let trackingID = UUID()

        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: trackingID,
                    name: "Manually placed tracking",
                    scheduleMode: .record,
                    customTaskSectionID: manualSectionID
                )
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            customSections: [
                HomeCustomTaskSection(id: manualSectionID, title: "Manual", createdAt: nil)
            ],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        #expect(presentation.sections.map(\.title) == ["Manual"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [trackingID])
    }

    @Test
    func sidebarPresentationGroupsInternalRecordRowsWithFutureRoutines() {
        let adminTrackingID = UUID()
        let focusTrackingID = UUID()
        let futureID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: focusTrackingID,
                    name: "Review workouts",
                    tags: ["Focus"],
                    scheduleMode: .record
                ),
                TestTaskDisplay(
                    taskID: adminTrackingID,
                    name: "Log errands",
                    tags: ["Admin"],
                    scheduleMode: .recordChecklist
                ),
                TestTaskDisplay(
                    taskID: futureID,
                    name: "Weekly planning",
                    tags: ["Focus"],
                    daysUntilDue: 4
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

        let futureSection = presentation.sections.first { $0.kind == HomeTaskListPresentationSectionKind.future }

        let sectionKinds: [HomeTaskListPresentationSectionKind] = presentation.sections.map(\.kind)
        #expect(sectionKinds == [.future])
        #expect((futureSection?.taskGroups.map(\.title) ?? []) == [String?("#Admin"), String?("#Focus")])
        #expect((futureSection?.taskGroups.map(\.kind) ?? []) == [.tag, .tag])
        #expect((futureSection?.taskGroups.map(\.isCollapsible) ?? []) == [true, true])
        #expect((futureSection?.taskGroups.first?.tasks.map(\.taskID) ?? []) == [adminTrackingID])
        #expect(Set(futureSection?.taskGroups.last?.tasks.map(\.taskID) ?? []) == [focusTrackingID, futureID])
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

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [plannedID])
        #expect(Set(presentation.sections.last?.tasks.map(\.taskID) ?? []) == [plannedID, tagID])
        #expect(presentation.sections.last?.taskGroups.map(\.title) == [String?("#HSE")])
        #expect(presentation.sections.last?.taskGroups.map(\.kind) == [.tag])
        #expect(presentation.sections.last?.taskGroups.map(\.isCollapsible) == [true])
        #expect(presentation.datePlannedTodayTaskIDs == [plannedID])
        #expect(!presentation.showsPlannedTodayLabel(
            for: plannedID,
            in: presentation.sections[0]
        ))
        #expect(presentation.showsPlannedTodayLabel(
            for: plannedID,
            in: presentation.sections[1]
        ))
        #expect(!presentation.showsPlannedTodayLabel(
            for: tagID,
            in: presentation.sections[1]
        ))
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

        let futureSection = presentation.sections.last
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.first?.taskGroups.map(\.title) == [String?("Daily Routines")])
        #expect(presentation.sections.first?.taskGroups.map(\.isCollapsible) == [true])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["daily"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs.first) == [focusID])
        #expect(futureSection?.taskGroups.map(\.title) == [String?("#Admin")])
        #expect(futureSection?.taskGroups.map(\.kind) == [.tag])
        #expect(futureSection?.taskGroups.map(\.isCollapsible) == [true])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["tag:admin"])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs.first) == [adminID])
    }

    @Test
    func sidebarPresentationTagGroupingCanSplitFutureTagsByTaskKind() {
        let todoID = UUID()
        let routineID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(routineListSectioningMode: .tags),
            routineDisplays: [
                TestTaskDisplay(taskID: routineID, name: "Stretch", tags: ["Focus"], daysUntilDue: 4),
                TestTaskDisplay(taskID: todoID, name: "Book appointment", tags: ["Focus"], daysUntilDue: 4, isOneOffTask: true)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            separateTodosAndRoutinesInTagSections: true,
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let futureSection = presentation.sections.first
        let tagGroup = futureSection?.taskGroups.first
        #expect(futureSection?.kind == .future)
        #expect(tagGroup?.title == "#Focus")
        #expect(tagGroup?.kind == .tag)
        #expect(tagGroup?.isCollapsible == true)
        #expect(tagGroup?.moveContext?.sectionKey == "tag:focus")
        #expect(tagGroup?.childGroups.map(\.title) == [String?("Todos"), String?("Routines")])
        #expect(tagGroup?.childGroups.map(\.id) == ["tag:focus:todos", "tag:focus:routines"])
        #expect(tagGroup?.childGroups.map(\.isCollapsible) == [true, true])
        #expect(tagGroup?.childGroups.map { $0.tasks.map(\.taskID) } == [[todoID], [routineID]])
    }

    @Test
    func sidebarPresentationTagGroupingCanSeparateDeadlineStatusInsideFuture() {
        let missedID = UUID()
        let overdueID = UUID()
        let dueSoonID = UUID()
        let taggedID = UUID()
        let presentation = HomeTaskListPresentation.sidebar(
            filtering: makeFiltering(
                routineListSectioningMode: .tags,
                separateDeadlineStatusInTagSections: true
            ),
            routineDisplays: [
                TestTaskDisplay(
                    taskID: missedID,
                    name: "Missed",
                    tags: ["Focus"],
                    daysUntilDue: 1,
                    hasMissedExactTimedOccurrence: true
                ),
                TestTaskDisplay(taskID: overdueID, name: "Overdue", tags: ["Focus"], daysUntilDue: -2),
                TestTaskDisplay(taskID: dueSoonID, name: "Due soon", tags: ["Admin"], daysUntilDue: 1),
                TestTaskDisplay(taskID: taggedID, name: "Tagged", tags: ["Focus"], daysUntilDue: 4)
            ],
            awayRoutineDisplays: [],
            archivedRoutineDisplays: [],
            emptyState: HomeTaskListEmptyState(
                title: "No matching tasks",
                message: "Try a different place or clear a few filters.",
                systemImage: "magnifyingglass"
            )
        )

        let futureSection = presentation.sections.first
        let taskGroups = futureSection?.taskGroups ?? []
        #expect(futureSection?.kind == .future)
        #expect(taskGroups.map(\.title) == ["Missed", "Overdue", "Due Soon", "#Focus"])
        #expect(taskGroups.map(\.kind) == [.deadlineDate, .deadlineDate, .deadlineDate, .tag])
        #expect(taskGroups.map(\.isCollapsible) == [true, true, true, true])
        #expect(taskGroups.compactMap(\.moveContext?.sectionKey) == ["missed", "overdue", "dueSoon", "tag:focus"])
        #expect(taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [
            [missedID],
            [overdueID],
            [dueSoonID],
            [taggedID]
        ])
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

        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["plannedToday", "daily"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [plannedID, dailyID])
        #expect(Set(presentation.sections.last?.tasks.map(\.taskID) ?? []) == [plannedID, tagID])
        #expect(presentation.sections.last?.taskGroups.map(\.title) == [String?("#HSE")])
        #expect(presentation.sections.last?.taskGroups.map(\.kind) == [.tag])
        #expect(presentation.sections.last?.taskGroups.map(\.isCollapsible) == [true])
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

        let futureSection = presentation.sections.last
        #expect(presentation.sections.map(\.kind) == [.plannedToday, .future])
        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.first?.taskGroups.map(\.title) == [String?("Daily Routines")])
        #expect(presentation.sections.first?.taskGroups.map(\.isCollapsible) == [true])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["daily"])
        #expect(presentation.sections.first?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [[dailyID]])
        #expect(futureSection?.taskGroups.map(\.title) == [nil])
        #expect(futureSection?.taskGroups.map(\.kind) == [.regular])
        #expect(futureSection?.taskGroups.map(\.isCollapsible) == [false])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.sectionKey) == ["tasks"])
        #expect(futureSection?.taskGroups.compactMap(\.moveContext?.orderedTaskIDs) == [[weeklyID]])
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

        #expect(presentation.sections.map(\.title) == ["Today", "Future"])
        #expect(presentation.sections.first?.tasks.map(\.taskID) == [secondID, firstID])
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.sectionKey == "plannedToday")
        #expect(presentation.sections.first?.taskGroups.first?.moveContext?.orderedTaskIDs == [secondID, firstID])
        #expect(Set(presentation.sections.last?.tasks.map(\.taskID) ?? []) == [firstID, secondID])
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

        #expect(presentation.sections.map(\.title) == ["Today"])
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

        #expect(presentation.sections.map(\.title) == ["Today"])
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
    func gentleElapsedStatusUsesTheHomeSnapshotReferenceDate() {
        let task = TestTaskDisplay(
            name: "Call Mom",
            interval: 3,
            recurrenceRule: .interval(days: 3),
            scheduleMode: .softInterval,
            lastDone: makeDate("2024-08-10T16:00:00Z"),
            isSoftIntervalRoutine: true,
            hasPassedSoftThreshold: true
        )
        let presenter = HomeRoutineDisplayMetadataPresenter<TestTaskDisplay>(
            referenceDate: makeDate("2024-08-13T10:00:00Z"),
            showPersianDates: false,
            badgeMode: .complete
        )

        #expect(presenter.completionDescription(for: task) == "3 days ago since last time")
        #expect(presenter.badgeStyle(for: task)?.title == "3 days ago")
    }

    @Test
    func trackingRowsUseRoutineStyleGentleBadges() {
        let task = TestTaskDisplay(
            name: "Clean coffee machine",
            interval: 14,
            recurrenceRule: .interval(days: 14),
            scheduleMode: .record,
            isSoftIntervalRoutine: true
        )
        let presenter = HomeRoutineDisplayMetadataPresenter(
            filtering: makeFiltering(),
            showPersianDates: false,
            badgeMode: .complete
        )

        let badge = presenter.badgeStyle(for: task)

        #expect(badge?.title == "Ready to Do")
        #expect(badge?.systemImage == "circle")
    }

    @Test
    func assumedTrackingRowsUseAssumedBadgeInsteadOfDoneBadge() {
        let task = TestTaskDisplay(
            name: "Eat fruit",
            interval: 1,
            recurrenceRule: .interval(days: 1),
            scheduleMode: .record,
            isDoneToday: true,
            isAssumedDoneToday: true,
            isSoftIntervalRoutine: true
        )
        let presenter = HomeRoutineDisplayMetadataPresenter(
            filtering: makeFiltering(),
            showPersianDates: false,
            badgeMode: .complete
        )

        let badge = presenter.badgeStyle(for: task)

        #expect(badge?.title == "Assumed")
        #expect(badge?.systemImage == "checkmark.circle")
    }

    @Test
    func trackingRowsCanKeepCadenceWithoutGentleNudgeBadges() {
        let task = TestTaskDisplay(
            name: "Clean coffee machine",
            interval: 14,
            recurrenceRule: .interval(days: 14),
            scheduleMode: .record,
            isSoftIntervalRoutine: true,
            surfacesSoftIntervalNudges: false
        )
        let presenter = HomeRoutineDisplayMetadataPresenter(
            filtering: makeFiltering(),
            showPersianDates: false,
            badgeMode: .complete
        )

        #expect(presenter.badgeStyle(for: task) == nil)
        #expect(presenter.rowMetadataText(for: task) == "Every 2 weeks • 0 completions • Not recorded yet")
    }

    @Test
    func cadenceFreeRowsHaveNoCadenceBadgeOrDailyClassification() {
        let task = TestTaskDisplay(
            name: "Visit the library",
            interval: 1,
            recurrenceRule: .interval(days: 1),
            scheduleMode: .fixedInterval,
            trackingCadenceEnabled: false,
            isDoneToday: true
        )
        let presenter = HomeRoutineDisplayMetadataPresenter(
            filtering: makeFiltering(),
            showPersianDates: false,
            badgeMode: .complete
        )

        #expect(!task.isDailyRoutine)
        #expect(presenter.badgeStyle(for: task) == nil)
        #expect(presenter.rowMetadataText(for: task)?.contains("No cadence") == true)
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

    @Test
    func appearanceFieldsRespectFeatureAvailability() {
        let defaultFields = HomeTaskRowField.availableAppearanceFields(
            showsTaskTypeBadge: false,
            showsGoals: false,
            showsPlaces: false
        )
        #expect(!defaultFields.contains(.taskTypeBadge))
        #expect(!defaultFields.contains(.goals))
        #expect(!defaultFields.contains(.place))

        let betaFields = HomeTaskRowField.availableAppearanceFields(
            showsTaskTypeBadge: false,
            showsGoals: true,
            showsPlaces: true
        )
        #expect(!betaFields.contains(.taskTypeBadge))
        #expect(betaFields.contains(.goals))
        #expect(betaFields.contains(.place))
    }
}

private func makeFiltering(
    selectedFilter: RoutineListFilter = .all,
    selectedManualPlaceFilterID: UUID? = nil,
    selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
    selectedTodoStateFilter: TodoState? = nil,
    selectedPressureFilter: RoutineTaskPressure? = nil,
    selectedThinkingNeededFilter: RoutineTaskThinkingNeeded? = nil,
    selectedGoalFilter: HomeTaskGoalFilter = .all,
    selectedMediaFilter: TaskMediaFilter = .all,
    selectedEstimationFilter: TaskEstimationFilter = .all,
    hideAssumedDoneTasks: Bool = false,
    taskListViewMode: HomeTaskListViewMode = .all,
    taskListSortOrder: HomeTaskListSortOrder = .smart,
    createdDateFilter: HomeTaskCreatedDateFilter = .all,
    advancedQuery: String = "",
    selectedTags: Set<String> = [],
    includeTagMatchMode: RoutineTagMatchMode = .all,
    selectedFlags: Set<String> = [],
    includeFlagMatchMode: RoutineTagMatchMode = .all,
    excludedTags: Set<String> = [],
    excludeTagMatchMode: RoutineTagMatchMode = .any,
    searchText: String = "",
    routineListSectioningMode: RoutineListSectioningMode = .status,
    separateDeadlineStatusInTagSections: Bool = false,
    flagRules: [RoutineFlagRule] = [],
    referenceDate: Date = Date(timeIntervalSince1970: 1_714_608_000)
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
            selectedThinkingNeededFilter: selectedThinkingNeededFilter,
            selectedGoalFilter: selectedGoalFilter,
            selectedMediaFilter: selectedMediaFilter,
            selectedEstimationFilter: selectedEstimationFilter,
            hideAssumedDoneTasks: hideAssumedDoneTasks,
            taskListViewMode: taskListViewMode,
            taskListSortOrder: taskListSortOrder,
            createdDateFilter: createdDateFilter,
            selectedTags: selectedTags,
            includeTagMatchMode: includeTagMatchMode,
            selectedFlags: selectedFlags,
            includeFlagMatchMode: includeFlagMatchMode,
            excludedTags: excludedTags,
            excludeTagMatchMode: excludeTagMatchMode,
            searchText: searchText,
            routineListSectioningMode: routineListSectioningMode,
            separateDeadlineStatusInTagSections: separateDeadlineStatusInTagSections,
            flagRules: flagRules,
            routineTasks: [],
            referenceDate: referenceDate,
            calendar: calendar
        ),
        matchesCurrentTaskListMode: { _ in true }
    )
}

private struct TestTaskDisplay: HomeRoutineMetadataDisplay, Equatable {
    var taskID: UUID = UUID()
    var name: String
    var emoji: String = "✅"
    var taskDescription: String?
    var notes: String?
    var hasImage: Bool = false
    var hasFileAttachment: Bool = false
    var placeID: UUID?
    var placeIDs: [UUID] = []
    var placeName: String?
    var locationAvailability: RoutineLocationAvailability = .unrestricted
    var tags: [String] = []
    var flags: [String] = []
    var goalTitles: [String] = []
    var steps: [String] = []
    var interval: Int = 7
    var recurrenceRule: RoutineRecurrenceRule = .interval(days: 7)
    var scheduleMode: RoutineScheduleMode = .fixedInterval
    var trackingCadenceEnabled: Bool = true
    var estimatedDurationMinutes: Int?
    var createdAt: Date?
    var lastDone: Date?
    var lastSatisfiedScheduledOccurrenceAt: Date?
    var canceledAt: Date?
    var dueDate: Date?
    var plannedDate: Date?
    var customTaskSectionID: UUID?
    var priority: RoutineTaskPriority = .none
    var importance: RoutineTaskImportance = .level2
    var urgency: RoutineTaskUrgency = .level2
    var pressure: RoutineTaskPressure = .none
    var thinkingNeeded: RoutineTaskThinkingNeeded = .none
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var pinnedAt: Date?
    var daysUntilDue: Int = 7
    var hasMissedExactTimedOccurrence: Bool = false
    var isOneOffTask: Bool = false
    var isCompletedOneOff: Bool = false
    var isCanceledOneOff: Bool = false
    var isDoneToday: Bool = false
    var isCanceledToday: Bool = false
    var isAssumedDoneToday: Bool = false
    var isPaused: Bool = false
    var isSnoozed: Bool = false
    var isPinned: Bool = false
    var isSoftIntervalRoutine: Bool = false
    var surfacesSoftIntervalNudges: Bool = true
    var isOngoing: Bool = false
    var ongoingSince: Date?
    var hasPassedSoftThreshold: Bool = false
    var completedStepCount: Int = 0
    var isInProgress: Bool = false
    var hasActiveRelationshipBlocker: Bool = false
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
