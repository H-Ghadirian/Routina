import SwiftUI

struct HomeIOSTaskListView<HeaderContent: View, EmptyRowContent: View, RowContent: View, DestinationContent: View>: View {
    let presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    let selectedTaskID: Binding<UUID?>
    let isCompactHeaderHidden: Bool
    let hasActiveOptionalFilters: Bool
    let isTaskSearchActive: Bool
    let headerContent: () -> HeaderContent
    let emptyRowContent: (HomeTaskListEmptyState) -> EmptyRowContent
    let rowContent: (HomeFeature.RoutineDisplay, Int, Bool, HomeTaskListMoveContext?) -> RowContent
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

    init(
        presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        selectedTaskID: Binding<UUID?>,
        isCompactHeaderHidden: Bool,
        hasActiveOptionalFilters: Bool,
        isTaskSearchActive: Bool,
        @ViewBuilder headerContent: @escaping () -> HeaderContent,
        @ViewBuilder emptyRowContent: @escaping (HomeTaskListEmptyState) -> EmptyRowContent,
        @ViewBuilder rowContent: @escaping (HomeFeature.RoutineDisplay, Int, Bool, HomeTaskListMoveContext?) -> RowContent,
        onDelete: @escaping (IndexSet, [HomeFeature.RoutineDisplay]) -> Void,
        onScroll: @escaping (CGFloat, CGFloat) -> Void,
        @ViewBuilder destinationContent: @escaping (UUID) -> DestinationContent
    ) {
        self.presentation = presentation
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
        let visibleOffsets = visibleRowNumberOffsets

        return List(selection: selectedTaskID) {
            ForEach(presentation.sections) { section in
                Section {
                    if isSectionExpanded(section) {
                        ForEach(section.taskGroups) { group in
                            if let title = group.title {
                                taskGroupHeader(for: group, title: title)
                            }

                            if isTaskGroupExpanded(group) {
                                ForEach(group.tasks, id: \.taskID) { task in
                                    rowContent(
                                        task,
                                        visibleRowNumber(
                                            for: task,
                                            in: group,
                                            section: section,
                                            visibleOffsets: visibleOffsets
                                        ),
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
                    sectionHeader(for: section)
                }
            }
        }
        .listStyle(.sidebar)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
        } action: { oldOffset, newOffset in
            onScroll(oldOffset, newOffset)
        }
        .navigationDestination(for: UUID.self) { taskID in
            destinationContent(taskID)
        }
    }

    @ViewBuilder
    private func taskGroupHeader(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        title: String
    ) -> some View {
        if group.isCollapsible {
            let isExpanded = isTaskGroupExpanded(group)
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
    private func sectionHeader(for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>) -> some View {
        if section.kind.isCollapsible {
            Button {
                toggleSection(section)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(isSectionExpanded(section) ? 90 : 0))

                    Text(section.title)

                    Text("\(section.tasks.count)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(section.title)
            .accessibilityValue(isSectionExpanded(section) ? "Expanded" : "Collapsed")
        } else {
            Text(section.title)
        }
    }

    private func isSectionExpanded(_ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>) -> Bool {
        switch section.kind {
        case .plannedToday, .plannedTomorrow, .custom:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .daily:
            return !isDailyRoutinesSectionCollapsed
        case .future:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .tag, .untagged:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .archived:
            return !isArchivedSectionCollapsed
        case .pinned, .regular, .deadlineDate, .away:
            return true
        }
    }

    private func toggleSection(_ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>) {
        guard section.kind.isCollapsible else { return }
        withAnimation(.snappy(duration: 0.2)) {
            switch section.kind {
            case .plannedToday, .plannedTomorrow, .custom:
                setTagTaskListSection(section, collapsed: isSectionExpanded(section))
            case .daily:
                isDailyRoutinesSectionCollapsed.toggle()
            case .future:
                setTagTaskListSection(section, collapsed: isSectionExpanded(section))
            case .tag, .untagged:
                setTagTaskListSection(section, collapsed: isSectionExpanded(section))
            case .archived:
                isArchivedSectionCollapsed.toggle()
            case .pinned, .regular, .deadlineDate, .away:
                break
            }
        }
    }

    private var visibleRowNumberOffsets: [String: Int] {
        var offsets: [String: Int] = [:]
        var offset = 0
        for section in presentation.sections {
            offsets[section.id] = offset
            if isSectionExpanded(section) {
                offset += section.taskGroups.reduce(into: 0) { count, group in
                    if isTaskGroupExpanded(group) {
                        count += group.tasks.count
                    }
                }
            }
        }
        return offsets
    }

    private func visibleRowNumber(
        for task: HomeFeature.RoutineDisplay,
        in group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        visibleOffsets: [String: Int]
    ) -> Int {
        let sectionOffset = visibleOffsets[section.id] ?? 0
        let groupOffset = section.taskGroups
            .prefix { $0.id != group.id }
            .reduce(into: 0) { count, precedingGroup in
                if isTaskGroupExpanded(precedingGroup) {
                    count += precedingGroup.tasks.count
                }
            }
        let taskIndex = group.taskIndex(for: task.taskID) ?? 0
        return sectionOffset + groupOffset + taskIndex + 1
    }

    private func isTaskGroupExpanded(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Bool {
        guard group.isCollapsible else { return true }
        if isTaskSearchActive {
            return true
        }
        if group.isCollapsedByDefault {
            return collapsedTagTaskListSectionIDs.contains(taskListGroupExpandedOverrideID(group))
        }
        return !collapsedTagTaskListSectionIDs.contains(taskListGroupCollapseID(group))
    }

    private func toggleTaskGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) {
        guard group.isCollapsible else { return }
        withAnimation(.snappy(duration: 0.2)) {
            if group.isCollapsedByDefault {
                setDefaultCollapsedTaskListGroup(group, expanded: !isTaskGroupExpanded(group))
            } else {
                setTaskListGroup(group, collapsed: isTaskGroupExpanded(group))
            }
        }
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
