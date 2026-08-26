import SwiftUI

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

                    Text("Inherit uses the highest value set on the group's actionable tasks. If none has a value, the group appears under No value.")
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

    fileprivate static func completionBehavior(
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

struct TaskLadderRepeatingTaskGroupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let tasks: [RoutineTask]
    let organization: TaskLadderOrganization
    let eligibleTaskIDs: Set<UUID>
    let onSave: (UUID, UUID, TaskLadderCompletionBehavior) -> Void

    @State private var selectedParentTaskID: UUID?
    @State private var selectedChildTaskID: UUID?
    @State private var completionBehavior = TaskLadderCompletionBehavior.none
    @State private var searchText = ""

    init(
        tasks: [RoutineTask],
        organization: TaskLadderOrganization,
        eligibleTaskIDs: Set<UUID>,
        initialParentTaskID: UUID? = nil,
        onSave: @escaping (UUID, UUID, TaskLadderCompletionBehavior) -> Void
    ) {
        self.tasks = tasks
        self.organization = organization
        self.eligibleTaskIDs = eligibleTaskIDs
        self.onSave = onSave
        _selectedParentTaskID = State(initialValue: initialParentTaskID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Use a Repeating Task as a Group")
                .font(.title2.weight(.semibold))

            Text("The repeating task keeps its schedule, completion action, and history. Choose a task to compare inside it, then decide separately whether that task can complete the repeating task.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if repeatingTasks.isEmpty {
                ContentUnavailableView(
                    "No repeating tasks",
                    systemImage: "repeat",
                    description: Text("Create a repeating task before using one as a Task Ladder group.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    Picker("Repeating task", selection: $selectedParentTaskID) {
                        Text("Choose a repeating task")
                            .tag(nil as UUID?)
                        ForEach(repeatingTasks) { task in
                            Text("\(task.emoji ?? "✨") \(task.name ?? "Untitled task")")
                                .tag(task.id as UUID?)
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(height: 86)

                TextField("Search tasks to add", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(selectedParentTask == nil)

                if let parentTask = selectedParentTask {
                    if filteredChildTasks.isEmpty {
                        ContentUnavailableView(
                            "No tasks to add",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("Every valid task is already inside \(parentTask.name ?? "this repeating task"), or no task matches the search.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(filteredChildTasks) { candidate in
                            childTaskRow(candidate, parentTask: parentTask)
                        }
                        .listStyle(.inset)
                    }
                } else {
                    ContentUnavailableView(
                        "Choose a repeating task",
                        systemImage: "repeat.circle",
                        description: Text("It will remain a real repeating task while also containing its own nested Task Ladder.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let parentTask = selectedParentTask,
                   let childTask = selectedChildTask {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("When \(childTask.name ?? "this task") is completed")
                            .font(.headline)
                        Picker("Completion behavior", selection: $completionBehavior) {
                            Text("Does not complete \(parentTask.name ?? "repeating task")")
                                .tag(TaskLadderCompletionBehavior.none)
                            Text("Can complete \(parentTask.name ?? "repeating task") — ask me")
                                .tag(TaskLadderCompletionBehavior.canComplete)
                            Text("Completes \(parentTask.name ?? "repeating task") automatically")
                                .tag(TaskLadderCompletionBehavior.completes)
                        }
                        .labelsHidden()
                        .pickerStyle(.radioGroup)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Task") {
                    guard let parentTaskID = selectedParentTaskID,
                          let childTaskID = selectedChildTaskID else { return }
                    onSave(childTaskID, parentTaskID, completionBehavior)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedParentTaskID == nil || selectedChildTaskID == nil)
            }
        }
        .padding(20)
        .frame(width: 620, height: 700)
        .onChange(of: selectedParentTaskID) { _, _ in
            selectedChildTaskID = nil
            completionBehavior = .none
            searchText = ""
        }
    }

    private var repeatingTasks: [RoutineTask] {
        tasks
            .filter { !$0.isOneOffTask && eligibleTaskIDs.contains($0.id) }
            .sorted(by: taskNameSort)
    }

    private var selectedParentTask: RoutineTask? {
        guard let selectedParentTaskID else { return nil }
        return repeatingTasks.first(where: { $0.id == selectedParentTaskID })
    }

    private var selectedChildTask: RoutineTask? {
        guard let selectedChildTaskID else { return nil }
        return tasks.first(where: { $0.id == selectedChildTaskID })
    }

    private var filteredChildTasks: [RoutineTask] {
        guard let parentTask = selectedParentTask else { return [] }
        let validTaskIDs = Set(tasks.map(\.id))
        let parentNodeID = TaskLadderNodeID.task(parentTask.id)
        return tasks
            .filter { candidate in
                candidate.id != parentTask.id
                    && eligibleTaskIDs.contains(candidate.id)
                    && organization.parent(of: candidate.id) != parentNodeID
                    && organization.validParents(
                        for: candidate.id,
                        validTaskIDs: validTaskIDs
                    ).contains(parentNodeID)
                    && matchesSearch(candidate.name ?? "")
            }
            .sorted(by: taskNameSort)
    }

    private func childTaskRow(
        _ candidate: RoutineTask,
        parentTask: RoutineTask
    ) -> some View {
        Button {
            selectedChildTaskID = candidate.id
            completionBehavior = TaskLadderPlacementEditorSheet.completionBehavior(
                for: candidate,
                parent: .task(parentTask.id),
                tasks: tasks
            )
        } label: {
            HStack(spacing: 10) {
                Text(candidate.emoji ?? "✨")
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.name ?? "Untitled task")
                    Text(childLocationDescription(for: candidate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedChildTaskID == candidate.id {
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

    private func childLocationDescription(for task: RoutineTask) -> String {
        guard let parent = organization.parent(of: task.id) else {
            return "Currently in the general Task Ladder"
        }
        switch parent {
        case let .group(groupID):
            let groupName = organization.group(id: groupID)?.displayName ?? "another group"
            return "Move from \(groupName)"
        case let .task(taskID):
            let taskName = tasks.first(where: { $0.id == taskID })?.name ?? "another task"
            return "Move from \(taskName)"
        }
    }

    private func matchesSearch(_ value: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || value.localizedCaseInsensitiveContains(query)
    }

    private func taskNameSort(_ lhs: RoutineTask, _ rhs: RoutineTask) -> Bool {
        (lhs.name ?? "").localizedCaseInsensitiveCompare(rhs.name ?? "") == .orderedAscending
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
                    Text(childCount == 1 ? "1 actionable task" : "\(childCount) actionable tasks")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Edit Group", action: onEdit)
            }

            Text("Tasks inside this group are completed independently.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
