import ComposableArchitecture
import SwiftUI

struct TaskDetailTaskLadderValuesControls: View {
    let store: StoreOf<TaskDetailFeature>

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isReadOnly: Bool {
        store.task.temporalWeightRule != nil
    }

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
        TaskDetailImportancePickerPill(store: store, isReadOnly: isReadOnly)
        TaskDetailUrgencyPickerPill(store: store, isReadOnly: isReadOnly)
        TaskDetailPressurePickerPill(store: store, isReadOnly: isReadOnly)
        TaskDetailThinkingNeededPickerPill(store: store, isReadOnly: isReadOnly)
    }
}

struct TaskDetailPressurePickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    let isReadOnly: Bool
    @State private var isPresented = false

    @ViewBuilder
    var body: some View {
        let pressure = store.task.pressure

        if isReadOnly {
            Label("After done pressure: \(pressure.title)", systemImage: TaskDetailValuePresentation.pressureSystemImage(for: pressure))
                .taskDetailTaskLadderValuePillStyle(
                    tint: TaskDetailValuePresentation.pressureTint(for: pressure, style: .compactPill)
                )
                .accessibilityLabel("After done pressure")
                .accessibilityValue(pressure.title)
        } else {
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
}

struct TaskDetailImportancePickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    let isReadOnly: Bool
    @State private var isPresented = false

    @ViewBuilder
    var body: some View {
        let importance = store.task.importance
        let tint = TaskDetailValuePresentation.importanceTint(for: importance)

        if isReadOnly {
            Label("After done importance: \(importance.title)", systemImage: "arrow.up.circle.fill")
                .taskDetailTaskLadderValuePillStyle(tint: tint)
                .accessibilityLabel("After done importance")
                .accessibilityValue(importance.title)
        } else {
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
}

struct TaskDetailUrgencyPickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    let isReadOnly: Bool
    @State private var isPresented = false

    @ViewBuilder
    var body: some View {
        let urgency = store.task.urgency
        let tint = TaskDetailValuePresentation.urgencyTint(for: urgency)

        if isReadOnly {
            Label("After done urgency: \(urgency.title)", systemImage: "clock.fill")
                .taskDetailTaskLadderValuePillStyle(tint: tint)
                .accessibilityLabel("After done urgency")
                .accessibilityValue(urgency.title)
        } else {
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
}

struct TaskDetailThinkingNeededPickerPill: View {
    let store: StoreOf<TaskDetailFeature>
    let isReadOnly: Bool
    @State private var isPresented = false

    @ViewBuilder
    var body: some View {
        let level = store.task.thinkingNeeded

        if isReadOnly {
            Label("Thinking: \(level.title)", systemImage: "lightbulb.fill")
                .taskDetailTaskLadderValuePillStyle(tint: .indigo)
                .accessibilityLabel("Thinking needed")
                .accessibilityValue(level.title)
        } else {
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

struct TaskDetailTodoStatePickerPill: View {
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
