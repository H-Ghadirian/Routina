import SwiftUI

struct HomeIOSHomeToolbarContent: ToolbarContent {
    let taskListMode: HomeFeature.TaskListMode
    let areTaskListModeActionsExpanded: Bool
    let areTopActionsExpanded: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    let onToggleTaskListModeActions: () -> Void
    let onToggleTopActions: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if areTaskListModeActionsExpanded {
                taskListModeButton(.all)
                taskListModeButton(.routines)
                taskListModeButton(.todos)
            }

            Button(action: onToggleTaskListModeActions) {
                Label(
                    areTaskListModeActionsExpanded ? "Collapse Task List Modes" : "Expand Task List Modes",
                    systemImage: areTaskListModeActionsExpanded ? "chevron.left.circle" : taskListMode.systemImage
                )
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onToggleTopActions) {
                Label(
                    areTopActionsExpanded ? "Collapse Actions" : "Expand Actions",
                    systemImage: areTopActionsExpanded ? "chevron.up.circle" : "ellipsis.circle"
                )
            }
        }
    }

    private func taskListModeButton(_ mode: HomeFeature.TaskListMode) -> some View {
        let isSelected = taskListMode == mode

        return Button {
            onSelectTaskListMode(mode)
        } label: {
            Image(systemName: mode.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 30)
                .routinaIf(isSelected) { view in
                    view.routinaGlassPill(tint: .accentColor, tintOpacity: 0.16, interactive: true)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
    }
}
