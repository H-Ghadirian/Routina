import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var isMacTimelineMode: Bool { store.macSidebarMode == .timeline }
    var isMacStatsMode: Bool    { store.macSidebarMode == .stats }
    var isMacSettingsMode: Bool { store.macSidebarMode == .settings }
    var isMacRoutinesMode: Bool { store.macSidebarMode == .routines }
    var isMacBoardMode: Bool    { store.macSidebarMode == .board }
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
            case .board:
                return "Filter Board"
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
        case .board:
            return boardScopeTitle
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
                || !store.selectedTimelineTags.isEmpty
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
        homeFilterPresentation.activeTaskFiltersSummary(resultCount: macVisibleTaskResultCount, maxVisibleCount: 4)
    }

    var macSidebarSearchFiltersSummary: String? {
        isMacTimelineMode ? macActiveTimelineFiltersSummary : macActiveTaskFiltersSummary
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
        HomeFilterPresentation.summarizedFilterLabels(from: labels, maxVisibleCount: maxVisibleCount)
    }

    func summaryWithResultCount(_ summary: String, resultCount: Int) -> String? {
        HomeFilterPresentation.summaryWithResultCount(summary, resultCount: resultCount)
    }

    func clearAllMacFilters() {
        if store.macSidebarMode == .timeline {
            store.send(.selectedTimelineRangeChanged(.all))
            store.send(.selectedTimelineFilterTypeChanged(.all))
            store.send(.selectedTimelineTagsChanged([]))
            store.send(.selectedTimelineIncludeTagMatchModeChanged(.all))
            store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
            store.send(.selectedTimelineExcludedTagsChanged([]))
            store.send(.selectedTimelineExcludeTagMatchModeChanged(.any))
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
                case .board:     openBoardInSidebar()
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

    func openBoardInSidebar() {
        store.send(.macSidebarModeChanged(.board))
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
            } else if isMacBoardMode && !store.routineTasks.contains(where: \.isOneOffTask) {
                VStack(spacing: 0) {
                    macSidebarHeader
                    Divider()
                    emptyStateView(
                        title: "No todos yet",
                        message: "Add a to-do, and the board will group it by workflow state here.",
                        systemImage: "square.grid.3x3.topleft.filled"
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
                    } else if isMacBoardMode {
                        macBoardSidebarView
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

    var macAddFormSections: [FormSection] {
        let scheduleMode = store.addRoutineState?.schedule.scheduleMode ?? .fixedInterval
        let isStepBased = scheduleMode == .fixedInterval || scheduleMode == .softInterval || scheduleMode == .oneOff
        var sections: [FormSection] = [.identity, .color, .behavior, .pressure, .estimation, .places, .importanceUrgency, .tags, .linkedTasks, .linkURL, .notes]
        if isStepBased { sections.append(.steps) }
        sections.append(.image)
        sections.append(.attachment)
        return sections
    }

    var macEditFormSections: [FormSection] {
        guard let detail = store.taskDetailState else { return [] }
        let scheduleMode = detail.editScheduleMode
        var sections: [FormSection] = [.identity, .color, .behavior, .pressure, .estimation, .places, .importanceUrgency, .tags, .linkedTasks, .linkURL, .notes]
        if scheduleMode == .fixedInterval || scheduleMode == .softInterval || scheduleMode == .oneOff {
            sections.append(.steps)
        }
        sections.append(.image)
        sections.append(.attachment)
        sections.append(.dangerZone)
        return sections
    }

    var macSidebarHeader: some View {
        HomeMacSidebarHeaderView(
            selectedSidebarMode: macSidebarModeBinding,
            selectedTaskListMode: store.taskListMode,
            isRoutinesMode: isMacRoutinesMode,
            isBoardMode: isMacBoardMode,
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
                selectedFilter: homeFilterBindings.selectedFilter,
                taskListViewMode: homeFilterBindings.taskListViewMode,
                selectedImportanceUrgencyFilter: homeFilterBindings.selectedImportanceUrgencyFilter,
                importanceUrgencySummary: importanceUrgencyFilterSummary,
                showsTagSection: homeTagFilterData.hasTags,
                showsPlaceSection: hasPlaceAwareContent
            ) {
                tagFilterBar
            } placeSectionContent: {
                MacPlaceFilterPanel(
                    options: macPlaceFilterOptions,
                    selectedPlaceID: homeFilterBindings.selectedPlaceID,
                    hideUnavailableRoutines: homeFilterBindings.hideUnavailableRoutines,
                    showAvailabilityToggle: hasPlaceLinkedRoutines && store.locationSnapshot.authorizationStatus.isAuthorized,
                    currentLocation: store.locationSnapshot.coordinate,
                    taskListMode: store.taskListMode,
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
        HomeTodoStateFilterChips(
            selectedTodoStateFilter: homeFilterBindings.selectedTodoStateFilter,
            layoutStyle: .adaptiveGrid(minimumWidth: 80, spacing: 8),
            selectedForegroundColor: .white,
            unselectedForegroundColor: .primary,
            selectedBackgroundOpacity: 1,
            fillsAvailableWidth: true,
            verticalPadding: 8
        )
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
