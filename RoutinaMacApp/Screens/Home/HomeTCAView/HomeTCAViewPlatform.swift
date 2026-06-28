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
    }
}

extension HomeTCAView {
    // Typealiases for brevity — the canonical definitions live in HomeFeature
    typealias MacSidebarMode = HomeFeature.MacSidebarMode
    typealias MacSidebarSelection = HomeFeature.MacSidebarSelection

    @ToolbarContentBuilder
    var homeToolbarContent: some ToolbarContent {
        HomeMacHomeToolbarContent(
            mode: homeToolbarMode,
            showsProgressModePicker: showsProgressModePickerInToolbar,
            showsPlaces: isPlacesEnabled,
            progressMode: macHomeProgressModeBinding,
            locationSnapshot: store.locationSnapshot,
            focusStartTaskCount: homeToolbarFocusStartTaskCount,
            activePlanFocusSession: homeToolbarActivePlanFocusSession,
            isPlanFocusStartDisabled: homeToolbarIsPlanFocusStartDisabled,
            onPlaceCheckInMapRequested: {
                openMacPlacesWorkspace()
            },
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
            }
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

    private var homeToolbarMode: HomeMacHomeToolbarContent.Mode {
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
        HomeMacNavigationContent(
            isBoardMode: isMacBoardMode,
            isGoalsMode: isMacGoalsMode,
            isBoardInspectorPresented: macBoardInspectorPresentedBinding,
            addEditFormCoordinator: addEditFormCoordinator
        ) {
            macSidebarContent
                .toolbar {
                    macSidebarDoneToolbarContent
                }
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
                    onEditNote: openEditNote,
                    onDeleteNote: closeDeletedNote,
                    onToggleBoardInspector: toggleMacBoardTicketInspector,
                    onExpandTaskDetails: expandTaskDetailPane,
                    fullscreenTaskDetailReturnPlacement: fullscreenTaskDetailReturnPlacement,
                    onMinimizeFullscreenTaskDetails: minimizeFullscreenTaskDetailsAction,
                    onCloseTaskDetails: closeTaskDetailPane,
                    onCloseFullscreenTaskDetails: closeFullscreenTaskDetails,
                    addRoutineStore: self.store.scope(
                        state: \.addRoutineState,
                        action: \.addRoutineSheet
                    )
                ) {
                    macActiveFiltersDetailView
                } boardView: {
                    macTodoBoardDetailView
                } boardInspectorView: {
                    macBoardTaskInspector
                }
            }
        } homeToolbarContent: {
            homeToolbarContent
        } boardToolbarContent: {
            macBoardDetailToolbarContent
        }
    }

    @ToolbarContentBuilder
    private var macSidebarDoneToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if isDevelopmentAppVariant {
                MacToolbarStatusBadge(
                    title: "Dev Version",
                    systemImage: "hammer.fill",
                    tintColor: .systemOrange
                )
                .help("Development version")
            }

            MacToolbarStatusBadge(
                title: "\(store.doneStats.totalCount) done",
                systemImage: "checkmark.seal.fill",
                tintColor: .systemGreen
            )
            .help("\(store.doneStats.totalCount) total done")
        }
    }

    private var isDevelopmentAppVariant: Bool {
        Bundle.main.object(forInfoDictionaryKey: "RoutinaSandboxDataMode") as? Bool == true
    }

    @ToolbarContentBuilder
    var macBoardDetailToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HomeMacBoardInspectorToolbarButton(
                isPresented: isMacBoardTicketInspectorPresented,
                onToggle: toggleMacBoardTicketInspector
            )
        }
    }

    private func toggleMacBoardTicketInspector() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isMacBoardTicketInspectorPresented.toggle()
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
            onOpenQuickAdd: showQuickAddSpotlight,
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
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            alignMacDetailModeForDeepLinkNotification(notification)
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
                    .padding(.top, 18)
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
            .overlay {
                if isQuickAddSheetPresented {
                    MacQuickAddSpotlightOverlay(
                        isPresented: $isQuickAddSheetPresented,
                        onCreated: handleQuickAddCreated,
                        onLimitReached: { snapshot in
                            store.send(.subscriptionRequired(snapshot, nil))
                        }
                    )
                }
            }
            .sheet(isPresented: subscriptionPaywallBinding) {
                subscriptionPaywallContent
            }
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

    func showQuickAddSpotlight() {
        isQuickAddSheetPresented = true
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
                            includingAway: isAwayEnabled
                        )
                    },
                    set: {
                        store.send(.selectedTimelineFilterTypeChanged(
                            $0.normalized(
                                includingEventEmotion: areMacEventEmotionActionsEnabled,
                                includingPlaces: isPlacesEnabled,
                                includingNotes: isNotesEnabled,
                                includingAway: isAwayEnabled
                            )
                        ))
                    }
                ),
                includesEventEmotion: areMacEventEmotionActionsEnabled,
                includesPlaces: isPlacesEnabled,
                includesNotes: isNotesEnabled,
                includesAway: isAwayEnabled
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
