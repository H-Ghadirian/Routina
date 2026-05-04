import ComposableArchitecture
import SwiftUI

struct AddRoutineNavigationChromeModifier: ViewModifier {
    let store: StoreOf<AddRoutineFeature>
    let isSaveDisabled: Bool

    func body(content: Content) -> some View {
        content
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.cancelTapped)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.saveTapped)
                    }
                    .disabled(isSaveDisabled)
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
        isSaveDisabled: Bool
    ) -> some View {
        modifier(
            AddRoutineNavigationChromeModifier(
                store: store,
                isSaveDisabled: isSaveDisabled
            )
        )
    }

    func routinaAddRoutineTagNotifications(
        store: StoreOf<AddRoutineFeature>
    ) -> some View {
        modifier(AddRoutineTagNotificationsModifier(store: store))
    }
}
