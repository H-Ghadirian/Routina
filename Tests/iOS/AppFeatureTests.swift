import ComposableArchitecture
import ConcurrencyExtras
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
}
