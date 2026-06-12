import SwiftUI

struct HomeMacSidebarHeaderView<SearchPanel: View>: View {
    @Binding var selectedSidebarMode: HomeFeature.MacSidebarMode
    let selectedTaskListMode: HomeFeature.TaskListMode
    let isRoutinesMode: Bool
    let isBoardMode: Bool
    let isGoalsMode: Bool
    let isTimelineMode: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    let onAddEvent: () -> Void
    let onAddEmotion: () -> Void
    let onAddNote: () -> Void
    let onAddGoal: () -> Void
    let onAddTask: () -> Void
    let onCheckIn: () -> Void
    let onStartAway: () -> Void
    @AppStorage(
        UserDefaultBoolValueKey.appSettingHomeTaskListModeTabsVisible.rawValue,
        store: SharedDefaults.app
    ) private var isTaskListModeStripVisible = false
    @ViewBuilder let searchPanel: () -> SearchPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacSidebarModeStripView(
                selectedMode: $selectedSidebarMode,
                onAddEvent: onAddEvent,
                onAddEmotion: onAddEmotion,
                onAddNote: onAddNote,
                onAddGoal: onAddGoal,
                onAddTask: onAddTask,
                onCheckIn: onCheckIn,
                onStartAway: onStartAway
            )

            if isRoutinesMode && isTaskListModeStripVisible {
                HomeMacTaskListModeStripView(selectedMode: selectedTaskListMode) { mode in
                    onSelectTaskListMode(mode)
                }
            }

            if isRoutinesMode || isBoardMode || isGoalsMode || isTimelineMode {
                searchPanel()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}
