import SwiftUI

struct HomeIOSTaskListView<HeaderContent: View, EmptyRowContent: View, RowContent: View, DestinationContent: View>: View {
    let presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    let selectedTaskID: Binding<UUID?>
    let isCompactHeaderHidden: Bool
    let hasActiveOptionalFilters: Bool
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
        List(selection: selectedTaskID) {
            ForEach(presentation.sections) { section in
                Section {
                    if isSectionExpanded(section) {
                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                            rowContent(
                                task,
                                visibleRowNumber(for: section, taskIndex: index),
                                section.includeMarkDone,
                                section.moveContext
                            )
                        }
                        .onDelete { offsets in
                            onDelete(offsets, section.tasks)
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
                        .foregroundStyle(.tertiary)
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
        case .daily:
            return !isDailyRoutinesSectionCollapsed
        case .tag, .untagged:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .archived:
            return !isArchivedSectionCollapsed
        case .pinned, .regular, .away:
            return true
        }
    }

    private func toggleSection(_ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>) {
        guard section.kind.isCollapsible else { return }
        withAnimation(.snappy(duration: 0.2)) {
            switch section.kind {
            case .daily:
                isDailyRoutinesSectionCollapsed.toggle()
            case .tag, .untagged:
                setTagTaskListSection(section, collapsed: isSectionExpanded(section))
            case .archived:
                isArchivedSectionCollapsed.toggle()
            case .pinned, .regular, .away:
                break
            }
        }
    }

    private func visibleRowNumber(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        taskIndex: Int
    ) -> Int {
        var offset = 0
        for currentSection in presentation.sections {
            if currentSection.id == section.id {
                return offset + taskIndex + 1
            }
            if isSectionExpanded(currentSection) {
                offset += currentSection.tasks.count
            }
        }
        return taskIndex + 1
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
}
