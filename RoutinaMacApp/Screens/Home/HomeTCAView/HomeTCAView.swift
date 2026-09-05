import ComposableArchitecture
import SwiftData
import SwiftUI

struct HomeMacSearchSidebarRevealSnapshot {
    let sidebarColumnVisibility: NavigationSplitViewVisibility
    let isDailyRoutinesSectionCollapsed: Bool
    let isMacPlanTodayDailyRoutinesGroupCollapsed: Bool
    let isMacFutureTasksSectionCollapsed: Bool
    let isArchivedSectionCollapsed: Bool
    let collapsedTagTaskListSectionIDsStorage: String
}

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let goalsStore: StoreOf<GoalsFeature>
    let statsStore: StoreOf<StatsFeature>?
    let backlogStore: StoreOf<BacklogFeature>
    let taskRankingStore: StoreOf<TaskRankingFeature>
    let openActiveFocusTarget: (RoutinaDeepLink?) -> Void
    @State var addEditFormCoordinator = AddEditFormCoordinator()
    let externalSearchText: Binding<String>?
    @Environment(\.calendar) var calendar
    @Environment(\.modelContext) var modelContext
    @Environment(\.openWindow) var openWindow
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) var showPersianDates = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) var taskRowHiddenFieldsRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingBacklogTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) var backlogTaskRowHiddenFieldsRawValue = HomeTaskRowVisibility.backlogDefaultStorageRawValue
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTimelineRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) var timelineRowHiddenFieldsRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingTaskLadderTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) var taskLadderTaskRowHiddenFieldsRawValue = HomeTaskRowVisibility.taskLadderDefaultStorageRawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAdventureMapEnabled.rawValue,
        store: SharedDefaults.app
    ) var isAdventureMapEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingBoardScreenEnabled.rawValue,
        store: SharedDefaults.app
    ) var isBoardScreenEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacTimelineQuickFiltersVisible.rawValue,
        store: SharedDefaults.app
    ) var areMacTimelineQuickFiltersVisible = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacHomeSectionFocusTimersEnabled.rawValue,
        store: SharedDefaults.app
    ) var areMacHomeSectionFocusTimersEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacStatusComposerEnabled.rawValue,
        store: SharedDefaults.app
    ) var isMacStatusComposerEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSettingsDevicesSectionEnabled.rawValue,
        store: SharedDefaults.app
    ) var isSettingsDevicesSectionEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) var areMacEventEmotionActionsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsWinsEnabled.rawValue,
        store: SharedDefaults.app
    ) var isStatsWinsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsSleepTabEnabled.rawValue,
        store: SharedDefaults.app
    ) var isStatsSleepTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsAchievementsEnabled.rawValue,
        store: SharedDefaults.app
    ) var isStatsAchievementsEnabled = false
    @AppStorage("macTodoBoardCompactCards", store: SharedDefaults.app)
    var isMacTodoBoardCompactCards = false
    @AppStorage("macBoardTicketInspectorPresented", store: SharedDefaults.app)
    var isMacBoardTicketInspectorPresented = true
    @AppStorage(
        UserDefaultBoolValueKey.appSettingDailyRoutinesSectionCollapsed.rawValue,
        store: SharedDefaults.app
    ) var isDailyRoutinesSectionCollapsed = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacPlanTodayDailyRoutinesGroupCollapsed.rawValue,
        store: SharedDefaults.app
    ) var isMacPlanTodayDailyRoutinesGroupCollapsed = true
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacFutureTasksSectionCollapsed.rawValue,
        store: SharedDefaults.app
    ) var isMacFutureTasksSectionCollapsed = true
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSeparateDailyRoutinesInTaskList.rawValue,
        store: SharedDefaults.app
    ) var separatesDailyRoutinesInTaskList = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowTomorrowInTaskList.rawValue,
        store: SharedDefaults.app
    ) var showsTomorrowInTaskList = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacShowDoneCountInToolbar.rawValue,
        store: SharedDefaults.app
    ) var showsDoneCountInToolbar = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacDevelopmentBadgeVisible.rawValue,
        store: SharedDefaults.app
    ) var showsDevelopmentBadgeInToolbar = true
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSeparateTodosAndRoutinesInTagTaskListSections.rawValue,
        store: SharedDefaults.app
    ) var separatesTodosAndRoutinesInTagTaskListSections = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingSeparateDeadlineStatusInTagTaskListSections.rawValue,
        store: SharedDefaults.app
    ) var separatesDeadlineStatusInTagTaskListSections = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingArchivedRoutinesSectionCollapsed.rawValue,
        store: SharedDefaults.app
    ) var isArchivedSectionCollapsed = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingCollapsedTagTaskListSections.rawValue,
        store: SharedDefaults.app
    ) var collapsedTagTaskListSectionIDsStorage = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) var customTaskSectionsRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingMacHomeTaskListSectionOrder.rawValue,
        store: SharedDefaults.app
    ) var macHomeTaskListSectionOrderRawValue = ""
    @StateObject var collapsedTagTaskListSectionIDsCache = HomeCollapsedTagTaskListSectionIDsCache()
    @State var localSearchText = ""
    @State var isManualCloudRefreshInProgress = false
    @State var manualCloudRefreshStatusText = ""
    @State var macSearchPresentationText = ""
    @State var macSearchPresentationUpdateTask: Task<Void, Never>?
    @State var isMacSearchPresentationCurrent = true
    @State var toolbarSearchHasResult = false
    @State var isCompactHeaderHidden = false
    @State var quickAddCreatedToast: MacTaskCreatedToast?
    @State var isToolbarSearchTextFocused = false
    @State var isToolbarSearchExpanded = false
    @State var toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth
    @State var toolbarSearchExpansionTransitionID = 0
    @State var toolbarSearchFocusRequestID = 0
    @State var toolbarSearchFocusDismissRequestID = 0
    @State var isToolbarSearchCreateInProgress = false
    @State var toolbarSearchCreateErrorMessage: String?
    @State var toolbarSearchReminderChoice: HomeMacToolbarSearchReminderChoice = .none
    @State var toolbarSearchCustomReminderAt = Date()
    @State var toolbarSearchEditableTaskTitle = ""
    @State var isToolbarSearchTaskTitleFocused = false
    @State var toolbarSearchTaskTitleWasEdited = false
    @State var toolbarSearchLinkMetadataURL: URL?
    @State var toolbarSearchResolvedLinkTitle: String?
    @State var toolbarSearchLinkMetadataStatus: HomeMacToolbarLinkMetadataStatus = .idle
    @State var toolbarSearchPinnedParserPreviewDraft: RoutinaQuickAddDraft?
    @State var pendingBacklogSearchCreationText: String?
    @State var macHomeNoticeToast: MacHomeNoticeToast?
    @State var isMacWindowFullscreen = false
    @State var isEventEditorPresented = false
    @State var isEmotionLogEditorPresented = false
    @State var isNoteEditorPresented = false
    @State var editingNoteID: UUID?
    @State var isAwayStartPresented = false
    @State var selectedNoteID: UUID?
    @State var isRefreshScheduled = false
    @State var hasDeferredRoutineUpdateRefresh = false
    @State var deferredRoutineUpdateRefreshTask: Task<Void, Never>?
    @State var relatedFilterTagSuggestionAnchor: String?
    @State var relatedTimelineTagSuggestionAnchor: String?
    @State var relatedStatsTagSuggestionAnchor: String?
    @State var macSharedFiltersPresentationCache: HomeMacSharedFiltersPresentationCache?
    @State var macHomeDetailMode: MacHomeDetailMode = .defaultLandingMode
    @State var macHomeProgressMode: MacHomeProgressMode = .stats
    @State var macHomeSidebarColumnVisibility: NavigationSplitViewVisibility = .all
    @State var macSearchSidebarRevealSnapshot: HomeMacSearchSidebarRevealSnapshot?
    @State var macSearchSidebarRestoreScrollRequestID = 0
    @State var macTaskSourceListScrollViewReference = MacTaskSourceListScrollViewReference()
    @State var isMacSearchSidebarRestoreInProgress = false
    @State var macFilterDetailScope: HomeMacFilterDetailScope = .taskList
    @State var macWorkspaceControlInitialTab: HomeMacFilterDetailTab = .filter
    @State var isMacFilterDetailFullscreen = false
    @State var selectedStatsDashboardScope: StatsDashboardScope = .all
    @State var macNavigationHistory = HomeMacNavigationHistory()
    @State var isRestoringMacNavigationHistory = false
    @State var taskDetailPanePlacement: MacTaskDetailPanePlacement?
    @State var plannerTaskDetailDoneSelection: MacPlannerDoneTaskDetailSelection?
    @State var dayPlanDisplayMode = MacPlannerPresentationPreferencesStore.load().displayMode
    @State var dayPlanCalendarTaskViewMode = MacPlannerPresentationPreferencesStore.load().calendarTaskViewMode
    @State var dayPlanCalendarFilters = DayPlanCalendarFilterState()
    @State var fullscreenTaskDetailReturnMode: MacHomeDetailMode?
    @State var fullscreenTaskDetailReturnPlacement: MacTaskDetailPanePlacement?
    @StateObject var dayPlanPlanner = DayPlanPlannerState(
        visibleRangeMode: MacPlannerPresentationPreferencesStore.load().visibleRangeMode,
        preferredVisibleRangeModeDidChange: { mode in
            MacPlannerPresentationPreferencesStore.update { preferences in
                preferences.visibleRangeMode = mode
            }
        }
    )
    @StateObject var macTaskListPresentationCache = HomeMacTaskListPresentationCache()
    @StateObject var macTimelinePresentationCache = HomeMacTimelinePresentationCache()
    @State var dayPlanUnplannedCompletedFilterDate: Date?
    @State var macSidebarTaskScrollRequest: MacSidebarTaskScrollRequest?
    @State var hoveredAssumedDoneTaskID: UUID?
    @State var macTimelineSidebarPresentationID = UUID()
    @State var macTimelineSidebarPositionedPresentationID: UUID?
    @State var macTimelineSidebarScrollRequest: MacTimelineSidebarScrollRequest?
    @State var isFinishedSprintsExpanded = false
    @State var placeCheckInSelectedPlaceID: UUID?
    @State var placeCheckInSelectedHistoryMarkerID: PlaceCheckInHistoryMapMarker.ID?
    @State var planningDateTaskID: UUID?
    @State var planningDateDraft = Date()
    @State var isCustomTaskSectionPromptPresented = false
    @State var customTaskSectionNameDraft = ""
    @State var pendingCustomTaskSectionTaskID: UUID?
    @State var pendingCustomTaskSectionParentID: UUID?
    @State var pendingCustomTaskSectionSurface: HomeTaskSectionSurface = .radar
    @State var isCustomTaskSectionRenamePromptPresented = false
    @State var pendingRenameCustomTaskSectionID: UUID?
    @State var customTaskSectionRenameDraft = ""
    @State var isCustomTaskSectionDeleteConfirmationPresented = false
    @State var pendingDeleteCustomTaskSectionID: UUID?
    @State var pendingDeleteCustomTaskSectionTitle = ""
    @State var homeToolbarFocusPickerPresentation: HomeMacFocusTimerPickerPresentation?
    @FocusState var isSprintCreationFieldFocused: Bool
    @FocusState var isBacklogCreationFieldFocused: Bool
    @FocusState var isSprintRenameFieldFocused: Bool
    @FocusState var isMacTaskSourceListFocused: Bool
    @Query(sort: \FocusSession.startedAt, order: .reverse) var focusSessions: [FocusSession]
    @Query(sort: \SprintFocusSessionRecord.startedAt, order: .reverse) var sprintFocusSessions: [SprintFocusSessionRecord]
    @Query(
        filter: homeFocusPauseResumeActionPredicate,
        sort: \RoutinaDeviceActionLog.timestamp,
        order: .reverse
    ) var focusSessionActionLogs: [RoutinaDeviceActionLog]
    @Query(
        filter: #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        },
        sort: \FocusSession.startedAt,
        order: .reverse
    ) var activeToolbarFocusSessions: [FocusSession]
    @Query(
        filter: #Predicate<SprintFocusSessionRecord> { session in
            session.stoppedAt == nil
        },
        sort: \SprintFocusSessionRecord.startedAt,
        order: .reverse
    ) var activeToolbarSprintFocusSessions: [SprintFocusSessionRecord]
    @Query(sort: \BoardSprintRecord.createdAt, order: .reverse) var boardSprints: [BoardSprintRecord]
    @Query(sort: \DayPlanBlockRecord.createdAt, order: .reverse) var dayPlanBlocks: [DayPlanBlockRecord]
    @Query(sort: \SleepSession.startedAt, order: .reverse) var sleepSessions: [SleepSession]
    @Query(sort: \AwaySession.startedAt, order: .reverse) var awaySessions: [AwaySession]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) var placeCheckInSessions: [PlaceCheckInSession]
    @Query var fileAttachments: [RoutineAttachment]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) var events: [RoutineEvent]
    @Query(sort: \EmotionLog.createdAt, order: .reverse) var emotionLogs: [EmotionLog]
    @Query(sort: \RoutineNote.createdAt, order: .reverse) var notes: [RoutineNote]
    @Query var noteAttachments: [RoutineNoteAttachment]

    init(
        store: StoreOf<HomeFeature>,
        settingsStore: StoreOf<SettingsFeature>,
        goalsStore: StoreOf<GoalsFeature>,
        statsStore: StoreOf<StatsFeature>? = nil,
        backlogStore: StoreOf<BacklogFeature>,
        taskRankingStore: StoreOf<TaskRankingFeature>,
        openActiveFocusTarget: @escaping (RoutinaDeepLink?) -> Void = { deepLink in
            guard let deepLink else {
                RoutinaMacWindowRouter.shared.openHomeAndActivate()
                return
            }
            RoutinaDeepLinkDispatcher.open(deepLink)
        },
        searchText: Binding<String>? = nil
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.goalsStore = goalsStore
        self.statsStore = statsStore
        self.backlogStore = backlogStore
        self.taskRankingStore = taskRankingStore
        self.openActiveFocusTarget = openActiveFocusTarget
        self.externalSearchText = searchText
    }

    var body: some View {
        homeContent
    }

    private var homeContent: some View {
        applyHomeRefreshObservers(
            to: applyPlatformHomeObservers(
                to: applyAddRoutinePresentation(
                    to: applyPlatformDeleteConfirmation(
                        to: applyPlatformRefresh(
                            to: applyCustomTaskSectionRenamePrompt(
                                to: applyCustomTaskSectionDeleteConfirmation(
                                    to: applyCustomTaskSectionPrompt(
                                        to: applyPlatformSearchExperience(
                                            to: platformNavigationContent,
                                            searchText: searchTextBinding
                                        )
                                    )
                                )
                            )
                        )
                    )
                )
            )
            .sheet(isPresented: isFilterSheetPresentedBinding) {
                homeFiltersSheet
            }
            .sheet(isPresented: planningDatePickerPresentedBinding) {
                TaskPlanningDatePickerSheet(
                    date: $planningDateDraft,
                    onCancel: dismissPlanningDatePicker,
                    onSave: savePlanningDatePicker
                )
            }
            .sheet(item: $homeToolbarFocusPickerPresentation) { presentation in
                HomeMacFocusTimerTaskPickerSheet(
                    tasks: presentation.tasks,
                    availableTags: presentation.availableTags,
                    defaults: presentation.defaults
                )
            }
            .confirmationDialog(
                "Where should this task go?",
                isPresented: Binding(
                    get: { pendingBacklogSearchCreationText != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingBacklogSearchCreationText = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                ForEach(backlogSearchCreationDestinations) { destination in
                    Button(destination.title) {
                        createBacklogSearchTask(in: destination.id)
                    }
                }

                Button("Main task list") {
                    createBacklogSearchTask(in: nil)
                }

                Button("Cancel", role: .cancel) {
                    pendingBacklogSearchCreationText = nil
                }
            } message: {
                Text("Choose a Backlog section, or add the task to your main task list.")
            }
            .task {
                syncFileAttachmentTaskIDs()
            }
            .onChange(of: fileAttachmentChangeToken) { _, _ in
                syncFileAttachmentTaskIDs()
            }
            .onAppear {
                validateMacEventEmotionFilterVisibility()
                handlePendingSleepPlannerDeepLink(store.pendingSleepPlannerSessionID)
            }
            .onChange(of: areMacEventEmotionActionsEnabled) { _, isEnabled in
                validateMacTimelineFilterVisibility()
                guard !isEnabled else { return }
                isEventEditorPresented = false
                if case let .timelineEntry(entryID) = store.macSidebarSelection,
                    events.contains(where: { $0.id == entryID })
                {
                    store.send(.macSidebarSelectionChanged(nil))
                }
            }
            .onChange(of: isGoalsTabEnabled) { _, isEnabled in
                store.send(.onAppear)
                guard !isEnabled else { return }
                goalsStore.send(.dismissEditor)
            }
            .onChange(of: isPlacesEnabled) { _, _ in
                validateMacTimelineFilterVisibility()
                if !isPlacesEnabled {
                    macHomeDetailMode = .details
                    placeCheckInSelectedPlaceID = nil
                    placeCheckInSelectedHistoryMarkerID = nil
                } else if macHomeDetailMode.visibleSurfaceMode != .places {
                    placeCheckInSelectedPlaceID = nil
                    placeCheckInSelectedHistoryMarkerID = nil
                }
            }
            .onChange(of: isNotesEnabled) { _, _ in
                validateMacTimelineFilterVisibility()
                if !isNotesEnabled {
                    isNoteEditorPresented = false
                    editingNoteID = nil
                    selectedNoteID = nil
                }
            }
            .onChange(of: isAwayEnabled) { _, _ in
                validateMacTimelineFilterVisibility()
                if !isAwayEnabled {
                    closeAwayStart()
                }
            }
            .onChange(of: isStatsSleepTabEnabled) { _, _ in
                validateMacTimelineFilterVisibility()
            }
            .onChange(of: store.selectedTimelineFilterType) { _, _ in
                validateMacTimelineFilterVisibility()
            }
            .onChange(of: store.pendingSleepPlannerSessionID) { _, sleepID in
                handlePendingSleepPlannerDeepLink(sleepID)
            }
            .onChange(of: macHomeDetailMode) { _, mode in
                if mode.visibleSurfaceMode != .planner {
                    dayPlanPlanner.clearPlannerUndo()
                }
                normalizeTaskDetailPanePlacement()
            }
            .onChange(of: store.macSidebarMode) { _, mode in
                if mode != .routines {
                    dayPlanPlanner.clearPlannerUndo()
                }
            }
        )
        .environment(\.routinaMacOpenFocusTimerTarget, openFocusTimerTarget)
    }
}
