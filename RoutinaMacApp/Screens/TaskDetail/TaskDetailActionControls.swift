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
                .fill(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .segmentedControl).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(TaskDetailPriorityPresentation.todoStateTint(for: currentState, style: .segmentedControl).opacity(0.24), lineWidth: 1)
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
        let tint = TaskDetailPriorityPresentation.todoStateTint(for: state, style: .compactPill)
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
        guard let timingSummary else {
            return nil
        }

        if timingSummary.currentState != nil,
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
