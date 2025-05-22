import ComposableArchitecture
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
            timelineSelectedRange: .month,
            timelineFilterType: .todos,
            timelineSelectedTag: "Errands",
            statsSelectedRange: .year,
            statsSelectedTag: "Focus",
            statsTaskTypeFilterRawValue: nil
        )

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.temporaryViewState = { persistedState }
        }

        await store.send(.onAppear) {
            $0.selectedTab = .timeline
            $0.timeline.selectedRange = .month
            $0.timeline.filterType = .todos
            $0.timeline.selectedTag = "Errands"
            $0.stats.selectedRange = .year
            $0.stats.selectedTag = "Focus"
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
    func timelineFilterChange_persistsDonesSelection() async {
        var persistedState: TemporaryViewState?

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.appSettingsClient.setTemporaryViewState = { persistedState = $0 }
        }

        await store.send(.timeline(.selectedRangeChanged(.week))) {
            $0.timeline.selectedRange = .week
        }

        #expect(persistedState?.timelineSelectedRange == .week)
    }

    @Test
    func resetTemporaryViewState_clearsLiveDonesFiltersImmediately() async {
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
                    selectedTag: "Focus"
                ),
                settings: SettingsFeature.State()
            )
        ) {
            AppFeature()
        }

        await store.send(.settings(.resetTemporaryViewStateTapped)) {
            $0.timeline.selectedRange = .all
            $0.timeline.filterType = .all
            $0.timeline.selectedTag = nil
            $0.timeline.isFilterSheetPresented = false
            $0.timeline.availableTags = []
            $0.timeline.groupedEntries = []
            $0.stats.selectedRange = .week
            $0.stats.selectedTag = nil
            $0.settings.temporaryViewStateStatusMessage = "Saved filters and temporary selections were reset."
        }
        await store.receive(.timeline(.setData(tasks: [], logs: [])))
        await store.receive(.stats(.setData(tasks: [], logs: [])))
    }
}
