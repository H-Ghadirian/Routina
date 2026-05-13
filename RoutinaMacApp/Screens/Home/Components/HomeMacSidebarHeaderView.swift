import SwiftUI

struct HomeMacSidebarHeaderView<SearchPanel: View>: View {
    @Binding var selectedSidebarMode: HomeFeature.MacSidebarMode
    let doneCount: Int
    let selectedTaskListMode: HomeFeature.TaskListMode
    let isRoutinesMode: Bool
    let isBoardMode: Bool
    let isGoalsMode: Bool
    let isTimelineMode: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    @ViewBuilder let searchPanel: () -> SearchPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacSidebarDoneCounterView(doneCount: doneCount)
            HomeMacSidebarModeStripView(selectedMode: $selectedSidebarMode)

            if isRoutinesMode {
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

struct HomeMacSidebarDoneCounterView: View {
    let doneCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Text("\(doneCount.formatted()) done")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 10, tint: .green, tintOpacity: 0.12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(doneCount.formatted()) done")
    }
}
