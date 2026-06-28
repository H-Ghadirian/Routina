import SwiftUI

struct HomeMacSidebarHeaderView<SearchPanel: View>: View {
    let selectedTaskListMode: HomeFeature.TaskListMode
    let isRoutinesMode: Bool
    let isBoardMode: Bool
    let isGoalsMode: Bool
    let isTimelineMode: Bool
    let showsSearchPanelContent: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    @AppStorage(
        UserDefaultBoolValueKey.appSettingHomeTaskListModeTabsVisible.rawValue,
        store: SharedDefaults.app
    ) private var isTaskListModeStripVisible = false
    @ViewBuilder let searchPanel: () -> SearchPanel

    var body: some View {
        if hasHeaderContent {
            VStack(alignment: .leading, spacing: 12) {
                if showsTaskListModeStrip {
                    HomeMacTaskListModeStripView(selectedMode: selectedTaskListMode) { mode in
                        onSelectTaskListMode(mode)
                    }
                }

                if showsSearchPanel {
                    searchPanel()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
    }

    private var hasHeaderContent: Bool {
        showsTaskListModeStrip || showsSearchPanel
    }

    private var showsTaskListModeStrip: Bool {
        isRoutinesMode && isTaskListModeStripVisible
    }

    private var showsSearchPanel: Bool {
        showsSearchPanelContent && (isRoutinesMode || isBoardMode || isGoalsMode || isTimelineMode)
    }
}
