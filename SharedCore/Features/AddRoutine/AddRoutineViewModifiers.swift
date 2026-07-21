import ComposableArchitecture
import SwiftUI

struct AddRoutineNavigationChromeModifier: ViewModifier {
    let store: StoreOf<AddRoutineFeature>
    let isSaveDisabled: Bool
    let isSaving: Bool
    var showsToolbarActions = true

    func body(content: Content) -> some View {
        content
            .navigationTitle("Add Task")
            .toolbar {
                if showsToolbarActions {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.cancelTapped)
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            store.send(.saveTapped)
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    .accessibilityLabel("Saving task")
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(isSaveDisabled)
                    }
                }
            }
    }
}

struct AddRoutineTagNotificationsModifier: ViewModifier {
    let store: StoreOf<AddRoutineFeature>

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(for: .routineTagDidRename)
                    .receive(on: RunLoop.main)
            ) { notification in
                guard let payload = notification.routineTagRenamePayload else { return }
                store.send(.tagRenamed(oldName: payload.oldName, newName: payload.newName))
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .routineTagDidDelete)
                    .receive(on: RunLoop.main)
            ) { notification in
                guard let tagName = notification.routineTagDeletedName else { return }
                store.send(.tagDeleted(tagName))
            }
    }
}

extension View {
    func routinaAddRoutineNavigationChrome(
        store: StoreOf<AddRoutineFeature>,
        isSaveDisabled: Bool,
        isSaving: Bool,
        showsToolbarActions: Bool = true
    ) -> some View {
        modifier(
            AddRoutineNavigationChromeModifier(
                store: store,
                isSaveDisabled: isSaveDisabled,
                isSaving: isSaving,
                showsToolbarActions: showsToolbarActions
            )
        )
    }

    func routinaAddRoutineTagNotifications(
        store: StoreOf<AddRoutineFeature>
    ) -> some View {
        modifier(AddRoutineTagNotificationsModifier(store: store))
    }
}
