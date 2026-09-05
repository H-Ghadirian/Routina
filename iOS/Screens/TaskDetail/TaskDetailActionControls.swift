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
                isStateTimingExpanded
            {
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
                    !store.isTodoStateDerivedFromRelationshipBlocker
                {
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
                TaskDetailIOSCompletionButtonLabel(state: store.state)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .contentShape(Rectangle())
            }
            .buttonStyle(
                TaskDetailJoinedPrimaryButtonStyle(
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
        .accessibilityLabel("More repeating-task actions")
        .accessibilityHint("Not today, pause, pause until, or resume this repeating task")
    }

    private var pauseUntilActionTitle: String {
        store.task.isOneOffTask ? "Archive Until…" : "Pause Until…"
    }

    @ViewBuilder
    private var explanatoryMessages: some View {
        if store.isStepRoutineOffToday {
            Text("Step-based repeating tasks can only be progressed for today.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }

        if store.isChecklistCompletionFromStoredItems && !store.canUndoSelectedDate && !store.isSelectedDateAssumedDone {
            Text("Complete checklist items below to finish this repeating task.")
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

private struct TaskDetailJoinedPrimaryButtonStyle: ButtonStyle {
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
    let phase: TaskDetailCompletionStatusPillPhase

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .contentTransition(.symbolEffect(.replace))

            Text(title)
                .contentTransition(.opacity)
        }
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
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18),
            value: phase
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var title: String {
        switch phase {
        case .assumed:
            String(localized: "Assumed done")
        case .confirmed:
            String(localized: "Confirmed")
        }
    }

    private var systemImage: String {
        switch phase {
        case .assumed:
            "checkmark.circle.dashed"
        case .confirmed:
            "checkmark.circle.fill"
        }
    }

    private var accessibilityLabel: String {
        switch phase {
        case .assumed:
            String(localized: "Assumed done")
        case .confirmed:
            String(localized: "Completion confirmed")
        }
    }

    private var accessibilityHint: String {
        switch phase {
        case .assumed:
            String(localized: "This day is provisional until you confirm it")
        case .confirmed:
            String(localized: "The completion was recorded and can be undone")
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
            TaskDetailIOSCompletionButtonLabel(state: store.state)
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
            if let systemImage = state.completionButtonSystemImage {
                return systemImage
            }
            return state.isCompletionButtonDisabled ? nil : "checkmark.circle.fill"
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

private struct TaskDetailIOSCompletionButtonLabel: View {
    let state: TaskDetailFeature.State

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var title: String {
        TaskDetailIOSCompletionPresentation.title(for: state)
    }

    private var systemImage: String? {
        TaskDetailIOSCompletionPresentation.systemImage(for: state)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .contentTransition(.symbolEffect(.replace))
            }

            Text(title)
                .contentTransition(.opacity)
        }
        .animation(
            accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18),
            value: title
        )
    }
}
