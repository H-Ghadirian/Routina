import SwiftUI

struct HomeIOSHomeToolbarContent: ToolbarContent {
    let taskListMode: HomeFeature.TaskListMode
    let areTaskListModeActionsExpanded: Bool
    let areTopActionsExpanded: Bool
    let hasActiveOptionalFilters: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    let onToggleTaskListModeActions: () -> Void
    let onQuickAdd: () -> Void
    let onShowFilters: () -> Void
    let onAddTask: () -> Void
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
            if areTopActionsExpanded {
                Button {
                    onQuickAdd()
                } label: {
                    Label("Quick Add", systemImage: "text.badge.plus")
                }

                filterButton

                Button {
                    onAddTask()
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }

            Button(action: onToggleTopActions) {
                Label(
                    areTopActionsExpanded ? "Collapse Actions" : "Expand Actions",
                    systemImage: areTopActionsExpanded ? "chevron.right.circle" : "ellipsis.circle"
                )
            }
        }
    }

    private var filterButton: some View {
        Button(action: onShowFilters) {
            Image(
                systemName: hasActiveOptionalFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveOptionalFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
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
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
    }
}
