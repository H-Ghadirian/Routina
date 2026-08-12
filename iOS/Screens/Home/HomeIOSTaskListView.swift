import SwiftUI

struct HomeIOSTaskListView<HeaderContent: View, EmptyRowContent: View, RowContent: View, DestinationContent: View>: View {
    let presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    let presentationRevision: UInt
    let selectedTaskID: Binding<UUID?>
    let isCompactHeaderHidden: Bool
    let hasActiveOptionalFilters: Bool
    let isTaskSearchActive: Bool
    let headerContent: () -> HeaderContent
    let emptyRowContent: (HomeTaskListEmptyState) -> EmptyRowContent
    let rowContent: (HomeFeature.RoutineDisplay, Int?, Bool, HomeTaskListMoveContext?) -> RowContent
    let onDelete: (IndexSet, [HomeFeature.RoutineDisplay]) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    let destinationContent: (UUID) -> DestinationContent
    @AppStorage(
        UserDefaultBoolValueKey.appSettingDailyRoutinesSectionCollapsed.rawValue,
        store: SharedDefaults.app
    ) private var isDailyRoutinesSectionCollapsed = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingArchivedRoutinesSectionCollapsed.rawValue,
        store: SharedDefaults.app
    ) private var isArchivedSectionCollapsed = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingCollapsedTagTaskListSections.rawValue,
        store: SharedDefaults.app
    ) private var collapsedTagTaskListSectionIDsStorage = ""
    @State private var rowNumberCache = HomeIOSTaskListRowNumberCache()

    init(
        presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        presentationRevision: UInt,
        selectedTaskID: Binding<UUID?>,
        isCompactHeaderHidden: Bool,
        hasActiveOptionalFilters: Bool,
        isTaskSearchActive: Bool,
        @ViewBuilder headerContent: @escaping () -> HeaderContent,
        @ViewBuilder emptyRowContent: @escaping (HomeTaskListEmptyState) -> EmptyRowContent,
        @ViewBuilder rowContent: @escaping (HomeFeature.RoutineDisplay, Int?, Bool, HomeTaskListMoveContext?) -> RowContent,
        onDelete: @escaping (IndexSet, [HomeFeature.RoutineDisplay]) -> Void,
        onScroll: @escaping (CGFloat, CGFloat) -> Void,
        @ViewBuilder destinationContent: @escaping (UUID) -> DestinationContent
    ) {
        self.presentation = presentation
        self.presentationRevision = presentationRevision
        self.selectedTaskID = selectedTaskID
        self.isCompactHeaderHidden = isCompactHeaderHidden
        self.hasActiveOptionalFilters = hasActiveOptionalFilters
        self.isTaskSearchActive = isTaskSearchActive
        self.headerContent = headerContent
        self.emptyRowContent = emptyRowContent
        self.rowContent = rowContent
        self.onDelete = onDelete
        self.onScroll = onScroll
        self.destinationContent = destinationContent
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCompactHeaderHidden && hasActiveOptionalFilters {
                headerContent()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let emptyState = presentation.emptyState {
                emptyRowContent(emptyState)
            } else {
                taskList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.25), value: isCompactHeaderHidden)
    }

    private var taskList: some View {
        let expansionState = currentExpansionState

        return List(selection: selectedTaskID) {
            ForEach(presentation.sections) { section in
                Section {
                    if isSectionExpanded(section, expansionState: expansionState) {
                        ForEach(section.taskGroups) { group in
                            if let title = group.title {
                                taskGroupHeader(
                                    for: group,
                                    title: title,
                                    expansionState: expansionState
                                )
                            }

                            if isTaskGroupExpanded(group, expansionState: expansionState) {
                                ForEach(group.tasks, id: \.taskID) { task in
                                    rowContent(
                                        task,
                                        section.tasks.count == 1
                                            ? nil
                                            : rowNumberCache.values[task.taskID],
                                        section.includeMarkDone,
                                        group.moveContext
                                            ?? (group.usesSectionMoveContext ? section.moveContext : nil)
                                    )
                                }
                                .onDelete { offsets in
                                    onDelete(offsets, group.tasks)
                                }
                            }
                        }
                    }
                } header: {
                    sectionHeader(for: section, expansionState: expansionState)
                }
            }
        }
        .listStyle(.sidebar)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
        } action: { oldOffset, newOffset in
            if oldOffset != newOffset {
                RoutinaPerformanceProfiler.shared.recordInteraction(
                    isTaskSearchActive
                        ? .searchResultsScrolled
                        : .homeTaskListScrolled
                )
            }
            onScroll(oldOffset, newOffset)
        }
        .task(id: rowNumberCacheInvalidation) {
            rowNumberCache = HomeIOSTaskListRowNumberCache.make(
                presentation: presentation,
                expansionState: currentExpansionState,
                isTaskSearchActive: isTaskSearchActive
            )
        }
        .navigationDestination(for: UUID.self) { taskID in
            destinationContent(taskID)
        }
    }

    @ViewBuilder
    private func taskGroupHeader(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        title: String,
        expansionState: HomeIOSTaskListExpansionState
    ) -> some View {
        if group.isCollapsible {
            let isExpanded = isTaskGroupExpanded(group, expansionState: expansionState)
            Button {
                toggleTaskGroup(group)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(title)

                    Text("\(group.tasks.count)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    private func sectionHeader(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        expansionState: HomeIOSTaskListExpansionState
    ) -> some View {
        if section.kind.isCollapsible {
            let isExpanded = isSectionExpanded(section, expansionState: expansionState)
            Button {
                toggleSection(section, expansionState: expansionState)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Text(section.title)

                    Text("\(section.tasks.count)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(section.title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        } else {
            Text(section.title)
        }
    }

    private func isSectionExpanded(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        expansionState: HomeIOSTaskListExpansionState
    ) -> Bool {
        switch section.kind {
        case .plannedToday, .plannedTomorrow, .custom:
            return !expansionState.collapsedSectionIDs.contains(section.id)
        case .daily:
            return !expansionState.isDailyRoutinesSectionCollapsed
        case .future:
            return !expansionState.collapsedSectionIDs.contains(section.id)
        case .tag, .untagged:
            return !expansionState.collapsedSectionIDs.contains(section.id)
        case .archived:
            return !expansionState.isArchivedSectionCollapsed
        case .pinned, .regular, .deadlineDate, .away:
            return true
        }
    }

    private func toggleSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        expansionState: HomeIOSTaskListExpansionState
    ) {
        guard section.kind.isCollapsible else { return }
        withAnimation(.snappy(duration: 0.2)) {
            switch section.kind {
            case .plannedToday, .plannedTomorrow, .custom:
                setTagTaskListSection(
                    section,
                    collapsed: isSectionExpanded(section, expansionState: expansionState)
                )
            case .daily:
                isDailyRoutinesSectionCollapsed.toggle()
            case .future:
                setTagTaskListSection(
                    section,
                    collapsed: isSectionExpanded(section, expansionState: expansionState)
                )
            case .tag, .untagged:
                setTagTaskListSection(
                    section,
                    collapsed: isSectionExpanded(section, expansionState: expansionState)
                )
            case .archived:
                isArchivedSectionCollapsed.toggle()
            case .pinned, .regular, .deadlineDate, .away:
                break
            }
        }
    }

    private func isTaskGroupExpanded(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        expansionState: HomeIOSTaskListExpansionState
    ) -> Bool {
        guard group.isCollapsible else { return true }
        if isTaskSearchActive {
            return true
        }
        if group.isCollapsedByDefault {
            return expansionState.collapsedSectionIDs.contains(taskListGroupExpandedOverrideID(group))
        }
        return !expansionState.collapsedSectionIDs.contains(taskListGroupCollapseID(group))
    }

    private func toggleTaskGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) {
        guard group.isCollapsible else { return }
        let expansionState = currentExpansionState
        withAnimation(.snappy(duration: 0.2)) {
            if group.isCollapsedByDefault {
                setDefaultCollapsedTaskListGroup(
                    group,
                    expanded: !isTaskGroupExpanded(group, expansionState: expansionState)
                )
            } else {
                setTaskListGroup(
                    group,
                    collapsed: isTaskGroupExpanded(group, expansionState: expansionState)
                )
            }
        }
    }

    private var currentExpansionState: HomeIOSTaskListExpansionState {
        HomeIOSTaskListExpansionState(
            isDailyRoutinesSectionCollapsed: isDailyRoutinesSectionCollapsed,
            isArchivedSectionCollapsed: isArchivedSectionCollapsed,
            collapsedSectionIDs: collapsedTagTaskListSectionIDs
        )
    }

    private var rowNumberCacheInvalidation: HomeIOSTaskListRowNumberCacheInvalidation {
        HomeIOSTaskListRowNumberCacheInvalidation(
            presentationRevision: presentationRevision,
            isDailyRoutinesSectionCollapsed: isDailyRoutinesSectionCollapsed,
            isArchivedSectionCollapsed: isArchivedSectionCollapsed,
            collapsedSectionIDsStorage: collapsedTagTaskListSectionIDsStorage,
            isTaskSearchActive: isTaskSearchActive
        )
    }

    private var collapsedTagTaskListSectionIDs: Set<String> {
        Set(
            collapsedTagTaskListSectionIDsStorage
                .split(separator: "\n")
                .map(String.init)
        )
    }

    private func setTagTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        collapsed: Bool
    ) {
        var ids = collapsedTagTaskListSectionIDs
        if collapsed {
            ids.insert(section.id)
        } else {
            ids.remove(section.id)
        }
        collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
    }

    private func taskListGroupCollapseID(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> String {
        "group:\(group.id)"
    }

    private func taskListGroupExpandedOverrideID(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> String {
        "expandedGroup:\(group.id)"
    }

    private func setTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        collapsed: Bool
    ) {
        var ids = collapsedTagTaskListSectionIDs
        let id = taskListGroupCollapseID(group)
        if collapsed {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
    }

    private func setDefaultCollapsedTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        expanded: Bool
    ) {
        var ids = collapsedTagTaskListSectionIDs
        let id = taskListGroupExpandedOverrideID(group)
        if expanded {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
    }
}

private struct HomeIOSTaskListExpansionState {
    let isDailyRoutinesSectionCollapsed: Bool
    let isArchivedSectionCollapsed: Bool
    let collapsedSectionIDs: Set<String>

    func isSectionExpanded(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Bool {
        switch section.kind {
        case .plannedToday, .plannedTomorrow, .custom, .future, .tag, .untagged:
            return !collapsedSectionIDs.contains(section.id)
        case .daily:
            return !isDailyRoutinesSectionCollapsed
        case .archived:
            return !isArchivedSectionCollapsed
        case .pinned, .regular, .deadlineDate, .away:
            return true
        }
    }

    func isTaskGroupExpanded(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        isTaskSearchActive: Bool
    ) -> Bool {
        guard group.isCollapsible else { return true }
        if isTaskSearchActive { return true }
        if group.isCollapsedByDefault {
            return collapsedSectionIDs.contains("expandedGroup:\(group.id)")
        }
        return !collapsedSectionIDs.contains("group:\(group.id)")
    }
}

private struct HomeIOSTaskListRowNumberCacheInvalidation: Equatable {
    let presentationRevision: UInt
    let isDailyRoutinesSectionCollapsed: Bool
    let isArchivedSectionCollapsed: Bool
    let collapsedSectionIDsStorage: String
    let isTaskSearchActive: Bool
}

private struct HomeIOSTaskListRowNumberCache {
    var values: [UUID: Int] = [:]

    static func make(
        presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        expansionState: HomeIOSTaskListExpansionState,
        isTaskSearchActive: Bool
    ) -> Self {
        var values: [UUID: Int] = [:]
        values.reserveCapacity(presentation.visibleTaskCount)
        var rowNumber = 1

        for section in presentation.sections where expansionState.isSectionExpanded(section) {
            for group in section.taskGroups where expansionState.isTaskGroupExpanded(
                group,
                isTaskSearchActive: isTaskSearchActive
            ) {
                for task in group.tasks {
                    values[task.taskID] = rowNumber
                    rowNumber += 1
                }
            }
        }

        return Self(values: values)
    }
}
