import SwiftUI
import ComposableArchitecture

struct TaskDetailToolbarContent: ToolbarContent {
    let store: StoreOf<TaskDetailFeature>
    let isInlineEditPresented: Bool
    let canSaveCurrentEdit: Bool
    let isTaskSharingEnabled: Bool
    let onShare: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if isInlineEditPresented {
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
            } else {
                Text(store.routineEmoji)
                    .font(TaskDetailPlatformStyle.principalTitleFont)
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
                if isTaskSharingEnabled {
                    Button(action: onShare) {
                        Label("Share", systemImage: "person.crop.circle.badge.plus")
                    }
                }

                Button {
                    store.send(.setEditSheet(true))
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }

                Menu {
                    RoutinaDeepLinkShareActions(
                        title: RoutineTask.trimmedName(store.task.name) ?? "Untitled task",
                        deepLink: .task(store.task.id)
                    )

                    if store.task.isOneOffTask
                        && !store.task.isCompletedOneOff
                        && !store.task.isCanceledOneOff {
                        Divider()

                        Button {
                            store.send(.cancelTodo)
                        } label: {
                            Label(store.cancelTodoButtonTitle, systemImage: "xmark.circle")
                        }
                        .disabled(store.isCancelTodoButtonDisabled)
                    }

                    Divider()

                    Button(role: .destructive) {
                        store.send(.setDeleteConfirmation(true))
                    } label: {
                        Label("Delete Task", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.vertical")
                }
                .accessibilityLabel("More task actions")
            }
        }
    }
}
