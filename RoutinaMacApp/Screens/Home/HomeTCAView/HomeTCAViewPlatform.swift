import AppKit
import Combine
import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

private enum HomeSidebarSizing {
    static let minWidth: CGFloat = 220
    static let idealWidth: CGFloat = 300
    static let maxWidth: CGFloat = 360
}

private enum HomeMacSearchPresentationPolicy {
    static let inputDebounce: Duration = .milliseconds(120)
}

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        navigationSplitViewColumnWidth(
            min: HomeSidebarSizing.minWidth,
            ideal: HomeSidebarSizing.idealWidth,
            max: HomeSidebarSizing.maxWidth
        )
        .routinaHomeSidebarSplitViewConstraints()
    }

    func routinaHomeSidebarSplitViewConstraints() -> some View {
        self.background(
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

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                context.allowsImplicitAnimation = false
                splitView.setPosition(clampedWidth, ofDividerAt: 0)
                splitView.layoutSubtreeIfNeeded()
            }
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
            showsDoneCount: showsDoneCountInToolbar,
            isDevelopmentAppVariant: isDevelopmentAppVariant && showsDevelopmentBadgeInToolbar,
            showsProgressModePicker: showsProgressModePickerInToolbar,
            showsPlaces: isPlacesEnabled,
            showsSearch: showsHomeToolbarSearch,
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
            onSearchSubmit: { rawText in
                createTaskFromToolbarSearch(rawText)
            },
            onSearchCommandSubmit: openAddTaskFromToolbarSearch,
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

    private var showsHomeToolbarSearch: Bool {
        !isMacStatsMode && !isMacAddTaskMode
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
        activeToolbarFocusSessions
    }

    private var homeToolbarFocusStartDisplayCount: Int {
        store.routineDisplays.count + store.awayRoutineDisplays.count
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

    private func presentHomeToolbarFocusPicker() {
        let availableTags = FocusSessionTagRecency.orderedAvailableTags(
            RoutineTag.allTags(from: homeToolbarFocusStartTasks.map(\.tags)),
            focusSessions: focusSessions
        )
        homeToolbarFocusPickerAvailableTags = availableTags
        homeToolbarFocusPickerDefaults = FocusSessionStartDefaults.latest(
            focusSessions: focusSessions,
            availableTags: availableTags
        )
        isHomeToolbarFocusPickerPresented = true
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
                    let isPlannerFilterDetailPresented = store.isMacFilterDetailPresented
                        && macFilterDetailScope == (dayPlanDisplayMode == .list ? .timeline : .calendar)
                    let detailSurfaceMode = macHomeDetailMode.visibleSurfaceMode
                    let isPlannerSurfaceVisible = !isMacBoardMode
                        && !isMacTimelineMode
                        && !isMacStatsMode
                        && !isMacSettingsMode
                        && detailSurfaceMode == .planner
                    let isPlannerTimelineListVisible = isPlannerSurfaceVisible
                        && dayPlanDisplayMode == .list
                    let toolbarActiveFocusSessions = homeToolbarActiveFocusSessions
                    let toolbarActivePlanFocusSession = toolbarActiveFocusSessions.first(where: \.isUnassigned)
                    let toolbarIsPlanFocusStartDisabled = toolbarActivePlanFocusSession != nil
                        || toolbarActiveFocusSessions.contains { !$0.isUnassigned }
                        || !activeToolbarSprintFocusSessions.isEmpty
                    let toolbarFocusStartTaskCount = toolbarActivePlanFocusSession == nil
                        ? homeToolbarFocusStartDisplayCount
                        : 0

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
                        dayPlanCalendarTaskViewMode: $dayPlanCalendarTaskViewMode,
                        dayPlanCalendarFilters: $dayPlanCalendarFilters,
                        isDayPlanCalendarFilterDetailPresented: isPlannerFilterDetailPresented,
                        plannerTimelineActivityDates: isPlannerTimelineListVisible
                            ? groupedPlannerTimelineEntries.map(\.date)
                            : [],
                        isPlannerTimelineFilterActive: isPlannerTimelineListVisible && macHasActiveTimelineFilters,
                        plannerTimelineFilterSummary: isPlannerTimelineListVisible ? macActiveTimelineFiltersSummary : nil,
                        plannerSearchText: macSearchPresentationText,
                        focusStartTaskCount: toolbarFocusStartTaskCount,
                        activePlanFocusSession: toolbarActivePlanFocusSession,
                        isPlanFocusStartDisabled: toolbarIsPlanFocusStartDisabled,
                        isBoardInspectorPresented: macBoardInspectorPresentedBinding,
                        taskDetailPanePlacement: $taskDetailPanePlacement,
                        plannerTaskDetailDoneSelection: plannerTaskDetailDoneSelection,
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
                        onOpenDayPlanCalendarListTaskDetails: { item, date in
                            openDayPlanCalendarListTaskDetails(item, on: date)
                        },
                        onOpenEventDetails: openSavedEvent,
                        onToggleDayPlanCalendarFilters: toggleMacCalendarFilterDetailFromPlanner,
                        onTaskFocusRequested: {
                            presentHomeToolbarFocusPicker()
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
                        taskSidebarLocation: macTaskSourceListSidebarLocation,
                        onLocateTaskInSidebar: scrollSelectedTaskInMacSidebar,
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
        .background(
            HomeMacWindowFullscreenObserver(isFullscreen: $isMacWindowFullscreen)
        )
        .routinaMacHomeToolbarTitlebarIntegration(isFullscreen: isMacWindowFullscreen)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
    }

    private var isDevelopmentAppVariant: Bool {
        AppEnvironment.isDevelopmentAppVariant
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

    private func updateMacSearchSidebarReveal(for rawSearchText: String) {
        let isSearching = !rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isSearching {
            beginMacSearchSidebarRevealIfNeeded()
        } else {
            restoreMacSearchSidebarRevealIfNeeded()
        }
    }

    private func scheduleMacSearchPresentationUpdate(for rawSearchText: String) {
        macSearchPresentationUpdateTask?.cancel()

        let trimmedSearchText = rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
            applyMacSearchPresentation(rawSearchText)
            return
        }

        isMacSearchPresentationCurrent = false
        macSearchPresentationUpdateTask = Task { @MainActor in
            do {
                try await Task.sleep(for: HomeMacSearchPresentationPolicy.inputDebounce)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            applyMacSearchPresentation(rawSearchText)
        }
    }

    private func applyMacSearchPresentation(_ rawSearchText: String) {
        macSearchPresentationText = rawSearchText
        isMacSearchPresentationCurrent = true

        let trimmedSearchText = rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        toolbarSearchHasResult = !trimmedSearchText.isEmpty
            && hasToolbarSearchResult(for: trimmedSearchText)
    }

    private func beginMacSearchSidebarRevealIfNeeded() {
        isMacSearchSidebarRestoreInProgress = false
        guard macSearchSidebarRevealSnapshot == nil else {
            if macHomeSidebarColumnVisibility != .all {
                withAnimation(.easeInOut(duration: 0.22)) {
                    macHomeSidebarColumnVisibility = .all
                }
            }
            return
        }

        let snapshot = HomeMacSearchSidebarRevealSnapshot(
            sidebarColumnVisibility: macHomeSidebarColumnVisibility,
            isDailyRoutinesSectionCollapsed: isDailyRoutinesSectionCollapsed,
            isMacPlanTodayDailyRoutinesGroupCollapsed: isMacPlanTodayDailyRoutinesGroupCollapsed,
            isMacFutureTasksSectionCollapsed: isMacFutureTasksSectionCollapsed,
            isArchivedSectionCollapsed: isArchivedSectionCollapsed,
            collapsedTagTaskListSectionIDsStorage: collapsedTagTaskListSectionIDsStorage
        )

        withAnimation(.easeInOut(duration: 0.22)) {
            macSearchSidebarRevealSnapshot = snapshot
            macHomeSidebarColumnVisibility = .all
        }
    }

    private func restoreMacSearchSidebarRevealIfNeeded() {
        guard let snapshot = macSearchSidebarRevealSnapshot else { return }

        withTransaction(Transaction(animation: nil)) {
            isMacSearchSidebarRestoreInProgress = true
            isDailyRoutinesSectionCollapsed = snapshot.isDailyRoutinesSectionCollapsed
            isMacPlanTodayDailyRoutinesGroupCollapsed = snapshot.isMacPlanTodayDailyRoutinesGroupCollapsed
            isMacFutureTasksSectionCollapsed = snapshot.isMacFutureTasksSectionCollapsed
            isArchivedSectionCollapsed = snapshot.isArchivedSectionCollapsed
            collapsedTagTaskListSectionIDsStorage = snapshot.collapsedTagTaskListSectionIDsStorage
            macHomeSidebarColumnVisibility = snapshot.sidebarColumnVisibility
            macSearchSidebarRevealSnapshot = nil
            macSearchSidebarRestoreScrollRequestID += 1
        }

        let handledRequestID = macSearchSidebarRestoreScrollRequestID
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard macSearchSidebarRestoreScrollRequestID == handledRequestID else { return }
            isMacSearchSidebarRestoreInProgress = false
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
            .onAppear {
                updateMacSearchSidebarReveal(for: searchText.wrappedValue)
                applyMacSearchPresentation(searchText.wrappedValue)
            }
            .onChange(of: searchText.wrappedValue) { _, newValue in
                updateMacSearchSidebarReveal(for: newValue)
                scheduleMacSearchPresentationUpdate(for: newValue)
            }
            .onDisappear {
                macSearchPresentationUpdateTask?.cancel()
            }
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
            .safeAreaInset(edge: .top) {
                if isManualCloudRefreshInProgress {
                    HomeManualCloudRefreshProgressBanner(
                        statusText: manualCloudRefreshStatusText
                    )
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: CloudKitSyncDiagnostics.didUpdateNotification
                )
            ) { _ in
                updateManualCloudRefreshStatus()
            }
            .alert(
                "Couldn't Refresh from iCloud",
                isPresented: Binding(
                    get: { store.manualRefreshErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.manualRefreshErrorDismissed)
                        }
                    }
                )
            ) {
                Button("Try Again") {
                    Task { @MainActor in
                        await performManualCloudRefresh()
                    }
                }
                Button("OK", role: .cancel) {
                    store.send(.manualRefreshErrorDismissed)
                }
            } message: {
                Text(store.manualRefreshErrorMessage ?? "")
            }
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        MacToolbarIconButton(title: "Sync with iCloud", systemImage: "arrow.clockwise") {
            Task { @MainActor in
                await performManualCloudRefresh()
            }
        }
    }

    @MainActor
    func performManualCloudRefresh() async {
        guard !isManualCloudRefreshInProgress else { return }

        isManualCloudRefreshInProgress = true
        manualCloudRefreshStatusText = "Checking iCloud for updates…"
        defer {
            isManualCloudRefreshInProgress = false
            manualCloudRefreshStatusText = ""
        }

        await store.send(.manualRefreshRequested).finish()
    }

    func updateManualCloudRefreshStatus() {
        guard isManualCloudRefreshInProgress else { return }

        let message = CloudKitSyncDiagnostics.snapshot().manualRefreshDisplayMessage
        if !message.isEmpty {
            manualCloudRefreshStatusText = message
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
            onOpenStats: openStatsInSidebar,
            onScrollSelectedTaskInSidebar: scrollSelectedTaskInMacSidebar
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
                plannerTaskDetailDoneSelection = nil
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
        .onChange(of: showsHomeToolbarSearch) { _, showsSearch in
            if !showsSearch {
                dismissToolbarSearchFocus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            alignMacDetailModeForDeepLinkNotification(notification)
        }
    }

    private func focusExpandedToolbarSearchFromCommand() {
        guard showsHomeToolbarSearch else { return }
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

    private func dismissToolbarSearchFocus() {
        guard isToolbarSearchTextFocused || isToolbarSearchExpanded else { return }
        toolbarSearchExpansionTransitionID += 1
        isToolbarSearchTextFocused = false
        isToolbarSearchExpanded = false
        toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth
        toolbarSearchFocusDismissRequestID += 1
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
            return "Search tasks"
        case .routines:
            return "Search routines"
        case .todos:
            return "Search todos"
        }
    }

    func applyAddRoutinePresentation<Content: View>(to content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showsHomeToolbarSearch,
                   let toolbarSearchCreateDraft,
                   isToolbarSearchExpanded || isToolbarSearchTaskTitleFocused {
                    HomeMacToolbarSearchParserPreview(
                        draft: toolbarSearchCreateDraft,
                        taskTitle: toolbarSearchTaskTitleBinding(for: toolbarSearchCreateDraft),
                        isTaskTitleFocused: $isToolbarSearchTaskTitleFocused,
                        reminderChoice: $toolbarSearchReminderChoice,
                        customReminderAt: $toolbarSearchCustomReminderAt,
                        linkMetadataStatus: toolbarSearchLinkMetadataStatus,
                        onSubmit: { submission in
                            createTaskFromToolbarSearch(
                                searchTextBinding.wrappedValue,
                                draft: toolbarSearchCreateDraft,
                                submission: submission
                            )
                        }
                    )
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
                }
            }
            .overlay(alignment: .topTrailing) {
                VStack(alignment: .trailing, spacing: 10) {
                    if let taskCreationConfirmation = store.taskCreationConfirmation {
                        let toast = MacTaskCreatedToast(
                            id: taskCreationConfirmation.id,
                            taskID: taskCreationConfirmation.taskID,
                            taskName: taskCreationConfirmation.taskName
                        )

                        MacTaskCreatedToastView(
                            toast: toast,
                            onOpen: nil,
                            onClose: {
                                store.send(.dismissTaskCreationConfirmation)
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: toast.id) {
                            do {
                                try await Task.sleep(for: .seconds(10))
                                await MainActor.run {
                                    if store.taskCreationConfirmation?.id == toast.id {
                                        store.send(.dismissTaskCreationConfirmation)
                                    }
                                }
                            } catch {}
                        }
                    }

                    if let quickAddCreatedToast {
                        MacTaskCreatedToastView(
                            toast: quickAddCreatedToast,
                            onOpen: {
                                openQuickAddCreatedTask(quickAddCreatedToast)
                            },
                            onClose: {
                                self.quickAddCreatedToast = nil
                            }
                        )
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

                    if let macHomeNoticeToast {
                        MacHomeNoticeToastView(
                            toast: macHomeNoticeToast,
                            onClose: {
                                self.macHomeNoticeToast = nil
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: macHomeNoticeToast.id) {
                            do {
                                try await Task.sleep(for: .seconds(5))
                                await MainActor.run {
                                    if self.macHomeNoticeToast?.id == macHomeNoticeToast.id {
                                        self.macHomeNoticeToast = nil
                                    }
                                }
                            } catch {}
                        }
                    }
                }
                .padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight + 18)
                .padding(.trailing, 22)
            }
            .animation(
                .easeOut(duration: 0.12),
                value: toolbarSearchCreateDraft
            )
            .animation(
                .easeOut(duration: 0.18),
                value: store.taskCreationConfirmation
            )
            .onChange(of: searchTextBinding.wrappedValue) { oldValue, newValue in
                reconcileToolbarSearchPreviewState(
                    previousText: oldValue,
                    currentText: newValue
                )
            }
            .task(id: toolbarSearchLinkResolutionID) {
                guard let draft = RoutinaQuickAddParser.parse(
                    searchTextBinding.wrappedValue,
                    calendar: calendar,
                    includingPlaces: isPlacesEnabled
                ) else { return }
                await resolveToolbarSearchLinkTitle(for: draft)
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

    var canCreateTaskFromToolbarSearch: Bool {
        let trimmedText = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty
            && !isToolbarSearchCreateInProgress
            && isMacSearchPresentationCurrent
            && !toolbarSearchHasResult
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

    private var toolbarSearchLinkResolutionID: String? {
        guard let draft = RoutinaQuickAddParser.parse(
            searchTextBinding.wrappedValue,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        ),
              let linkURL = draft.primaryLinkURL else {
            return nil
        }
        return linkURL.absoluteString
    }

    private func toolbarSearchTaskTitleBinding(
        for draft: RoutinaQuickAddDraft
    ) -> Binding<String> {
        Binding(
            get: { toolbarSearchEffectiveTaskTitle(for: draft) },
            set: { newValue in
                toolbarSearchEditableTaskTitle = newValue
                toolbarSearchTaskTitleWasEdited = true
            }
        )
    }

    private func toolbarSearchEffectiveTaskTitle(for draft: RoutinaQuickAddDraft) -> String {
        return toolbarSearchEditableTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? draft.name
            : toolbarSearchEditableTaskTitle
    }

    private func reconcileToolbarSearchPreviewState(
        previousText: String,
        currentText: String
    ) {
        let previousDraft = RoutinaQuickAddParser.parse(
            previousText,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        )
        let currentDraft = RoutinaQuickAddParser.parse(
            currentText,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        )

        guard RoutinaQuickAddDraftContinuity.canPreservePreviewState(
            previousText: previousText,
            currentText: currentText,
            previousDraft: previousDraft,
            currentDraft: currentDraft
        ) else {
            resetToolbarSearchPreviewState(for: currentDraft)
            return
        }

        guard !toolbarSearchTaskTitleWasEdited,
              let currentDraft else {
            return
        }
        toolbarSearchEditableTaskTitle = defaultToolbarSearchTaskTitle(for: currentDraft)
    }

    private func resetToolbarSearchPreviewState(for draft: RoutinaQuickAddDraft?) {
        toolbarSearchReminderChoice = .none
        toolbarSearchCustomReminderAt = Date()
        toolbarSearchEditableTaskTitle = draft?.name ?? ""
        toolbarSearchTaskTitleWasEdited = false
        toolbarSearchLinkMetadataURL = nil
        toolbarSearchResolvedLinkTitle = nil
        toolbarSearchLinkMetadataStatus = .idle
    }

    private func defaultToolbarSearchTaskTitle(for draft: RoutinaQuickAddDraft) -> String {
        guard draft.usesGeneratedLinkName,
              toolbarSearchLinkMetadataURL == draft.primaryLinkURL,
              let toolbarSearchResolvedLinkTitle,
              let linkURL = draft.primaryLinkURL else {
            return draft.name
        }
        return RoutinaQuickAddLinkSupport.taskTitle(
            fromMetadataTitle: toolbarSearchResolvedLinkTitle,
            url: linkURL
        ) ?? draft.name
    }

    @MainActor
    private func resolveToolbarSearchLinkTitle(for draft: RoutinaQuickAddDraft) async {
        guard let linkURL = draft.primaryLinkURL else { return }
        if toolbarSearchLinkMetadataURL == linkURL {
            switch toolbarSearchLinkMetadataStatus {
            case .resolved, .unavailable:
                return
            case .idle, .loading:
                break
            }
        }
        toolbarSearchLinkMetadataURL = linkURL
        guard RoutinaQuickAddLinkSupport.canFetchMetadata(for: linkURL) else {
            toolbarSearchLinkMetadataStatus = .unavailable
            return
        }

        toolbarSearchLinkMetadataStatus = .loading
        let metadataTitle = await HomeMacLinkMetadataResolver.title(for: linkURL)
        guard !Task.isCancelled,
              toolbarSearchLinkMetadataURL == linkURL,
              let currentDraft = RoutinaQuickAddParser.parse(
                  searchTextBinding.wrappedValue,
                  calendar: calendar,
                  includingPlaces: isPlacesEnabled
              ),
              currentDraft.primaryLinkURL == linkURL else {
            return
        }

        guard let metadataTitle else {
            toolbarSearchLinkMetadataStatus = .unavailable
            return
        }

        toolbarSearchResolvedLinkTitle = metadataTitle
        toolbarSearchLinkMetadataStatus = .resolved
        if currentDraft.usesGeneratedLinkName,
           !toolbarSearchTaskTitleWasEdited,
           let suggestedTitle = RoutinaQuickAddLinkSupport.taskTitle(
               fromMetadataTitle: metadataTitle,
               url: linkURL
           ) {
            toolbarSearchEditableTaskTitle = suggestedTitle
        }
    }

    private func createTaskFromToolbarSearch(
        _ rawText: String,
        draft: RoutinaQuickAddDraft? = nil,
        submission: HomeMacToolbarQuickAddSubmission? = nil
    ) {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
              !isToolbarSearchCreateInProgress,
              !hasToolbarSearchResult(for: trimmedText) else {
            return
        }

        toolbarSearchCreateErrorMessage = nil
        isToolbarSearchCreateInProgress = true
        let createDraft = draft ?? RoutinaQuickAddParser.parse(
            trimmedText,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        )
        let resolvedSubmission = submission ?? createDraft.map { draft in
            HomeMacToolbarQuickAddSubmission(
                draft: draft,
                taskTitle: toolbarSearchEffectiveTaskTitle(for: draft),
                reminderChoice: toolbarSearchReminderChoice,
                customReminderAt: toolbarSearchCustomReminderAt,
                calendar: calendar
            )
        }
        let primaryLinkTitle = createDraft?.primaryLinkURL == toolbarSearchLinkMetadataURL
            ? toolbarSearchResolvedLinkTitle
            : nil

        Task { @MainActor in
            defer { isToolbarSearchCreateInProgress = false }

            do {
                let result = try await RoutinaQuickAddService.createTask(
                    from: trimmedText,
                    context: modelContext,
                    calendar: calendar,
                    includingPlaces: isPlacesEnabled,
                    reminderAt: resolvedSubmission?.reminderAt,
                    taskNameOverride: resolvedSubmission?.taskTitle,
                    primaryLinkTitle: primaryLinkTitle
                )
                searchTextBinding.wrappedValue = ""
                resetToolbarSearchPreviewState(for: nil)
                isToolbarSearchTaskTitleFocused = false
                handleQuickAddCreated(result)
            } catch {
                toolbarSearchCreateErrorMessage = error.localizedDescription
            }
        }
    }

    func openAddTaskFromToolbarSearch(_ rawText: String) {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        toolbarSearchCreateErrorMessage = nil
        addEditFormCoordinator.resetRevealedTaskFormSections()
        isToolbarSearchTextFocused = false
        toolbarSearchFocusDismissRequestID += 1
        searchTextBinding.wrappedValue = ""
        quickAddCreatedToast = nil
        store.send(.openAddTaskSheet(seedName: trimmedText))
        scheduleAddTaskNameFocus()
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
            quickAddCreatedToast = MacTaskCreatedToast(
                taskID: result.taskID,
                taskName: result.taskName
            )
        }
    }

    private func openQuickAddCreatedTask(_ toast: MacTaskCreatedToast) {
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
            return task.scheduleMode.taskType == .routine
                || task.scheduleMode.taskType == .record
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
        let showsFlagFilters = !isMacBoardSidebarPresented && homeFlagFilterData.hasFlags
        if homeTagFilterData.hasTags || showsFlagFilters {
            VStack(alignment: .leading, spacing: 16) {
                if homeTagFilterData.hasTags {
                    HomeMacRoutineTagFiltersView(
                        bindings: homeFilterBindings.tagRules,
                        data: homeTagFilterData,
                        actions: homeTagFilterActions
                    )
                }

                if showsFlagFilters {
                    HomeMacRoutineFlagFiltersView(
                        includeFlagMatchMode: homeFilterBindings.includeFlagMatchMode,
                        data: homeFlagFilterData,
                        actions: homeFlagFilterActions
                    )
                }
            }
        }
    }

    @ViewBuilder
    var platformFlagFilterBar: some View {
        if !isMacBoardSidebarPresented, homeFlagFilterData.hasFlags {
            HomeMacRoutineFlagFiltersView(
                includeFlagMatchMode: homeFilterBindings.includeFlagMatchMode,
                data: homeFlagFilterData,
                actions: homeFlagFilterActions
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

private struct HomeManualCloudRefreshProgressBanner: View {
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView()
                .progressViewStyle(.linear)
                .accessibilityLabel("Receiving iCloud data")
                .accessibilityValue(statusText)
            Text(statusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
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

private extension View {
    @ViewBuilder
    func routinaMacHomeToolbarTitlebarIntegration(isFullscreen: Bool) -> some View {
        if isFullscreen {
            self
        } else {
            ignoresSafeArea(edges: .top)
        }
    }
}

private struct HomeMacWindowFullscreenObserver: NSViewRepresentable {
    @Binding var isFullscreen: Bool

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isFullscreen = $isFullscreen
        context.coordinator.attach(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isFullscreen: $isFullscreen)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: @unchecked Sendable {
        var isFullscreen: Binding<Bool>
        private weak var observedWindow: NSWindow?
        private var notificationObservers: [NSObjectProtocol] = []
        private var isAttachRetryScheduled = false

        init(isFullscreen: Binding<Bool>) {
            self.isFullscreen = isFullscreen
        }

        func attach(to view: NSView) {
            guard let window = view.window else {
                guard !isAttachRetryScheduled else { return }
                isAttachRetryScheduled = true
                Task { @MainActor [weak self, weak view] in
                    self?.isAttachRetryScheduled = false
                    guard let view else { return }
                    self?.attach(to: view)
                }
                return
            }

            guard observedWindow !== window else {
                update(from: window)
                return
            }

            detach()
            observedWindow = window
            update(from: window)

            let center = NotificationCenter.default
            notificationObservers = [
                center.addObserver(
                    forName: NSWindow.willEnterFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.setFullscreen(true)
                    }
                },
                center.addObserver(
                    forName: NSWindow.didEnterFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    Task { @MainActor [weak self, weak window] in
                        guard let window else { return }
                        self?.update(from: window)
                    }
                },
                center.addObserver(
                    forName: NSWindow.willExitFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.setFullscreen(false)
                    }
                },
                center.addObserver(
                    forName: NSWindow.didExitFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    Task { @MainActor [weak self, weak window] in
                        guard let window else { return }
                        self?.update(from: window)
                    }
                },
            ]
        }

        func detach() {
            notificationObservers.forEach(NotificationCenter.default.removeObserver)
            notificationObservers.removeAll()
            observedWindow = nil
        }

        private func update(from window: NSWindow) {
            setFullscreen(window.styleMask.contains(.fullScreen))
        }

        private func setFullscreen(_ value: Bool) {
            guard isFullscreen.wrappedValue != value else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isFullscreen.wrappedValue != value else { return }
                self.isFullscreen.wrappedValue = value
            }
        }
    }
}
