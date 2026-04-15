import SwiftUI

struct HomeMacSidebarHeaderView<SearchPanel: View>: View {
    @Binding var selectedSidebarMode: HomeFeature.MacSidebarMode
    let selectedTaskListMode: HomeFeature.TaskListMode
    let isRoutinesMode: Bool
    let isTimelineMode: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    @ViewBuilder let searchPanel: () -> SearchPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacSidebarModeStripView(selectedMode: $selectedSidebarMode)

            if isRoutinesMode {
                HomeMacTaskListModeStripView(selectedMode: selectedTaskListMode) { mode in
                    onSelectTaskListMode(mode)
                }
            }

            if isRoutinesMode || isTimelineMode {
                searchPanel()
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }
}
