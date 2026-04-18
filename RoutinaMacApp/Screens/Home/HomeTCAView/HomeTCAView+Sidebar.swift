import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var isMacTimelineMode: Bool { store.macSidebarMode == .timeline }
    var isMacStatsMode: Bool    { store.macSidebarMode == .stats }
    var isMacSettingsMode: Bool { store.macSidebarMode == .settings }
    var isMacRoutinesMode: Bool { store.macSidebarMode == .routines }
    var isMacAddTaskMode: Bool  { store.macSidebarMode == .addTask }

    var macSidebarNavigationTitle: String {
        if store.isMacFilterDetailPresented {
            switch store.macSidebarMode {
            case .routines:
                switch store.taskListMode {
                case .all:
                    return "Filter All"
                case .routines:
                    return "Filter Routines"
                case .todos:
                    return "Filter Todos"
                }
            case .timeline:
                return "Filter Dones"
            case .stats:
                return "Stats"
            case .settings:
                return "Settings"
            case .addTask:
                return "Add Task"
            }
        }

        switch store.macSidebarMode {
        case .routines:
            switch store.taskListMode {
            case .all:
                return "All"
            case .routines:
                return "Routines"
            case .todos:
                return "Todos"
            }
        case .timeline:
            return "Dones"
        case .stats:
            return "Stats"
        case .settings:
            return "Settings"
        case .addTask:
            return "Add Task"
        }
    }

    var currentSelectedSettingsSection: SettingsMacSection {
        store.selectedSettingsSection ?? .notifications
    }

    var macHasCustomFiltersApplied: Bool {
        if store.macSidebarMode == .timeline {
            return store.selectedTimelineRange != .all
                || store.selectedTimelineFilterType != .all
                || store.selectedTimelineTag != nil
                || store.selectedTimelineImportanceUrgencyFilter != nil
                || !store.selectedTimelineExcludedTags.isEmpty
        }
        if store.macSidebarMode == .stats { return false }
        return store.selectedFilter != .all || hasActiveOptionalFilters
    }

    var macExcludeTagsForCurrentMode: Binding<Set<String>> {
        Binding(
            get: { store.excludedTags },
            set: { store.send(.excludedTagsChanged($0)) }
        )
    }

    var macActiveTaskFiltersSummary: String? {
        let summary = summarizedFilterLabels(from: taskFilterLabels, maxVisibleCount: 4)
        return summaryWithResultCount(summary, resultCount: macVisibleTaskResultCount)
    }

    var macSidebarSearchFiltersSummary: String? {
        isMacTimelineMode ? macActiveTimelineFiltersSummary : macActiveTaskFiltersSummary
    }

    private var taskFilterLabels: [String] {
        var labels: [String] = []

        if store.selectedFilter != .all {
            labels.append(store.selectedFilter.rawValue)
        }

        if let todoState = store.selectedTodoStateFilter {
            labels.append(todoState.displayTitle)
        }

        if let selectedTag = store.selectedTag {
            labels.append("#\(selectedTag)")
        }

        if !store.excludedTags.isEmpty {
            if store.excludedTags.count == 1, let tag = store.excludedTags.first {
                labels.append("not #\(tag)")
            } else {
                labels.append("not \(store.excludedTags.count) tags")
            }
        }

        if let selectedPlaceName {
            labels.append(selectedPlaceName)
        }

        if let selectedImportanceUrgencyFilterLabel {
            labels.append(selectedImportanceUrgencyFilterLabel)
        }

        if store.hideUnavailableRoutines {
            labels.append("Away hidden")
        }

        return labels
    }

    var macVisibleTaskResultCount: Int {
        let pinnedTasks = filteredPinnedTasks(
            activeRoutineDisplays: store.routineDisplays,
            awayRoutineDisplays: store.awayRoutineDisplays,
            archivedRoutineDisplays: store.archivedRoutineDisplays
        )
        let sections = groupedRoutineSections(
            from: (store.routineDisplays + store.awayRoutineDisplays).filter { !$0.isPinned }
        )
        let archivedTasks = filteredArchivedTasks(store.archivedRoutineDisplays, includePinned: false)

        return pinnedTasks.count
            + sections.reduce(0) { $0 + $1.tasks.count }
            + archivedTasks.count
    }

    func summarizedFilterLabels(from labels: [String], maxVisibleCount: Int) -> String {
        guard !labels.isEmpty else { return "" }
        let visibleLabels = Array(labels.prefix(maxVisibleCount))
        let remainderCount = labels.count - visibleLabels.count
        let baseSummary = visibleLabels.joined(separator: " • ")
        guard remainderCount > 0 else { return baseSummary }
        return "\(baseSummary) +\(remainderCount)"
    }

    func summaryWithResultCount(_ summary: String, resultCount: Int) -> String? {
        guard !summary.isEmpty else { return nil }
        let resultLabel = resultCount == 1 ? "1 result" : "\(resultCount) results"
        return "\(summary) • \(resultLabel)"
    }

    func clearAllMacFilters() {
        if store.macSidebarMode == .timeline {
            store.send(.selectedTimelineRangeChanged(.all))
            store.send(.selectedTimelineFilterTypeChanged(.all))
            store.send(.selectedTimelineTagChanged(nil))
            store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
            store.send(.selectedTimelineExcludedTagsChanged([]))
        } else {
            store.send(.selectedFilterChanged(.all))
            store.send(.clearOptionalFilters)
        }
    }

    var macSidebarModeBinding: Binding<MacSidebarMode> {
        Binding(
            get: { store.macSidebarMode },
            set: { mode in
                switch mode {
                case .routines:  showRoutinesInSidebar()
                case .timeline:  openTimelineInSidebar()
                case .stats:     openStatsInSidebar()
                case .settings:  openSettingsInSidebar()
                case .addTask:   openAddTask()
                }
            }
        )
    }

    var macSidebarSelectionBinding: Binding<MacSidebarSelection?> {
        Binding(
            get: { store.macSidebarSelection },
            set: { selection in
                switch selection {
                case let .task(taskID):
                    store.send(.macSidebarSelectionChanged(.task(taskID)))
                case let .timelineEntry(entryID):
                    store.send(.macSidebarSelectionChanged(.timelineEntry(entryID)))
                    let taskID = timelineEntries.first(where: { $0.id == entryID })?.taskID
                    store.send(.setSelectedTask(taskID))
                case nil:
                    store.send(.macSidebarSelectionChanged(nil))
                }
            }
        )
    }

    func showRoutinesInSidebar() {
        store.send(.macSidebarModeChanged(.routines))
    }

    func openStatsInSidebar() {
        store.send(.macSidebarModeChanged(.stats))
    }

    func openSettingsInSidebar() {
        store.send(.macSidebarModeChanged(.settings))
        settingsStore.send(.onAppear)
    }

    func openSettingsPlacesInSidebar() {
        store.send(.selectedSettingsSectionChanged(.places))
        store.send(.macSidebarModeChanged(.settings))
        settingsStore.send(.onAppear)
    }

    @ViewBuilder
    var macSidebarContent: some View {
        Group {
            if isMacAddTaskMode || store.taskDetailState?.isEditSheetPresented == true {
                macFormSectionNav
            } else if isMacRoutinesMode && store.routineTasks.isEmpty {
                VStack(spacing: 0) {
                    macSidebarHeader
                    Divider()
                    emptyStateView(
                        title: "No tasks yet",
                        message: "Add a routine or to-do, and the sidebar will organize what needs attention for you.",
                        systemImage: "checklist"
                    ) {
                        openAddTask()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 0) {
                    macSidebarHeader

                    Divider()

                    if isMacTimelineMode {
                        macTimelineSidebarView
                    } else if isMacStatsMode {
                        macStatsSidebarView
                    } else if isMacSettingsMode {
                        macSettingsSidebarView
                    } else {
                        listOfSortedTasksView(
                            routineDisplays: store.routineDisplays,
                            awayRoutineDisplays: store.awayRoutineDisplays,
                            archivedRoutineDisplays: store.archivedRoutineDisplays
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Routina")
        .toolbar { homeToolbarContent }
        .routinaHomeSidebarColumnWidth()
    }

    var macFormSectionNav: some View {
        let isAdding = isMacAddTaskMode
        let available = isAdding ? macAddFormSections : macEditFormSections
        return HomeMacFormSectionNavView(
            availableSections: available,
            coordinator: addEditFormCoordinator,
            draggedSection: $draggedSection
        ) {
            macSidebarHeader
        }
    }

    var macAddFormSections: [String] {
        let scheduleMode = store.addRoutineState?.schedule.scheduleMode ?? .fixedInterval
        let isStepBased = scheduleMode == .fixedInterval || scheduleMode == .oneOff
        var sections = ["Identity", "Behavior", "Places", "Importance & Urgency", "Tags", "Linked tasks", "Link URL", "Notes"]
        if isStepBased { sections.append("Steps") }
        sections.append("Image")
        sections.append("Attachment")
        return sections
    }

    var macEditFormSections: [String] {
        guard let detail = store.taskDetailState else { return [] }
        let scheduleMode = detail.editScheduleMode
        var sections = ["Identity", "Behavior", "Places", "Importance & Urgency", "Tags", "Linked tasks", "Link URL", "Notes"]
        if scheduleMode == .fixedInterval || scheduleMode == .oneOff {
            sections.append("Steps")
        }
        sections.append("Image")
        sections.append("Attachment")
        sections.append("Danger Zone")
        return sections
    }

    var macSidebarHeader: some View {
        HomeMacSidebarHeaderView(
            selectedSidebarMode: macSidebarModeBinding,
            selectedTaskListMode: store.taskListMode,
            isRoutinesMode: isMacRoutinesMode,
            isTimelineMode: isMacTimelineMode,
            onSelectTaskListMode: { mode in
                store.send(.taskListModeChanged(mode))
            }
        ) {
            macSearchPanel
        }
    }

    var emptyTaskListTitle: String {
        switch store.taskListMode {
        case .all:
            return "No matching tasks"
        case .routines:
            return "No matching routines"
        case .todos:
            return "No matching todos"
        }
    }

    var emptyTaskListMessage: String {
        switch store.taskListMode {
        case .all:
            return "Try a different place or clear a few filters."
        case .routines:
            return "Try a different place or switch back to all routines."
        case .todos:
            return "Try a different place or switch back to all todos."
        }
    }

    var macSearchPanel: some View {
        HomeMacSearchPanelView(
            hasCustomFiltersApplied: macHasCustomFiltersApplied,
            activeFiltersSummary: macSidebarSearchFiltersSummary,
            isFilterDetailPresented: store.isMacFilterDetailPresented,
            onToggleFilters: {
                store.send(.setMacFilterDetailPresented(!store.isMacFilterDetailPresented))
            },
            onClearFilters: {
                clearAllMacFilters()
            }
        ) {
            platformSearchField(searchText: searchTextBinding)
        }
    }

    @ViewBuilder
    var macActiveFiltersDetailView: some View {
        if isMacTimelineMode {
            macTimelineFiltersDetailView
        } else {
            macFiltersDetailView
        }
    }

    var macFiltersDetailView: some View {
        HomeMacFilterDetailContainerView(
        ) {
            HomeMacRoutineFiltersDetailView(
                availableFilters: macAvailableFilters,
                selectedFilter: Binding(
                    get: { store.selectedFilter },
                    set: { store.send(.selectedFilterChanged($0)) }
                ),
                selectedImportanceUrgencyFilter: Binding(
                    get: { store.selectedImportanceUrgencyFilter },
                    set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
                ),
                importanceUrgencySummary: importanceUrgencyFilterSummary,
                showsTagSection: !availableTags.isEmpty,
                showsPlaceSection: hasPlaceAwareContent
            ) {
                tagFilterBar
            } placeSectionContent: {
                MacPlaceFilterPanel(
                    options: macPlaceFilterOptions,
                    selectedPlaceID: manualPlaceFilterBinding,
                    hideUnavailableRoutines: hideUnavailableRoutinesBinding,
                    showAvailabilityToggle: hasPlaceLinkedRoutines && store.locationSnapshot.authorizationStatus.isAuthorized,
                    currentLocation: store.locationSnapshot.coordinate,
                    manualPlaceFilterDescription: manualPlaceFilterDescription,
                    locationStatusText: hasPlaceLinkedRoutines ? locationStatusText : nil,
                    onManagePlaces: { openSettingsPlacesInSidebar() }
                )
            }

            if store.taskListMode == .todos || store.taskListMode == .all {
                HomeMacSidebarSectionCard(title: "Todo State") {
                    macTodoStateFilterSection
                }
            }
        }
    }

    private var macTodoStateFilterSection: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            Button {
                store.send(.selectedTodoStateFilterChanged(nil))
            } label: {
                Text("Any State")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .foregroundStyle(store.selectedTodoStateFilter == nil ? Color.white : Color.primary)
                    .background(
                        Capsule()
                            .fill(store.selectedTodoStateFilter == nil ? Color.accentColor : Color.secondary.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)

            ForEach(TodoState.filterableCases) { todoState in
                Button {
                    store.send(.selectedTodoStateFilterChanged(
                        store.selectedTodoStateFilter == todoState ? nil : todoState
                    ))
                } label: {
                    Text(todoState.displayTitle)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(store.selectedTodoStateFilter == todoState ? Color.white : Color.primary)
                        .background(
                            Capsule()
                                .fill(store.selectedTodoStateFilter == todoState ? Color.accentColor : Color.secondary.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var macSettingsSidebarView: some View {
        HomeMacSettingsSidebarView(
            store: settingsStore,
            selectedSection: currentSelectedSettingsSection,
            onSelectSection: { section in
                store.send(.selectedSettingsSectionChanged(section))
            }
        )
    }
}
