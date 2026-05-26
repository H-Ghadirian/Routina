import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import Testing
@testable @preconcurrency import Routina

@MainActor
struct AppFeatureTests {
    @Test
    func onAppear_restoresPersistedTabAndDonesFilters() async {
        let persistedState = TemporaryViewState(
            selectedAppTabRawValue: Tab.timeline.rawValue,
            homeTaskListModeRawValue: HomeFeature.TaskListMode.all.rawValue,
            homeSelectedFilter: .all,
            homeSelectedTag: nil,
            homeExcludedTags: [],
            homeSelectedManualPlaceFilterID: nil,
            homeTabFilterSnapshots: [:],
            hideUnavailableRoutines: false,
            homeSelectedTimelineRange: .all,
            homeSelectedTimelineFilterType: .all,
            homeSelectedTimelineTag: nil,
            macHomeSidebarModeRawValue: nil,
            macSelectedSettingsSectionRawValue: nil,
            timelineSelectedRange: .month,
            timelineFilterType: .todos,
            timelineSelectedTag: "Errands",
            statsSelectedRange: .year,
            statsSelectedTag: "Focus",
            statsExcludedTags: ["Deep Work"],
            statsTaskTypeFilterRawValue: StatsTaskTypeFilter.todos.rawValue
        )

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.temporaryViewState = { persistedState }
        }

        await store.send(.onAppear) {
            $0.hasRestoredTemporaryViewState = true
            $0.selectedTab = .timeline
            $0.timeline.selectedRange = .month
            $0.timeline.filterType = .todos
            $0.timeline.selectedTag = "Errands"
            $0.timeline.selectedTags = ["Errands"]
            $0.stats.selectedRange = .year
            $0.stats.taskTypeFilter = .todos
            $0.stats.selectedTag = "Focus"
            $0.stats.selectedTags = ["Focus"]
            $0.stats.excludedTags = ["Deep Work"]
        }
    }

    @Test
    func onAppear_restoresPersistedStateOnlyOnce() async {
        let persistedState = TemporaryViewState(
            selectedAppTabRawValue: Tab.timeline.rawValue,
            homeTaskListModeRawValue: HomeFeature.TaskListMode.all.rawValue,
            homeSelectedFilter: .all,
            homeSelectedTag: nil,
            homeExcludedTags: [],
            homeSelectedManualPlaceFilterID: nil,
            homeTabFilterSnapshots: [:],
            hideUnavailableRoutines: false,
            homeSelectedTimelineRange: .all,
            homeSelectedTimelineFilterType: .all,
            homeSelectedTimelineTag: nil,
            macHomeSidebarModeRawValue: nil,
            macSelectedSettingsSectionRawValue: nil,
            timelineSelectedRange: .month,
            timelineFilterType: .todos,
            timelineSelectedTag: "Errands",
            statsSelectedRange: .week,
            statsSelectedTag: nil,
            statsExcludedTags: [],
            statsTaskTypeFilterRawValue: StatsTaskTypeFilter.all.rawValue
        )

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.temporaryViewState = { persistedState }
        }

        await store.send(.onAppear) {
            $0.hasRestoredTemporaryViewState = true
            $0.selectedTab = .timeline
            $0.timeline.selectedRange = .month
            $0.timeline.filterType = .todos
            $0.timeline.selectedTag = "Errands"
            $0.timeline.selectedTags = ["Errands"]
        }

        await store.send(.tabSelected(.search)) {
            $0.selectedTab = .search
        }

        await store.send(.onAppear)
    }

    @Test
    func deepLinkBeforeOnAppearPreventsPersistedTabRestore() async {
        let taskID = UUID()
        let persistedState = TemporaryViewState(
            selectedAppTabRawValue: Tab.stats.rawValue,
            homeTaskListModeRawValue: HomeFeature.TaskListMode.all.rawValue,
            homeSelectedFilter: .all,
            homeSelectedTag: nil,
            homeExcludedTags: [],
            homeSelectedManualPlaceFilterID: nil,
            homeTabFilterSnapshots: [:],
            hideUnavailableRoutines: false,
            homeSelectedTimelineRange: .all,
            homeSelectedTimelineFilterType: .all,
            homeSelectedTimelineTag: nil,
            macHomeSidebarModeRawValue: nil,
            macSelectedSettingsSectionRawValue: nil,
            timelineSelectedRange: .all,
            timelineFilterType: .all,
            timelineSelectedTag: nil,
            statsSelectedRange: .year,
            statsSelectedTag: nil,
            statsExcludedTags: [],
            statsTaskTypeFilterRawValue: StatsTaskTypeFilter.all.rawValue
        )
        let task = RoutineTask(id: taskID, name: "Focus target", scheduleMode: .oneOff)

        let store = TestStore(
            initialState: AppFeature.State(
                selectedTab: .timeline,
                home: HomeFeature.State(routineTasks: [task])
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.temporaryViewState = { persistedState }
        }
        store.exhaustivity = .off

        await store.send(.openDeepLink(.task(taskID))) {
            $0.hasRestoredTemporaryViewState = true
            $0.selectedTab = .home
        }

        await store.send(.onAppear)
    }

    @Test
    func openDeepLink_goalSelectsGoalsTabAndGoal() async {
        let goalID = UUID()
        let goal = makeGoalDisplay(id: goalID, title: "Health")
        let store = TestStore(
            initialState: AppFeature.State(
                selectedTab: .home,
                goals: GoalsFeature.State(goals: [goal])
            )
        ) {
            AppFeature()
        }

        await store.send(.openDeepLink(.goal(goalID))) {
            $0.hasRestoredTemporaryViewState = true
            $0.selectedTab = .goals
        }

        await store.receive(.goals(.openGoalDeepLink(goalID))) {
            $0.goals.selectedGoalID = goalID
            $0.goals.deepLinkedGoalNavigationID = goalID
        }
    }

    @Test
    func openDeepLink_noteSelectsTimelineAndPreparesNotePresentation() async {
        let noteID = UUID()
        let store = TestStore(
            initialState: AppFeature.State(
                selectedTab: .home,
                timeline: TimelineFeature.State(
                    tasks: [],
                    logs: [],
                    selectedRange: .month,
                    filterType: .todos,
                    selectedTag: "Errands",
                    selectedTags: ["Errands"],
                    excludedTags: ["Hidden"],
                    mediaFilter: .withImage,
                    isFilterSheetPresented: true
                )
            )
        ) {
            AppFeature()
        }

        await store.send(.openDeepLink(.note(noteID))) {
            $0.hasRestoredTemporaryViewState = true
            $0.selectedTab = .timeline
        }

        await store.receive(.timeline(.openNoteDeepLink(noteID))) {
            $0.timeline.selectedRange = .all
            $0.timeline.filterType = .notes
            $0.timeline.selectedTag = nil
            $0.timeline.selectedTags = []
            $0.timeline.excludedTags = []
            $0.timeline.mediaFilter = .all
            $0.timeline.isFilterSheetPresented = false
            $0.timeline.deepLinkedNoteID = noteID
        }
    }

    @Test
    func tabSelected_switchesToStatsTab() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.tabSelected(.stats)) {
            $0.selectedTab = .stats
        }
    }

    @Test
    func tabSelected_switchesToSearchTab() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.tabSelected(.search)) {
            $0.selectedTab = .search
        }
    }

    @Test
    func tabSelected_persistsSelectedTab() async {
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.tabSelected(.search)) {
            $0.selectedTab = .search
        }

        #expect(persistedState.value?.selectedAppTabRawValue == Tab.search.rawValue)
    }

    @Test
    func timelineFilterChange_persistsDonesSelection() async {
        let persistedState = LockIsolated<TemporaryViewState?>(nil)
        let now = makeDate("2026-04-10T10:00:00Z")
        let calendar = makeTestCalendar()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }

        await store.send(.timeline(.selectedRangeChanged(.week))) {
            $0.timeline.selectedRange = .week
        }

        #expect(persistedState.value?.timelineSelectedRange == .week)
    }

    @Test
    func resetTemporaryViewState_clearsLiveDonesFiltersImmediately() async {
        let now = makeDate("2026-04-10T10:00:00Z")
        let calendar = makeTestCalendar()
        let expectedChartPoints = RoutineCompletionStats.points(
            for: .week,
            timestamps: [],
            referenceDate: now,
            calendar: calendar
        )
        let expectedFocusChartPoints = FocusDurationStats.points(
            for: .week,
            sessions: [],
            referenceDate: now,
            calendar: calendar
        )

        let store = TestStore(
            initialState: AppFeature.State(
                selectedTab: .settings,
                timeline: TimelineFeature.State(
                    tasks: [],
                    logs: [],
                    selectedRange: .month,
                    filterType: .todos,
                    selectedTag: "Errands",
                    isFilterSheetPresented: true,
                    availableTags: ["Errands"]
                ),
                stats: StatsFeature.State(
                    tasks: [],
                    logs: [],
                    selectedRange: .year,
                    taskTypeFilter: .todos,
                    isFilterSheetPresented: true,
                    selectedTag: "Focus"
                ),
                settings: SettingsFeature.State()
            )
        ) {
            AppFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }
        store.exhaustivity = .off

        await store.send(.settings(.resetTemporaryViewStateTapped)) {
            $0.home.taskListMode = .all
            $0.timeline.selectedRange = .all
            $0.timeline.filterType = .all
            $0.timeline.selectedTag = nil
            $0.timeline.isFilterSheetPresented = false
            $0.timeline.availableTags = []
            $0.timeline.groupedEntries = []
            $0.stats.selectedRange = .week
            $0.stats.isFilterSheetPresented = false
            $0.stats.selectedTag = nil
            $0.stats.taskTypeFilter = .all
            $0.settings.appearance.temporaryViewStateStatusMessage = "Saved filters and temporary selections were reset."
        }
        await store.receive(.timeline(.setData(tasks: [], logs: [])))
        await store.receive(.stats(.setData(tasks: [], logs: [], focusSessions: []))) {
            $0.stats.metrics = StatsFeature.Metrics(
                chartPoints: expectedChartPoints,
                focusChartPoints: expectedFocusChartPoints,
                totalDoneCount: 0,
                totalCanceledCount: 0,
                activeRoutineCount: 0,
                archivedRoutineCount: 0,
                totalCount: 0,
                averagePerDay: 0,
                highlightedBusiestDay: nil,
                activeDayCount: 0,
                chartUpperBound: 1,
                focusChartUpperBound: 10,
                sparklinePoints: expectedChartPoints,
                sparklineMaxCount: 1,
                xAxisDates: expectedChartPoints.map(\.date)
            )
        }
    }

    @Test
    func statsTypeFilterChange_persistsSelection() async {
        let persistedState = LockIsolated<TemporaryViewState?>(nil)
        let now = makeDate("2026-03-20T10:00:00Z")

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
            setTestDateDependencies(&$0, now: now)
        }
        store.exhaustivity = .off

        await store.send(.stats(.taskTypeFilterChanged(.todos))) {
            $0.stats.taskTypeFilter = .todos
        }

        #expect(persistedState.value?.statsTaskTypeFilterRawValue == StatsTaskTypeFilter.todos.rawValue)
    }

    @Test
    func statsClearFilters_resetsAndPersistsClearedState() async {
        let persistedState = LockIsolated<TemporaryViewState?>(nil)
        let now = makeDate("2026-03-20T10:00:00Z")

        let store = TestStore(
            initialState: AppFeature.State(
                stats: StatsFeature.State(
                    tasks: [],
                    logs: [],
                    selectedRange: .year,
                    taskTypeFilter: .todos,
                    selectedTag: "Focus",
                    excludedTags: ["Deep Work"]
                )
            )
        ) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
            setTestDateDependencies(&$0, now: now)
        }
        store.exhaustivity = .off

        await store.send(.stats(.clearFilters)) {
            $0.stats.selectedRange = .week
            $0.stats.taskTypeFilter = .all
            $0.stats.selectedTag = nil
            $0.stats.excludedTags = []
        }

        #expect(persistedState.value?.statsSelectedRange == .week)
        #expect(persistedState.value?.statsTaskTypeFilterRawValue == StatsTaskTypeFilter.all.rawValue)
        #expect(persistedState.value?.statsSelectedTag == nil)
        #expect(persistedState.value?.statsExcludedTags == [])
    }

    private func makeGoalDisplay(id: UUID, title: String) -> GoalsFeature.GoalDisplay {
        GoalsFeature.GoalDisplay(
            id: id,
            title: title,
            emoji: nil,
            notes: nil,
            targetDate: nil,
            tags: [],
            status: .active,
            color: .none,
            parentGoalID: nil,
            parentGoal: nil,
            childGoals: [],
            createdAt: nil,
            sortOrder: 0,
            linkedTasks: [],
            taskSuggestions: []
        )
    }
}
