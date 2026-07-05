import AppKit
import ComposableArchitecture
import MapKit
import SwiftUI

private enum HomeSidebarSizing {
    static let minWidth: CGFloat = 220
    static let idealWidth: CGFloat = 300
    static let maxWidth: CGFloat = 360
}

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        navigationSplitViewColumnWidth(
            min: HomeSidebarSizing.minWidth,
            ideal: HomeSidebarSizing.idealWidth,
            max: HomeSidebarSizing.maxWidth
        )
        .background(
            HomeMacSidebarSplitViewConfigurator(
                minimumWidth: HomeSidebarSizing.minWidth,
                maximumWidth: HomeSidebarSizing.maxWidth
            )
        )
    }
}

private struct HomeMacSidebarSplitViewConfigurator: NSViewRepresentable {
    let minimumWidth: CGFloat
    let maximumWidth: CGFloat

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard
                let splitView = nsView.enclosingSplitView,
                let splitViewController = splitView.delegate as? NSSplitViewController,
                let sidebarItem = splitViewController.splitViewItems.first
            else {
                return
            }

            sidebarItem.canCollapse = true
            sidebarItem.canCollapseFromWindowResize = false
            sidebarItem.minimumThickness = minimumWidth
            sidebarItem.maximumThickness = maximumWidth
            sidebarItem.holdingPriority = .defaultHigh
            splitViewController.minimumThicknessForInlineSidebars = minimumWidth

            guard
                !sidebarItem.isCollapsed,
                splitView.subviews.count > 1,
                let sidebarView = splitView.subviews.first,
                sidebarView.frame.width > 1
            else {
                return
            }

            let clampedWidth = min(max(sidebarView.frame.width, minimumWidth), maximumWidth)
            guard sidebarView.frame.width != clampedWidth else { return }

            splitView.setPosition(clampedWidth, ofDividerAt: 0)
        }
    }
}

private extension NSView {
    var enclosingSplitView: NSSplitView? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? NSSplitView }
            .first
    }
}

extension HomeTCAView {
    // Typealiases for brevity — the canonical definitions live in HomeFeature
    typealias MacSidebarMode = HomeFeature.MacSidebarMode
    typealias MacSidebarSelection = HomeFeature.MacSidebarSelection

    private var homeTopToolbarChrome: some View {
        HomeMacTopToolbarChrome(
            mode: homeToolbarMode,
            doneCount: store.doneStats.totalCount,
            isDevelopmentAppVariant: isDevelopmentAppVariant,
            showsProgressModePicker: showsProgressModePickerInToolbar,
            showsPlaces: isPlacesEnabled,
            progressMode: macHomeProgressModeBinding,
            selectedSidebarMode: macSidebarModeBinding,
            searchText: searchTextBinding,
            isSearchTextFocused: $isToolbarSearchTextFocused,
            isSearchExpanded: $isToolbarSearchExpanded,
            searchVisiblePillWidth: $toolbarSearchVisiblePillWidth,
            searchExpansionTransitionID: $toolbarSearchExpansionTransitionID,
            searchFocusRequestID: $toolbarSearchFocusRequestID,
            searchFocusDismissRequestID: $toolbarSearchFocusDismissRequestID,
            isSidebarCollapsed: isMacHomeSidebarCollapsed,
            locationSnapshot: store.locationSnapshot,
            onPlaceCheckInMapRequested: {
                openMacPlacesWorkspace()
            },
            isCreatingTaskFromSearch: isToolbarSearchCreateInProgress,
            canCreateTaskFromSearch: canCreateTaskFromToolbarSearch,
            onSearchSubmit: createTaskFromToolbarSearch,
            onAddEvent: openAddEvent,
            onAddEmotion: openAddEmotion,
            onAddNote: openAddNote,
            onAddGoal: openAddGoal,
            onAddTask: openAddTask,
            onCheckIn: openCheckInFromAddMenu,
            onStartAway: openAwayFromAddMenu,
            isBoardInspectorPresented: isMacBoardTicketInspectorPresented,
            onToggleBoardInspector: toggleMacBoardTicketInspector,
            onToggleSidebar: toggleMacHomeSidebar
        )
    }

    private var showsProgressModePickerInToolbar: Bool {
        !store.isMacFilterDetailPresented
            && isMacStatsMode
            && MacHomeProgressMode.visibleModes.count > 1
            && !isEmotionLogEditorPresented
            && !isNoteEditorPresented
            && !isAwayStartPresented
            && store.addRoutineState == nil
    }

    private var homeToolbarMode: HomeMacTopToolbarChrome.Mode {
        if isMacBoardSidebarPresented {
            return .board
        }
        if isMacGoalsMode {
            return .goals
        }
        return .standard
    }

    private var homeToolbarActiveFocusSessions: [FocusSession] {
        focusSessions
            .filter { $0.completedAt == nil && $0.abandonedAt == nil }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    private var homeToolbarIsPlanFocusStartDisabled: Bool {
        homeToolbarActiveFocusSessions.contains { !$0.isUnassigned }
            || sprintFocusSessions.contains(where: \.isActive)
            || homeToolbarActiveFocusSessions.contains(where: \.isUnassigned)
    }

    private var homeToolbarActivePlanFocusSession: FocusSession? {
        homeToolbarActiveFocusSessions.first(where: \.isUnassigned)
    }

    private var homeToolbarFocusStartTaskCount: Int {
        guard homeToolbarActivePlanFocusSession == nil else {
            return 0
        }
        return homeToolbarFocusStartTasks.count
    }

    var homeToolbarFocusStartTasks: [RoutineTask] {
        let referenceDate = Date()
        return store.routineTasks.filter { task in
            guard !task.isArchived(referenceDate: referenceDate, calendar: calendar),
                  !task.isCompletedOneOff,
                  !task.isCanceledOneOff else {
                return false
            }

            return true
        }
    }

    var homeToolbarFocusPickerPresentedBinding: Binding<Bool> {
        Binding(
            get: { homeToolbarFocusPickerDuration != nil },
            set: { isPresented in
                if !isPresented {
                    homeToolbarFocusPickerDuration = nil
                }
            }
        )
    }

    private func presentHomeToolbarFocusPicker(duration: TimeInterval) {
        homeToolbarFocusPickerDuration = duration
    }

    private func pauseHomeToolbarPlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.pauseFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext
            )
        } catch {
            NSLog("Failed to pause plan focus from toolbar: \(error.localizedDescription)")
        }
    }

    private func resumeHomeToolbarPlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.resumeFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext
            )
        } catch {
            NSLog("Failed to resume plan focus from toolbar: \(error.localizedDescription)")
        }
    }

    private func finishHomeToolbarPlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.finishFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext,
                calendar: calendar
            )
        } catch {
            NSLog("Failed to finish plan focus from toolbar: \(error.localizedDescription)")
        }
    }

    private func abandonHomeToolbarPlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.abandonFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext
            )
        } catch {
            NSLog("Failed to abandon plan focus from toolbar: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    var platformNavigationContent: some View {
        ZStack(alignment: .top) {
            HomeMacNavigationContent(
                isBoardMode: isMacBoardMode,
                isGoalsMode: isMacGoalsMode,
                isBoardInspectorPresented: macBoardInspectorPresentedBinding,
                sidebarColumnVisibility: $macHomeSidebarColumnVisibility,
                addEditFormCoordinator: addEditFormCoordinator
            ) {
                macSidebarContent
            } boardCenterContent: {
                macBoardCenterContent
            } boardInspectorContent: {
                macBoardTaskInspector
            } goalsDetailContent: {
                MacGoalsDetailView(store: goalsStore)
            } mainDetailContent: {
                if isEmotionLogEditorPresented {
                    EmotionLogEditorView(
                        onCancel: closeAddEmotion,
                        onSaved: openSavedEmotion
                    )
                } else if isEventEditorPresented {
                    RoutineEventEditorView(
                        onCancel: closeAddEvent,
                        onSaved: openSavedEvent
                    )
                } else if isNotesEnabled && isNoteEditorPresented {
                    if editingNoteID != nil {
                        if let editingNote {
                            RoutineNoteEditorView(
                                note: editingNote,
                                attachments: noteAttachments(for: editingNote),
                                onCancel: closeAddNote,
                                onSaved: openSavedNote
                            )
                        } else {
                            ContentUnavailableView(
                                "Note unavailable",
                                systemImage: "note.text",
                                description: Text("The note being edited is no longer available.")
                            )
                        }
                    } else {
                        RoutineNoteEditorView(
                            onCancel: closeAddNote,
                            onSaved: openSavedNote
                        )
                    }
                } else if isAwayEnabled && isAwayStartPresented {
                    AwaySessionStartSheet(
                        presentation: .inline,
                        onCancel: closeAwayStart,
                        onStarted: closeAwayStart,
                        onStartSleep: startSleepFromAway,
                        dismissOnCompletion: false
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    let timelineSelection = isMacTimelineMode
                        ? selectedMacTimelineSelection
                        : .empty
                    let adventureProgression = isMacStatsMode && macHomeProgressMode.visibleSurfaceMode == .adventure
                        ? homeAdventureProgression
                        : nil

                    MacDetailContainerView(
                        store: store,
                        isBoardPresented: isMacBoardMode,
                        isTimelinePresented: isMacTimelineMode,
                        isStatsPresented: isMacStatsMode,
                        currentProgressMode: macHomeProgressMode,
                        isSettingsPresented: isMacSettingsMode,
                        settingsStore: settingsStore,
                        statsStore: statsStore,
                        selectedStatsDashboardScope: $selectedStatsDashboardScope,
                        selectedSettingsSection: currentSelectedSettingsSection,
                        dayPlanPlanner: dayPlanPlanner,
                        adventureProgression: adventureProgression,
                        showsPlaces: isPlacesEnabled,
                        mainDetailMode: mainDetailModeBinding,
                        dayPlanDisplayMode: $dayPlanDisplayMode,
                        dayPlanCalendarFilters: $dayPlanCalendarFilters,
                        isDayPlanCalendarFilterDetailPresented: store.isMacFilterDetailPresented && macFilterDetailScope == .calendar,
                        plannerSearchText: searchTextBinding.wrappedValue,
                        focusStartTaskCount: homeToolbarFocusStartTaskCount,
                        activePlanFocusSession: homeToolbarActivePlanFocusSession,
                        isPlanFocusStartDisabled: homeToolbarIsPlanFocusStartDisabled,
                        isBoardInspectorPresented: macBoardInspectorPresentedBinding,
                        taskDetailPanePlacement: $taskDetailPanePlacement,
                        placeCheckInSelectedPlaceID: $placeCheckInSelectedPlaceID,
                        placeCheckInSelectedHistoryMarkerID: $placeCheckInSelectedHistoryMarkerID,
                        selectedTaskID: store.selectedTaskID,
                        selectedTimelineEntry: timelineSelection.entry,
                        selectedTimelineEmotion: timelineSelection.emotion,
                        selectedTimelineEvent: timelineSelection.event,
                        selectedTimelineNote: isNotesEnabled ? timelineSelection.note : nil,
                        selectedTimelineNoteAttachments: isNotesEnabled ? timelineSelection.noteAttachments : [],
                        selectedTimelinePlaceCheckInSession: isPlacesEnabled ? timelineSelection.placeCheckInSession : nil,
                        selectedTimelineAwaySession: isAwayEnabled ? timelineSelection.awaySession : nil,
                        onSelectDayPlanUnplannedCompletedDate: { date in
                            focusMacSidebarOnDayPlanUnplannedCompletedTasks(on: date)
                        },
                        onOpenDayPlanTaskDetails: { taskID in
                            openDayPlanTaskDetails(taskID)
                        },
                        onOpenEventDetails: openSavedEvent,
                        onToggleDayPlanCalendarFilters: toggleMacCalendarFilterDetailFromPlanner,
                        onTaskFocusDurationSelected: { duration in
                            presentHomeToolbarFocusPicker(duration: duration)
                        },
                        onPausePlanFocus: { session in
                            pauseHomeToolbarPlanFocus(session)
                        },
                        onResumePlanFocus: { session in
                            resumeHomeToolbarPlanFocus(session)
                        },
                        onFinishPlanFocus: { session in
                            finishHomeToolbarPlanFocus(session)
                        },
                        onAbandonPlanFocus: { session in
                            abandonHomeToolbarPlanFocus(session)
                        },
                        onEditNote: openEditNote,
                        onDeleteNote: closeDeletedNote,
                        onToggleBoardInspector: toggleMacBoardTicketInspector,
                        onExpandTaskDetails: expandTaskDetailPane,
                        fullscreenTaskDetailReturnPlacement: fullscreenTaskDetailReturnPlacement,
                        onMinimizeFullscreenTaskDetails: minimizeFullscreenTaskDetailsAction,
                        onCloseTaskDetails: closeTaskDetailPane,
                        onCloseFullscreenTaskDetails: closeFullscreenTaskDetails,
                        isFilterDetailFullscreen: isMacFilterDetailFullscreen,
                        onExpandFilterDetail: expandMacFilterDetailPane,
                        onMinimizeFullscreenFilterDetail: minimizeFullscreenMacFilterDetailAction,
                        onCloseFilterDetail: closeMacFilterDetailPane,
                        addRoutineStore: self.store.scope(
                            state: \.addRoutineState,
                            action: \.addRoutineSheet
                        )
                    ) {
                        macActiveFiltersDetailView
                    } plannerListView: { dateJumpRequest in
                        macPlannerTimelineListView(dateJumpRequest: dateJumpRequest)
                    } boardView: {
                        macTodoBoardDetailView
                    } boardInspectorView: {
                        macBoardTaskInspector
                    }
                }
            }
            .padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight)

            homeTopToolbarChrome
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
    }

    private var isDevelopmentAppVariant: Bool {
        Bundle.main.object(forInfoDictionaryKey: "RoutinaSandboxDataMode") as? Bool == true
    }

    private func toggleMacBoardTicketInspector() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isMacBoardTicketInspectorPresented.toggle()
        }
    }

    private var isMacHomeSidebarCollapsed: Bool {
        macHomeSidebarColumnVisibility == .detailOnly
    }

    private func toggleMacHomeSidebar() {
        withAnimation(.easeInOut(duration: 0.22)) {
            macHomeSidebarColumnVisibility = isMacHomeSidebarCollapsed ? .all : .detailOnly
        }
    }

    var macBoardInspectorPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                isMacBoardTicketInspectorPresented
            },
            set: { isPresented in
                isMacBoardTicketInspectorPresented = isPresented
            }
        )
    }

    func applyPlatformDeleteConfirmation<Content: View>(to view: Content) -> some View {
        view.alert(
            deleteConfirmationTitle,
            isPresented: deleteConfirmationBinding
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteTasksConfirmed)
            }
            Button("Cancel", role: .cancel) {
                store.send(.setDeleteConfirmation(false))
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    func applyPlatformSearchExperience<Content: View>(
        to view: Content,
        searchText: Binding<String>
    ) -> some View {
        view
    }

    @ViewBuilder
    func platformSearchField(searchText: Binding<String>) -> some View {
        HomeMacSearchField(
            placeholder: searchPlaceholderText,
            text: searchText
        )
    }

    func applyPlatformRefresh<Content: View>(to view: Content) -> some View {
        view
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        MacToolbarIconButton(title: "Sync with iCloud", systemImage: "arrow.clockwise") {
            Task { @MainActor in
                await store.send(.manualRefreshRequested).finish()
            }
        }
    }

    func applyPlatformHomeObservers<Content: View>(to view: Content) -> some View {
        HomeMacSidebarCommandRouter(
            content: view,
            mode: effectiveMacSidebarMode,
            onOpenRoutines: showRoutinesInSidebar,
            onOpenAddTask: openAddTask,
            onOpenAddEvent: openAddEvent,
            onOpenAddEmotion: openAddEmotion,
            onOpenAddNote: openAddNote,
            onOpenAddGoal: openAddGoal,
            onOpenCheckIn: openCheckInFromAddMenu,
            onOpenAway: openAwayFromAddMenu,
            onOpenTimeline: openTimelineInSidebar,
            onOpenStats: openStatsInSidebar
        ) { mode in
            if mode == .settings {
                settingsStore.send(.onAppear)
            } else if mode == .goals {
                goalsStore.send(.onAppear)
            }
        }
        .onAppear {
            settingsStore.send(.onAppear)
            recordMacNavigationSnapshotIfNeeded()
        }
        .onChange(of: macNavigationSnapshot) { _, snapshot in
            recordMacNavigationSnapshotIfNeeded(snapshot)
        }
        .onChange(of: store.selectedTaskID) { _, taskID in
            if taskID != nil {
                isEmotionLogEditorPresented = false
                isNoteEditorPresented = false
                isAwayStartPresented = false
                normalizeTaskDetailPanePlacement()
            } else {
                taskDetailPanePlacement = nil
            }
        }
        .onChange(of: store.macSidebarMode) { _, mode in
            if mode != .routines {
                isNoteEditorPresented = false
                isAwayStartPresented = false
            }
        }
        .onChange(of: store.isAddRoutineSheetPresented) { wasPresented, isPresented in
            guard wasPresented,
                  !isPresented,
                  effectiveMacSidebarMode == .routines,
                  let taskID = store.selectedTaskID else { return }
            searchTextBinding.wrappedValue = ""
            macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(taskID: taskID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaMacNavigateBack)) { _ in
            goBackInMacNavigationHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaMacNavigateForward)) { _ in
            goForwardInMacNavigationHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaMacFocusSearchOrCreate)) { _ in
            focusExpandedToolbarSearchFromCommand()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            alignMacDetailModeForDeepLinkNotification(notification)
        }
    }

    private func focusExpandedToolbarSearchFromCommand() {
        toolbarSearchFocusRequestID += 1
        toolbarSearchExpansionTransitionID += 1
        let transitionID = toolbarSearchExpansionTransitionID

        if !isToolbarSearchExpanded {
            toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth
            isToolbarSearchExpanded = true
        }

        if !isToolbarSearchTextFocused {
            isToolbarSearchTextFocused = true
        }

        DispatchQueue.main.async {
            guard toolbarSearchExpansionTransitionID == transitionID else { return }
            withAnimation(.easeInOut(duration: HomeMacToolbarSearchLayout.animationDuration)) {
                toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.focusedWidth
            }
        }
    }

    private func alignMacDetailModeForDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        switch deepLink {
        case .task:
            macHomeDetailMode = .details
            taskDetailPanePlacement = nil
        case .goal:
            break
        case let .note(noteID):
            macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: noteID)
        case let .event(eventID):
            macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: eventID)
        case .sprint:
            macHomeDetailMode = MacHomeDetailMode.board.visibleSurfaceMode
            taskDetailPanePlacement = nil
        case .sleep:
            macHomeDetailMode = .planner
            taskDetailPanePlacement = nil
        }
    }

    var searchPlaceholderText: String {
        if effectiveMacSidebarMode == .goals {
            return "Search goals"
        }
        if effectiveMacSidebarMode == .timeline {
            return "Search timeline"
        }
        if isMacBoardSidebarPresented {
            return "Search todos"
        }
        switch store.taskListMode {
        case .all:
            return "Search routines and todos"
        case .routines:
            return "Search routines"
        case .todos:
            return "Search todos"
        }
    }

    func applyAddRoutinePresentation<Content: View>(to content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toolbarSearchCreateDraft, isToolbarSearchExpanded {
                    HomeMacToolbarSearchParserPreview(draft: toolbarSearchCreateDraft)
                        .frame(
                            width: HomeMacToolbarSearchLayout.focusedWidth,
                            alignment: .leading
                        )
                        .padding(
                            .top,
                            HomeMacToolbarSearchLayout.topToolbarHeight
                                + HomeMacToolbarSearchLayout.parserPreviewTopPadding
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .zIndex(20)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let quickAddCreatedToast {
                    MacQuickAddCreatedToastView(
                        toast: quickAddCreatedToast,
                        onOpen: {
                            openQuickAddCreatedTask(quickAddCreatedToast)
                        },
                        onClose: {
                            self.quickAddCreatedToast = nil
                        }
                    )
                    .padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight + 18)
                    .padding(.trailing, 22)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: quickAddCreatedToast.id) {
                        do {
                            try await Task.sleep(for: .seconds(10))
                            await MainActor.run {
                                if self.quickAddCreatedToast?.id == quickAddCreatedToast.id {
                                    self.quickAddCreatedToast = nil
                                }
                            }
                        } catch {}
                    }
                }
            }
            .animation(
                .easeOut(duration: 0.12),
                value: toolbarSearchCreateDraft
            )
            .sheet(isPresented: subscriptionPaywallBinding) {
                subscriptionPaywallContent
            }
            .alert("Could Not Create Task", isPresented: toolbarSearchCreateErrorBinding) {
                Button("OK", role: .cancel) {
                    toolbarSearchCreateErrorMessage = nil
                }
            } message: {
                if let toolbarSearchCreateErrorMessage {
                    Text(toolbarSearchCreateErrorMessage)
                }
            }
    }

    private var toolbarSearchCreateErrorBinding: Binding<Bool> {
        Binding(
            get: { toolbarSearchCreateErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    toolbarSearchCreateErrorMessage = nil
                }
            }
        )
    }

    private var canCreateTaskFromToolbarSearch: Bool {
        let trimmedText = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty
            && !isToolbarSearchCreateInProgress
            && !hasToolbarSearchResult(for: trimmedText)
    }

    private var toolbarSearchCreateDraft: RoutinaQuickAddDraft? {
        guard canCreateTaskFromToolbarSearch,
              let draft = RoutinaQuickAddParser.parse(
                searchTextBinding.wrappedValue,
                calendar: calendar,
                includingPlaces: isPlacesEnabled
              ),
              draft.hasDetectedMetadata else {
            return nil
        }

        return draft
    }

    private func createTaskFromToolbarSearch(_ rawText: String) {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
              !isToolbarSearchCreateInProgress,
              !hasToolbarSearchResult(for: trimmedText) else {
            return
        }

        toolbarSearchCreateErrorMessage = nil
        isToolbarSearchCreateInProgress = true

        Task { @MainActor in
            defer { isToolbarSearchCreateInProgress = false }

            do {
                let result = try await RoutinaQuickAddService.createTask(
                    from: trimmedText,
                    context: modelContext,
                    calendar: calendar,
                    includingPlaces: isPlacesEnabled
                )
                searchTextBinding.wrappedValue = ""
                handleQuickAddCreated(result)
            } catch let error as RoutinaTaskLimitError {
                store.send(.subscriptionRequired(error.snapshot, nil))
            } catch {
                toolbarSearchCreateErrorMessage = error.localizedDescription
            }
        }
    }

    private func hasToolbarSearchResult(for searchText: String) -> Bool {
        hasTaskSearchResult(for: searchText)
            || hasTimelineSearchResult(for: searchText)
    }

    private func hasTaskSearchResult(for searchText: String) -> Bool {
        let displays = store.routineDisplays
            + store.awayRoutineDisplays
            + store.archivedRoutineDisplays
            + store.boardTodoDisplays

        return displays.contains { task in
            taskMatchesToolbarSearch(task, searchText: searchText)
        }
    }

    private func taskMatchesToolbarSearch(
        _ task: HomeFeature.RoutineDisplay,
        searchText: String
    ) -> Bool {
        task.name.localizedCaseInsensitiveContains(searchText)
            || task.emoji.localizedCaseInsensitiveContains(searchText)
            || (task.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            || (task.placeName?.localizedCaseInsensitiveContains(searchText) ?? false)
            || RoutineTag.matchesQuery(searchText, in: task.tags)
            || task.goalTitles.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private func handleQuickAddCreated(_ result: RoutinaQuickAddCreateResult) {
        requestRefresh()
        withAnimation(.easeOut(duration: 0.18)) {
            quickAddCreatedToast = MacQuickAddCreatedToast(
                taskID: result.taskID,
                taskName: result.taskName
            )
        }
    }

    private func openQuickAddCreatedTask(_ toast: MacQuickAddCreatedToast) {
        quickAddCreatedToast = nil
        macHomeDetailMode = .details
        taskDetailPanePlacement = nil
        RoutinaDeepLinkDispatcher.open(.task(toast.taskID))
    }

    func openAddTask() {
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        addEditFormCoordinator.resetRevealedTaskFormSections()
        store.send(.macSidebarModeChanged(.addTask))
        store.send(.setAddRoutineSheet(true))
        scheduleAddTaskNameFocus()
    }

    func openAddTodo() {
        openAddTask()
        store.send(.addRoutineSheet(.taskTypeChanged(.todo)))
    }

    private func scheduleAddTaskNameFocus() {
        let delays: [TimeInterval] = [0, 0.05, 0.15, 0.3, 0.6, 1.0, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                addEditFormCoordinator.requestNameFocus()
            }
        }
    }

    private var effectiveMacSidebarMode: HomeFeature.MacSidebarMode {
        guard !isGoalsTabEnabled else { return store.macSidebarMode }
        return store.macSidebarMode == .goals ? .routines : store.macSidebarMode
    }

    @ViewBuilder
    var locationFilterPanel: some View {
        EmptyView()
    }

    @ViewBuilder
    var homeFiltersSheet: some View {
        EmptyView()
    }

    func matchesCurrentTaskListMode(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch store.taskListMode {
        case .all:
            return true
        case .routines:
            return !task.isOneOffTask
        case .todos:
            return task.isOneOffTask
        }
    }

    var macAvailableFilters: [RoutineListFilter] {
        macHomeFilterPresentation.availableStatusFilters
    }

    var macPlaceFilterOptions: [MacPlaceFilterOption] {
        guard isPlacesEnabled else { return [] }
        return MacPlaceFilterOptionFactory.options(
            places: sortedRoutinePlaces,
            displays: store.routineDisplays
                + store.awayRoutineDisplays
                + store.archivedRoutineDisplays,
            taskListMode: store.taskListMode,
            locationSnapshot: store.locationSnapshot
        )
    }

    var platformTimelineRangePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Range",
            options: TimelineRange.allCases,
            selection: Binding(
                get: { store.selectedTimelineRange },
                set: { store.send(.selectedTimelineRangeChanged($0)) }
            )
        ) { range in
            Text(range.rawValue)
        }
    }

    @ViewBuilder
    var platformTimelineTypePicker: some View {
        if areMacTimelineQuickFiltersVisible {
            TimelinePigmentControl(
                selection: Binding(
                    get: {
                        store.selectedTimelineFilterType.normalized(
                            includingEventEmotion: areMacEventEmotionActionsEnabled,
                            includingPlaces: isPlacesEnabled,
                            includingNotes: isNotesEnabled,
                            includingAway: isAwayEnabled,
                            includingSleep: includesMacSleepTimelineFilters
                        )
                    },
                    set: {
                        store.send(.selectedTimelineFilterTypeChanged(
                            $0.normalized(
                                includingEventEmotion: areMacEventEmotionActionsEnabled,
                                includingPlaces: isPlacesEnabled,
                                includingNotes: isNotesEnabled,
                                includingAway: isAwayEnabled,
                                includingSleep: includesMacSleepTimelineFilters
                            )
                        ))
                    }
                ),
                includesEventEmotion: areMacEventEmotionActionsEnabled,
                includesPlaces: isPlacesEnabled,
                includesNotes: isNotesEnabled,
                includesAway: isAwayEnabled,
                includesSleep: includesMacSleepTimelineFilters
            )
        }
    }

    @ViewBuilder
    var platformTagFilterBar: some View {
        if homeTagFilterData.hasTags {
            HomeMacRoutineTagFiltersView(
                bindings: homeFilterBindings.tagRules,
                data: homeTagFilterData,
                actions: homeTagFilterActions
            )
        }
    }

    @ViewBuilder
    var platformCompactHomeHeader: some View {
        EmptyView()
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isDeleteConfirmationPresented },
            set: { store.send(.setDeleteConfirmation($0)) }
        )
    }

    private var deleteConfirmationTitle: String {
        store.pendingDeleteTaskIDs.count == 1 ? "Delete routine?" : "Delete routines?"
    }

    private var deleteConfirmationMessage: String {
        guard store.pendingDeleteTaskIDs.count == 1 else {
            return "This will permanently remove \(store.pendingDeleteTaskIDs.count) routines and their logs."
        }

        let taskID = store.pendingDeleteTaskIDs[0]
        let routineName = store.routineTasks.first(where: { $0.id == taskID })?.name ?? "this routine"
        return "This will permanently remove \(routineName) and its logs."
    }

}

struct HomeMacView: View {
    let appStore: StoreOf<AppFeature>
    let store: StoreOf<HomeFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let goalsStore: StoreOf<GoalsFeature>
    let statsStore: StoreOf<StatsFeature>

    var body: some View {
        HomeTCAView(
            store: store,
            settingsStore: settingsStore,
            goalsStore: goalsStore,
            statsStore: statsStore,
            openActiveFocusTarget: { deepLink in
                guard let deepLink else { return }
                appStore.send(.openDeepLink(deepLink))
            }
        )
        .awayModeGate()
        .sleepModeGate()
        .task {
            appStore.send(.onAppear)
            handlePendingDeepLink()
        }
        .onOpenURL(perform: handleOpenURL)
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            handleDeepLinkNotification(notification)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsStore.send(.onAppBecameActive)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: CloudKitSyncDiagnostics.didUpdateNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsStore.send(.cloudDiagnosticsUpdated)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            appStore.send(.cloudSettingsChanged)
            store.send(.onAppear)
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard let deepLink = RoutinaDeepLink(url: url) else { return }
        RoutinaDeepLinkDispatcher.open(deepLink)
    }

    @MainActor
    private func handleDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        RoutinaDeepLinkDispatcher.markHandled(deepLink)
        appStore.send(.openDeepLink(deepLink))
    }

    @MainActor
    private func handlePendingDeepLink() {
        guard let deepLink = RoutinaDeepLinkDispatcher.consumePendingDeepLink() else { return }
        appStore.send(.openDeepLink(deepLink))
    }
}
