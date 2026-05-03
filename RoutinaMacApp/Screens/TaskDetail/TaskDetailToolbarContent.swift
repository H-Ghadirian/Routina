import SwiftUI
import ComposableArchitecture

struct TaskDetailToolbarContent: ToolbarContent {
    let store: StoreOf<TaskDetailFeature>
    let showsPrincipalToolbarTitle: Bool
    let isInlineEditPresented: Bool
    let canSaveCurrentEdit: Bool

    var body: some ToolbarContent {
        if showsPrincipalToolbarTitle {
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
            ToolbarItemGroup(placement: .primaryAction) {
                actionButtons
                CloudSharingToolbarButton(task: store.task)
                Button("Edit") {
                    store.send(.setEditSheet(true))
                }
            }
        }
    }

    private var editTitle: some View {
        HStack(spacing: 8) {
            Text("✏️")
            Text("Edit Task")
                .lineLimit(1)
        }
        .font(TaskDetailPlatformStyle.principalTitleFont)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            store.send(store.completionButtonAction)
        } label: {
            TaskDetailCompletionButtonLabel(
                title: store.completionButtonTitle,
                systemImage: store.completionButtonSystemImage
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(completionTint)
        .disabled(store.isCompletionButtonDisabled)

        if store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
            Button {
                store.send(.cancelTodo)
            } label: {
                Label(store.cancelTodoButtonTitle, systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(store.isCancelTodoButtonDisabled)
        }

        if !store.task.isOneOffTask {
            Button {
                store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
            } label: {
                Label(pauseActionTitle, systemImage: pauseSystemImage)
            }
            .buttonStyle(.bordered)
            .tint(pauseTint)
        }
    }

    private var completionTint: Color {
        store.canUndoSelectedDate ? .orange : .green
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
