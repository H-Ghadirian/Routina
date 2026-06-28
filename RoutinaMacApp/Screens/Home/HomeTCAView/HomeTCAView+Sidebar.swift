import ComposableArchitecture
import SwiftUI

enum MacTaskDetailPresentation {
    case fullDetail
    case listSelection
    case plannerPane
}

extension HomeTCAView {
    var isMacTimelineMode: Bool { visibleMacSidebarMode == .timeline }
    var isMacStatsMode: Bool { visibleMacSidebarMode == .stats || visibleMacSidebarMode == .adventure }
    var isMacSettingsMode: Bool { visibleMacSidebarMode == .settings }
    var isMacRoutinesMode: Bool { visibleMacSidebarMode == .routines }
    var isMacBoardMode: Bool { visibleMacSidebarMode == .board }
    var isMacGoalsMode: Bool { visibleMacSidebarMode == .goals }
    var isMacAdventureMode: Bool { visibleMacSidebarMode == .adventure }
    var isMacAddTaskMode: Bool { visibleMacSidebarMode == .addTask }
    var isMacSegmentedBoardMode: Bool { isMacRoutinesMode && macHomeDetailMode.visibleSurfaceMode == .board }
    var isMacBoardSidebarPresented: Bool { isMacBoardMode || isMacSegmentedBoardMode }
    var shouldHideMacSidebarHeaderForDayPlanTimelineFilter: Bool {
        dayPlanUnplannedCompletedFilterDate != nil && macHomeDetailMode == .planner
    }

    var macSidebarNavigationTitle: String {
        if store.isMacFilterDetailPresented {
            return macFilterDetailTitle
        }

        if isMacSegmentedBoardMode {
            return boardPresentation.scopeTitle
        }

        switch visibleMacSidebarMode {
        case .routines:
            return macTaskListSidebarTitle
        case .board:
            return boardPresentation.scopeTitle
        case .goals:
            return "Goals"
        case .adventure:
            return "Stats"
        case .timeline:
            return "Timeline"
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
            return "Tasks"
        case .todos:
            return "Todos"
        }
    }

    private var macTaskListFilterTitle: String {
        switch store.taskListMode {
        case .all:
            return "Filter All"
        case .routines:
            return "Filter Tasks"
        case .todos:
            return "Filter Todos"
        }
    }

    var macFilterDetailTitle: String {
        if isMacSegmentedBoardMode {
            return "Filter Board"
        }

        switch visibleMacSidebarMode {
        case .routines:
            return macTaskListFilterTitle
        case .board:
            return "Filter Board"
        case .goals:
            return "Goals"
        case .adventure:
            return "Stats"
        case .timeline:
            return "Filter Timeline"
        case .stats:
            return "Stats"
        case .settings:
            return "Settings"
        case .addTask:
            return "Add Task"
        }
    }

    var currentSelectedSettingsSection: SettingsMacSection {
        let visibleSections = SettingsMacSection.visibleSections(
            isGitFeaturesEnabled: settingsStore.appearance.isGitFeaturesEnabled,
            isDevicesSectionEnabled: isSettingsDevicesSectionEnabled,
            isPlacesEnabled: isPlacesEnabled
        )
        let candidate = store.selectedSettingsSection ?? .notifications
        let resolvedSection = candidate.resolvedNavigationSection
        guard visibleSections.contains(resolvedSection) else { return .general }
        return resolvedSection
    }

    var macHasCustomFiltersApplied: Bool {
        switch visibleMacSidebarMode {
        case .timeline:
            return store.selectedTimelineRange != .all
                || store.selectedTimelineFilterType != .all
                || !store.selectedTimelineTags.isEmpty
                || store.selectedTimelineImportanceUrgencyFilter != nil
                || store.selectedTimelineMediaFilter != .all
                || !store.selectedTimelineExcludedTags.isEmpty
        case .routines, .board:
            return store.taskListMode != .all
                || store.selectedFilter != .all
                || macHomeFilterPresentation.hasActiveOptionalFilters
        case .goals, .adventure, .stats, .settings, .addTask:
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
        macHomeFilterPresentation.activeTaskFiltersSummary(resultCount: macVisibleTaskResultCount, maxVisibleCount: 4)
    }

    var macHomeFilterPresentation: HomeFilterPresentation {
        HomeFilterPresentation(
            taskListKind: store.taskListMode.filterTaskListKind,
            selectedFilter: store.selectedFilter,
            advancedQuery: store.advancedQuery,
            taskListViewMode: store.taskListViewMode,
            taskListSortOrder: store.taskListSortOrder,
            createdDateFilter: store.createdDateFilter,
            selectedTodoStateFilter: store.selectedTodoStateFilter,
            selectedTags: store.selectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            excludedTags: store.excludedTags,
            selectedPlaceName: isPlacesEnabled ? selectedPlaceName : nil,
            hasSelectedPlaceFilter: isPlacesEnabled && store.selectedManualPlaceFilterID != nil,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            selectedPressureFilter: store.selectedPressureFilter,
            selectedGoalFilter: effectiveSelectedGoalFilter,
            selectedMediaFilter: store.selectedMediaFilter,
            hideAssumedDoneTasks: store.hideAssumedDoneTasks,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            showArchivedTasks: store.showArchivedTasks,
            hasSavedPlaces: isPlacesEnabled && hasSavedPlaces,
            awayRoutineCount: isPlacesEnabled ? store.awayRoutineDisplays.count : 0,
            locationAuthorizationStatus: store.locationSnapshot.authorizationStatus
        )
    }

    var macSidebarSearchFiltersSummary: String? {
        switch visibleMacSidebarMode {
        case .timeline:
            macActiveTimelineFiltersSummary
        case .routines, .board:
            macActiveTaskFiltersSummary
        case .goals, .adventure, .stats, .settings, .addTask:
            nil
        }
    }

    var macVisibleTaskResultCount: Int {
        taskListFiltering().sidebarVisibleTaskCount(
            activeDisplays: store.routineDisplays,
            awayDisplays: store.awayRoutineDisplays,
            archivedDisplays: store.archivedRoutineDisplays,
            showArchivedTasks: store.showArchivedTasks
        )
    }

    func summarizedFilterLabels(from labels: [String], maxVisibleCount: Int) -> String {
        HomeFilterPresentation.summarizedFilterLabels(from: labels, maxVisibleCount: maxVisibleCount)
    }

    func summaryWithResultCount(_ summary: String, resultCount: Int) -> String? {
        HomeFilterPresentation.summaryWithResultCount(summary, resultCount: resultCount)
    }

    func clearAllMacFilters() {
        if visibleMacSidebarMode == .timeline {
            store.send(.selectedTimelineRangeChanged(.all))
            store.send(.selectedTimelineFilterTypeChanged(.all))
            store.send(.selectedTimelineTagsChanged([]))
            store.send(.selectedTimelineIncludeTagMatchModeChanged(.all))
            store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
            store.send(.selectedTimelineMediaFilterChanged(.all))
            store.send(.selectedTimelineExcludedTagsChanged([]))
            store.send(.selectedTimelineExcludeTagMatchModeChanged(.any))
        } else {
            if store.taskListMode != .all {
                store.send(.taskListModeFilterChanged(.all))
            }
            store.send(.selectedFilterChanged(.all))
            store.send(.clearOptionalFilters)
        }
    }

    var macSidebarModeBinding: Binding<MacSidebarMode> {
        Binding(
            get: { visibleMacSidebarMode },
            set: { mode in
                switch resolvedMacSidebarMode(mode) {
                case .routines:  showRoutinesInSidebar()
                case .board:     openBoardInSidebar()
                case .goals:     openGoalsInSidebar()
                case .adventure: openAdventureInSidebar()
                case .timeline:  openTimelineInSidebar()
                case .stats:     openStatsInSidebar()
                case .settings:  openSettingsInSidebar()
                case .addTask:   openAddTask()
                }
            }
        )
    }

    var mainDetailModeBinding: Binding<MacHomeDetailMode> {
        Binding(
            get: { macHomeDetailMode.visibleSurfaceMode },
            set: { mode in
                let visibleMode = mode.visibleSurfaceMode
                macHomeDetailMode = visibleMode
                if visibleMode != .planner {
                    dayPlanPlanner.clearPlannerUndo()
                }
                normalizeTaskDetailPanePlacement()
                if visibleMode == .places {
                    clearDayPlanUnplannedCompletedFilter()
                }
                if visibleMode != .places {
                    placeCheckInSelectedPlaceID = nil
                    placeCheckInSelectedHistoryMarkerID = nil
                }
                if visibleMode == .board, store.taskListMode != .todos {
                    store.send(.taskListModeChanged(.todos))
                }
            }
        )
    }

    var macHomeProgressModeBinding: Binding<MacHomeProgressMode> {
        Binding(
            get: { macHomeProgressMode.visibleSurfaceMode },
            set: { mode in
                withAnimation(.easeInOut(duration: 0.18)) {
                    macHomeProgressMode = mode.visibleSurfaceMode
                }
            }
        )
    }

    func openMacPlacesWorkspace() {
        guard isPlacesEnabled else {
            mainDetailModeBinding.wrappedValue = .details
            showRoutinesInSidebar()
            return
        }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        withAnimation(.easeInOut(duration: 0.18)) {
            store.send(.setMacFilterDetailPresented(false))
            clearDayPlanUnplannedCompletedFilter()
            if visibleMacSidebarMode != .routines {
                showRoutinesInSidebar()
            }
            mainDetailModeBinding.wrappedValue = .places
        }
    }

    var macSidebarSelectionBinding: Binding<MacSidebarSelection?> {
        Binding(
            get: { store.macSidebarSelection },
            set: { selection in
                isEventEditorPresented = false
                isEmotionLogEditorPresented = false
                isNoteEditorPresented = false
                isAwayStartPresented = false
                switch selection {
                case let .task(taskID):
                    selectedNoteID = nil
                    store.send(.macSidebarSelectionChanged(.task(taskID)))
                case let .timelineEntry(entryID):
                    guard !store.isMacFilterDetailPresented || !isMacTimelineMode else {
                        return
                    }
                    store.send(.macSidebarSelectionChanged(.timelineEntry(entryID)))
                    let entry = timelineEntries.first { $0.id == entryID }
                    selectedNoteID = entry?.isNote == true ? entryID : nil
                    let taskID = entry?.taskID
                    store.send(.setSelectedTask(taskID))
                case nil:
                    guard !store.isMacFilterDetailPresented || !isMacTimelineMode else {
                        return
                    }
                    selectedNoteID = nil
                    store.send(.macSidebarSelectionChanged(nil))
                }
            }
        )
    }

    func showRoutinesInSidebar() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.macSidebarModeChanged(.routines))
    }

    func openBoardInSidebar() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.macSidebarModeChanged(.board))
    }

    func openGoalsInSidebar() {
        guard isGoalsTabEnabled else { return }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.macSidebarModeChanged(.goals))
    }

    func openAdventureInSidebar() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.macSidebarModeChanged(.adventure))
        macHomeProgressMode = .adventure
    }

    func openAddNote() {
        guard isNotesEnabled else { return }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isAwayStartPresented = false
        editingNoteID = nil
        selectedNoteID = nil
        macHomeDetailMode = .details
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        store.send(.macSidebarModeChanged(.routines))
        isNoteEditorPresented = true
    }

    func openEditNote(_ noteID: UUID) {
        guard isNotesEnabled else { return }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isAwayStartPresented = false
        editingNoteID = noteID
        selectedNoteID = noteID
        macHomeDetailMode = .details
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        isNoteEditorPresented = true
    }

    func closeAddNote() {
        isNoteEditorPresented = false
        editingNoteID = nil
    }

    func openSavedNote(_ noteID: UUID) {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        editingNoteID = nil
        selectedNoteID = noteID
        macHomeDetailMode = .details
        searchTextBinding.wrappedValue = ""
        macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: noteID)
        store.send(.openNoteDeepLink(noteID))
    }

    func closeDeletedNote(_ noteID: UUID) {
        if selectedNoteID == noteID {
            selectedNoteID = nil
        }
        if editingNoteID == noteID {
            editingNoteID = nil
            isNoteEditorPresented = false
        }
        if case .timelineEntry(noteID) = store.macSidebarSelection {
            store.send(.macSidebarSelectionChanged(nil))
        }
    }

    func openAddGoal() {
        guard isGoalsTabEnabled else { return }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.macSidebarModeChanged(.goals))
        goalsStore.send(.addGoalTapped)
    }

    func openStatsInSidebar() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        macHomeProgressMode = .stats
        store.send(.macSidebarModeChanged(.stats))
    }

    func openSettingsInSidebar() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.macSidebarModeChanged(.settings))
        settingsStore.send(.onAppear)
    }

    func openSettingsPlacesInSidebar() {
        guard isPlacesEnabled else {
            openSettingsInSidebar()
            store.send(.selectedSettingsSectionChanged(.general))
            return
        }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.selectedSettingsSectionChanged(.places))
        store.send(.macSidebarModeChanged(.settings))
        settingsStore.send(.onAppear)
    }

    func focusMacSidebarOnDayPlanUnplannedCompletedTasks(on date: Date) {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        dayPlanUnplannedCompletedFilterDate = calendar.startOfDay(for: date)
        macHomeDetailMode = .planner
        taskDetailPanePlacement = nil
        store.send(.macSidebarModeChanged(.routines))
        store.send(.setMacFilterDetailPresented(false))
    }

    func clearDayPlanUnplannedCompletedFilter() {
        dayPlanUnplannedCompletedFilterDate = nil
        dayPlanPlanner.clearFocusedUnplannedCompletedTasks()
    }

    func openDayPlanTaskDetails(_ taskID: UUID) {
        openMacTaskDetails(taskID, presentation: .plannerPane)
    }

    func openBoardTaskDetails(_ taskID: UUID) {
        openMacTaskDetails(taskID)
    }

    func expandTaskDetailPane() {
        guard store.selectedTaskID != nil, let returnPlacement = taskDetailPanePlacement else { return }
        withAnimation(MacHomeDetailAnimation.taskDetailSurface) {
            fullscreenTaskDetailReturnMode = macHomeDetailMode.visibleSurfaceMode
            fullscreenTaskDetailReturnPlacement = returnPlacement
            taskDetailPanePlacement = nil
            macHomeDetailMode = .details
        }
    }

    func closeTaskDetailPane() {
        withAnimation(.easeInOut(duration: 0.18)) {
            taskDetailPanePlacement = nil
        }
    }

    func closeFullscreenTaskDetails() {
        withAnimation(.easeInOut(duration: 0.18)) {
            fullscreenTaskDetailReturnMode = nil
            fullscreenTaskDetailReturnPlacement = nil
            taskDetailPanePlacement = nil
            macHomeDetailMode = .planner
        }
    }

    var canMinimizeFullscreenTaskDetails: Bool {
        store.selectedTaskID != nil
            && macHomeDetailMode.visibleSurfaceMode == .details
            && fullscreenTaskDetailReturnMode != nil
            && fullscreenTaskDetailReturnPlacement != nil
    }

    var minimizeFullscreenTaskDetailsAction: (() -> Void)? {
        guard canMinimizeFullscreenTaskDetails else { return nil }
        return { minimizeFullscreenTaskDetails() }
    }

    func minimizeFullscreenTaskDetails() {
        guard let returnMode = fullscreenTaskDetailReturnMode,
              let returnPlacement = fullscreenTaskDetailReturnPlacement,
              store.selectedTaskID != nil else {
            closeFullscreenTaskDetails()
            return
        }

        withAnimation(MacHomeDetailAnimation.taskDetailSurface) {
            macHomeDetailMode = returnMode.visibleSurfaceMode
            taskDetailPanePlacement = returnPlacement
            fullscreenTaskDetailReturnMode = nil
            fullscreenTaskDetailReturnPlacement = nil
        }
    }

    func openMacTaskDetails(
        _ taskID: UUID,
        presentation: MacTaskDetailPresentation = .fullDetail,
        scrollAnchor: MacSidebarTaskScrollRequest.Anchor? = .center
    ) {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        selectedNoteID = nil
        if shouldShowTaskInRegularSidebar(taskID) {
            clearDayPlanUnplannedCompletedFilter()
        }
        switch presentation {
        case .fullDetail:
            fullscreenTaskDetailReturnMode = nil
            fullscreenTaskDetailReturnPlacement = nil
            macHomeDetailMode = .details
            taskDetailPanePlacement = nil
        case .listSelection:
            fullscreenTaskDetailReturnMode = nil
            fullscreenTaskDetailReturnPlacement = nil
            switch macHomeDetailMode.visibleSurfaceMode {
            case .details:
                taskDetailPanePlacement = nil
            case .planner:
                taskDetailPanePlacement = .plannerAdjacent
            case .board, .places:
                taskDetailPanePlacement = .listAdjacent
            }
        case .plannerPane:
            fullscreenTaskDetailReturnMode = nil
            fullscreenTaskDetailReturnPlacement = nil
            macHomeDetailMode = .planner
            taskDetailPanePlacement = .plannerAdjacent
        }
        if let scrollAnchor {
            macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(
                taskID: taskID,
                anchor: scrollAnchor
            )
        }
        if visibleMacSidebarMode == .board {
            store.send(.macSidebarModeChanged(.routines))
        }
        store.send(.macSidebarSelectionChanged(.task(taskID)))
    }

    func normalizeTaskDetailPanePlacement() {
        guard store.selectedTaskID != nil else {
            taskDetailPanePlacement = nil
            fullscreenTaskDetailReturnMode = nil
            fullscreenTaskDetailReturnPlacement = nil
            return
        }

        if macHomeDetailMode.visibleSurfaceMode != .details {
            fullscreenTaskDetailReturnMode = nil
            fullscreenTaskDetailReturnPlacement = nil
        }

        switch taskDetailPanePlacement {
        case .plannerAdjacent where macHomeDetailMode.visibleSurfaceMode != .planner:
            taskDetailPanePlacement = nil
        case .listAdjacent where macHomeDetailMode.visibleSurfaceMode == .planner:
            taskDetailPanePlacement = .plannerAdjacent
        case .listAdjacent where macHomeDetailMode.visibleSurfaceMode == .details:
            taskDetailPanePlacement = nil
        case .plannerAdjacent, .listAdjacent, nil:
            break
        }
    }

    private func shouldShowTaskInRegularSidebar(_ taskID: UUID) -> Bool {
        guard let task = store.routineTasks.first(where: { $0.id == taskID }) else { return true }
        return !task.isCompletedOneOff && !task.isCanceledOneOff
    }

    func dayPlanUnplannedCompletedDisplays(for date: Date) -> [HomeFeature.RoutineDisplay] {
        let displays = uniqueDayPlanCandidateDisplays
        let plannedBlocks = dayPlanPlanner.blocks(on: date, calendar: calendar, context: modelContext)
        let matchingIDs = DayPlanTimelineTasks.taskIDs(
            on: date,
            taskIDs: displays.map(\.taskID),
            lastDoneForTaskID: Dictionary(uniqueKeysWithValues: displays.map { ($0.taskID, $0.lastDone) }),
            canceledAtForTaskID: Dictionary(uniqueKeysWithValues: displays.map { ($0.taskID, $0.canceledAt) }),
            logs: store.timelineLogs,
            plannedBlocks: plannedBlocks,
            calendar: calendar
        )

        return displays
            .filter { matchingIDs.contains($0.taskID) }
            .sorted { lhs, rhs in
                let lhsDate = latestActivityDate(
                    for: lhs.taskID,
                    fallbackLastDone: lhs.lastDone,
                    fallbackCanceledAt: lhs.canceledAt,
                    on: date
                ) ?? .distantPast
                let rhsDate = latestActivityDate(
                    for: rhs.taskID,
                    fallbackLastDone: rhs.lastDone,
                    fallbackCanceledAt: rhs.canceledAt,
                    on: date
                ) ?? .distantPast
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
        return "Timeline \(dateText) · Not in planner"
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

    private func latestActivityDate(
        for taskID: UUID,
        fallbackLastDone: Date?,
        fallbackCanceledAt: Date?,
        on date: Date
    ) -> Date? {
        DayPlanTimelineTasks.latestActivityDate(
            for: taskID,
            fallbackLastDone: fallbackLastDone,
            fallbackCanceledAt: fallbackCanceledAt,
            logs: store.timelineLogs,
            on: date,
            calendar: calendar
        )
    }

    @ViewBuilder
    var macSidebarContent: some View {
        Group {
            if isPlacesEnabled && macHomeDetailMode == .places && isMacRoutinesMode {
                macPlacesSidebarView
            } else if isMacAddTaskMode || store.taskDetailState?.isEditSheetPresented == true {
                macFormSectionNav
            } else if isMacRoutinesMode && showsInitialTaskLoading && !shouldHideMacSidebarHeaderForDayPlanTimelineFilter {
                VStack(spacing: 0) {
                    macSidebarHeader
                    Divider()
                    HomeLoadingStateView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if isMacRoutinesMode && showsLoadedEmptyTaskList && !shouldHideMacSidebarHeaderForDayPlanTimelineFilter {
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
            } else if isMacBoardSidebarPresented && showsInitialTaskLoading {
                VStack(spacing: 0) {
                    macSidebarHeader
                    Divider()
                    HomeLoadingStateView(
                        title: "Loading Board",
                        message: "Fetching todos and workflow state.",
                        systemImage: "square.grid.3x3.topleft.filled"
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 0) {
                    if !shouldHideMacSidebarHeaderForDayPlanTimelineFilter {
                        macSidebarHeader
                        Divider()
                    }

                    ZStack(alignment: .top) {
                        if isMacTimelineMode {
                            macTimelineSidebarView
                        } else if isMacGoalsMode {
                            MacGoalsSidebarView(store: goalsStore)
                        } else if isMacStatsMode {
                            macProgressSidebarView
                        } else if isMacSettingsMode {
                            macSettingsSidebarView
                        } else if isMacBoardSidebarPresented {
                            macBoardSidebarView
                        } else {
                            listOfSortedTasksView(
                                routineDisplays: store.routineDisplays,
                                awayRoutineDisplays: store.awayRoutineDisplays,
                                archivedRoutineDisplays: store.archivedRoutineDisplays
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Routina")
        .routinaHomeSidebarColumnWidth()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isMacStatusComposerEnabled && isNotesEnabled {
                HomeMacStatusComposerView()
            }
        }
    }

    private var macPlacesSidebarView: some View {
        VStack(spacing: 0) {
            PlaceCheckInMapSheet(
                showsNavigationChrome: false,
                showsInlineHeader: false,
                layout: .controlsOnly,
                selectedPlaceID: $placeCheckInSelectedPlaceID,
                selectedHistoryMarkerID: $placeCheckInSelectedHistoryMarkerID
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        let addState = store.addRoutineState
        let scheduleMode = addState?.schedule.scheduleMode ?? .fixedInterval
        let populatedSections = addState?.populatedMacFormSections ?? []
        let sections = FormSection.taskFormSections(
            scheduleMode: scheduleMode,
            includesIdentity: true,
            includesDangerZone: false
        ).filter { section in
            (section != .planning || addState?.supportsPlanning != false)
            && shouldDisplayFormSection(section)
        }
        return FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveCreate,
            revealedSections: addEditFormCoordinator.revealedTaskFormSections,
            populatedSections: populatedSections,
            allowsOptionalChecklistReveal: addState?.taskType == .todo
        )
    }

    var macEditFormSections: [FormSection] {
        guard let detail = store.taskDetailState else { return [] }
        let sections = FormSection.taskFormSections(
            scheduleMode: detail.editScheduleMode,
            includesIdentity: true,
            includesDangerZone: true
        ).filter { section in
            (section != .planning || detail.supportsPlanning)
            && shouldDisplayFormSection(section)
        }
        return FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveEdit,
            revealedSections: addEditFormCoordinator.revealedTaskFormSections,
            populatedSections: detail.populatedMacFormSections,
            allowsOptionalChecklistReveal: detail.editScheduleMode.taskType == .todo
        )
    }

    private func shouldDisplayFormSection(_ section: FormSection) -> Bool {
        if section == .places {
            return isPlacesEnabled
        }
        if section == .notes || section == .voiceNote {
            return isNotesEnabled
        }
        return section != .goals || isGoalsTabEnabled
    }

    var macSidebarHeader: some View {
        HomeMacSidebarHeaderView(
            selectedTaskListMode: store.taskListMode,
            isRoutinesMode: isMacRoutinesMode && !isMacSegmentedBoardMode,
            isBoardMode: isMacBoardSidebarPresented,
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

    func openAddEmotion() {
        isEventEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        selectedNoteID = nil
        macHomeDetailMode = .details
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        store.send(.macSidebarModeChanged(.routines))
        isEmotionLogEditorPresented = true
    }

    func closeAddEmotion() {
        isEmotionLogEditorPresented = false
    }

    func openAddEvent() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        selectedNoteID = nil
        macHomeDetailMode = .details
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        store.send(.macSidebarModeChanged(.routines))
        isEventEditorPresented = true
    }

    func closeAddEvent() {
        isEventEditorPresented = false
    }

    func openSavedEvent(_ eventID: UUID) {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        selectedNoteID = nil
        macHomeDetailMode = .details
        searchTextBinding.wrappedValue = ""
        store.send(.setAddRoutineSheet(false))
        store.send(.setSelectedTask(nil))
        store.send(.setMacFilterDetailPresented(false))
        store.send(.macSidebarModeChanged(.timeline))
        store.send(.selectedTimelineRangeChanged(.all))
        store.send(.selectedTimelineFilterTypeChanged(.events))
        store.send(.selectedTimelineTagsChanged([]))
        store.send(.selectedTimelineIncludeTagMatchModeChanged(.all))
        store.send(.selectedTimelineExcludedTagsChanged([]))
        store.send(.selectedTimelineExcludeTagMatchModeChanged(.any))
        store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
        store.send(.selectedTimelineMediaFilterChanged(.all))
        store.send(.macSidebarSelectionChanged(.timelineEntry(eventID)))
        macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: eventID)
    }

    func openSavedEmotion(_ emotionID: UUID) {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        selectedNoteID = nil
        macHomeDetailMode = .details
        searchTextBinding.wrappedValue = ""
        store.send(.setAddRoutineSheet(false))
        store.send(.setSelectedTask(nil))
        store.send(.setMacFilterDetailPresented(false))
        store.send(.macSidebarModeChanged(.timeline))
        store.send(.selectedTimelineRangeChanged(.all))
        store.send(.selectedTimelineFilterTypeChanged(.emotions))
        store.send(.selectedTimelineTagsChanged([]))
        store.send(.selectedTimelineIncludeTagMatchModeChanged(.all))
        store.send(.selectedTimelineExcludedTagsChanged([]))
        store.send(.selectedTimelineExcludeTagMatchModeChanged(.any))
        store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
        store.send(.selectedTimelineMediaFilterChanged(.all))
        store.send(.macSidebarSelectionChanged(.timelineEntry(emotionID)))
        macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: emotionID)
    }

    func openCheckInFromAddMenu() {
        guard isPlacesEnabled else { return }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        openMacPlacesWorkspace()
    }

    func openAwayFromAddMenu() {
        guard isAwayEnabled else { return }
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        selectedNoteID = nil
        macHomeDetailMode = .details
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        store.send(.setMacFilterDetailPresented(false))
        if visibleMacSidebarMode != .routines {
            store.send(.macSidebarModeChanged(.routines))
        }
        isAwayStartPresented = true
    }

    private var visibleMacSidebarMode: MacSidebarMode {
        guard !isGoalsTabEnabled else { return store.macSidebarMode }
        if store.macSidebarMode == .goals {
            return .routines
        }
        guard !isAdventureMapEnabled else { return store.macSidebarMode }
        return store.macSidebarMode == .adventure ? .stats : store.macSidebarMode
    }

    private func resolvedMacSidebarMode(_ mode: MacSidebarMode) -> MacSidebarMode {
        guard !isGoalsTabEnabled else { return mode }
        if mode == .goals {
            return .routines
        }
        guard !isAdventureMapEnabled else { return mode }
        return mode == .adventure ? .stats : mode
    }

    func closeAwayStart() {
        isAwayStartPresented = false
    }

    func startSleepFromAway() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        RoutinaMacSleepModeStarter.requestStartUsingSharedPersistence()
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
            return isPlacesEnabled ? "Try a different place or clear a few filters." : "Clear a few filters and try again."
        case .routines:
            return isPlacesEnabled ? "Try a different place or switch back to all routines." : "Clear a few filters or switch back to all routines."
        case .todos:
            return isPlacesEnabled ? "Try a different place or switch back to all todos." : "Clear a few filters or switch back to all todos."
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
        )
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
            title: macFilterDetailTitle,
            showsTitle: false
        ) {
            HomeMacRoutineFiltersDetailView(
                availableFilters: macAvailableFilters,
                taskListMode: macFilterTaskListModeBinding,
                selectedFilter: homeFilterBindings.selectedFilter,
                advancedQuery: homeFilterBindings.advancedQuery,
                taskListViewMode: homeFilterBindings.taskListViewMode,
                routineListSectioningMode: homeFilterBindings.routineListSectioningMode,
                taskListSortOrder: homeFilterBindings.taskListSortOrder,
                createdDateFilter: homeFilterBindings.createdDateFilter,
                hideAssumedDoneTasks: homeFilterBindings.hideAssumedDoneTasks,
                showArchivedTasks: homeFilterBindings.showArchivedTasks,
                selectedImportanceUrgencyFilter: homeFilterBindings.selectedImportanceUrgencyFilter,
                selectedPressureFilter: homeFilterBindings.selectedPressureFilter,
                selectedGoalFilter: homeFilterBindings.selectedGoalFilter,
                selectedMediaFilter: homeFilterBindings.selectedMediaFilter,
                selectedTodoStateFilter: homeFilterBindings.selectedTodoStateFilter,
                taskRowVisibility: taskRowVisibility,
                queryOptions: HomeAdvancedQueryOptions(
                    tags: homeTagFilterData.tagSummaries.map(\.name),
                    places: isPlacesEnabled ? sortedRoutinePlaces.map(\.displayName) : []
                ),
                importanceUrgencySummary: importanceUrgencyFilterSummary,
                showsGoalFilter: isGoalsTabEnabled,
                showsTagSection: homeTagFilterData.hasTags,
                showsPlaceSection: isPlacesEnabled && hasPlaceAwareContent,
                onTaskRowFieldVisibilityChanged: { field, isVisible in
                    settingsStore.send(.taskRowFieldVisibilityChanged(field, isVisible))
                }
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
        }
    }

    private var macFilterTaskListModeBinding: Binding<HomeFeature.TaskListMode> {
        Binding(
            get: { store.taskListMode },
            set: { store.send(.taskListModeFilterChanged($0)) }
        )
    }

    var macSettingsSidebarView: some View {
        HomeMacSettingsSidebarView(
            store: settingsStore,
            selectedSection: currentSelectedSettingsSection,
            isDevicesSectionEnabled: isSettingsDevicesSectionEnabled,
            isPlacesEnabled: isPlacesEnabled,
            onSelectSection: { section in
                store.send(.selectedSettingsSectionChanged(section))
            }
        )
    }
}
