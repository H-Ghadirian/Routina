import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var isMacTimelineMode: Bool { store.macSidebarMode == .timeline }
    var isMacStatsMode: Bool { store.macSidebarMode == .stats }
    var isMacSettingsMode: Bool { store.macSidebarMode == .settings }
    var isMacRoutinesMode: Bool { store.macSidebarMode == .routines }
    var isMacBoardMode: Bool { store.macSidebarMode == .board }
    var isMacGoalsMode: Bool { store.macSidebarMode == .goals }
    var isMacAddTaskMode: Bool { store.macSidebarMode == .addTask }

    var macSidebarNavigationTitle: String {
        if store.isMacFilterDetailPresented {
            return macFilterDetailNavigationTitle
        }

        switch store.macSidebarMode {
        case .routines:
            return macTaskListSidebarTitle
        case .board:
            return boardPresentation.scopeTitle
        case .goals:
            return "Goals"
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

    private var macTaskListSidebarTitle: String {
        switch store.taskListMode {
        case .all:
            return "All"
        case .routines:
            return "Routines"
        case .todos:
            return "Todos"
        }
    }

    private var macTaskListFilterTitle: String {
        switch store.taskListMode {
        case .all:
            return "Filter All"
        case .routines:
            return "Filter Routines"
        case .todos:
            return "Filter Todos"
        }
    }

    private var macFilterDetailNavigationTitle: String {
        switch store.macSidebarMode {
        case .routines:
            return macTaskListFilterTitle
        case .board:
            return "Filter Board"
        case .goals:
            return "Goals"
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

    var currentSelectedSettingsSection: SettingsMacSection {
        store.selectedSettingsSection ?? .notifications
    }

    var macHasCustomFiltersApplied: Bool {
        switch store.macSidebarMode {
        case .timeline:
            return store.selectedTimelineRange != .all
                || store.selectedTimelineFilterType != .all
                || !store.selectedTimelineTags.isEmpty
                || store.selectedTimelineImportanceUrgencyFilter != nil
                || !store.selectedTimelineExcludedTags.isEmpty
        case .routines, .board:
            return store.selectedFilter != .all || hasActiveOptionalFilters
        case .goals, .stats, .settings, .addTask:
            return false
        }
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
        switch store.macSidebarMode {
        case .timeline:
            macActiveTimelineFiltersSummary
        case .routines, .board:
            macActiveTaskFiltersSummary
        case .goals, .stats, .settings, .addTask:
            nil
        }
    }

    var macVisibleTaskResultCount: Int {
        macTaskListPresentation(
            routineDisplays: store.routineDisplays,
            awayRoutineDisplays: store.awayRoutineDisplays,
            archivedRoutineDisplays: store.archivedRoutineDisplays
        ).visibleTaskCount
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
                case .goals:     openGoalsInSidebar()
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

    func openGoalsInSidebar() {
        store.send(.macSidebarModeChanged(.goals))
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

    func focusMacSidebarOnDayPlanUnplannedCompletedTasks(on date: Date) {
        dayPlanUnplannedCompletedFilterDate = calendar.startOfDay(for: date)
        macHomeDetailMode = .planner
        store.send(.macSidebarModeChanged(.routines))
        store.send(.setMacFilterDetailPresented(false))
    }

    func clearDayPlanUnplannedCompletedFilter() {
        dayPlanUnplannedCompletedFilterDate = nil
        dayPlanPlanner.clearFocusedUnplannedCompletedTasks()
    }

    func openDayPlanTaskDetails(_ taskID: UUID) {
        if shouldShowTaskInRegularSidebar(taskID) {
            clearDayPlanUnplannedCompletedFilter()
        }
        macHomeDetailMode = .details
        macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(taskID: taskID)
        store.send(.macSidebarSelectionChanged(.task(taskID)))
    }

    private func shouldShowTaskInRegularSidebar(_ taskID: UUID) -> Bool {
        guard let task = store.routineTasks.first(where: { $0.id == taskID }) else { return true }
        return !task.isCompletedOneOff && !task.isCanceledOneOff
    }

    func dayPlanUnplannedCompletedDisplays(for date: Date) -> [HomeFeature.RoutineDisplay] {
        let displays = uniqueDayPlanCandidateDisplays
        let plannedBlocks = dayPlanPlanner.blocks(on: date, calendar: calendar, context: modelContext)
        let matchingIDs = DayPlanUnplannedCompletedTasks.taskIDs(
            on: date,
            taskIDs: displays.map(\.taskID),
            lastDoneForTaskID: Dictionary(uniqueKeysWithValues: displays.map { ($0.taskID, $0.lastDone) }),
            logs: store.timelineLogs,
            plannedBlocks: plannedBlocks,
            calendar: calendar
        )

        return displays
            .filter { matchingIDs.contains($0.taskID) && !$0.isCanceledOneOff }
            .sorted { lhs, rhs in
                let lhsDate = latestCompletionDate(for: lhs.taskID, fallbackLastDone: lhs.lastDone, on: date) ?? .distantPast
                let rhsDate = latestCompletionDate(for: rhs.taskID, fallbackLastDone: rhs.lastDone, on: date) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func dayPlanUnplannedCompletedFilterTitle(for date: Date) -> String {
        let dateText: String
        if calendar.isDateInToday(date) {
            dateText = "today"
        } else if calendar.isDateInYesterday(date) {
            dateText = "yesterday"
        } else {
            dateText = date.formatted(date: .abbreviated, time: .omitted)
        }
        return "Done \(dateText) · Not in planner"
    }

    private var uniqueDayPlanCandidateDisplays: [HomeFeature.RoutineDisplay] {
        var seenIDs = Set<UUID>()
        return (store.routineDisplays + store.awayRoutineDisplays + store.archivedRoutineDisplays + store.boardTodoDisplays)
            .filter { display in
                guard !seenIDs.contains(display.taskID) else { return false }
                seenIDs.insert(display.taskID)
                return true
            }
    }

    private func latestCompletionDate(
        for taskID: UUID,
        fallbackLastDone: Date?,
        on date: Date
    ) -> Date? {
        let logDate = store.timelineLogs
            .filter { log in
                guard log.taskID == taskID,
                      log.kind == .completed,
                      let timestamp = log.timestamp
                else { return false }
                return calendar.isDate(timestamp, inSameDayAs: date)
            }
            .compactMap(\.timestamp)
            .max()

        guard let fallbackLastDone,
              calendar.isDate(fallbackLastDone, inSameDayAs: date)
        else {
            return logDate
        }

        return max(logDate ?? fallbackLastDone, fallbackLastDone)
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
                    } else if isMacGoalsMode {
                        MacGoalsSidebarView(store: goalsStore)
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
        return FormSection.taskFormSections(
            scheduleMode: scheduleMode,
            includesIdentity: true,
            includesDangerZone: false
        )
    }

    var macEditFormSections: [FormSection] {
        guard let detail = store.taskDetailState else { return [] }
        return FormSection.taskFormSections(
            scheduleMode: detail.editScheduleMode,
            includesIdentity: true,
            includesDangerZone: true
        )
    }

    var macSidebarHeader: some View {
        HomeMacSidebarHeaderView(
            selectedSidebarMode: macSidebarModeBinding,
            selectedTaskListMode: store.taskListMode,
            isRoutinesMode: isMacRoutinesMode,
            isBoardMode: isMacBoardMode,
            isGoalsMode: isMacGoalsMode,
            isTimelineMode: isMacTimelineMode,
            onSelectTaskListMode: { mode in
                store.send(.taskListModeChanged(mode))
            }
        ) {
            if isMacGoalsMode {
                platformSearchField(searchText: goalsSearchTextBinding)
            } else {
                macSearchPanel
            }
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

    var goalsSearchTextBinding: Binding<String> {
        Binding(
            get: { goalsStore.searchText },
            set: { goalsStore.send(.searchTextChanged($0)) }
        )
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
                advancedQuery: homeFilterBindings.advancedQuery,
                taskListViewMode: homeFilterBindings.taskListViewMode,
                taskListSortOrder: homeFilterBindings.taskListSortOrder,
                createdDateFilter: homeFilterBindings.createdDateFilter,
                showArchivedTasks: homeFilterBindings.showArchivedTasks,
                selectedImportanceUrgencyFilter: homeFilterBindings.selectedImportanceUrgencyFilter,
                selectedPressureFilter: homeFilterBindings.selectedPressureFilter,
                queryOptions: HomeAdvancedQueryOptions(
                    tags: homeTagFilterData.tagSummaries.map(\.name),
                    places: sortedRoutinePlaces.map(\.displayName)
                ),
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
