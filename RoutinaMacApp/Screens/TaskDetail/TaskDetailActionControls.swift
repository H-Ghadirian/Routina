import SwiftUI
import ComposableArchitecture

struct TaskDetailSelectedCalendarDayActions: View {
    let occurrence: TaskDetailOccurrencePresentation
    let onMarkMissed: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Selected occurrence")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            if occurrence.canMarkMissed {
                Button(action: onMarkMissed) {
                    Label("Missed", systemImage: "xmark")
                        .frame(minHeight: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            if occurrence.canCancel {
                Button(action: onCancel) {
                    Label("Canceled", systemImage: "slash.circle")
                        .frame(minHeight: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
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

struct TaskDetailPressureSegmentedPicker: View {
    let store: StoreOf<TaskDetailFeature>
    let isExpanded: Bool
    let onExpansionToggle: () -> Void
    let onSelection: (RoutineTaskPressure) -> Void

    var body: some View {
        TaskDetailExpandableSegmentedPicker(
            title: "PRESSURE",
            accessibilityLabel: "Pressure",
            options: RoutineTaskPressure.allCases,
            selection: store.task.pressure,
            optionTitle: { $0.title },
            tint: { TaskDetailValuePresentation.pressureTint(for: $0, style: .segmentedControl) },
            selectedForeground: { TaskDetailValuePresentation.pressureSelectedForeground(for: $0) },
            isExpanded: isExpanded,
            onExpansionToggle: onExpansionToggle,
            onSelection: onSelection
        )
    }
}

struct TaskDetailThinkingNeededSegmentedPicker: View {
    let store: StoreOf<TaskDetailFeature>
    let isExpanded: Bool
    let onExpansionToggle: () -> Void
    let onSelection: (RoutineTaskThinkingNeeded) -> Void

    var body: some View {
        TaskDetailExpandableSegmentedPicker(
            title: "THINKING NEEDED",
            accessibilityLabel: "Thinking needed",
            options: RoutineTaskThinkingNeeded.allCases,
            selection: store.task.thinkingNeeded,
            optionTitle: { $0.title },
            tint: { $0 == .none ? Color.secondary : Color.indigo },
            selectedForeground: { _ in Color.white },
            isExpanded: isExpanded,
            onExpansionToggle: onExpansionToggle,
            onSelection: onSelection
        )
    }
}

struct TaskDetailImportanceSegmentedPicker: View {
    let store: StoreOf<TaskDetailFeature>
    let isExpanded: Bool
    let onExpansionToggle: () -> Void
    let onSelection: (RoutineTaskImportance) -> Void

    var body: some View {
        TaskDetailExpandableSegmentedPicker(
            title: "IMPORTANCE",
            accessibilityLabel: "Importance",
            options: RoutineTaskImportance.allCases,
            selection: store.task.importance,
            optionTitle: { $0.title },
            tint: { TaskDetailValuePresentation.importanceTint(for: $0) },
            selectedForeground: { TaskDetailValuePresentation.importanceSelectedForeground(for: $0) },
            isExpanded: isExpanded,
            onExpansionToggle: onExpansionToggle,
            onSelection: onSelection
        )
    }
}

struct TaskDetailUrgencySegmentedPicker: View {
    let store: StoreOf<TaskDetailFeature>
    let isExpanded: Bool
    let onExpansionToggle: () -> Void
    let onSelection: (RoutineTaskUrgency) -> Void

    var body: some View {
        TaskDetailExpandableSegmentedPicker(
            title: "URGENCY",
            accessibilityLabel: "Urgency",
            options: RoutineTaskUrgency.allCases,
            selection: store.task.urgency,
            optionTitle: { $0.title },
            tint: { TaskDetailValuePresentation.urgencyTint(for: $0) },
            selectedForeground: { TaskDetailValuePresentation.urgencySelectedForeground(for: $0) },
            isExpanded: isExpanded,
            onExpansionToggle: onExpansionToggle,
            onSelection: onSelection
        )
    }
}

struct TaskDetailTaskLadderValuesControlsGrid: View {
    let store: StoreOf<TaskDetailFeature>
    @State private var expandedValue: TaskDetailExpandedTaskLadderValue?
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                priorityControls
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 12) {
                priorityControls
            }
        }
        .onChange(of: store.task.id) { _, _ in
            expandedValue = nil
        }
    }

    @ViewBuilder
    private var priorityControls: some View {
        TaskDetailImportanceSegmentedPicker(
            store: store,
            isExpanded: expandedValue == .importance,
            onExpansionToggle: { toggle(.importance) },
            onSelection: { option in
                store.send(.importanceChanged(option))
                collapseExpandedValue()
            }
        )

        TaskDetailUrgencySegmentedPicker(
            store: store,
            isExpanded: expandedValue == .urgency,
            onExpansionToggle: { toggle(.urgency) },
            onSelection: { option in
                store.send(.urgencyChanged(option))
                collapseExpandedValue()
            }
        )

        TaskDetailPressureSegmentedPicker(
            store: store,
            isExpanded: expandedValue == .pressure,
            onExpansionToggle: { toggle(.pressure) },
            onSelection: { option in
                store.send(.pressureChanged(option))
                collapseExpandedValue()
            }
        )

        TaskDetailThinkingNeededSegmentedPicker(
            store: store,
            isExpanded: expandedValue == .thinkingNeeded,
            onExpansionToggle: { toggle(.thinkingNeeded) },
            onSelection: { option in
                store.send(.thinkingNeededChanged(option))
                collapseExpandedValue()
            }
        )
    }

    private func toggle(_ value: TaskDetailExpandedTaskLadderValue) {
        animateExpansion {
            expandedValue = expandedValue == value ? nil : value
        }
    }

    private func collapseExpandedValue() {
        animateExpansion {
            expandedValue = nil
        }
    }

    private func animateExpansion(_ changes: () -> Void) {
        if accessibilityReduceMotion {
            changes()
        } else {
            withAnimation(.easeInOut(duration: 0.18), changes)
        }
    }
}

private enum TaskDetailExpandedTaskLadderValue: Hashable {
    case importance
    case urgency
    case pressure
    case thinkingNeeded
}

private struct TaskDetailExpandableSegmentedPicker<Option: Hashable>: View {
    let title: String
    let accessibilityLabel: String
    let options: [Option]
    let selection: Option
    let optionTitle: (Option) -> String
    let tint: (Option) -> Color
    let selectedForeground: (Option) -> Color
    let isExpanded: Bool
    let onExpansionToggle: () -> Void
    let onSelection: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .leading) {
                if isExpanded {
                    TaskDetailColoredSegmentedControl(
                        accessibilityLabel: accessibilityLabel,
                        options: options,
                        selection: selection,
                        title: optionTitle,
                        tint: tint,
                        selectedForeground: selectedForeground,
                        action: onSelection
                    )
                    .transition(.taskDetailHorizontalReveal)
                } else {
                    Button(action: onExpansionToggle) {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(tint(selection))
                                .frame(width: 7, height: 7)

                            Text(optionTitle(selection))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Image(systemName: "chevron.forward")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 11)
                        .frame(minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(tint(selection).opacity(0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(tint(selection).opacity(0.34), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(accessibilityLabel): \(optionTitle(selection))")
                    .accessibilityHint("Show all options")
                    .transition(.taskDetailHorizontalReveal)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct TaskDetailHorizontalRevealModifier: ViewModifier {
    let horizontalScale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: horizontalScale, y: 1, anchor: .leading)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var taskDetailHorizontalReveal: AnyTransition {
        .modifier(
            active: TaskDetailHorizontalRevealModifier(horizontalScale: 0.72, opacity: 0),
            identity: TaskDetailHorizontalRevealModifier(horizontalScale: 1, opacity: 1)
        )
    }
}

struct TaskDetailTodoStateSegmentedPicker: View {
    let store: StoreOf<TaskDetailFeature>
    let timingSummary: TodoStateTimingSummary?
    let showPersianDates: Bool
    @State private var isExpanded = false

    var body: some View {
        let currentState = store.effectiveTodoState ?? .ready

        VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 8) {
                    stateHeaderLabel(for: currentState)

                    Spacer(minLength: 8)

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
                    options: store.selectableTodoStates,
                    selection: currentState,
                    title: { $0.displayTitle },
                    tint: { TaskDetailValuePresentation.todoStateTint(for: $0, style: .segmentedControl) },
                    selectedForeground: { TaskDetailValuePresentation.todoStateSelectedForeground(for: $0) },
                    action: { newState in
                        if newState == .done && store.hasActiveRelationshipBlocker {
                            store.send(.setBlockedStateConfirmation(true))
                        } else {
                            store.send(.todoStateChanged(newState))
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.vertical, isExpanded ? 10 : 6)
        .frame(maxWidth: .infinity, minHeight: isExpanded ? 54 : nil, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(TaskDetailValuePresentation.todoStateTint(for: currentState, style: .segmentedControl).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(TaskDetailValuePresentation.todoStateTint(for: currentState, style: .segmentedControl).opacity(0.24), lineWidth: 1)
        )
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
    }

    private func stateHeaderLabel(for state: TodoState) -> some View {
        let tint = TaskDetailValuePresentation.todoStateTint(for: state, style: .compactPill)
        let detailText = stateTimingDetailText(for: state)

        return HStack(spacing: 7) {
            Text(state.displayTitle)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.14), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )

            if let detailText {
                Text(detailText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private func stateTimingDetailText(for state: TodoState) -> String? {
        if state == .blocked, store.hasActiveRelationshipBlocker {
            return "by linked task"
        }

        guard let timingSummary else {
            return nil
        }

        if timingSummary.currentState == state,
           let elapsedDays = timingSummary.currentStateElapsedDays,
           let startedAt = timingSummary.currentStateStartedAt {
            return "for \(durationText(elapsedDays)) since \(dateText(startedAt))"
        }

        if state == .done,
           let completedLeadDays = timingSummary.completedLeadDays {
            return "after \(durationText(completedLeadDays)) since \(dateText(timingSummary.createdAt))"
        }

        return "since \(dateText(timingSummary.createdAt))"
    }

    private func durationText(_ days: Int) -> String {
        let clampedDays = max(days, 0)
        return clampedDays == 1 ? "1 day" : "\(clampedDays) days"
    }

    private func dateText(_ date: Date) -> String {
        PersianDateDisplay.appendingSupplementaryDate(
            to: date.formatted(date: .abbreviated, time: .omitted),
            for: date,
            enabled: showPersianDates
        )
    }
}
