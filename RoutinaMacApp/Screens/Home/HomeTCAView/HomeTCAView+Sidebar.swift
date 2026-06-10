import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var isMacTimelineMode: Bool { store.macSidebarMode == .timeline }
    var isMacStatsMode: Bool { store.macSidebarMode == .stats || store.macSidebarMode == .adventure }
    var isMacSettingsMode: Bool { store.macSidebarMode == .settings }
    var isMacRoutinesMode: Bool { store.macSidebarMode == .routines }
    var isMacBoardMode: Bool { store.macSidebarMode == .board }
    var isMacGoalsMode: Bool { store.macSidebarMode == .goals }
    var isMacAdventureMode: Bool { store.macSidebarMode == .adventure }
    var isMacAddTaskMode: Bool { store.macSidebarMode == .addTask }
    var isMacSegmentedBoardMode: Bool { isMacRoutinesMode && macHomeDetailMode == .board }
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

        switch store.macSidebarMode {
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

    var macFilterDetailTitle: String {
        if isMacSegmentedBoardMode {
            return "Filter Board"
        }

        switch store.macSidebarMode {
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
            isGitFeaturesEnabled: settingsStore.appearance.isGitFeaturesEnabled
        )
        let candidate = store.selectedSettingsSection ?? .notifications
        let resolvedSection = candidate.resolvedNavigationSection
        guard visibleSections.contains(resolvedSection) else { return .general }
        return resolvedSection
    }

    var macHasCustomFiltersApplied: Bool {
        switch store.macSidebarMode {
        case .timeline:
            return store.selectedTimelineRange != .all
                || store.selectedTimelineFilterType != .all
                || !store.selectedTimelineTags.isEmpty
                || store.selectedTimelineImportanceUrgencyFilter != nil
                || store.selectedTimelineMediaFilter != .all
                || !store.selectedTimelineExcludedTags.isEmpty
        case .routines, .board:
            return store.selectedFilter != .all || hasActiveOptionalFilters
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
        homeFilterPresentation.activeTaskFiltersSummary(resultCount: macVisibleTaskResultCount, maxVisibleCount: 4)
    }

    var macSidebarSearchFiltersSummary: String? {
        switch store.macSidebarMode {
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
        if store.macSidebarMode == .timeline {
            store.send(.selectedTimelineRangeChanged(.all))
            store.send(.selectedTimelineFilterTypeChanged(.all))
            store.send(.selectedTimelineTagsChanged([]))
            store.send(.selectedTimelineIncludeTagMatchModeChanged(.all))
            store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
            store.send(.selectedTimelineMediaFilterChanged(.all))
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
            get: { macHomeDetailMode },
            set: { mode in
                macHomeDetailMode = mode
                if mode == .places {
                    clearDayPlanUnplannedCompletedFilter()
                }
                if mode != .places {
                    placeCheckInSelectedPlaceID = nil
                    placeCheckInSelectedHistoryMarkerID = nil
                }
                if mode == .board, store.taskListMode != .todos {
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
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        withAnimation(.easeInOut(duration: 0.18)) {
            store.send(.setMacFilterDetailPresented(false))
            clearDayPlanUnplannedCompletedFilter()
            if store.macSidebarMode != .routines {
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
                    store.send(.macSidebarSelectionChanged(.timelineEntry(entryID)))
                    let entry = timelineEntries.first { $0.id == entryID }
                    selectedNoteID = entry?.isNote == true ? entryID : nil
                    let taskID = entry?.taskID
                    store.send(.setSelectedTask(taskID))
                case nil:
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
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.macSidebarModeChanged(.goals))
    }

    func openAdventureInSidebar() {
        openStatsInSidebar()
    }

    func openAddNote() {
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
        store.send(.openNoteDeepLink(noteID))
    }

    func openAddGoal() {
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
        store.send(.macSidebarModeChanged(.routines))
        store.send(.setMacFilterDetailPresented(false))
    }

    func clearDayPlanUnplannedCompletedFilter() {
        dayPlanUnplannedCompletedFilterDate = nil
        dayPlanPlanner.clearFocusedUnplannedCompletedTasks()
    }

    func openDayPlanTaskDetails(_ taskID: UUID) {
        openMacTaskDetails(taskID)
    }

    func openBoardTaskDetails(_ taskID: UUID) {
        openMacTaskDetails(taskID)
    }

    private func openMacTaskDetails(_ taskID: UUID) {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        selectedNoteID = nil
        if shouldShowTaskInRegularSidebar(taskID) {
            clearDayPlanUnplannedCompletedFilter()
        }
        macHomeDetailMode = .details
        macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(taskID: taskID)
        if store.macSidebarMode == .board {
            store.send(.macSidebarModeChanged(.routines))
        }
        store.send(.macSidebarSelectionChanged(.task(taskID)))
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
            if macHomeDetailMode == .places && isMacRoutinesMode {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Routina")
        .routinaHomeSidebarColumnWidth()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HomeMacStatusComposerView()
        }
    }

    private var macPlacesSidebarView: some View {
        VStack(spacing: 0) {
            macPlacesSidebarHeader
            Divider()

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

    private var macPlacesSidebarHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacSidebarModeStripView(
                selectedMode: macSidebarModeBinding,
                onAddEvent: openAddEvent,
                onAddEmotion: openAddEmotion,
                onAddNote: openAddNote,
                onAddGoal: openAddGoal,
                onAddTask: openAddTask,
                onCheckIn: openCheckInFromAddMenu,
                onStartAway: openAwayFromAddMenu,
                onStartSleep: startSleepFromAddMenu
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
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
            section != .planning || addState?.supportsPlanning != false
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
            section != .planning || detail.supportsPlanning
        }
        return FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveEdit,
            revealedSections: addEditFormCoordinator.revealedTaskFormSections,
            populatedSections: detail.populatedMacFormSections,
            allowsOptionalChecklistReveal: detail.editScheduleMode.taskType == .todo
        )
    }

    var macSidebarHeader: some View {
        HomeMacSidebarHeaderView(
            selectedSidebarMode: macSidebarModeBinding,
            selectedTaskListMode: store.taskListMode,
            isRoutinesMode: isMacRoutinesMode && !isMacSegmentedBoardMode,
            isBoardMode: isMacBoardSidebarPresented,
            isGoalsMode: isMacGoalsMode,
            isTimelineMode: isMacTimelineMode,
            onSelectTaskListMode: { mode in
                store.send(.taskListModeChanged(mode))
            },
            onAddEvent: openAddEvent,
            onAddEmotion: openAddEmotion,
            onAddNote: openAddNote,
            onAddGoal: openAddGoal,
            onAddTask: openAddTask,
            onCheckIn: openCheckInFromAddMenu,
            onStartAway: openAwayFromAddMenu,
            onStartSleep: startSleepFromAddMenu
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
    }

    func openCheckInFromAddMenu() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        openMacPlacesWorkspace()
    }

    func openAwayFromAddMenu() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        selectedNoteID = nil
        macHomeDetailMode = .details
        store.send(.setSelectedTask(nil))
        store.send(.setAddRoutineSheet(false))
        store.send(.setMacFilterDetailPresented(false))
        if store.macSidebarMode != .routines {
            store.send(.macSidebarModeChanged(.routines))
        }
        isAwayStartPresented = true
    }

    func closeAwayStart() {
        isAwayStartPresented = false
    }

    func startSleepFromAddMenu() {
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
            title: macFilterDetailTitle
        ) {
            HomeMacRoutineFiltersDetailView(
                availableFilters: macAvailableFilters,
                selectedFilter: homeFilterBindings.selectedFilter,
                advancedQuery: homeFilterBindings.advancedQuery,
                taskListViewMode: homeFilterBindings.taskListViewMode,
                routineListSectioningMode: homeFilterBindings.routineListSectioningMode,
                taskListSortOrder: homeFilterBindings.taskListSortOrder,
                createdDateFilter: homeFilterBindings.createdDateFilter,
                showArchivedTasks: homeFilterBindings.showArchivedTasks,
                selectedImportanceUrgencyFilter: homeFilterBindings.selectedImportanceUrgencyFilter,
                selectedPressureFilter: homeFilterBindings.selectedPressureFilter,
                selectedGoalFilter: homeFilterBindings.selectedGoalFilter,
                selectedMediaFilter: homeFilterBindings.selectedMediaFilter,
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
