import ComposableArchitecture
import SwiftUI

/// Separate View struct so SwiftUI gives it its own observation lifecycle.
/// Inline closures inside `NavigationSplitView.detail` on macOS can lose
/// observation tracking after several view swaps, causing state changes
/// (like toggling the filter panel) to stop updating the detail column.
struct MacDetailContainerView<FilterView: View, BoardView: View>: View {
    let store: StoreOf<HomeFeature>
    let isBoardPresented: Bool
    let isTimelinePresented: Bool
    let isStatsPresented: Bool
    let isSettingsPresented: Bool
    let settingsStore: StoreOf<SettingsFeature>
    let statsStore: StoreOf<StatsFeature>?
    let selectedSettingsSection: SettingsMacSection
    let dayPlanPlanner: DayPlanPlannerState
    @Binding var mainDetailMode: MacHomeDetailMode
    let selectedTaskID: UUID?
    let onSelectDayPlanUnplannedCompletedDate: (Date) -> Void
    let onOpenDayPlanTaskDetails: (UUID) -> Void
    let addRoutineStore: StoreOf<AddRoutineFeature>?
    @ViewBuilder let filterView: () -> FilterView
    @ViewBuilder let boardView: () -> BoardView

    var body: some View {
        WithPerceptionTracking {
            if store.isMacFilterDetailPresented {
                filterView()
            } else if isBoardPresented {
                boardView()
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
            } else if isTimelinePresented {
                timelineDetailContent
            } else {
                mainDetailContent
            }
        }
    }

    private var mainDetailContent: some View {
        Group {
            switch mainDetailMode {
            case .details:
                selectedTaskDetailContent
            case .planner:
                DayPlanDetailView(
                    planner: dayPlanPlanner,
                    selectedTaskID: selectedTaskID,
                    onSelectUnplannedCompletedDate: onSelectDayPlanUnplannedCompletedDate,
                    onOpenTaskDetails: onOpenDayPlanTaskDetails
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .principal) {
                detailModePicker
            }
        }
    }

    private var detailModePicker: some View {
        Picker("Detail mode", selection: $mainDetailMode) {
            ForEach(MacHomeDetailMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 220)
    }

    @ViewBuilder
    private var timelineDetailContent: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
            )
        } else {
            ContentUnavailableView(
                "Select a done item or filters",
                systemImage: "clock.arrow.circlepath",
                description: Text("Choose a completed routine or todo from the sidebar, or open filters beside search to refine the done history.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var selectedTaskDetailContent: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
            )
        } else {
            ContentUnavailableView(
                store.routineTasks.isEmpty ? "Add a task to get started" : "Select a task",
                systemImage: "sidebar.right",
                description: Text(
                    store.routineTasks.isEmpty
                        ? "Add a routine or to-do to see its details here."
                        : "Choose a routine or to-do from the sidebar to see its details."
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
