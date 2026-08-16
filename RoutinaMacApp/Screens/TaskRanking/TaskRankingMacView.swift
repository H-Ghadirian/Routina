import ComposableArchitecture
import SwiftUI

struct TaskRankingMacView: View {
    let store: StoreOf<TaskRankingFeature>
    @AppStorage(
        UserDefaultStringValueKey.appSettingMacTaskRankingReversedMetrics.rawValue,
        store: SharedDefaults.app
    ) private var reversedMetricsRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingFlagRules.rawValue,
        store: SharedDefaults.app
    ) private var flagRulesRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingMacTaskLadderOrganization.rawValue,
        store: SharedDefaults.app
    ) private var taskLadderOrganizationRawValue = ""
    @State private var collapsedSectionIDs = Set<String>()
    @State private var isGroupEditorPresented = false
    @State private var editingGroupID: UUID?
    @State private var placementTaskID: UUID?
    @State private var isRepeatingTaskGroupEditorPresented = false
    @State private var repeatingTaskGroupParentID: UUID?

    var body: some View {
        HSplitView {
            rankingList
                .frame(minWidth: 340, idealWidth: 440, maxWidth: 560)

            taskDetail
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.send(
                .reversedMetricsChanged(
                    TaskRankingDirectionStorage.decode(reversedMetricsRawValue)
                )
            )
            store.send(.onAppear)
        }
        .onDisappear { store.send(.onDisappear) }
        .onChange(of: store.reversedMetrics) { _, reversedMetrics in
            reversedMetricsRawValue = TaskRankingDirectionStorage.encode(reversedMetrics)
            AppSettingsPersistenceMirror.schedule()
        }
        .onChange(of: flagRulesRawValue) { _, _ in
            store.send(.flagRulesChanged)
        }
        .onChange(of: taskLadderOrganizationRawValue) { _, _ in
            store.send(.organizationChanged)
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.routineDataChanged)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Rank by", selection: Binding(
                    get: { store.metric },
                    set: { store.send(.metricChanged($0)) }
                )) {
                    ForEach(TaskRankingMetric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New Container Group…") {
                        editingGroupID = nil
                        isGroupEditorPresented = true
                    }

                    Button("Use Repeating Task as Group…") {
                        repeatingTaskGroupParentID = nil
                        isRepeatingTaskGroupEditorPresented = true
                    }
                    .disabled(!store.tasks.contains {
                        !$0.isOneOffTask
                            && store.presentation.eligibleTaskIDs.contains($0.id)
                    })
                } label: {
                    Label("Add Task Ladder Group", systemImage: "folder.badge.plus")
                        .frame(minWidth: 22, minHeight: 22)
                        .contentShape(Rectangle())
                }
                .help("Create a container group or use a repeating task as a group")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.directionToggled)
                } label: {
                    Label(store.metric.directionTitle(isReversed: store.isReversed), systemImage: "arrow.up.arrow.down")
                }
                .help("Reverse order: \(store.metric.directionTitle(isReversed: !store.isReversed))")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.refresh)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .help("Refresh task ranking")
                .disabled(store.isLoading)
            }
        }
        .alert(
            "Task Ranking",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            ),
            actions: {
                Button("OK", role: .cancel) { store.send(.errorDismissed) }
            },
            message: { Text(store.errorMessage ?? "") }
        )
        .sheet(isPresented: $isGroupEditorPresented) {
            TaskLadderGroupEditorSheet(
                group: editingGroupID.flatMap { store.organization.group(id: $0) },
                onSave: { store.send(.groupSaved($0)) },
                onDelete: { store.send(.groupDeleted($0)) }
            )
        }
        .sheet(isPresented: Binding(
            get: { placementTaskID != nil },
            set: { if !$0 { placementTaskID = nil } }
        )) {
            if let taskID = placementTaskID,
               let task = store.tasks.first(where: { $0.id == taskID }) {
                TaskLadderPlacementEditorSheet(
                    task: task,
                    tasks: store.tasks,
                    organization: store.organization,
                    onSave: { parent, behavior in
                        store.send(.taskPlacementSaved(taskID, parent, behavior))
                    }
                )
            }
        }
        .sheet(
            isPresented: $isRepeatingTaskGroupEditorPresented,
            onDismiss: { repeatingTaskGroupParentID = nil }
        ) {
            TaskLadderRepeatingTaskGroupEditorSheet(
                tasks: store.tasks,
                organization: store.organization,
                eligibleTaskIDs: store.presentation.eligibleTaskIDs,
                initialParentTaskID: repeatingTaskGroupParentID,
                onSave: { childTaskID, parentTaskID, behavior in
                    store.send(
                        .taskPlacementSaved(
                            childTaskID,
                            .task(parentTaskID),
                            behavior
                        )
                    )
                    store.send(.childLadderOpened(parentTaskID))
                }
            )
        }
    }

    private var rankingList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    if !store.scopePath.isEmpty {
                        Button {
                            store.send(.scopeBackTapped)
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Back to previous ladder")
                    }

                    Text(ladderTitle)
                        .font(.title2.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(taskCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(listSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if store.isLoading && store.presentation.isEmpty {
                ProgressView("Loading active tasks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.presentation.isEmpty {
                ContentUnavailableView(
                    emptyStateTitle,
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(emptyStateDescription)
                )
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if !store.presentation.linkedTaskChildSuggestions.isEmpty {
                            linkedTaskChildSuggestionsHeader

                            ForEach(store.presentation.linkedTaskChildSuggestions) { suggestion in
                                VStack(spacing: 0) {
                                    linkedTaskChildSuggestionRow(suggestion)

                                    if suggestion.id != store.presentation.linkedTaskChildSuggestions.last?.id {
                                        Divider().padding(.leading, 12)
                                    }
                                }
                                .background(Color(nsColor: .textBackgroundColor).opacity(0.62))
                            }

                            Color.clear
                                .frame(height: 12)
                                .accessibilityHidden(true)
                        }

                        ForEach(store.presentation.sections) { section in
                            let isCollapsed = collapsedSectionIDs.contains(section.id)

                            Section {
                                if !isCollapsed {
                                    ForEach(section.tasks) { task in
                                        VStack(spacing: 0) {
                                            rankingRow(task, in: section)
                                            if task.id != section.tasks.last?.id {
                                                Divider().padding(.leading, 12)
                                            }
                                        }
                                        .background(Color(nsColor: .textBackgroundColor).opacity(0.62))
                                    }
                                }

                                Color.clear
                                    .frame(height: 12)
                                    .accessibilityHidden(true)
                            } header: {
                                rankingSectionHeader(section, isCollapsed: isCollapsed)
                            }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))
    }

    private var linkedTaskChildSuggestionsHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Linked task suggestions", systemImage: "link.badge.plus")
                    .font(.headline)

                Text("\(store.presentation.linkedTaskChildSuggestions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            Text("Accept a linked task to place it in this group. Rejecting only hides the suggestion; either choice keeps the task link and its completion behavior unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.09))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func linkedTaskChildSuggestionRow(
        _ suggestion: TaskRankingPresentation.LinkedTaskChildSuggestion
    ) -> some View {
        HStack(spacing: 10) {
            Text(suggestion.taskEmoji)
                .font(.body)

            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.taskName)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Label(
                        suggestion.relationshipKind.title,
                        systemImage: suggestion.relationshipKind.systemImage
                    )

                    if suggestion.willMoveFromAnotherPlacement {
                        Text("Moves from its current Ladder location")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Button {
                store.send(.linkedTaskChildSuggestionRejected(
                    parentTaskID: suggestion.parentTaskID,
                    childTaskID: suggestion.taskID
                ))
            } label: {
                Label("Reject", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .help("Hide this child suggestion without removing the task link")

            Button {
                store.send(.linkedTaskChildSuggestionAccepted(
                    parentTaskID: suggestion.parentTaskID,
                    childTaskID: suggestion.taskID
                ))
            } label: {
                Label("Accept", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .help("Place this linked task inside the group")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func rankingSectionHeader(
        _ section: TaskRankingPresentation.Section,
        isCollapsed: Bool
    ) -> some View {
        Button {
            toggleRankingSection(section)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title)
                    .font(.headline)
                Text("\(section.tasks.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if !section.supportsManualOrdering {
                    Text(section.isMissingValue ? "Separate" : "Read only")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isCollapsed ? "Expand" : "Collapse") \(section.title)")
        .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
        .background(section.isMissingValue ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.09))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(section.isMissingValue ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func toggleRankingSection(_ section: TaskRankingPresentation.Section) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if collapsedSectionIDs.contains(section.id) {
                collapsedSectionIDs.remove(section.id)
            } else {
                collapsedSectionIDs.insert(section.id)
            }
        }
    }

    private func rankingRow(
        _ task: RoutineTask,
        in section: TaskRankingPresentation.Section
    ) -> some View {
        let metadata = store.presentation.rowMetadataByTaskID[task.id]
        let isGroup = metadata?.isGroup == true
        let isTaskGroup = metadata?.isTaskGroup == true
        let childCount = metadata?.childCount ?? 0
        let canOpenInnerLadder = isGroup || isTaskGroup || childCount > 0
        let isSelected = isGroup
            ? store.selectedGroupID == task.id
            : store.selectedTaskID == task.id
        return HStack(spacing: 9) {
            Button {
                if isGroup {
                    store.send(.groupSelected(task.id))
                } else {
                    store.send(.taskSelected(task.id))
                }
            } label: {
                HStack(spacing: 9) {
                    Text(task.emoji ?? "✨")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.name ?? "Untitled task")
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if let metadata {
                            rowMetadata(metadata)
                        }
                    }

                    Spacer(minLength: 2)

                    if canOpenInnerLadder {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(
                canOpenInnerLadder
                    ? "Click to show details; double-click to open the inner Task Ladder"
                    : "Click to show details"
            )
            .accessibilityHint(
                canOpenInnerLadder
                    ? "Double-click to open the inner Task Ladder"
                    : "Shows task details"
            )
            .onMacDoubleClick(enabled: canOpenInnerLadder) {
                store.send(.childLadderOpened(task.id))
            }

            if section.supportsManualOrdering {
                VStack(spacing: 2) {
                    Button {
                        store.send(.moveTask(task.id, .up))
                    } label: {
                        Image(systemName: "chevron.up")
                            .frame(width: 22, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Move up")

                    Button {
                        store.send(.moveTask(task.id, .down))
                    } label: {
                        Image(systemName: "chevron.down")
                            .frame(width: 22, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Move down")
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(isSelected ? Color.accentColor.opacity(0.14) : .clear)
        .contextMenu {
            if isGroup {
                Button("Show Group Details") {
                    store.send(.groupSelected(task.id))
                }
                Button("Open Inner Task Ladder") {
                    store.send(.childLadderOpened(task.id))
                }
                Button("Edit Group…") {
                    editingGroupID = task.id
                    isGroupEditorPresented = true
                }
            } else {
                Button("Open Task") {
                    store.send(.taskSelected(task.id))
                }
                Button("Organize in Task Ladder…") {
                    placementTaskID = task.id
                }
                if !task.isOneOffTask {
                    Button(
                        isTaskGroup || childCount > 0
                            ? "Add Task to This Group…"
                            : "Use as Task Ladder Group…"
                    ) {
                        repeatingTaskGroupParentID = task.id
                        isRepeatingTaskGroupEditorPresented = true
                    }
                }
                if isTaskGroup || childCount > 0 {
                    Button("Open Inner Task Ladder") {
                        store.send(.childLadderOpened(task.id))
                    }
                }
            }
            if section.supportsManualOrdering {
                Divider()
                Button("Move Up") { store.send(.moveTask(task.id, .up)) }
                Button("Move Down") { store.send(.moveTask(task.id, .down)) }
            }
        }
    }

    @ViewBuilder
    private func rowMetadata(_ metadata: TaskRankingPresentation.RowMetadata) -> some View {
        if metadata.isGroup || metadata.isTaskGroup || metadata.inheritsMetricValue || !metadata.tagLabels.isEmpty || metadata.isRepeating || metadata.childCount > 0 {
            HStack(spacing: 6) {
                if metadata.isGroup {
                    Label("Group", systemImage: "folder")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if metadata.inheritsMetricValue {
                    Label("Inherited", systemImage: "arrow.triangle.branch")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("Value inherited from tasks")
                }

                if metadata.isTaskGroup {
                    Label("Task group", systemImage: "square.stack.3d.up")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if !metadata.tagLabels.isEmpty {
                    Text(metadata.tagLabels.joined(separator: " • "))
                        .lineLimit(1)
                }

                if metadata.isRepeating {
                    Label("Repeating", systemImage: "repeat")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("Repeating task")
                }

                if metadata.childCount > 0 {
                    Label(
                        metadata.childCount == 1
                            ? "1 task"
                            : "\(metadata.childCount) tasks",
                        systemImage: "square.stack.3d.up"
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var taskDetail: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(store: detailStore)
        } else if let group = store.detailGroup {
            TaskLadderGroupDetailView(
                group: group,
                childCount: store.detailGroupChildCount,
                onEdit: {
                    editingGroupID = group.id
                    isGroupEditorPresented = true
                }
            )
        } else {
            ContentUnavailableView(
                "Select a task or group",
                systemImage: "arrow.up.arrow.down.circle",
                description: Text("Move categorical tasks up or down to set their place in this metric’s ladder.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var taskCountLabel: String {
        let count = store.presentation.taskCount
        if !store.scopePath.isEmpty {
            return count == 1 ? "1 task" : "\(count) tasks"
        }
        return count == 1 ? "1 task" : "\(count) tasks"
    }

    private var listSubtitle: String {
        let rankingDescription: String
        if store.metric == .estimatedTime {
            rankingDescription = "\(store.metric.directionTitle(isReversed: store.isReversed)) • factual sort"
        } else {
            rankingDescription = "\(store.metric.directionTitle(isReversed: store.isReversed)) • move tasks within or between values"
        }
        guard !store.scopePath.isEmpty else { return rankingDescription }
        return "Nested tasks • \(rankingDescription)"
    }

    private var ladderTitle: String {
        store.scopeParentName ?? "Task Ladder"
    }

    private var emptyStateTitle: String {
        store.scopePath.isEmpty
            ? "No tasks in Task Ladder"
            : "No actionable nested tasks"
    }

    private var emptyStateDescription: String {
        if let parentName = store.scopeParentName {
            return "\(parentName) has no nested tasks available in Task Ladder right now."
        }
        return "Paused, blocked, completed, canceled, archived, nested, and Flag-hidden tasks stay out of the root task ladder."
    }

}
