import ComposableArchitecture
import SwiftUI

struct TaskDetailPresentationRouting {
    private let store: StoreOf<TaskDetailFeature>

    init(store: StoreOf<TaskDetailFeature>) {
        self.store = store
    }

    var editSheet: Binding<Bool> {
        Binding(
            get: { MainActor.assumeIsolated { store.isEditSheetPresented } },
            set: { isPresented in
                MainActor.assumeIsolated {
                    _ = store.send(.setEditSheet(isPresented))
                }
            }
        )
    }

    var deleteConfirmation: Binding<Bool> {
        Binding(
            get: { MainActor.assumeIsolated { store.isDeleteConfirmationPresented } },
            set: { isPresented in
                MainActor.assumeIsolated {
                    _ = store.send(.setDeleteConfirmation(isPresented))
                }
            }
        )
    }

    var undoCompletionConfirmation: Binding<Bool> {
        Binding(
            get: { MainActor.assumeIsolated { store.isUndoCompletionConfirmationPresented } },
            set: { isPresented in
                MainActor.assumeIsolated {
                    _ = store.send(.setUndoCompletionConfirmation(isPresented))
                }
            }
        )
    }

    var editRoutineEmoji: Binding<String> {
        Binding(
            get: { MainActor.assumeIsolated { store.editRoutineEmoji } },
            set: { emoji in
                MainActor.assumeIsolated {
                    _ = store.send(.editRoutineEmojiChanged(emoji))
                }
            }
        )
    }

    var linkedTaskRelationshipKind: Binding<RoutineTaskRelationshipKind> {
        Binding(
            get: { MainActor.assumeIsolated { store.addLinkedTaskRelationshipKind } },
            set: { kind in
                MainActor.assumeIsolated {
                    _ = store.send(.addLinkedTaskRelationshipKindChanged(kind))
                }
            }
        )
    }
}

extension Store where State == TaskDetailFeature.State, Action == TaskDetailFeature.Action {
    var taskDetailPresentationRouting: TaskDetailPresentationRouting {
        TaskDetailPresentationRouting(store: self)
    }
}

enum TaskDetailUndoCompletionAlertMode {
    case adaptiveRemoval
    case undoOnly
}

struct TaskDetailUndoCompletionAlertCopy: Equatable {
    let title: String
    let actionTitle: String
    let message: String

    static func make(
        pendingLogRemovalTimestamp: Date?,
        mode: TaskDetailUndoCompletionAlertMode
    ) -> Self {
        switch mode {
        case .adaptiveRemoval where pendingLogRemovalTimestamp != nil:
            Self(
                title: "Remove log?",
                actionTitle: "Remove",
                message: "This will permanently remove this routine log and may update the routine's schedule."
            )

        case .adaptiveRemoval:
            Self(
                title: "Undo log?",
                actionTitle: "Undo",
                message: "This will remove the selected completion log and may update the routine's schedule."
            )

        case .undoOnly:
            Self(
                title: "Undo log?",
                actionTitle: "Undo",
                message: "This will remove the selected log and may update the routine's schedule."
            )
        }
    }
}

enum TaskDetailAttachmentExportPresentation {
    static func isPresentedBinding(fileToSave: Binding<AttachmentItem?>) -> Binding<Bool> {
        Binding(
            get: { fileToSave.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    fileToSave.wrappedValue = nil
                }
            }
        )
    }
}

extension View {
    func taskDetailDeleteConfirmationAlert(store: StoreOf<TaskDetailFeature>) -> some View {
        let routing = store.taskDetailPresentationRouting

        return alert(
            "Delete routine?",
            isPresented: routing.deleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteRoutineConfirmed)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove \(store.task.name ?? "this routine") and its logs.")
        }
    }

    func taskDetailUndoCompletionConfirmationAlert(
        store: StoreOf<TaskDetailFeature>,
        mode: TaskDetailUndoCompletionAlertMode
    ) -> some View {
        let routing = store.taskDetailPresentationRouting
        let copy = TaskDetailUndoCompletionAlertCopy.make(
            pendingLogRemovalTimestamp: store.pendingLogRemovalTimestamp,
            mode: mode
        )

        return alert(
            copy.title,
            isPresented: routing.undoCompletionConfirmation
        ) {
            Button(copy.actionTitle, role: .destructive) {
                store.send(.confirmUndoCompletion)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(copy.message)
        }
    }
}
