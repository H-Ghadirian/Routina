import SwiftUI
import ComposableArchitecture

struct TaskDetailToolbarContent: ToolbarContent {
    let store: StoreOf<TaskDetailFeature>
    let showsPrincipalToolbarTitle: Bool
    let isInlineEditPresented: Bool
    let canSaveCurrentEdit: Bool

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
            ToolbarItemGroup(placement: .primaryAction) {
                actionButtons
                RoutinaDeepLinkShareMenu(
                    title: RoutineTask.trimmedName(store.task.name) ?? "Untitled task",
                    deepLink: .task(store.task.id)
                )
                CloudSharingToolbarButton(task: store.task)
                Button {
                    store.send(.setEditSheet(true))
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
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
        Button {
            store.send(store.completionButtonAction)
        } label: {
            HStack(spacing: 6) {
                if let systemImage = store.completionButtonSystemImage {
                    Image(systemName: systemImage)
                }
                Text(store.completionButtonTitle)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
            .help(store.cancelTodoButtonTitle)
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
