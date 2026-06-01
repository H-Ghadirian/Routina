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
    let timingSummary: TodoStateTimingSummary?
    let showPersianDates: Bool
    @State private var isExpanded = false

    var body: some View {
        let currentState = store.task.todoState ?? .ready

        VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    Text("STATE")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    stateSummaryPill(currentState)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse state" : "Expand state")

            if isExpanded {
                TaskDetailColoredSegmentedControl(
                    options: TodoState.allCases,
                    selection: currentState,
                    title: { $0.displayTitle },
                    tint: { TaskDetailPriorityPresentation.todoStateTint(for: $0, style: .segmentedControl) },
                    selectedForeground: { TaskDetailPriorityPresentation.todoStateSelectedForeground(for: $0) },
                    action: { newState in
                        if newState == .done && store.hasActiveRelationshipBlocker {
                            store.send(.setBlockedStateConfirmation(true))
                        } else {
                            store.send(.todoStateChanged(newState))
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isExpanded = false
                            }
                        }
                    }
                )

                if let timingSummary {
                    Divider()
                        .padding(.vertical, 6)

                    TodoStateTimingInlineView(
                        summary: timingSummary,
                        showPersianDates: showPersianDates
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle(tint: TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .segmentedControl))
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
        .onChange(of: store.task.id) { _, _ in
            isExpanded = false
        }
        .onChange(of: store.task.todoStateRawValue) { _, _ in
            isExpanded = false
        }
    }

    private func stateSummaryPill(_ state: TodoState) -> some View {
        let tint = TaskDetailPriorityPresentation.todoStateTint(for: state, style: .compactPill)

        return Label(state.displayTitle, systemImage: state.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.13), in: Capsule())
    }
}
