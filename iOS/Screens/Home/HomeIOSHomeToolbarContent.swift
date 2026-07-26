import SwiftUI

struct HomeIOSHomeToolbarContent: ToolbarContent {
    let taskListMode: HomeFeature.TaskListMode
    let areTaskListModeActionsExpanded: Bool
    let showTaskListModeActions: Bool
    let hasActiveOptionalFilters: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    let onToggleTaskListModeActions: () -> Void
    let onShowFilters: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if showTaskListModeActions {
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
        }

        ToolbarItemGroup(placement: .primaryAction) {
            topActionButton(
                title: "Filters",
                systemImage: hasActiveOptionalFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle",
                tint: hasActiveOptionalFilters ? .accentColor : .secondary,
                isHighlighted: hasActiveOptionalFilters,
                action: onShowFilters
            )
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

    private func topActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isHighlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
                .routinaIf(isHighlighted) { view in
                    view.routinaGlassPill(tint: .accentColor, tintOpacity: 0.16, interactive: true)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
