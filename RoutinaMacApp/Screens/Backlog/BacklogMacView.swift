import ComposableArchitecture
import SwiftUI

struct BacklogMacView<FilterView: View>: View {
    let store: StoreOf<BacklogFeature>
    let onShowTaskInPlanner: (UUID, String) -> Void
    let onShowTaskInTimeline: (UUID, String) -> Void
    let isFilterPresented: Bool
    let isFilterFullscreen: Bool
    let onExpandFilter: () -> Void
    let onMinimizeFilter: () -> Void
    let onCloseFilter: () -> Void
    @ViewBuilder let filterView: () -> FilterView

    init(
        store: StoreOf<BacklogFeature>,
        onShowTaskInPlanner: @escaping (UUID, String) -> Void = { _, _ in },
        onShowTaskInTimeline: @escaping (UUID, String) -> Void = { _, _ in },
        isFilterPresented: Bool,
        isFilterFullscreen: Bool,
        onExpandFilter: @escaping () -> Void,
        onMinimizeFilter: @escaping () -> Void,
        onCloseFilter: @escaping () -> Void,
        @ViewBuilder filterView: @escaping () -> FilterView
    ) {
        self.store = store
        self.onShowTaskInPlanner = onShowTaskInPlanner
        self.onShowTaskInTimeline = onShowTaskInTimeline
        self.isFilterPresented = isFilterPresented
        self.isFilterFullscreen = isFilterFullscreen
        self.onExpandFilter = onExpandFilter
        self.onMinimizeFilter = onMinimizeFilter
        self.onCloseFilter = onCloseFilter
        self.filterView = filterView
    }

    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) private var customTaskSectionsRawValue = ""
    @State private var newSectionTitle = ""
    @State private var newSectionTaskID: UUID?
    @State private var isNewSectionPromptPresented = false
    @State private var newSubsectionTitleBySectionID: [UUID: String] = [:]

    var body: some View {
        backlogContent
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .onChange(of: customTaskSectionsRawValue) { _, rawValue in
            store.send(.customSectionsChanged(HomeCustomTaskSectionStorage.decoded(from: rawValue)))
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.routineDataChanged)
        }
        .alert("New Backlog Super Section", isPresented: $isNewSectionPromptPresented) {
            TextField("Name", text: $newSectionTitle)
            Button("Create") {
                createBacklogSection()
            }
            .disabled(HomeCustomTaskSectionStorage.sanitizedTitle(newSectionTitle) == nil)
            Button("Cancel", role: .cancel) {
                resetNewSectionPrompt()
            }
        }
    }

    @ViewBuilder
    private var backlogContent: some View {
        if isFilterPresented && isFilterFullscreen {
            fullscreenFilterContent
        } else {
            contentWithOptionalFilterPane
        }
    }

    private var workspaceContent: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 280, idealWidth: 330, maxWidth: 420)

            detail
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var contentWithOptionalFilterPane: some View {
        GeometryReader { proxy in
            let filterPaneWidth = isFilterPresented ? MacDetailContainerSizing.filterDetailPaneWidth : 0
            let workspaceWidth = max(proxy.size.width - filterPaneWidth, 0)

            HStack(spacing: 0) {
                workspaceContent
                    .frame(width: workspaceWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()

                if isFilterPresented {
                    filterPane
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MacHomeDetailAnimation.secondaryPane, value: isFilterPresented)
    }

    private var filterPane: some View {
        VStack(spacing: 0) {
            filterHeader(showsFullscreenAction: true)
            Divider()
            filterView()
        }
        .frame(width: MacDetailContainerSizing.filterDetailPaneWidth)
        .frame(maxHeight: .infinity)
        .background(Color.secondary.opacity(0.045), ignoresSafeAreaEdges: [])
        .overlay(alignment: .leading) {
            Divider()
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .zIndex(1)
    }

    private var fullscreenFilterContent: some View {
        VStack(spacing: 0) {
            filterHeader(showsFullscreenAction: false)
            Divider()
            filterView()
                .frame(
                    maxWidth: MacDetailContainerSizing.fullscreenFilterContentMaxWidth,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func filterHeader(showsFullscreenAction: Bool) -> some View {
        HStack(spacing: 10) {
            Label("Filter and Sort", systemImage: "line.3.horizontal.decrease.circle")
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            filterHeaderButton(
                systemName: showsFullscreenAction
                    ? "arrow.up.left.and.arrow.down.right"
                    : "arrow.down.right.and.arrow.up.left",
                title: showsFullscreenAction ? "Open Fullscreen" : "Minimize",
                action: showsFullscreenAction ? onExpandFilter : onMinimizeFilter
            )

            filterHeaderButton(
                systemName: "xmark",
                title: "Close",
                action: onCloseFilter
            )
        }
        .padding(.horizontal, showsFullscreenAction ? 14 : 20)
        .padding(.vertical, showsFullscreenAction ? 10 : 12)
    }

    private func filterHeaderButton(
        systemName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Backlog")
                        .font(.title2.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(backlogCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        store.send(.refresh)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh Backlog")
                    .disabled(store.isLoading)
                }

                Text("Tasks kept off your main task list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if store.isLoading && store.presentation.isEmpty {
                ProgressView("Loading Backlog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearching
                        && store.presentation.taskCount == 0
                        && store.presentation.outsideBacklogResults.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.presentation.isEmpty
                        && store.presentation.outsideBacklogResults.isEmpty {
                ContentUnavailableView(
                    "Backlog is clear",
                    systemImage: "tray",
                    description: Text("Move a task here from the main task list, or create a Backlog section in Settings.")
                )
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.presentation.sections) { section in
                            backlogSection(section)
                        }

                        if !store.presentation.hiddenByFlagTasks.isEmpty {
                            automaticFlagSection
                        }

                        if !store.presentation.outsideBacklogResults.isEmpty {
                            outsideBacklogSection
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private func backlogSection(_ section: BacklogTaskListPresentation.Section) -> some View {
        let isExpanded = isSearching || !store.collapsedSuperSectionIDs.contains(section.id)

        return VStack(alignment: .leading, spacing: 5) {
            Button {
                toggleSection(section.id)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(sectionColor(section.section))
                        .frame(width: 12)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: "folder.fill")
                        .foregroundStyle(sectionColor(section.section))

                    Text(section.section.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(section.taskCount)")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(section.tasks) { task in
                    taskRow(task, pathTitle: section.section.title)
                }

                ForEach(section.subsections) { subsection in
                    backlogSubsection(subsection, parentSection: section.section)
                }

                if !isSearching {
                    newSubsectionControl(for: section.section.id)
                        .padding(.leading, 18)
                        .padding(.top, 3)
                }
            }
        }
    }

    private func backlogSubsection(
        _ subsection: BacklogTaskListPresentation.Subsection,
        parentSection: HomeCustomTaskSection
    ) -> some View {
        let isExpanded = isSearching || !store.collapsedSubsectionIDs.contains(subsection.id)

        return VStack(alignment: .leading, spacing: 5) {
            Button {
                toggleSubsection(subsection.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)

                    Text(subsection.section.title)
                        .font(.caption.weight(.medium))

                    Spacer(minLength: 0)

                    Text("\(subsection.tasks.count)")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(subsection.tasks) { task in
                    taskRow(
                        task,
                        pathTitle: "\(parentSection.title) › \(subsection.section.title)",
                        indentation: 14
                    )
                }
            }
        }
    }

    private var automaticFlagSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.orange)

                Text("Hidden by flag")
                    .font(.caption.weight(.semibold))

                Text("\(store.presentation.hiddenByFlagTasks.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            ForEach(store.presentation.hiddenByFlagTasks) { task in
                taskRow(task, pathTitle: "Hidden by flag")
            }
        }
    }

    private var outsideBacklogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.presentation.taskCount == 0 ? "No matches in Backlog" : "Found outside Backlog")
                    .font(.caption.weight(.semibold))

                if store.presentation.taskCount == 0 {
                    Text("Found outside Backlog")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            ForEach(store.presentation.outsideBacklogResults) { result in
                outsideBacklogResultRow(result)
            }
        }
        .padding(.top, store.presentation.taskCount == 0 ? 2 : 8)
    }

    private func outsideBacklogResultRow(
        _ result: BacklogTaskListPresentation.OutsideBacklogResult
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                store.send(.taskSelected(result.task.id))
            } label: {
                HStack(spacing: 9) {
                    Text(result.task.emoji ?? "✨")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.task.name ?? "Untitled task")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)

                        Text(result.locationTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(result.task.name ?? "Untitled task") task details")

            HStack(spacing: 7) {
                Button("Open Task") {
                    store.send(.taskSelected(result.task.id))
                }

                switch result.revealDestination {
                case .planner:
                    Button("Show in Planner") {
                        onShowTaskInPlanner(result.task.id, store.searchText)
                    }
                case .timeline:
                    Button("Show in Timeline") {
                        onShowTaskInTimeline(result.task.id, store.searchText)
                    }
                }

                Menu("Move to Backlog…") {
                    backlogMoveMenuItems(for: result.task.id)
                }
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.68))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    private func newSubsectionControl(for parentSectionID: UUID) -> some View {
        let draft = Binding(
            get: { newSubsectionTitleBySectionID[parentSectionID, default: ""] },
            set: { newSubsectionTitleBySectionID[parentSectionID] = $0 }
        )
        return HStack(spacing: 7) {
            TextField("New subsection", text: draft)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit { createBacklogSubsection(parentSectionID) }

            Button {
                createBacklogSubsection(parentSectionID)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Add subsection")
            .disabled(HomeCustomTaskSectionStorage.sanitizedTitle(draft.wrappedValue) == nil)
        }
    }

    private func taskRow(
        _ task: RoutineTask,
        pathTitle: String,
        indentation: CGFloat = 0
    ) -> some View {
        let isSelected = store.selectedTaskID == task.id

        return Button {
            store.send(.taskSelected(task.id))
        } label: {
            HStack(spacing: 9) {
                Text(task.emoji ?? "✨")
                    .font(.body)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.name ?? "Untitled task")
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    taskSubtitle(task, pathTitle: pathTitle)
                }

                Spacer(minLength: 4)

                if task.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 10 + indentation)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Task") {
                store.send(.taskSelected(task.id))
            }

            Menu("Move to Backlog") {
                backlogMoveMenuItems(for: task.id)
            }

            if task.customTaskSectionID != nil {
                Button("Move to Main Task List") {
                    store.send(.moveTask(task.id, to: nil))
                }
            }
        }
    }

    @ViewBuilder
    private func taskSubtitle(_ task: RoutineTask, pathTitle: String) -> some View {
        let hidingFlags = RoutineFlagRules.flagsHidingFromTaskLists(task.flags, rules: store.flagRules)
        let labels = [pathTitle] + (hidingFlags.isEmpty ? [] : [hidingFlags.joined(separator: ", ")])
        Text(labels.joined(separator: " • "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var detail: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
            )
        } else {
            ContentUnavailableView(
                "Select a backlog task",
                systemImage: "tray.full",
                description: Text("Open a task to review its details or edit it without bringing it back to the main sidebar.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var backlogCountLabel: String {
        let count = store.presentation.taskCount
        if isSearching {
            return count == 1 ? "1 in Backlog" : "\(count) in Backlog"
        }
        return count == 1 ? "1 task" : "\(count) tasks"
    }

    private var isSearching: Bool {
        HomeTaskSearchIndex.query(store.searchText) != nil
    }

    @ViewBuilder
    private func backlogMoveMenuItems(for taskID: UUID) -> some View {
        let sections = HomeCustomTaskSectionStorage.topLevelSections(
            in: store.customSections,
            surface: .backlog
        )

        ForEach(sections) { section in
            let subsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: store.customSections
            )

            if subsections.isEmpty {
                Button(section.title) {
                    store.send(.moveTask(taskID, to: section.id))
                }
            } else {
                Menu(section.title) {
                    Button("In \(section.title)") {
                        store.send(.moveTask(taskID, to: section.id))
                    }

                    ForEach(subsections) { subsection in
                        Button(subsection.title) {
                            store.send(.moveTask(taskID, to: subsection.id))
                        }
                    }
                }
            }
        }

        if !sections.isEmpty {
            Divider()
        }

        Button("New Backlog Super Section…") {
            presentNewBacklogSection(for: taskID)
        }
    }

    private func presentNewBacklogSection(for taskID: UUID) {
        newSectionTaskID = taskID
        newSectionTitle = ""
        isNewSectionPromptPresented = true
    }

    private func resetNewSectionPrompt() {
        isNewSectionPromptPresented = false
        newSectionTitle = ""
        newSectionTaskID = nil
    }

    private func createBacklogSection() {
        guard let update = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSectionTitle,
            surface: .backlog,
            in: storedCustomSections
        ) else {
            return
        }
        persistCustomSections(update.sections)
        if let taskID = newSectionTaskID {
            store.send(.moveTask(taskID, to: update.section.id))
        }
        resetNewSectionPrompt()
    }

    private func createBacklogSubsection(_ parentSectionID: UUID) {
        let title = newSubsectionTitleBySectionID[parentSectionID, default: ""]
        guard let update = HomeCustomTaskSectionStorage.upsertingSection(
            title: title,
            parentSectionID: parentSectionID,
            in: storedCustomSections
        ) else {
            return
        }
        newSubsectionTitleBySectionID[parentSectionID] = ""
        persistCustomSections(update.sections)
    }

    private var storedCustomSections: [HomeCustomTaskSection] {
        HomeCustomTaskSectionStorage.decoded(from: customTaskSectionsRawValue)
    }

    private func persistCustomSections(_ sections: [HomeCustomTaskSection]) {
        customTaskSectionsRawValue = HomeCustomTaskSectionStorage.encoded(sections)
        AppSettingsPersistenceMirror.schedule()
        store.send(.customSectionsChanged(sections))
    }

    private func toggleSection(_ sectionID: UUID) {
        guard !isSearching else { return }
        store.send(.superSectionDisclosureToggled(sectionID))
    }

    private func toggleSubsection(_ subsectionID: UUID) {
        guard !isSearching else { return }
        store.send(.subsectionDisclosureToggled(subsectionID))
    }

    private func sectionColor(_ section: HomeCustomTaskSection) -> Color {
        guard let colorHex = section.colorHex else { return .accentColor }
        return Color(hex: colorHex)
    }
}

struct BacklogMacFiltersDetailView: View {
    let store: StoreOf<BacklogFeature>

    var body: some View {
        HomeMacFilterDetailContainerView(
            title: "Backlog Filter and Sort",
            showsTitle: false
        ) {
            header
            coreFilters
            taskLadderFilters
            tagFilters
            flagFilters
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Backlog")
                    .font(.title2.weight(.semibold))

                Text("Filtering and sorting affect Backlog only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Reset") {
                store.send(.clearFilters)
            }
            .disabled(!store.filters.hasNonDefaultOptions)
        }
    }

    private var coreFilters: some View {
        HomeMacSidebarSectionCard(title: "Filter and Sort") {
            VStack(alignment: .leading, spacing: 18) {
                HomeMacAdaptiveFilterControlRow("Sort") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog sort order",
                        options: BacklogSortOrder.allCases,
                        selection: filterBinding(\.sortOrder),
                        minimumSegmentWidth: 126,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { order in
                        Label(order.title, systemImage: order.systemImage)
                    }
                }

                HomeMacAdaptiveFilterControlRow("Task type") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog task type",
                        options: HomeTaskListMode.allCases,
                        selection: filterBinding(\.taskListMode),
                        minimumSegmentWidth: 112,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { mode in
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                }

                HomeMacAdaptiveFilterControlRow("Created") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog created date",
                        options: HomeTaskCreatedDateFilter.allCases,
                        selection: filterBinding(\.createdDateFilter),
                        minimumSegmentWidth: 126,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }

                if store.filters.taskListMode != .routines {
                    HomeMacAdaptiveFilterControlRow("Status") {
                        HomeMacAdaptiveFilterChoiceControl(
                            accessibilityLabel: "Backlog one-time status",
                            options: todoStateOptions,
                            selection: filterBinding(\.selectedTodoState),
                            minimumSegmentWidth: 92,
                            compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                        ) { state in
                            if let state {
                                Label(state.displayTitle, systemImage: state.systemImage)
                            } else {
                                Label("All", systemImage: "circle.grid.2x2")
                            }
                        }
                    }
                }

                HomeMacAdaptiveFilterControlRow("Media") {
                    HomeMacAdaptiveFilterChoiceControl(
                        accessibilityLabel: "Backlog media",
                        options: TaskMediaFilter.allCases,
                        selection: filterBinding(\.selectedMediaFilter),
                        minimumSegmentWidth: 104,
                        compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth
                    ) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }
            }
        }
    }

    private var taskLadderFilters: some View {
        HomeMacTaskLadderFiltersSection(
            selectedImportanceUrgencyFilter: filterBinding(\.selectedImportanceUrgencyFilter),
            selectedPressureFilter: filterBinding(\.selectedPressureFilter),
            selectedThinkingNeededFilter: filterBinding(\.selectedThinkingNeededFilter),
            selectedEstimationFilter: filterBinding(\.selectedEstimationFilter)
        )
    }

    private var tagFilters: some View {
        HomeMacTimelineTagFiltersView(
            availableTags: store.presentation.filterCatalog.tags,
            suggestedRelatedTags: [],
            availableExcludeTags: store.presentation.filterCatalog.tags,
            selectedTags: store.filters.selectedTags,
            includeTagMatchMode: store.filters.includeTagMatchMode,
            excludeTagMatchMode: store.filters.excludeTagMatchMode,
            selectedExcludedTags: store.filters.excludedTags,
            tagCount: { tag in
                store.presentation.filterCatalog.tagCounts[RoutineTag.normalized(tag) ?? tag, default: 0]
            },
            tagColor: { tag in
                guard let hex = store.tagColors[RoutineTag.normalized(tag) ?? tag] else { return nil }
                return Color(hex: hex)
            },
            onSelectTags: { updateFilter(\.selectedTags, to: $0) },
            onIncludeTagMatchModeChange: { updateFilter(\.includeTagMatchMode, to: $0) },
            onSelectSuggestedTag: { tag in
                var tags = store.filters.selectedTags
                tags.insert(tag)
                updateFilter(\.selectedTags, to: tags)
            },
            onExcludeTagMatchModeChange: { updateFilter(\.excludeTagMatchMode, to: $0) },
            onToggleExcludedTag: toggleExcludedTag,
            presentation: .compactActions
        )
    }

    private var flagFilters: some View {
        HomeMacSharedFlagFiltersView(
            availableFlags: store.presentation.filterCatalog.flags,
            selectedFlags: store.filters.selectedFlags,
            excludedFlags: store.filters.excludedFlags,
            includeFlagMatchMode: store.filters.includeFlagMatchMode,
            excludeFlagMatchMode: store.filters.excludeFlagMatchMode,
            onSelectIncludedFlags: { updateFilter(\.selectedFlags, to: $0) },
            onIncludeFlagMatchModeChange: { updateFilter(\.includeFlagMatchMode, to: $0) },
            onSelectExcludedFlags: { updateFilter(\.excludedFlags, to: $0) },
            onExcludeFlagMatchModeChange: { updateFilter(\.excludeFlagMatchMode, to: $0) }
        )
    }

    private var todoStateOptions: [TodoState?] {
        [nil] + TodoState.filterableCases.map(Optional.some)
    }

    private func filterBinding<Value: Equatable>(
        _ keyPath: WritableKeyPath<BacklogFilterState, Value>
    ) -> Binding<Value> {
        Binding(
            get: { store.filters[keyPath: keyPath] },
            set: { updateFilter(keyPath, to: $0) }
        )
    }

    private func updateFilter<Value: Equatable>(
        _ keyPath: WritableKeyPath<BacklogFilterState, Value>,
        to value: Value
    ) {
        guard store.filters[keyPath: keyPath] != value else { return }
        var filters = store.filters
        filters[keyPath: keyPath] = value
        store.send(.filtersChanged(filters))
    }

    private func toggleExcludedTag(_ tag: String) {
        var tags = store.filters.excludedTags
        if let existing = tags.first(where: { RoutineTag.contains($0, in: [tag]) }) {
            tags.remove(existing)
        } else {
            tags.insert(tag)
        }
        updateFilter(\.excludedTags, to: tags)
    }
}
