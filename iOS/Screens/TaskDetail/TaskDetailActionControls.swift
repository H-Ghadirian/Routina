import SwiftUI
import ComposableArchitecture

struct TaskDetailTodoPrimaryActionSection: View {
    let store: StoreOf<TaskDetailFeature>
    let showsTodoStateControl: Bool
    let showsThinkingNeededControl: Bool
    let stateTimingSummary: TodoStateTimingSummary?
    let showPersianDates: Bool
    @State private var isStateTimingExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if shouldShowStatusControls {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        if showsTodoStateControl {
                            todoStateControl
                        }
                        if showsThinkingNeededControl {
                            TaskDetailThinkingNeededPickerPill(store: store)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        if showsTodoStateControl {
                            todoStateControl
                        }
                        if showsThinkingNeededControl {
                            TaskDetailThinkingNeededPickerPill(store: store)
                        }
                    }
                }
            }

            if showsTodoStateControl, let stateTimingSummary, isStateTimingExpanded {
                TodoStateTimingInlineView(
                    summary: stateTimingSummary,
                    showPersianDates: showPersianDates
                )
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
        .onChange(of: store.task.id) { _, _ in
            isStateTimingExpanded = false
        }
        .onChange(of: store.task.todoStateRawValue) { _, _ in
            isStateTimingExpanded = false
        }
    }

    private var shouldShowStatusControls: Bool {
        showsTodoStateControl || showsThinkingNeededControl
    }

    @ViewBuilder
    private var todoStateControl: some View {
        if showsTodoStateControl {
            HStack(spacing: 6) {
                TaskDetailTodoStatePickerPill(store: store)

                if stateTimingSummary != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isStateTimingExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isStateTimingExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isStateTimingExpanded ? "Collapse state details" : "Expand state details")
                }
            }
        }
    }
}

struct TaskDetailRoutinePrimaryActionSection: View {
    let store: StoreOf<TaskDetailFeature>
    let pauseArchivePresentation: RoutinePauseArchivePresentation
    let showsThinkingNeededControl: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsThinkingNeededControl {
                TaskDetailThinkingNeededPickerPill(store: store)
            }
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

    @ViewBuilder
    private var secondaryActionControls: some View {
        if showsPauseResumeControl {
            routineActionsMenu
        }
    }

    private var showsPauseResumeControl: Bool {
        !store.task.isOneOffTask
            || (!store.task.isCompletedOneOff && !store.task.isCanceledOneOff)
    }

    private var pauseResumeSystemImage: String {
        if store.task.isOneOffTask {
            return store.task.isArchived() ? "arrow.uturn.backward.circle" : "archivebox"
        }
        return store.task.isArchived() ? "play.circle" : "pause.circle"
    }

    private var routineActionsMenu: some View {
        Menu {
            Button {
                store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
            } label: {
                Label(
                    pauseArchivePresentation.actionTitle,
                    systemImage: pauseResumeSystemImage
                )
            }

            if pauseArchivePresentation.secondaryActionTitle != nil {
                Button {
                    store.send(.notTodayTapped)
                } label: {
                    Label("Not today — hide until tomorrow", systemImage: "moon.zzz.fill")
                }
            }
        } label: {
            Label("More routine actions", systemImage: "ellipsis.circle")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
        .routinaPlatformSecondaryActionControlSize()
        .accessibilityHint("Pause, resume, or hide this routine until tomorrow")
    }

    @ViewBuilder
    private var explanatoryMessages: some View {
        if store.isStepRoutineOffToday {
            Text("Step-based routines can only be progressed for today.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if store.isChecklistCompletionFromStoredItems && !store.canUndoSelectedDate && !store.isSelectedDateAssumedDone {
            Text("Complete checklist items below to finish this routine.")
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
                title: TaskDetailIOSCompletionPresentation.title(for: store.state),
                systemImage: TaskDetailIOSCompletionPresentation.systemImage(for: store.state)
            )
            .routinaPlatformPrimaryActionLabelLayout()
        }
        .buttonStyle(.borderedProminent)
        .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: useLargePrimaryControl)
        .routinaPlatformPrimaryActionButtonLayout()
        .disabled(store.isCompletionButtonDisabled)
    }
}

enum TaskDetailIOSCompletionPresentation {
    static func title(for state: TaskDetailFeature.State) -> String {
        guard isCadenceFreeRoutineCompletedToday(state) else {
            return state.completionButtonTitle
        }
        return "Log another completion"
    }

    static func systemImage(for state: TaskDetailFeature.State) -> String? {
        guard isCadenceFreeRoutineCompletedToday(state) else {
            return state.completionButtonSystemImage
        }
        return "plus.circle.fill"
    }

    private static func isCadenceFreeRoutineCompletedToday(
        _ state: TaskDetailFeature.State
    ) -> Bool {
        !state.task.isOneOffTask
            && !state.task.usesEffectiveRoutineCadence
            && !state.isChecklistDrivenFromStoredItems
            && state.isSelectedDateTerminal
            && Calendar.current.isDateInToday(state.resolvedSelectedDate)
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

struct TaskDetailThinkingNeededPickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    @State private var isPresented = false

    var body: some View {
        let level = store.task.thinkingNeeded

        Button {
            isPresented = true
        } label: {
            Label("Thinking: \(level.title)", systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.indigo)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.indigo.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Set Thinking Needed", isPresented: $isPresented) {
            ForEach(RoutineTaskThinkingNeeded.allCases, id: \.self) { option in
                if option != level {
                    Button(option.title) {
                        store.send(.thinkingNeededChanged(option))
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current: \(level.title)")
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
