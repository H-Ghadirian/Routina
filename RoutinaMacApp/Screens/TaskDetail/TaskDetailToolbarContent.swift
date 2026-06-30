import SwiftUI
import ComposableArchitecture

struct TaskDetailToolbarContent: ToolbarContent {
    private enum ToolbarMetrics {
        static let controlHeight: CGFloat = 34
        static let iconControlWidth: CGFloat = 42
        static let textCornerRadius: CGFloat = 10
        static let iconCornerRadius: CGFloat = 8
    }

    let store: StoreOf<TaskDetailFeature>
    let showsPrincipalToolbarTitle: Bool
    let isInlineEditPresented: Bool
    let canSaveCurrentEdit: Bool
    let showsEditToolbarButton: Bool
    let onMinimizeFullscreen: (() -> Void)?
    let onCloseFullscreen: (() -> Void)?
    let isTaskSharingEnabled: Bool

    var body: some ToolbarContent {
        if showsPrincipalToolbarTitle {
            RoutinaMacFocusTimerToolbarItem()

            ToolbarItem(placement: .principal) {
                if isInlineEditPresented {
                    editTitle
                } else {
                    Text(store.routineEmoji)
                        .font(TaskDetailPlatformStyle.principalTitleFont)
                }
            }
        }

        if isInlineEditPresented {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    store.send(.setEditSheet(false))
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.send(.editSaveTapped)
                }
                .disabled(!canSaveCurrentEdit)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    actionButtons
                    RoutinaDeepLinkShareMenu(
                        title: RoutineTask.trimmedName(store.task.name) ?? "Untitled task",
                        deepLink: .task(store.task.id),
                        presentation: .plainToolbar
                    )
                    if isTaskSharingEnabled {
                        CloudSharingToolbarButton(task: store.task)
                    }
                    if showsEditToolbarButton {
                        toolbarIconButton(
                            title: "Edit",
                            systemImage: "square.and.pencil"
                        ) {
                            store.send(.setEditSheet(true))
                        }
                    }
                    if let onMinimizeFullscreen {
                        toolbarIconButton(
                            title: "Return to task details sidebar",
                            systemImage: "arrow.down.right.and.arrow.up.left",
                            action: onMinimizeFullscreen
                        )
                    }
                    if let onCloseFullscreen {
                        toolbarIconButton(
                            title: "Close details and show Planner",
                            systemImage: "xmark",
                            action: onCloseFullscreen
                        )
                    }
                }
            }
        }
    }

    private var editTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
            Text("Edit Task")
                .lineLimit(1)
        }
        .font(TaskDetailPlatformStyle.principalTitleFont)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .routinaGlassPill(tint: .accentColor, tintOpacity: 0.10, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        if !store.task.isOneOffTask {
            Button {
                store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
            } label: {
                toolbarTextActionLabel(
                    title: pauseActionTitle,
                    systemImage: pauseSystemImage,
                    tint: pauseTint
                )
            }
            .buttonStyle(.plain)
            .help(pauseActionTitle)
            .accessibilityLabel(pauseActionTitle)
        }

        Button {
            store.send(store.completionButtonAction)
        } label: {
            completionActionLabel
        }
        .buttonStyle(.plain)
        .disabled(store.isCompletionButtonDisabled)
        .help(store.completionButtonTitle)
        .accessibilityLabel(store.completionButtonTitle)

        if showsCancelTodoButton {
            Button {
                store.send(.cancelTodo)
            } label: {
                toolbarTextActionLabel(
                    title: store.cancelTodoButtonTitle,
                    systemImage: "slash.circle",
                    tint: .orange
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isCancelTodoButtonDisabled)
            .help(store.cancelTodoButtonTitle)
            .accessibilityLabel(store.cancelTodoButtonTitle)
        }
    }

    private func toolbarIconButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            toolbarIconLabel(systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    private var completionActionLabel: some View {
        HStack(spacing: 6) {
            if let systemImage = store.completionButtonSystemImage {
                Image(systemName: systemImage)
            }
            Text(store.completionButtonTitle)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 16)
        .frame(minWidth: 68, minHeight: ToolbarMetrics.controlHeight)
        .background(
            RoundedRectangle(cornerRadius: ToolbarMetrics.textCornerRadius, style: .continuous)
                .fill(completionTint)
        )
        .contentShape(RoundedRectangle(cornerRadius: ToolbarMetrics.textCornerRadius, style: .continuous))
        .opacity(store.isCompletionButtonDisabled ? 0.55 : 1)
    }

    private func toolbarTextActionLabel(
        title: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 12)
        .frame(minHeight: ToolbarMetrics.controlHeight)
        .background(
            RoundedRectangle(cornerRadius: ToolbarMetrics.textCornerRadius, style: .continuous)
                .fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ToolbarMetrics.textCornerRadius, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: ToolbarMetrics.textCornerRadius, style: .continuous))
    }

    private func toolbarIconLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: ToolbarMetrics.iconControlWidth, height: ToolbarMetrics.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: ToolbarMetrics.iconCornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ToolbarMetrics.iconCornerRadius, style: .continuous)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: ToolbarMetrics.iconCornerRadius, style: .continuous))
    }

    private var showsCancelTodoButton: Bool {
        store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff
    }

    private var completionTint: Color {
        if store.task.isMultiDayRoutine && store.task.isOngoing {
            return Color.orange
        }
        return store.canUndoSelectedDate ? Color.orange : Color.green
    }

    private var pauseActionTitle: String {
        store.task.isArchived() ? "Resume" : "Pause"
    }

    private var pauseSystemImage: String {
        store.task.isArchived() ? "play.fill" : "pause.fill"
    }

    private var pauseTint: Color {
        store.task.isArchived() ? .teal : .orange
    }
}
