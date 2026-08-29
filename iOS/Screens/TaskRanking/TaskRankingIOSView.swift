import ComposableArchitecture
import SwiftUI

struct TaskRankingIOSView: View {
    let store: StoreOf<TaskRankingFeature>
    private let isInnerLadderDestination: Bool

    @State private var innerLadderNodeID: UUID?

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

    init(
        store: StoreOf<TaskRankingFeature>,
        isInnerLadderDestination: Bool = false
    ) {
        self.store = store
        self.isInnerLadderDestination = isInnerLadderDestination
    }

    var body: some View {
        List {
            controlsSection

            if isSearching {
                searchSections
            } else if store.isLoading && store.presentation.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading active tasks…")
                        Spacer()
                    }
                    .padding(.vertical, 28)
                }
            } else if store.presentation.isEmpty {
                Section {
                    ContentUnavailableView(
                        emptyStateTitle,
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text(emptyStateDescription)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                linkedTaskSuggestionsSection

                ForEach(store.presentation.sections) { section in
                    Section {
                        ForEach(section.tasks) { task in
                            rankingRow(task, in: section)
                        }
                    } header: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(section.title)

                            Spacer(minLength: 8)

                            Text("\(section.tasks.count)")
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(store.scopeParentName ?? "Task Ladder")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: searchTextBinding, prompt: "Search Task Ladder")
        .navigationDestination(item: $innerLadderNodeID) { _ in
            TaskRankingIOSView(
                store: store,
                isInnerLadderDestination: true
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.send(.directionToggled)
                } label: {
                    Label(
                        store.metric.directionTitle(isReversed: store.isReversed),
                        systemImage: "arrow.up.arrow.down"
                    )
                }

                Button {
                    store.send(.refresh)
                } label: {
                    Label("Refresh Task Ladder", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .onAppear {
            store.send(
                .reversedMetricsChanged(
                    TaskRankingDirectionStorage.decode(reversedMetricsRawValue)
                )
            )
            store.send(.onAppear)
        }
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
        .onChange(of: innerLadderNodeID) { previousNodeID, nodeID in
            if previousNodeID != nil, nodeID == nil {
                store.send(.scopeBackTapped)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.routineDataChanged)
        }
        .alert(
            "Task Ladder",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.errorDismissed)
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var controlsSection: some View {
        Section {
            Picker("Rank by", selection: Binding(
                get: { store.metric },
                set: { store.send(.metricChanged($0)) }
            )) {
                ForEach(TaskRankingMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }

            if store.metric.supportsTemporalWeight {
                Picker("Values", selection: Binding(
                    get: { store.valueMode },
                    set: { store.send(.valueModeChanged($0)) }
                )) {
                    ForEach(TaskRankingValueMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            if !store.scopePath.isEmpty && !isInnerLadderDestination {
                Button {
                    store.send(.scopeBackTapped)
                } label: {
                    Label("Previous Task Ladder", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }

            LabeledContent("Order") {
                Text(store.metric.directionTitle(isReversed: store.isReversed))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var searchSections: some View {
        if store.searchPresentation.matches.isEmpty
            && store.searchPresentation.outsideMatches.isEmpty {
            Section {
                ContentUnavailableView.search(text: store.searchText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        } else {
            if !store.searchPresentation.matches.isEmpty {
                Section("Found in Task Ladder") {
                    ForEach(store.searchPresentation.matches) { match in
                        NavigationLink {
                            TaskRankingIOSTaskDestination(
                                store: store,
                                taskID: match.task.id,
                                selection: .searchMatch
                            )
                        } label: {
                            taskLabel(
                                match.task,
                                subtitle: match.locationTitle,
                                metadata: nil
                            )
                        }
                    }
                }
            }

            if !store.searchPresentation.outsideMatches.isEmpty {
                Section("Outside Task Ladder") {
                    ForEach(store.searchPresentation.outsideMatches) { match in
                        NavigationLink {
                            TaskRankingIOSTaskDestination(
                                store: store,
                                taskID: match.task.id,
                                selection: .task
                            )
                        } label: {
                            taskLabel(
                                match.task,
                                subtitle: match.reason,
                                metadata: nil
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var linkedTaskSuggestionsSection: some View {
        if !store.presentation.linkedTaskChildSuggestions.isEmpty {
            Section("Linked task suggestions") {
                ForEach(store.presentation.linkedTaskChildSuggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Text(suggestion.taskEmoji)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.taskName)

                                Text(suggestion.relationshipKind.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Button("Reject") {
                                store.send(
                                    .linkedTaskChildSuggestionRejected(
                                        parentTaskID: suggestion.parentTaskID,
                                        childTaskID: suggestion.taskID
                                    )
                                )
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button("Accept") {
                                store.send(
                                    .linkedTaskChildSuggestionAccepted(
                                        parentTaskID: suggestion.parentTaskID,
                                        childTaskID: suggestion.taskID
                                    )
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func rankingRow(
        _ task: RoutineTask,
        in section: TaskRankingPresentation.Section
    ) -> some View {
        let metadata = store.presentation.rowMetadataByTaskID[task.id]
        let canOpenInnerLadder = metadata?.isGroup == true
            || metadata?.isTaskGroup == true
            || (metadata?.childCount ?? 0) > 0

        return HStack(spacing: 6) {
            NavigationLink {
                rankingDestination(for: task, metadata: metadata)
            } label: {
                taskLabel(
                    task,
                    subtitle: rowSubtitle(metadata),
                    metadata: metadata
                )
            }

            if canOpenInnerLadder {
                Button {
                    openInnerLadder(task.id)
                } label: {
                    Image(systemName: "square.stack.3d.up")
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open inner Task Ladder")
            }
        }
        .contextMenu {
            if canOpenInnerLadder {
                Button("Open Inner Task Ladder") {
                    openInnerLadder(task.id)
                }
            }

            if section.supportsManualOrdering {
                Button("Move Up") {
                    store.send(.moveTask(task.id, .up))
                }

                Button("Move Down") {
                    store.send(.moveTask(task.id, .down))
                }
            }
        }
    }

    private func openInnerLadder(_ nodeID: UUID) {
        store.send(.childLadderOpened(nodeID))
        innerLadderNodeID = nodeID
    }

    @ViewBuilder
    private func rankingDestination(
        for task: RoutineTask,
        metadata: TaskRankingPresentation.RowMetadata?
    ) -> some View {
        if metadata?.isGroup == true,
           let group = store.organization.group(id: task.id) {
            TaskLadderIOSGroupDetailView(
                group: group,
                childCount: metadata?.childCount ?? 0
            )
        } else {
            TaskRankingIOSTaskDestination(
                store: store,
                taskID: task.id,
                selection: .task
            )
        }
    }

    private func taskLabel(
        _ task: RoutineTask,
        subtitle: String?,
        metadata: TaskRankingPresentation.RowMetadata?
    ) -> some View {
        HStack(spacing: 10) {
            Text(task.emoji ?? "✨")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name ?? "Untitled task")
                    .lineLimit(2)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 2)

            if metadata?.inheritsMetricValue == true {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Inherited value")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func rowSubtitle(
        _ metadata: TaskRankingPresentation.RowMetadata?
    ) -> String? {
        guard let metadata else { return nil }
        var labels: [String] = []
        if metadata.isGroup {
            labels.append("Group")
        } else if metadata.isTaskGroup {
            labels.append("Task group")
        }
        labels.append(contentsOf: metadata.tagLabels)
        if metadata.isRepeating {
            labels.append("Repeating")
        }
        if let temporalTimingLabel = metadata.temporalTimingLabel {
            labels.append(temporalTimingLabel)
        }
        if metadata.childCount > 0 {
            labels.append(metadata.childCount == 1 ? "1 task" : "\(metadata.childCount) tasks")
        }
        return labels.isEmpty ? nil : labels.joined(separator: " • ")
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { store.searchText },
            set: { store.send(.searchTextChanged($0)) }
        )
    }

    private var isSearching: Bool {
        HomeTaskSearchIndex.query(store.searchText) != nil
    }

    private var emptyStateTitle: String {
        store.scopePath.isEmpty ? "No active tasks" : "No tasks in this group"
    }

    private var emptyStateDescription: String {
        if store.scopePath.isEmpty {
            return "Paused, completed, canceled, archived, blocked, and hidden tasks stay outside the Task Ladder."
        }
        return "This Task Ladder group has no currently actionable tasks."
    }
}

private enum TaskRankingIOSSelection {
    case task
    case searchMatch
}

private struct TaskRankingIOSTaskDestination: View {
    let store: StoreOf<TaskRankingFeature>
    let taskID: UUID
    let selection: TaskRankingIOSSelection

    var body: some View {
        Group {
            if store.selectedTaskID == taskID,
               let detailStore = store.scope(
                   state: \.taskDetailState,
                   action: \.taskDetail
               ) {
                TaskDetailTCAView(store: detailStore)
            } else {
                ProgressView("Opening task…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: taskID) {
            guard store.selectedTaskID != taskID else { return }
            switch selection {
            case .task:
                store.send(.taskSelected(taskID))
            case .searchMatch:
                store.send(.searchMatchSelected(taskID))
            }
        }
    }
}

private struct TaskLadderIOSGroupDetailView: View {
    let group: TaskLadderGroup
    let childCount: Int

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text(group.displayEmoji)
                        .font(.largeTitle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.displayName)
                            .font(.title2.weight(.semibold))

                        Text(childCount == 1 ? "1 actionable task" : "\(childCount) actionable tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Task Ladder values") {
                ForEach(TaskRankingMetric.allCases.filter { $0 != .estimatedTime }) { metric in
                    LabeledContent(metric.title) {
                        Text(metric.value(for: group)?.title ?? "No value")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Group Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
