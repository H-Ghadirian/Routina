import SwiftUI

struct HomeIOSHomeToolbarContent: ToolbarContent {
    let taskListMode: HomeFeature.TaskListMode
    let areTaskListModeActionsExpanded: Bool
    let areTopActionsExpanded: Bool
    let hasActiveOptionalFilters: Bool
    let showsSleepAction: Bool
    let onSelectTaskListMode: (HomeFeature.TaskListMode) -> Void
    let onToggleTaskListModeActions: () -> Void
    let onShowFilters: () -> Void
    let onAddEmotion: () -> Void
    let onAddNote: () -> Void
    let onCheckIn: () -> Void
    let onStartSleep: () -> Void
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
                topActionButton(
                    title: "Filters",
                    systemImage: hasActiveOptionalFilters
                        ? "line.3.horizontal.decrease.circle.fill"
                        : "line.3.horizontal.decrease.circle",
                    tint: hasActiveOptionalFilters ? .accentColor : .secondary,
                    isHighlighted: hasActiveOptionalFilters,
                    action: onShowFilters
                )

                if showsSleepAction {
                    topActionButton(
                        title: "Going to sleep",
                        systemImage: "bed.double.fill",
                        tint: .indigo,
                        isHighlighted: false,
                        action: onStartSleep
                    )
                }

                topActionButton(
                    title: "Add Note",
                    systemImage: "note.text",
                    tint: .blue,
                    isHighlighted: false,
                    action: onAddNote
                )

                topActionButton(
                    title: "Check In",
                    systemImage: "mappin.and.ellipse",
                    tint: .teal,
                    isHighlighted: false,
                    action: onCheckIn
                )

                topActionButton(
                    title: "Log Emotion",
                    systemImage: "face.smiling",
                    tint: .pink,
                    isHighlighted: false,
                    action: onAddEmotion
                )
            }

            Button(action: onToggleTopActions) {
                Label(
                    areTopActionsExpanded ? "Collapse Actions" : "Expand Actions",
                    systemImage: areTopActionsExpanded ? "chevron.right.circle" : "ellipsis.circle"
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
