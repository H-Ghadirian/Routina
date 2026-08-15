import SwiftUI

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
                    optionalPicker(
                        "Pressure",
                        selection: Binding(
                            get: { group.pressure },
                            set: { group.pressure = $0 }
                        ),
                        values: RoutineTaskPressure.allCases.filter { $0 != .none },
                        titleForValue: { $0.title }
                    )
                    optionalPicker(
                        "Urgency",
                        selection: Binding(
                            get: { group.urgency },
                            set: { group.urgency = $0 }
                        ),
                        values: RoutineTaskUrgency.allCases,
                        titleForValue: { $0.title }
                    )
                    optionalPicker(
                        "Importance",
                        selection: Binding(
                            get: { group.importance },
                            set: { group.importance = $0 }
                        ),
                        values: RoutineTaskImportance.allCases,
                        titleForValue: { $0.title }
                    )
                    optionalPicker(
                        "Thinking needed",
                        selection: Binding(
                            get: { group.thinkingNeeded },
                            set: { group.thinkingNeeded = $0 }
                        ),
                        values: RoutineTaskThinkingNeeded.allCases.filter { $0 != .none },
                        titleForValue: { $0.title }
                    )
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

    private func optionalPicker<Value: Hashable>(
        _ title: String,
        selection: Binding<Value?>,
        values: [Value],
        titleForValue: @escaping (Value) -> String
    ) -> some View {
        Picker(title, selection: selection) {
            Text("No value").tag(Value?.none)
            ForEach(values, id: \.self) { value in
                Text(titleForValue(value)).tag(Optional(value))
            }
        }
    }
}

struct TaskLadderPlacementEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let task: RoutineTask
    let tasks: [RoutineTask]
    let organization: TaskLadderOrganization
    let onSave: (TaskLadderNodeID?, TaskLadderCompletionBehavior) -> Void

    @State private var selectedParent: TaskLadderNodeID?
    @State private var completionBehavior: TaskLadderCompletionBehavior
    @State private var searchText = ""

    init(
        task: RoutineTask,
        tasks: [RoutineTask],
        organization: TaskLadderOrganization,
        onSave: @escaping (TaskLadderNodeID?, TaskLadderCompletionBehavior) -> Void
    ) {
        self.task = task
        self.tasks = tasks
        self.organization = organization
        self.onSave = onSave
        let parent = organization.parent(of: task.id)
        _selectedParent = State(initialValue: parent)
        _completionBehavior = State(
            initialValue: Self.completionBehavior(
                for: task,
                parent: parent,
                tasks: tasks
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Place \(task.name ?? "Untitled task")")
                .font(.title2.weight(.semibold))

            TextField("Search groups and tasks", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List {
                placementRow(
                    title: "General Task Ladder",
                    subtitle: "Compare this task at the root",
                    emoji: "↔️",
                    parent: nil
                )

                if !filteredGroups.isEmpty {
                    Section("Groups") {
                        ForEach(filteredGroups) { group in
                            placementRow(
                                title: group.displayName,
                                subtitle: "Container only — no completion behavior",
                                emoji: group.displayEmoji,
                                parent: .group(group.id)
                            )
                        }
                    }
                }

                if !filteredTasks.isEmpty {
                    Section("Completable parents") {
                        ForEach(filteredTasks) { candidate in
                            placementRow(
                                title: candidate.name ?? "Untitled task",
                                subtitle: "Choose a separate completion behavior below",
                                emoji: candidate.emoji ?? "✨",
                                parent: .task(candidate.id)
                            )
                        }
                    }
                }
            }
            .listStyle(.inset)

            if case let .task(parentTaskID)? = selectedParent,
               let parentTask = tasks.first(where: { $0.id == parentTaskID }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When this task is completed")
                        .font(.headline)
                    Picker("Completion behavior", selection: $completionBehavior) {
                        Text("Does not complete \(parentTask.name ?? "parent")")
                            .tag(TaskLadderCompletionBehavior.none)
                        Text("Can complete \(parentTask.name ?? "parent") — ask me")
                            .tag(TaskLadderCompletionBehavior.canComplete)
                        Text("Completes \(parentTask.name ?? "parent") automatically")
                            .tag(TaskLadderCompletionBehavior.completes)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(selectedParent, completionBehavior)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560, height: 650)
        .onChange(of: selectedParent) { _, parent in
            completionBehavior = Self.completionBehavior(for: task, parent: parent, tasks: tasks)
        }
    }

    private var filteredGroups: [TaskLadderGroup] {
        organization.groups.filter { matchesSearch($0.displayName) }
    }

    private var filteredTasks: [RoutineTask] {
        let validTaskIDs = Set(tasks.map(\.id))
        let validParents = organization.validParents(for: task.id, validTaskIDs: validTaskIDs)
        return tasks
            .filter { validParents.contains(.task($0.id)) && matchesSearch($0.name ?? "") }
            .sorted {
                ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending
            }
    }

    private func matchesSearch(_ value: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || value.localizedCaseInsensitiveContains(query)
    }

    private func placementRow(
        title: String,
        subtitle: String,
        emoji: String,
        parent: TaskLadderNodeID?
    ) -> some View {
        Button {
            selectedParent = parent
        } label: {
            HStack(spacing: 10) {
                Text(emoji)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedParent == parent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static func completionBehavior(
        for task: RoutineTask,
        parent: TaskLadderNodeID?,
        tasks: [RoutineTask]
    ) -> TaskLadderCompletionBehavior {
        guard case let .task(parentTaskID)? = parent else { return .none }
        if let relationship = task.relationships.first(where: { $0.targetTaskID == parentTaskID }) {
            return TaskLadderCompletionBehavior(relationshipKind: relationship.kind)
        }
        if let parentTask = tasks.first(where: { $0.id == parentTaskID }),
           let inverse = parentTask.relationships.first(where: { $0.targetTaskID == task.id }) {
            return TaskLadderCompletionBehavior(relationshipKind: inverse.kind.inverse)
        }
        return .none
    }
}

struct TaskLadderGroupDetailView: View {
    let group: TaskLadderGroup
    let childCount: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(group.displayEmoji)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.displayName)
                        .font(.largeTitle.weight(.semibold))
                    Text("Task Ladder group · \(childCount) \(childCount == 1 ? "task" : "tasks")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Edit Group", action: onEdit)
            }

            Text("This is an organizational container. Completing a task inside it never completes the group.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
