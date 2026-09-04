import AppKit
import Combine
import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

extension HomeTCAView {
    // Typealiases for brevity — the canonical definitions live in HomeFeature
    typealias MacSidebarMode = HomeFeature.MacSidebarMode
    typealias MacSidebarSelection = HomeFeature.MacSidebarSelection

    var persistedDayPlanDisplayModeBinding: Binding<DayPlanDisplayMode> {
        Binding(
            get: { dayPlanDisplayMode },
            set: { mode in
                dayPlanDisplayMode = mode
                MacPlannerPresentationPreferencesStore.update { preferences in
                    preferences.displayMode = mode
                }
            }
        )
    }

    var persistedDayPlanCalendarTaskViewModeBinding: Binding<DayPlanCalendarTaskViewMode> {
        Binding(
            get: { dayPlanCalendarTaskViewMode },
            set: { mode in
                dayPlanCalendarTaskViewMode = mode
                MacPlannerPresentationPreferencesStore.update { preferences in
                    preferences.calendarTaskViewMode = mode
                }
            }
        )
    }

    var homeTopToolbarChrome: some View {
        HomeMacTopToolbarChrome(
            mode: homeToolbarMode,
            doneCount: store.doneStats.totalCount,
            showsDoneCount: showsDoneCountInToolbar,
            isDevelopmentAppVariant: isDevelopmentAppVariant && showsDevelopmentBadgeInToolbar,
            showsProgressModePicker: showsProgressModePickerInToolbar,
            showsPlaces: isPlacesEnabled,
            showsSearch: showsHomeToolbarSearch,
            showsSidebarToggle: !isMacBacklogMode && !isMacTaskLadderMode,
            isFilterPresented: store.isMacFilterDetailPresented,
            isFilterActive: homeToolbarFilterIsActive,
            progressMode: macHomeProgressModeBinding,
            selectedSidebarMode: macSidebarModeBinding,
            searchText: toolbarSearchTextBinding,
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
            onFocus: presentHomeToolbarFocusPicker,
            focusAvailability: homeToolbarFocusAvailability,
            onCheckIn: openCheckInFromAddMenu,
            onStartAway: openAwayFromAddMenu,
            onOpenSettings: {
                openWindow(id: RoutinaMacSceneID.settings)
            },
            onToggleFilters: toggleHomeToolbarFilters,
            isBoardInspectorPresented: isMacBoardTicketInspectorPresented,
            onToggleBoardInspector: toggleMacBoardTicketInspector,
            onToggleSidebar: toggleMacHomeSidebar
        )
    }

    var showsProgressModePickerInToolbar: Bool {
        !store.isMacFilterDetailPresented
            && isMacStatsMode
            && MacHomeProgressMode.visibleModes.count > 1
            && !isEmotionLogEditorPresented
            && !isNoteEditorPresented
            && !isAwayStartPresented
            && store.addRoutineState == nil
    }

    var showsHomeToolbarSearch: Bool {
        !isMacStatsMode
            && !isMacAddTaskMode
    }

    var homeToolbarFilterIsActive: Bool {
        if isMacBacklogMode {
            return backlogStore.filters.hasNonDefaultOptions
        }
        guard isMacRoutinesMode else { return false }
        return HomeMacFilterDetailScope.allCases.contains(where: macFilterScopeIsActive)
    }

    func toggleHomeToolbarFilters() {
        if isMacBacklogMode {
            if store.isMacFilterDetailPresented {
                closeMacFilterDetailPane()
            } else {
                withAnimation(MacHomeDetailAnimation.secondaryPane) {
                    isMacFilterDetailFullscreen = false
                    store.send(.setMacFilterDetailPresented(true))
                }
            }
            return
        }

        guard isMacRoutinesMode else { return }
        toggleMacCalendarFilterDetailFromPlanner()
    }

    var toolbarSearchTextBinding: Binding<String> {
        if isMacBacklogMode {
            return Binding(
                get: { backlogStore.searchText },
                set: { backlogStore.send(.searchTextChanged($0)) }
            )
        }
        if isMacTaskLadderMode {
            return Binding(
                get: { taskRankingStore.searchText },
                set: { taskRankingStore.send(.searchTextChanged($0)) }
            )
        }
        return searchTextBinding
    }

    var homeToolbarMode: HomeMacTopToolbarChrome.Mode {
        if isMacBoardSidebarPresented {
            return .board
        }
        if isMacGoalsMode {
            return .goals
        }
        return .standard
    }

    var homeToolbarFocusAvailability: MacFocusMenuAvailability {
        MacFocusMenuAvailability.resolve(
            hasStartableTasks: !store.routineDisplays.isEmpty || !store.awayRoutineDisplays.isEmpty,
            hasActiveFocus: !activeToolbarFocusSessions.isEmpty,
            hasActiveSprintFocus: !activeToolbarSprintFocusSessions.isEmpty
        )
    }

    func homeToolbarFocusStartTasks() -> [RoutineTask] {
        let referenceDate = Date()
        return store.routineTasks.compactMap { task in
            guard !task.isArchived(referenceDate: referenceDate, calendar: calendar),
                !task.isCompletedOneOff,
                !task.isCanceledOneOff
            else {
                return nil
            }

            return task
        }
    }

    func presentHomeToolbarFocusPicker() {
        guard !homeToolbarFocusAvailability.isDisabled else { return }
        homeToolbarFocusPickerPresentation = HomeMacFocusTimerPickerPresentation.make(
            tasks: homeToolbarFocusStartTasks(),
            focusSessions: focusSessions,
            rememberedDuration: FocusSessionStartDefaults.rememberedDuration()
        )
    }

    @ViewBuilder
    var platformNavigationContent: some View {
        ZStack(alignment: .top) {
            Group {
                if isMacBacklogMode {
                    BacklogMacView(
                        store: backlogStore,
                        onShowTaskInPlanner: showBacklogTaskInPlanner,
                        onShowTaskInTimeline: showBacklogTaskInTimeline,
                        isFilterPresented: store.isMacFilterDetailPresented,
                        isFilterFullscreen: isMacFilterDetailFullscreen,
                        onExpandFilter: expandMacFilterDetailPane,
                        onMinimizeFilter: minimizeFullscreenMacFilterDetail,
                        onCloseFilter: closeMacFilterDetailPane
                    ) {
                        BacklogMacFiltersDetailView(store: backlogStore)
                    }
                } else if isMacTaskLadderMode {
                    TaskRankingMacView(store: taskRankingStore)
                } else {
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
                        } else if areMacEventEmotionActionsEnabled && isEventEditorPresented {
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
                            let timelineSelection =
                                isMacTimelineMode
                                ? selectedMacTimelineSelection
                                : .empty
                            let adventureProgression =
                                isMacStatsMode && macHomeProgressMode.visibleSurfaceMode == .adventure
                                ? homeAdventureProgression
                                : nil
                            let isPlannerFilterDetailPresented =
                                store.isMacFilterDetailPresented
                                && macFilterDetailScope == (dayPlanDisplayMode == .list ? .timeline : .calendar)
                            let detailSurfaceMode = macHomeDetailMode.visibleSurfaceMode
                            let isPlannerSurfaceVisible =
                                !isMacBoardMode
                                && !isMacTimelineMode
                                && !isMacStatsMode
                                && !isMacSettingsMode
                                && detailSurfaceMode == .planner
                            let isPlannerTimelineListVisible =
                                isPlannerSurfaceVisible
                                && dayPlanDisplayMode == .list
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
                                dayPlanDisplayMode: persistedDayPlanDisplayModeBinding,
                                dayPlanCalendarTaskViewMode: persistedDayPlanCalendarTaskViewModeBinding,
                                dayPlanCalendarFilters: $dayPlanCalendarFilters,
                                isDayPlanCalendarFilterDetailPresented: isPlannerFilterDetailPresented,
                                plannerTimelineActivityDates: isPlannerTimelineListVisible
                                    ? groupedPlannerTimelineEntries.map(\.date)
                                    : [],
                                isPlannerTimelineFilterActive: isPlannerTimelineListVisible && macHasActiveTimelineFilters,
                                plannerTimelineFilterSummary: isPlannerTimelineListVisible ? macActiveTimelineFiltersSummary : nil,
                                plannerSearchText: macSearchPresentationText,
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
                                ),
                                filterView: {
                                    macActiveFiltersDetailView
                                },
                                plannerListView: { dateJumpRequest in
                                    macPlannerTimelineListView(dateJumpRequest: dateJumpRequest)
                                },
                                boardView: {
                                    macTodoBoardDetailView
                                },
                                boardInspectorView: {
                                    macBoardTaskInspector
                                }
                            )
                        }
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

    var isDevelopmentAppVariant: Bool {
        AppEnvironment.isDevelopmentAppVariant
    }

    func toggleMacBoardTicketInspector() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isMacBoardTicketInspectorPresented.toggle()
        }
    }

    var isMacHomeSidebarCollapsed: Bool {
        macHomeSidebarColumnVisibility == .detailOnly
    }

    func toggleMacHomeSidebar() {
        withAnimation(.easeInOut(duration: 0.22)) {
            macHomeSidebarColumnVisibility = isMacHomeSidebarCollapsed ? .all : .detailOnly
        }
    }

    func updateMacSearchSidebarReveal(for rawSearchText: String) {
        let isSearching = !rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isSearching {
            beginMacSearchSidebarRevealIfNeeded()
        } else {
            restoreMacSearchSidebarRevealIfNeeded()
        }
    }

    func scheduleMacSearchPresentationUpdate(for rawSearchText: String) {
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

    func applyMacSearchPresentation(_ rawSearchText: String) {
        macSearchPresentationText = rawSearchText
        isMacSearchPresentationCurrent = true

        let trimmedSearchText = rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        toolbarSearchHasResult =
            !trimmedSearchText.isEmpty
            && hasToolbarSearchResult(for: trimmedSearchText)
    }

    func beginMacSearchSidebarRevealIfNeeded() {
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

    func restoreMacSearchSidebarRevealIfNeeded() {
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

}
