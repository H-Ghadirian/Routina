import ComposableArchitecture
import SwiftUI

struct TaskRankingMacView: View {
    let store: StoreOf<TaskRankingFeature>
    let isControlsPresented: Bool
    let isControlsFullscreen: Bool
    let onExpandControls: () -> Void
    let onMinimizeControls: () -> Void
    let onCloseControls: () -> Void
    let initialControlsTab: HomeMacFilterDetailTab

    init(
        store: StoreOf<TaskRankingFeature>,
        isControlsPresented: Bool = false,
        isControlsFullscreen: Bool = false,
        onExpandControls: @escaping () -> Void = {},
        onMinimizeControls: @escaping () -> Void = {},
        onCloseControls: @escaping () -> Void = {},
        initialControlsTab: HomeMacFilterDetailTab = .filter
    ) {
        self.store = store
        self.isControlsPresented = isControlsPresented
        self.isControlsFullscreen = isControlsFullscreen
        self.onExpandControls = onExpandControls
        self.onMinimizeControls = onMinimizeControls
        self.onCloseControls = onCloseControls
        self.initialControlsTab = initialControlsTab
    }

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
    @AppStorage(
        UserDefaultStringValueKey.appSettingTaskLadderTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var taskRowHiddenFieldsRawValue = HomeTaskRowVisibility.taskLadderDefaultStorageRawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @State private var collapsedSectionIDs = Set<String>()
    @State var groupEditorPresentation: TaskLadderGroupEditorPresentation?
    @State private var placementTaskID: UUID?
    @State var isRepeatingTaskGroupEditorPresented = false
    @State var repeatingTaskGroupParentID: UUID?
    @State private var temporalWeightTaskID: UUID?

    var body: some View {
        // Observe list-driving snapshots and selection at the view-body boundary,
        // before HSplitView and the LazyVStack retain their child builders.
        // Reading them only inside descendant builders can leave old membership,
        // counts, or row chrome visible after the feature publishes a replacement.
        let presentation = store.presentation
        let searchPresentation = store.searchPresentation
        let currentScopeSearchMatchTaskIDs = store.currentScopeSearchMatchTaskIDs
        let searchText = store.searchText
        let isSearching = HomeTaskSearchIndex.query(searchText) != nil
        let selectedTaskID = store.selectedTaskID
        let selectedGroupID = store.selectedGroupID
        let selectedNodeID: TaskLadderNodeID? =
            if let selectedGroupID {
                .group(selectedGroupID)
            } else if let selectedTaskID {
                .task(selectedTaskID)
            } else {
                nil
            }

        return taskRankingControlsPresentation {
            HSplitView {
                rankingList(
                    presentation: presentation,
                    searchPresentation: searchPresentation,
                    currentScopeSearchMatchTaskIDs: currentScopeSearchMatchTaskIDs,
                    searchText: searchText,
                    isSearching: isSearching,
                    selectedNodeID: selectedNodeID
                )
                .frame(minWidth: 340, idealWidth: 440, maxWidth: 560)

                taskDetail
                    .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
            }
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
        .sheet(item: $groupEditorPresentation) { presentation in
            TaskLadderGroupEditorSheet(
                group: presentation.group,
                onSave: { store.send(.groupSaved($0)) },
                onDelete: { store.send(.groupDeleted($0)) }
            )
        }
        .sheet(
            isPresented: Binding(
                get: { placementTaskID != nil },
                set: { if !$0 { placementTaskID = nil } }
            )
        ) {
            if let taskID = placementTaskID,
                let task = store.tasks.first(where: { $0.id == taskID })
            {
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
            onDismiss: { repeatingTaskGroupParentID = nil },
            content: {
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
        )
        .sheet(
            isPresented: Binding(
                get: { temporalWeightTaskID != nil },
                set: { if !$0 { temporalWeightTaskID = nil } }
            )
        ) {
            if let taskID = temporalWeightTaskID,
                let task = store.tasks.first(where: { $0.id == taskID })
            {
                TaskTemporalWeightRuleSheet(
                    task: task,
                    onSave: { importance, urgency, pressure, rule in
                        store.send(
                            .temporalWeightRuleSaved(
                                taskID,
                                importance,
                                urgency,
                                pressure,
                                rule
                            )
                        )
                    }
                )
            }
        }
    }

    private func rankingList(
        presentation: TaskRankingPresentation,
        searchPresentation: TaskRankingSearchPresentation,
        currentScopeSearchMatchTaskIDs: Set<UUID>,
        searchText: String,
        isSearching: Bool,
        selectedNodeID: TaskLadderNodeID?
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !store.scopePath.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        store.send(.scopeBackTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Back to previous ladder")

                    Text(store.scopeParentName ?? "Nested tasks")
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(16)

                Divider()
            }

            if store.isLoading && presentation.isEmpty {
                ProgressView("Loading active tasks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if presentation.isEmpty
                && searchPresentation.matches.isEmpty
                && searchPresentation.outsideMatches.isEmpty
            {
                ContentUnavailableView(
                    isSearching
                        ? "No Task Ladder matches"
                        : TaskRankingMacEmptyState.title(isNested: !store.scopePath.isEmpty),
                    systemImage: isSearching ? "magnifyingglass" : "line.3.horizontal.decrease.circle",
                    description: Text(
                        isSearching
                            ? "Try a different task name, tag, Flag, note, or group path."
                            : TaskRankingMacEmptyState.description(parentName: store.scopeParentName)
                    )
                )
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if isSearching {
                                TaskRankingMacSearchResults(
                                    searchPresentation: searchPresentation,
                                    searchText: searchText,
                                    onSelectMatch: { store.send(.searchMatchSelected($0)) },
                                    onOpenOutsideMatch: { store.send(.taskSelected($0)) }
                                )

                                Color.clear
                                    .frame(height: 12)
                                    .accessibilityHidden(true)
                            }

                            if !presentation.linkedTaskChildSuggestions.isEmpty {
                                TaskRankingMacLinkedTaskSuggestions(
                                    presentation: presentation,
                                    onReject: { parentTaskID, childTaskID in
                                        store.send(
                                            .linkedTaskChildSuggestionRejected(
                                                parentTaskID: parentTaskID,
                                                childTaskID: childTaskID
                                            ))
                                    },
                                    onAccept: { parentTaskID, childTaskID in
                                        store.send(
                                            .linkedTaskChildSuggestionAccepted(
                                                parentTaskID: parentTaskID,
                                                childTaskID: childTaskID
                                            ))
                                    }
                                )

                                Color.clear
                                    .frame(height: 12)
                                    .accessibilityHidden(true)
                            }

                            ForEach(presentation.sections) { section in
                                let containsSearchMatch = section.tasks.contains {
                                    currentScopeSearchMatchTaskIDs.contains($0.id)
                                }
                                let isCollapsed =
                                    collapsedSectionIDs.contains(section.id)
                                    && !containsSearchMatch

                                Section {
                                    if !isCollapsed {
                                        ForEach(section.tasks) { task in
                                            let metadata = presentation.rowMetadataByTaskID[task.id]
                                            let nodeID: TaskLadderNodeID =
                                                metadata?.isGroup == true
                                                ? .group(task.id)
                                                : .task(task.id)
                                            let rowIdentity = TaskLadderLazyRowIdentity(
                                                nodeID: nodeID,
                                                metric: presentation.metric,
                                                valueMode: presentation.valueMode,
                                                sectionID: section.id,
                                                selectedNodeID: selectedNodeID
                                            )
                                            VStack(spacing: 0) {
                                                rankingRow(
                                                    task,
                                                    in: section,
                                                    metadata: metadata,
                                                    rowNumber: presentation.rowNumbersByTaskID[task.id],
                                                    isSelected: rowIdentity.isSelected,
                                                    isSearchMatch: currentScopeSearchMatchTaskIDs.contains(task.id)
                                                )
                                                // Retain the stable task target used by search-location scrolling
                                                // inside the presentation-scoped lazy-row identity.
                                                .id(task.id)
                                                if task.id != section.tasks.last?.id {
                                                    Divider().padding(.leading, 12)
                                                }
                                            }
                                            // A task can move through a completely different section layout when
                                            // the metric or value mode changes. Recreate that lazy row at the item
                                            // boundary so its later selection updates cannot reuse stale chrome.
                                            .id(rowIdentity)
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
                    .onChange(of: store.selectedTaskID) { _, selectedTaskID in
                        guard let selectedTaskID,
                            store.currentScopeSearchMatchTaskIDs.contains(selectedTaskID)
                        else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedTaskID, anchor: .center)
                        }
                    }
                    .onChange(of: store.searchLocateRequestID) { _, _ in
                        guard let selectedTaskID = store.selectedTaskID,
                            store.currentScopeSearchMatchTaskIDs.contains(selectedTaskID)
                        else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(selectedTaskID, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))
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
        .accessibilityValue(
            section.supportsManualOrdering
                ? (isCollapsed ? "Collapsed" : "Expanded")
                : "\(isCollapsed ? "Collapsed" : "Expanded"), read only"
        )
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

    @ViewBuilder
    private func rankingRow(
        _ task: RoutineTask,
        in section: TaskRankingPresentation.Section,
        metadata: TaskRankingPresentation.RowMetadata?,
        rowNumber: Int?,
        isSelected: Bool,
        isSearchMatch: Bool
    ) -> some View {
        if let metadata {
            TaskRankingMacRow(
                task: task,
                metadata: metadata,
                rowNumber: rowNumber,
                supportsManualOrdering: section.supportsManualOrdering,
                isSelected: isSelected,
                isSearchMatch: isSearchMatch,
                visibility: HomeTaskRowVisibility(storageRawValue: taskRowHiddenFieldsRawValue),
                showsPlaces: isPlacesEnabled,
                onSelect: {
                    if metadata.isGroup {
                        store.send(.groupSelected(task.id))
                    } else {
                        store.send(.taskSelected(task.id))
                    }
                },
                onOpenInnerLadder: { store.send(.childLadderOpened(task.id)) },
                onEditGroup: {
                    guard let group = store.organization.group(id: task.id) else { return }
                    groupEditorPresentation = TaskLadderGroupEditorPresentation(group: group)
                },
                onOrganize: { placementTaskID = task.id },
                onEditTemporalWeight: { temporalWeightTaskID = task.id },
                onUseAsGroup: {
                    repeatingTaskGroupParentID = task.id
                    isRepeatingTaskGroupEditorPresented = true
                },
                onMoveUp: { store.send(.moveTask(task.id, .up)) },
                onMoveDown: { store.send(.moveTask(task.id, .down)) }
            )
        }
    }

    @ViewBuilder
    private var taskDetail: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
            )
        } else if let group = store.detailGroup {
            TaskLadderGroupDetailView(
                group: group,
                childCount: store.detailGroupChildCount,
                onEdit: {
                    groupEditorPresentation = TaskLadderGroupEditorPresentation(group: group)
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

}
