import SwiftUI
import ComposableArchitecture

struct TaskDetailTodoPrimaryActionSection: View {
    let store: StoreOf<TaskDetailFeature>
    let showsTodoStateControl: Bool
    let stateTimingSummary: TodoStateTimingSummary?
    let showPersianDates: Bool
    @State private var isStateTimingExpanded = false

    var body: some View {
        Group {
            if hasSupportingContext {
                actionContent
                    .padding(16)
                    .detailCardStyle()
            } else {
                TaskDetailPrimaryActionButton(store: store)
            }
        }
        .onChange(of: store.task.id) { _, _ in
            isStateTimingExpanded = false
        }
        .onChange(of: store.task.todoStateRawValue) { _, _ in
            isStateTimingExpanded = false
        }
    }

    private var actionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTodoStateControl {
                todoStateControl
            }

            if showsTodoStateControl,
               !store.isTodoStateDerivedFromRelationshipBlocker,
               let stateTimingSummary,
               isStateTimingExpanded {
                TodoStateTimingInlineView(
                    summary: stateTimingSummary,
                    showPersianDates: showPersianDates
                )
            }

            TaskDetailPrimaryActionButton(store: store)

            if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff && !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hasSupportingContext: Bool {
        showsTodoStateControl
            || (!store.task.isCompletedOneOff
                && !store.task.isCanceledOneOff
                && !store.blockingRelationships.isEmpty)
    }

    @ViewBuilder
    private var todoStateControl: some View {
        if showsTodoStateControl {
            HStack(spacing: 6) {
                TaskDetailTodoStatePickerPill(store: store)

                if stateTimingSummary != nil,
                   !store.isTodoStateDerivedFromRelationshipBlocker {
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

    @State private var isPauseUntilPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsPauseResumeControl {
                routineLifecycleControl
            } else {
                TaskDetailPrimaryActionButton(store: store)
            }

            if store.shouldShowBulkConfirmAssumedDays {
                Button(store.bulkConfirmAssumedDaysTitle) {
                    store.send(.confirmAssumedPastDays)
                }
                .buttonStyle(.bordered)
                .tint(.mint)
                .routinaPlatformSecondaryActionControlSize()
                .frame(maxWidth: .infinity)
            }

            explanatoryMessages
        }
        .padding(16)
        .detailCardStyle()
        .sheet(isPresented: $isPauseUntilPresented) {
            TaskDetailPauseUntilSheet(
                actionTitle: pauseUntilActionTitle
            ) { pauseUntil in
                store.send(.pauseUntilTapped(pauseUntil))
            }
        }
    }

    private var routineLifecycleControl: some View {
        HStack(spacing: 0) {
            Button {
                store.send(store.completionButtonAction)
            } label: {
                TaskDetailCompletionButtonLabel(
                    title: TaskDetailIOSCompletionPresentation.title(for: store.state),
                    systemImage: TaskDetailIOSCompletionPresentation.systemImage(for: store.state)
                )
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(
                TaskDetailJoinedLifecyclePrimaryButtonStyle(
                    tint: TaskDetailPresentation.completionActionTint(
                        isOngoingMultiDayRoutine: store.task.isMultiDayRoutine && store.task.isOngoing,
                        canUndoSelectedDate: store.canUndoSelectedDate
                    )
                )
            )
            .disabled(store.isCompletionButtonDisabled)

            Rectangle()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 1)
                .padding(.vertical, 12)

            routineActionsMenu
        }
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
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
            if pauseArchivePresentation.secondaryActionTitle != nil {
                Button {
                    store.send(.notTodayTapped)
                } label: {
                    Label("Not today — hide until tomorrow", systemImage: "moon.zzz.fill")
                }

                Divider()
            }

            if store.task.isArchived() {
                Button {
                    store.send(.resumeTapped)
                } label: {
                    Label(
                        pauseArchivePresentation.actionTitle,
                        systemImage: pauseResumeSystemImage
                    )
                }
            } else {
                Button {
                    store.send(.pauseTapped)
                } label: {
                    Label(
                        pauseArchivePresentation.actionTitle,
                        systemImage: pauseResumeSystemImage
                    )
                }

                Button {
                    isPauseUntilPresented = true
                } label: {
                    Label(pauseUntilActionTitle, systemImage: "clock.arrow.circlepath")
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 54)
                .frame(minHeight: 50, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More routine actions")
        .accessibilityHint("Not today, pause, pause until, or resume this routine")
    }

    private var pauseUntilActionTitle: String {
        store.task.isOneOffTask ? "Archive Until…" : "Pause Until…"
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

private struct TaskDetailJoinedLifecyclePrimaryButtonStyle: ButtonStyle {
    let tint: Color

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.72))
            .background(
                tint.opacity(
                    isEnabled
                        ? (configuration.isPressed ? 0.78 : 1)
                        : 0.38
                )
            )
    }
}

struct TaskDetailAssumedDoneStatusPill: View {
    var body: some View {
        Label("Assumed done", systemImage: "checkmark.circle.dashed")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.mint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: .mint, tintOpacity: 0.12)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.mint.opacity(0.24), lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Assumed done")
            .accessibilityHint("This day is provisional until you confirm it")
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
        .tint(
            TaskDetailPresentation.completionActionTint(
                isOngoingMultiDayRoutine: store.task.isMultiDayRoutine && store.task.isOngoing,
                canUndoSelectedDate: store.canUndoSelectedDate
            )
        )
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

struct TaskDetailTaskLadderValuesControls: View {
    let store: StoreOf<TaskDetailFeature>

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                controls
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                controls
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        TaskDetailImportancePickerPill(store: store)
        TaskDetailUrgencyPickerPill(store: store)
        TaskDetailPressurePickerPill(store: store)
        TaskDetailThinkingNeededPickerPill(store: store)
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
            Label("Pressure: \(pressure.title)", systemImage: TaskDetailValuePresentation.pressureSystemImage(for: pressure))
                .taskDetailTaskLadderValuePillStyle(
                    tint: TaskDetailValuePresentation.pressureTint(for: pressure, style: .compactPill)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Pressure")
        .accessibilityValue(pressure.title)
        .accessibilityHint("Changes the task pressure")
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

struct TaskDetailImportancePickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    @State private var isPresented = false

    var body: some View {
        let importance = store.task.importance
        let tint = TaskDetailValuePresentation.importanceTint(for: importance)

        Button {
            isPresented = true
        } label: {
            Label("Importance: \(importance.title)", systemImage: "arrow.up.circle.fill")
                .taskDetailTaskLadderValuePillStyle(tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Importance")
        .accessibilityValue(importance.title)
        .accessibilityHint("Changes the task importance")
        .confirmationDialog("Set Importance", isPresented: $isPresented) {
            ForEach(RoutineTaskImportance.allCases, id: \.self) { option in
                if option != importance {
                    Button(option.title) {
                        store.send(.importanceChanged(option))
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current: \(importance.title)")
        }
    }
}

struct TaskDetailUrgencyPickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    @State private var isPresented = false

    var body: some View {
        let urgency = store.task.urgency
        let tint = TaskDetailValuePresentation.urgencyTint(for: urgency)

        Button {
            isPresented = true
        } label: {
            Label("Urgency: \(urgency.title)", systemImage: "clock.fill")
                .taskDetailTaskLadderValuePillStyle(tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Urgency")
        .accessibilityValue(urgency.title)
        .accessibilityHint("Changes the task urgency")
        .confirmationDialog("Set Urgency", isPresented: $isPresented) {
            ForEach(RoutineTaskUrgency.allCases, id: \.self) { option in
                if option != urgency {
                    Button(option.title) {
                        store.send(.urgencyChanged(option))
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Current: \(urgency.title)")
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
                .taskDetailTaskLadderValuePillStyle(tint: .indigo)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thinking needed")
        .accessibilityValue(level.title)
        .accessibilityHint("Changes how much thinking the task needs")
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

private struct TaskDetailTaskLadderValuePillStyle: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(tint.opacity(0.15), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.30), lineWidth: 1)
            }
            .contentShape(Capsule())
    }
}

private extension View {
    func taskDetailTaskLadderValuePillStyle(tint: Color) -> some View {
        modifier(TaskDetailTaskLadderValuePillStyle(tint: tint))
    }
}

private struct TaskDetailTodoStatePickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    @State private var isPresented = false

    var body: some View {
        let currentState = store.effectiveTodoState ?? .ready

        Button {
            isPresented = true
        } label: {
            Label(currentState.displayTitle, systemImage: currentState.systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaskDetailValuePresentation.todoStateTint(for: currentState, style: .compactPill))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TaskDetailValuePresentation.todoStateTint(for: currentState, style: .compactPill).opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Set State", isPresented: $isPresented) {
            ForEach(store.selectableTodoStates, id: \.self) { state in
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
