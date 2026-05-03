import SwiftUI
import ComposableArchitecture

struct TaskDetailPrimaryActionButton: View {
    let store: StoreOf<TaskDetailFeature>
    var useLargePrimaryControl = true

    var body: some View {
        Button {
            store.send(store.completionButtonAction)
        } label: {
            TaskDetailCompletionButtonLabel(
                title: store.completionButtonTitle,
                systemImage: store.completionButtonSystemImage
            )
            .routinaPlatformPrimaryActionLabelLayout()
        }
        .buttonStyle(.borderedProminent)
        .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: useLargePrimaryControl)
        .routinaPlatformPrimaryActionButtonLayout()
        .disabled(store.isCompletionButtonDisabled)
    }
}

struct TaskDetailPressureSegmentedPicker: View {
    let store: StoreOf<TaskDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PRESSURE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            TaskDetailColoredSegmentedControl(
                options: RoutineTaskPressure.allCases,
                selection: store.task.pressure,
                title: { $0.title },
                tint: { TaskDetailPriorityPresentation.pressureTint(for: $0, style: .segmentedControl) },
                selectedForeground: { TaskDetailPriorityPresentation.pressureSelectedForeground(for: $0) },
                action: { store.send(.pressureChanged($0)) }
            )
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle()
    }
}

struct TaskDetailTodoStateSegmentedPicker: View {
    let store: StoreOf<TaskDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("STATE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            TaskDetailColoredSegmentedControl(
                options: TodoState.allCases,
                selection: store.task.todoState ?? .ready,
                title: { $0.displayTitle },
                tint: { TaskDetailPriorityPresentation.todoStateTint(for: $0, style: .segmentedControl) },
                selectedForeground: { TaskDetailPriorityPresentation.todoStateSelectedForeground(for: $0) },
                action: { newState in
                    if newState == .done && store.hasActiveRelationshipBlocker {
                        store.send(.setBlockedStateConfirmation(true))
                    } else {
                        store.send(.todoStateChanged(newState))
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle()
        .alert(
            "Blocked Task",
            isPresented: Binding(
                get: { store.isBlockedStateConfirmationPresented },
                set: { store.send(.setBlockedStateConfirmation($0)) }
            )
        ) {
            Button("Mark Done Anyway", role: .destructive) {
                store.send(.confirmBlockedStateCompletion)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.blockerSummaryText)
        }
    }
}
