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
        .sheet(isPresented: $isPauseUntilPresented) {
            TaskDetailPauseUntilSheet(
                actionTitle: pauseUntilActionTitle
            ) { pauseUntil in
                store.send(.pauseUntilTapped(pauseUntil))
            }
        }
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
        .accessibilityHint("Pause, resume, choose a pause end time, or hide this routine until tomorrow")
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

struct TaskDetailPriorityContextControls: View {
    let store: StoreOf<TaskDetailFeature>
    let showsImportance: Bool
    let showsUrgency: Bool
    let showsPressure: Bool
    let showsThinkingNeeded: Bool

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
        if showsImportance {
            TaskDetailImportancePickerPill(store: store)
        }
        if showsUrgency {
            TaskDetailUrgencyPickerPill(store: store)
        }
        if showsPressure {
            TaskDetailPressurePickerPill(store: store)
        }
        if showsThinkingNeeded {
            TaskDetailThinkingNeededPickerPill(store: store)
        }
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
                .taskDetailPriorityPillStyle(
                    tint: TaskDetailPriorityPresentation.pressureTint(for: pressure, style: .compactPill)
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
        let tint = TaskDetailPriorityPresentation.importanceTint(for: importance)

        Button {
            isPresented = true
        } label: {
            Label("Importance: \(importance.title)", systemImage: "arrow.up.circle.fill")
                .taskDetailPriorityPillStyle(tint: tint)
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
        let tint = TaskDetailPriorityPresentation.urgencyTint(for: urgency)

        Button {
            isPresented = true
        } label: {
            Label("Urgency: \(urgency.title)", systemImage: "clock.fill")
                .taskDetailPriorityPillStyle(tint: tint)
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
                .taskDetailPriorityPillStyle(tint: .indigo)
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

private struct TaskDetailPriorityPillStyle: ViewModifier {
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
    func taskDetailPriorityPillStyle(tint: Color) -> some View {
        modifier(TaskDetailPriorityPillStyle(tint: tint))
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
                .foregroundStyle(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .compactPill))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .compactPill).opacity(0.12), in: Capsule())
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
