import ComposableArchitecture
import SwiftUI

/// Separate View struct so SwiftUI gives it its own observation lifecycle.
/// Inline closures inside `NavigationSplitView.detail` on macOS can lose
/// observation tracking after several view swaps, causing state changes
/// (like toggling the filter panel) to stop updating the detail column.
struct MacDetailContainerView<FilterView: View, BoardView: View>: View {
    let store: StoreOf<HomeFeature>
    let isBoardPresented: Bool
    let isPlanPresented: Bool
    let isTimelinePresented: Bool
    let isStatsPresented: Bool
    let isSettingsPresented: Bool
    let settingsStore: StoreOf<SettingsFeature>
    let statsStore: StoreOf<StatsFeature>?
    let selectedSettingsSection: SettingsMacSection
    let dayPlanPlanner: DayPlanPlannerState
    let addRoutineStore: StoreOf<AddRoutineFeature>?
    @ViewBuilder let filterView: () -> FilterView
    @ViewBuilder let boardView: () -> BoardView

    var body: some View {
        WithPerceptionTracking {
            if store.isMacFilterDetailPresented {
                filterView()
            } else if isBoardPresented {
                boardView()
            } else if isPlanPresented {
                DayPlanDetailView(planner: dayPlanPlanner)
            } else if let addRoutineStore {
                AddRoutineTCAView(store: addRoutineStore)
            } else if isStatsPresented, let statsStore {
                StatsViewWrapper(store: statsStore)
            } else if isStatsPresented {
                ContentUnavailableView(
                    "Stats unavailable",
                    systemImage: "chart.bar.xaxis",
                    description: Text("The stats store is not currently connected for this view.")
                )
            } else if isSettingsPresented {
                EmbeddedSettingsMacDetailView(
                    store: settingsStore,
                    section: selectedSettingsSection
                )
            } else if let detailStore = store.scope(
                state: \.taskDetailState,
                action: \.taskDetail
            ) {
                TaskDetailTCAView(store: detailStore)
            } else {
                ContentUnavailableView(
                    isTimelinePresented
                        ? "Select a done item or filters"
                        : (store.routineTasks.isEmpty ? "Add a task to get started" : "Select a task"),
                    systemImage: isTimelinePresented ? "clock.arrow.circlepath" : "sidebar.right",
                    description: Text(
                        isTimelinePresented
                            ? "Choose a completed routine or todo from the sidebar, or open filters beside search to refine the done history."
                            : (
                                store.routineTasks.isEmpty
                                    ? "Add a routine or to-do to see its details here."
                                    : "Choose a routine or to-do from the sidebar to see its details."
                            )
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
