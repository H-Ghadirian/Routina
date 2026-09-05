import SwiftUI

private enum TaskLadderGroupEditorCopy {
    // swift-format-ignore: LineLength
    static let inheritanceExplanation: LocalizedStringResource =
        "Inherit uses the highest value set on the group's actionable tasks. If none has a value, the group appears under No value."
}

private enum TaskLadderGroupMetricSelection<Value: Hashable>: Hashable {
    case inherit
    case noValue
    case value(Value)
}

struct TaskLadderGroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingGroup: TaskLadderGroup?
    let onSave: (TaskLadderGroup) -> Void
    let onDelete: ((UUID) -> Void)?

    @State private var group: TaskLadderGroup
    @State private var confirmsDeletion = false

    init(
        group: TaskLadderGroup?,
        onSave: @escaping (TaskLadderGroup) -> Void,
        onDelete: ((UUID) -> Void)? = nil
    ) {
        existingGroup = group
        self.onSave = onSave
        self.onDelete = onDelete
        _group = State(initialValue: group ?? TaskLadderGroup(name: ""))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existingGroup == nil ? "New Task Ladder Group" : "Edit Task Ladder Group")
                .font(.title2.weight(.semibold))

            Form {
                TextField("Name", text: $group.name)
                TextField("Emoji", text: $group.emoji)
                    .frame(maxWidth: 120)

                Section("Task Ladder values") {
                    metricPicker(
                        "Pressure",
                        selection: Binding(
                            get: {
                                metricSelection(
                                    for: .pressure,
                                    value: group.pressure
                                )
                            },
                            set: { selection in
                                apply(selection, for: .pressure) { group.pressure = $0 }
                            }
                        ),
                        values: RoutineTaskPressure.allCases.filter { $0 != .none },
                        titleForValue: { $0.title }
                    )
                    metricPicker(
                        "Urgency",
                        selection: Binding(
                            get: {
                                metricSelection(
                                    for: .urgency,
                                    value: group.urgency
                                )
                            },
                            set: { selection in
                                apply(selection, for: .urgency) { group.urgency = $0 }
                            }
                        ),
                        values: RoutineTaskUrgency.allCases,
                        titleForValue: { $0.title }
                    )
                    metricPicker(
                        "Importance",
                        selection: Binding(
                            get: {
                                metricSelection(
                                    for: .importance,
                                    value: group.importance
                                )
                            },
                            set: { selection in
                                apply(selection, for: .importance) { group.importance = $0 }
                            }
                        ),
                        values: RoutineTaskImportance.allCases,
                        titleForValue: { $0.title }
                    )
                    metricPicker(
                        "Thinking needed",
                        selection: Binding(
                            get: {
                                metricSelection(
                                    for: .thinkingNeeded,
                                    value: group.thinkingNeeded
                                )
                            },
                            set: { selection in
                                apply(selection, for: .thinkingNeeded) { group.thinkingNeeded = $0 }
                            }
                        ),
                        values: RoutineTaskThinkingNeeded.allCases.filter { $0 != .none },
                        titleForValue: { $0.title }
                    )

                    Text(TaskLadderGroupEditorCopy.inheritanceExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                if existingGroup != nil, onDelete != nil {
                    Button("Delete Group", role: .destructive) {
                        confirmsDeletion = true
                    }
                }

                Spacer()

                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(group)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480, height: 510)
        .confirmationDialog(
            "Delete \(group.displayName)?",
            isPresented: $confirmsDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Group", role: .destructive) {
                onDelete?(group.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its tasks will return to the general Task Ladder. No tasks or history will be deleted.")
        }
    }

    private func metricPicker<Value: Hashable>(
        _ title: String,
        selection: Binding<TaskLadderGroupMetricSelection<Value>>,
        values: [Value],
        titleForValue: @escaping (Value) -> String
    ) -> some View {
        Picker(title, selection: selection) {
            Text("Inherit (highest task value)")
                .tag(TaskLadderGroupMetricSelection<Value>.inherit)
            Text("No value")
                .tag(TaskLadderGroupMetricSelection<Value>.noValue)
            ForEach(values, id: \.self) { value in
                Text(titleForValue(value))
                    .tag(TaskLadderGroupMetricSelection<Value>.value(value))
            }
        }
    }

    private func metricSelection<Value: Hashable>(
        for metric: TaskRankingMetric,
        value: Value?
    ) -> TaskLadderGroupMetricSelection<Value> {
        if group.inheritsValue(for: metric) {
            return .inherit
        }
        return value.map(TaskLadderGroupMetricSelection.value) ?? .noValue
    }

    private func apply<Value: Hashable>(
        _ selection: TaskLadderGroupMetricSelection<Value>,
        for metric: TaskRankingMetric,
        setValue: (Value?) -> Void
    ) {
        switch selection {
        case .inherit:
            group.setInheritsValue(true, for: metric)
        case .noValue:
            group.setInheritsValue(false, for: metric)
            setValue(nil)
        case let .value(value):
            group.setInheritsValue(false, for: metric)
            setValue(value)
        }
    }
}
