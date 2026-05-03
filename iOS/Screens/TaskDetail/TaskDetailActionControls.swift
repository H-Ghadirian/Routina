import SwiftUI
import ComposableArchitecture

struct TaskDetailTodoPrimaryActionSection: View {
    let store: StoreOf<TaskDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        TaskDetailTodoStatePickerPill(store: store)
                        TaskDetailPressurePickerPill(store: store)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        TaskDetailTodoStatePickerPill(store: store)
                        TaskDetailPressurePickerPill(store: store)
                    }
                }
            } else {
                TaskDetailPressurePickerPill(store: store)
            }

            TaskDetailPrimaryActionButton(store: store)
            TaskDetailCancelTodoButton(store: store)

            if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff && !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .detailCardStyle()
    }
}

struct TaskDetailRoutinePrimaryActionSection: View {
    let store: StoreOf<TaskDetailFeature>
    let pauseArchivePresentation: RoutinePauseArchivePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TaskDetailPressurePickerPill(store: store)
            TaskDetailPrimaryActionButton(store: store)

            if store.shouldShowBulkConfirmAssumedDays {
                Button(store.bulkConfirmAssumedDaysTitle) {
                    store.send(.confirmAssumedPastDays)
                }
                .buttonStyle(.bordered)
                .tint(.mint)
                .routinaPlatformSecondaryActionControlSize()
                .frame(maxWidth: .infinity)
            }

            secondaryActionControls
            explanatoryMessages
        }
        .padding(16)
        .detailCardStyle()
    }

    private var secondaryActionControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                pauseResumeButton
                notTodayButton
                startOngoingButton
            }

            VStack(alignment: .leading, spacing: 10) {
                pauseResumeButton
                notTodayButton
                startOngoingButton
            }
        }
    }

    private var pauseResumeButton: some View {
        Button {
            store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
        } label: {
            Label(
                pauseArchivePresentation.actionTitle,
                systemImage: store.task.isArchived() ? "play.circle" : "pause.circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(store.task.isArchived() ? .teal : .orange)
        .routinaPlatformSecondaryActionControlSize()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var notTodayButton: some View {
        if let secondaryActionTitle = pauseArchivePresentation.secondaryActionTitle {
            Button {
                store.send(.notTodayTapped)
            } label: {
                Label(secondaryActionTitle, systemImage: "moon.zzz.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
            .routinaPlatformSecondaryActionControlSize()
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var startOngoingButton: some View {
        if store.task.isSoftIntervalRoutine && !store.task.isOngoing && !store.task.isArchived() {
            Button {
                store.send(.startOngoingTapped)
            } label: {
                Label("Start ongoing", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.teal)
            .routinaPlatformSecondaryActionControlSize()
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var explanatoryMessages: some View {
        if store.isStepRoutineOffToday {
            Text("Step-based routines can only be progressed for today.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if store.task.isChecklistCompletionRoutine && !store.canUndoSelectedDate {
            Text("Complete checklist items below to finish this routine.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let pauseDescription = pauseArchivePresentation.description {
            Text(pauseDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if let secondaryActionDescription = pauseArchivePresentation.secondaryActionDescription {
            Text(secondaryActionDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if !store.blockingRelationships.isEmpty {
            Text(store.blockerSummaryText)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

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

struct TaskDetailPressurePickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    @State private var isPresented = false

    var body: some View {
        let pressure = store.task.pressure

        Button {
            isPresented = true
        } label: {
            Label("Pressure: \(pressure.title)", systemImage: TaskDetailPriorityPresentation.pressureSystemImage(for: pressure))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaskDetailPriorityPresentation.pressureTint(for: pressure, style: .compactPill))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TaskDetailPriorityPresentation.pressureTint(for: pressure, style: .compactPill).opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Set Pressure", isPresented: $isPresented) {
            ForEach(RoutineTaskPressure.allCases, id: \.self) { option in
                if option != pressure {
                    Button(option.title) {
                        store.send(.pressureChanged(option))
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current: \(pressure.title)")
        }
    }
}

private struct TaskDetailTodoStatePickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    @State private var isPresented = false

    var body: some View {
        let currentState = store.task.todoState ?? .ready

        Button {
            isPresented = true
        } label: {
            Label(currentState.displayTitle, systemImage: currentState.systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .compactPill))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .compactPill).opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Set State", isPresented: $isPresented) {
            ForEach(TodoState.allCases, id: \.self) { state in
                if state != currentState {
                    Button(state.displayTitle) {
                        if state == .done && store.hasActiveRelationshipBlocker {
                            store.send(.setBlockedStateConfirmation(true))
                        } else {
                            store.send(.todoStateChanged(state))
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current: \(currentState.displayTitle)")
        }
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

private struct TaskDetailCancelTodoButton: View {
    let store: StoreOf<TaskDetailFeature>

    var body: some View {
        if store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
            Button {
                store.send(.cancelTodo)
            } label: {
                Label(store.cancelTodoButtonTitle, systemImage: "xmark.circle")
                    .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: true)
            .routinaPlatformPrimaryActionButtonLayout()
            .disabled(store.isCancelTodoButtonDisabled)
        }
    }
}
