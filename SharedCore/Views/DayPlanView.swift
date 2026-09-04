import SwiftData
import SwiftUI

struct DayPlanTimelinePanelContentView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @ObservedObject var planner: DayPlanPlannerState
    var onSelectUnplannedCompletedDate: ((Date) -> Void)?
    var onOpenTaskDetails: ((UUID) -> Void)?
    var onOpenCalendarListTaskDetails: ((DayPlanDayTaskListItem, Date) -> Void)?
    var onOpenEventDetails: ((UUID) -> Void)?
    var dataSnapshotID: UUID
    var tasks: [RoutineTask]
    var logs: [RoutineLog]
    var sleepSessions: [SleepSession]
    var awaySessions: [AwaySession]
    var events: [RoutineEvent]
    var sprintFocusSessions: [SprintFocusSessionRecord]
    var sprintFocusAllocations: [SprintFocusAllocationRecord]
    var boardSprints: [BoardSprintRecord]
    var focusSessions: [FocusSession]
    var includesEvents: Bool
    var includesAway: Bool
    @ObservedObject var timelinePlacementCache: DayPlanTimelinePlacementCache
    @ObservedObject var allDayBlocksCache: DayPlanAllDayBlocksCache
    @ObservedObject var visibleBlockContextCache: DayPlanVisibleBlockContextCache
    @ObservedObject var sleepBlocksCache: DayPlanSleepBlocksCache
    @ObservedObject var awayBlocksCache: DayPlanAwayBlocksCache
    @ObservedObject var completedSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache
    @ObservedObject var activeSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache
    @ObservedObject var renderSnapshotCache: DayPlanTimelineRenderSnapshotCache
    @ObservedObject var calendarTaskFilterCache: DayPlanCalendarTaskFilterCache
    @ObservedObject var plannedDateTaskVisibilityCache: DayPlanPlannedDateTaskVisibilityCache
    @ObservedObject var dayTaskListItemsCache: DayPlanDayTaskListItemsCache
    var calendarFilters: Binding<DayPlanCalendarFilterState> = .constant(DayPlanCalendarFilterState())
    var calendarSearchText = ""
    var calendarTaskFilter: (RoutineTask) -> Bool = { _ in true }
    var calendarTaskFilterCacheSeed = 0
    var calendarListRevealsHiddenTasks = false
    var calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule
    var isCalendarFilterSidebarPresented: Binding<Bool> = .constant(false)
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var parentAvailableWidth: CGFloat?
    var isExternalInspectorPresented = false
    var onSidebarPresentationRequested: (() -> Void)?
    @State private var selectedEventID: UUID?
    @State private var dayTaskResolutionOverlay = DayPlanDayTaskResolutionOverlay()
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowTimelineTasksInDayPlanner.rawValue,
        store: SharedDefaults.app
    ) private var showsTimelineTasksInDayPlanner = true
    @AppStorage(
        UserDefaultStringValueKey.appSettingHiddenDayPlanTimelineActivityIDs.rawValue,
        store: SharedDefaults.app
    ) private var hiddenTimelineActivityStorage = ""

    var body: some View {
        let referenceDate = Date()
        let renderSnapshot = renderSnapshotCache.snapshot(
            dataSnapshotID: dataSnapshotID,
            planner: planner,
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: events,
            includesEvents: includesEvents,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions,
            referenceDate: referenceDate,
            calendar: calendar,
            modelContext: modelContext,
            showsTimelineTasksInDayPlanner: showsTimelineTasksInDayPlanner,
            hiddenTimelineActivityStorage: hiddenTimelineActivityStorage,
            timelinePlacementCache: timelinePlacementCache,
            allDayBlocksCache: allDayBlocksCache,
            visibleBlockContextCache: visibleBlockContextCache,
            sleepBlocksCache: sleepBlocksCache,
            awayBlocksCache: awayBlocksCache,
            completedSprintFocusBlocksCache: completedSprintFocusBlocksCache,
            activeSprintFocusBlocksCache: activeSprintFocusBlocksCache
        )
        let visibleDates = renderSnapshot.visibleDates
        let taskFilterSnapshot = calendarTaskFilterCache.snapshot(
            dataSnapshotID: dataSnapshotID,
            tasks: renderSnapshot.tasks,
            filterSeed: calendarTaskFilterCacheSeed,
            revealsHiddenCalendarListTasks: calendarListRevealsHiddenTasks,
            filter: calendarTaskFilter
        )
        let allTaskIDs = taskFilterSnapshot.allTaskIDs
        let currentTasks = taskFilterSnapshot.currentTasks
        let currentSleepSessions = renderSnapshot.sleepSessions
        let currentAwaySessions = renderSnapshot.awaySessions
        let currentFocusSessions = renderSnapshot.focusSessions
        let currentSprintFocusAllocations = renderSnapshot.sprintFocusAllocations
        let currentBoardSprints = renderSnapshot.boardSprints
        let plannedBlocksByDayKey = renderSnapshot.plannedBlocksByDayKey
        let rawPlannedBlocks = renderSnapshot.rawPlannedBlocks
        let sleepBlocksByDayKey = renderSnapshot.sleepBlocksByDayKey
        let linkedAwayBlocksByDayKey = renderSnapshot.linkedAwayBlocksByDayKey
        let sprintFocusBlocksByDayKey = renderSnapshot.sprintFocusBlocksByDayKey
        let eventBlocksByDayKey = renderSnapshot.eventBlocksByDayKey
        let blockedIntervalsByDayKey = renderSnapshot.blockedIntervalsByDayKey
        let timelineBlocksByDayKey = renderSnapshot.timelineBlocksByDayKey
        let unplaceableAutomaticSuggestionBlocksByDayKey = renderSnapshot.unplaceableAutomaticSuggestionBlocksByDayKey
        let automaticSuggestionBlocksByDayKey = renderSnapshot.automaticSuggestionBlocksByDayKey
        let assumedDoneSummaryBlocksByDayKey = renderSnapshot.assumedDoneSummaryBlocksByDayKey
        let allDayBlocks = renderSnapshot.allDayBlocks
        let tintsByTaskID = renderSnapshot.tintsByTaskID
        let activeFocusRenderSessions = renderSnapshot.activeFocusRenderSessions
        let activeSprintFocusSessions = renderSnapshot.activeSprintFocusSessions
        let planFocusAllocatedMinutesBySessionID = renderSnapshot.planFocusAllocatedMinutesBySessionID
        let currentTaskIDs = taskFilterSnapshot.currentTaskIDs
        let calendarListHiddenTaskIDs = taskFilterSnapshot.calendarListHiddenTaskIDs
        let isCalendarTaskFilterActive = taskFilterSnapshot.isFilterActive
        let filterAvailability = DayPlanCalendarFilterAvailability(
            includesEvents: includesEvents,
            includesAway: includesAway,
            includesSleep: includesAway
        )
        let calendarFilterState = calendarFilters.wrappedValue.normalized(availability: filterAvailability)
        let dayTaskListVisibilitySignature = DayPlanDayTaskListVisibilitySignature(
            filters: calendarFilterState,
            availability: filterAvailability,
            calendarSearchText: calendarSearchText,
            calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed
        )
        let timelineSuggestionsVisible =
            showsTimelineTasksInDayPlanner
            && calendarFilterState.showsTimelineSuggestions
        let calendarSearchTasks = tasksMatchingCalendarSearch(from: currentTasks)
        let calendarSearchTaskIDs = Set(calendarSearchTasks.map(\.id))
        let visibleTimedBlocksByDayKey = filteredBlocksByDayKey(
            plannedBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            automaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let dayTaskListAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            automaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            includesAssumedDone: true,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleUnplaceableAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            unplaceableAutomaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let dayTaskListUnplaceableAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            unplaceableAutomaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            includesAssumedDone: true,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleAssumedDoneSummaryBlocksByDayKey = filteredTimelineBlocksByDayKey(
            assumedDoneSummaryBlocksByDayKey,
            filters: calendarFilterState,
            includesAssumedDone: true,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleTimelineBlocksByDayKey = filteredTimelineBlocksByDayKey(
            timelineBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleAllDayBlocks = filteredAllDayBlocks(
            allDayBlocks,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let scheduleAllDayBlocks = DayPlanScheduleViewVisibility.allDayBlocks(
            visibleAllDayBlocks,
            context: renderSnapshot.visibleBlockContext
        )
        let dayTaskListSource = DayPlanDayTaskListSource(
            plannedBlocksByDayKey: visibleTimedBlocksByDayKey,
            allDayBlocks: visibleAllDayBlocks,
            plannedDateTasks: calendarFilterState.showsAllDayTasks
                ? calendarSearchTasks
                : [],
            tasks: currentTasks,
            logs: logs,
            referenceDate: referenceDate,
            visibilitySignature: dayTaskListVisibilitySignature
        )
        let dayTaskListItemsForVisibility: (Date, Set<UUID>) -> [DayPlanDayTaskListItem] = { date, excludedTaskIDs in
            dayTaskResolutionOverlay.applying(
                to: dayTaskListItems(
                    on: date,
                    source: dayTaskListSource,
                    timelineActivityBlocks: timelineSuggestionsVisible
                        ? dayTimelineActivityBlocks(
                            on: date,
                            automaticSuggestionBlocksByDayKey: dayTaskListAutomaticSuggestionBlocksByDayKey,
                            unplaceableAutomaticSuggestionBlocksByDayKey: dayTaskListUnplaceableAutomaticSuggestionBlocksByDayKey,
                            assumedDoneSummaryBlocksByDayKey: visibleAssumedDoneSummaryBlocksByDayKey
                        )
                        : [],
                    excludedTaskIDs: excludedTaskIDs
                ),
                on: date,
                calendar: calendar
            )
        }
        let calendarDayTaskListItems: (Date) -> [DayPlanDayTaskListItem] = { date in
            dayTaskListItemsForVisibility(date, [])
        }
        let calendarListColumnItems: (Date) -> [DayPlanDayTaskListItem] = { date in
            dayTaskListItemsForVisibility(date, calendarListHiddenTaskIDs)
        }

        VStack(alignment: .leading, spacing: 12) {
            DayPlanWeekCalendarView(
                dates: visibleDates,
                selectedBlockID: planner.selectedBlockID,
                highlightedBlockID: planner.highlightedBlockID,
                highlightedBlockScrollMinute: planner.highlightedBlockScrollMinute,
                selectedDate: planner.selectedDate,
                focusedUnplannedCompletedDate: activeFocusedUnplannedCompletedDate,
                focusedSleep: planner.focusedSleep,
                calendar: calendar,
                hourHeight: CGFloat(planner.calendarHourHeight),
                dropDurationMinutes: planner.durationMinutes,
                calendarTaskViewMode: calendarTaskViewMode,
                showsUnplannedCompletedBadges: !timelineSuggestionsVisible,
                showsHourSpacingControls: planner.visibleRangeMode == .day,
                canDecreaseHourSpacing: planner.canDecreaseDayHourSpacing,
                canIncreaseHourSpacing: planner.canIncreaseDayHourSpacing,
                hourSpacingAccessibilityValue: "\(Int(planner.dayHourSpacing.hourHeight)) points per hour",
                blocksForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return visibleTimedBlocksByDayKey[dayKey] ?? []
                },
                automaticTimelineBlocksForDate: { date in
                    guard timelineSuggestionsVisible else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return DayPlanScheduleViewVisibility.automaticTimelineBlocks(
                        visibleAutomaticSuggestionBlocksByDayKey[dayKey] ?? []
                    )
                },
                unplaceableAutomaticTimelineBlocksForDate: { date in
                    guard timelineSuggestionsVisible else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return DayPlanScheduleViewVisibility.automaticTimelineBlocks(
                        visibleUnplaceableAutomaticSuggestionBlocksByDayKey[dayKey] ?? []
                    )
                },
                eventBlocksForDate: { date in
                    guard includesEvents, calendarFilterState.showsEvents else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return eventBlocksByDayKey[dayKey] ?? []
                },
                sleepBlocksForDate: { date in
                    guard calendarFilterState.showsSleep else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return sleepBlocksByDayKey[dayKey] ?? []
                },
                awayBlocksForDate: { date in
                    guard calendarFilterState.showsAway else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return linkedAwayBlocksByDayKey[dayKey] ?? []
                },
                sprintFocusBlocksForDate: { date in
                    guard calendarFilterState.showsFocus else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return sprintFocusBlocksByDayKey[dayKey] ?? []
                },
                blockedIntervalsForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return blockedIntervalsByDayKey[dayKey] ?? []
                },
                showsActiveFocusBlocks: calendarFilterState.showsFocus && !activeFocusRenderSessions.isEmpty,
                showsActiveSprintFocusBlocks: calendarFilterState.showsFocus && !activeSprintFocusSessions.isEmpty,
                onCalendarWidthChanged: { width in
                    updateAdaptiveVisibleRangeMode(for: width)
                },
                activeFocusSessionBlocks: { now in
                    guard calendarFilterState.showsFocus else { return [] }
                    let sessions = activeFocusRenderSessions.filter { session in
                        guard session.isUnassigned else { return true }
                        let allocatedMinutes = planFocusAllocatedMinutesBySessionID[session.id] ?? 0
                        let elapsedMinutes = Int(floor(session.activeDurationSeconds(at: now) / 60))
                        return allocatedMinutes < elapsedMinutes
                    }
                    return DayPlanFocusSessionBlocks.activeBlocks(
                        from: currentTasks,
                        sessions: sessions,
                        now: now,
                        calendar: calendar,
                        excluding: rawPlannedBlocks
                    )
                },
                activeSprintFocusBlocks: { now in
                    guard calendarFilterState.showsFocus else { return [] }
                    return activeSprintFocusBlocksCache.blocksByDayKey(
                        on: visibleDates,
                        from: activeSprintFocusSessions,
                        allocations: currentSprintFocusAllocations,
                        sprints: currentBoardSprints,
                        tasks: currentTasks,
                        referenceDate: now,
                        calendar: calendar
                    )
                    .values
                    .flatMap { $0 }
                },
                allDayBlocks: scheduleAllDayBlocks,
                unplannedCompletedCount: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return visibleTimelineBlocksByDayKey[dayKey]?.count ?? 0
                },
                taskTint: { block in
                    if block.taskID == FocusSession.unassignedTaskID {
                        return .teal
                    }
                    return tintsByTaskID[block.taskID] ?? .accentColor
                },
                allDayTint: { block in
                    if block.isEvent {
                        return .teal
                    }
                    guard let taskID = block.taskID else {
                        return .accentColor
                    }
                    return tintsByTaskID[taskID] ?? .accentColor
                },
                onSelectUnplannedCompletedDate: { date in
                    planner.focusUnplannedCompletedTasks(on: date, calendar: calendar)
                    onSelectUnplannedCompletedDate?(date)
                },
                dayTaskCounts: { date in
                    DayPlanDayTaskCounts(items: calendarDayTaskListItems(date))
                },
                dayTaskListItems: calendarListColumnItems,
                dayTaskTint: { taskID in
                    tintsByTaskID[taskID] ?? .accentColor
                },
                isDayTaskOpenable: { taskID in
                    onOpenTaskDetails != nil && currentTaskIDs.contains(taskID)
                },
                onOpenDayTaskDetails: { item, date in
                    if let onOpenCalendarListTaskDetails {
                        onOpenCalendarListTaskDetails(item, date)
                    } else {
                        onOpenTaskDetails?(item.taskID)
                    }
                },
                onCompletePlannedDayTask: { item, date in
                    completePlannedDayTask(item, on: date)
                },
                onConfirmAssumedDayTask: { item, date in
                    confirmAssumedDayTask(item, on: date)
                },
                onMarkAssumedDayTaskMissed: { item, date in
                    markAssumedDayTaskMissed(item, on: date)
                },
                onSelectSlot: { date, minute in
                    planner.selectSlot(on: date, startMinute: minute, calendar: calendar, context: modelContext)
                },
                onSelectBlock: { block, date in
                    planner.edit(block, on: date, calendar: calendar, context: modelContext)
                },
                onOpenBlockDetails: { block, date in
                    planner.edit(block, on: date, calendar: calendar, context: modelContext)
                    if currentTasks.contains(where: { $0.id == block.taskID }) {
                        onOpenTaskDetails?(block.taskID)
                    }
                },
                onOpenTimelineTaskDetails: { taskID in
                    if let task = currentTasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                    }
                    onOpenTaskDetails?(taskID)
                },
                onOpenEventDetails: { eventID in
                    guard includesEvents else { return }
                    if let onOpenEventDetails {
                        selectedEventID = nil
                        onOpenEventDetails(eventID)
                    } else {
                        selectedEventID = eventID
                    }
                },
                onOpenFocusTaskDetails: { taskID in
                    if let task = currentTasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                        onOpenTaskDetails?(taskID)
                    }
                },
                onOpenAllDayTaskDetails: { taskID in
                    if let task = currentTasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                    }
                    onOpenTaskDetails?(taskID)
                },
                onDeleteBlock: { block in
                    planner.deleteBlock(block.id, calendar: calendar, context: modelContext)
                },
                onDecreaseHourSpacing: {
                    planner.decreaseDayHourSpacing()
                },
                onIncreaseHourSpacing: {
                    planner.increaseDayHourSpacing()
                },
                onConfirmTimelineActivity: { activity, date in
                    guard
                        !hasSleepConflict(
                            on: date,
                            startMinute: activity.block.startMinute,
                            durationMinutes: activity.block.durationMinutes,
                            blockedIntervalsByDayKey: blockedIntervalsByDayKey
                        )
                    else {
                        return
                    }
                    planner.confirmTimelineActivity(activity, on: date, calendar: calendar, context: modelContext)
                },
                onHideTimelineActivity: { activity, _ in
                    hideTimelineActivity(activity)
                },
                onMoveBlock: { blockID, date, minute in
                    activatePlannerUndoManager()
                    let durationMinutes = plannedBlock(with: blockID)?.durationMinutes ?? planner.durationMinutes
                    guard
                        !hasSleepConflict(
                            on: date,
                            startMinute: minute,
                            durationMinutes: durationMinutes,
                            blockedIntervalsByDayKey: blockedIntervalsByDayKey
                        )
                    else {
                        return
                    }
                    planner.moveBlock(blockID, to: date, startMinute: minute, calendar: calendar, context: modelContext)
                },
                onDuplicateBlock: { blockID, date, minute in
                    activatePlannerUndoManager()
                    let durationMinutes = plannedBlock(with: blockID)?.durationMinutes ?? planner.durationMinutes
                    guard
                        !hasSleepConflict(
                            on: date,
                            startMinute: minute,
                            durationMinutes: durationMinutes,
                            blockedIntervalsByDayKey: blockedIntervalsByDayKey
                        )
                    else {
                        return
                    }
                    planner.duplicateBlock(blockID, to: date, startMinute: minute, calendar: calendar, context: modelContext)
                },
                onMoveTimelineActivity: { activity, date, minute in
                    guard
                        !hasSleepConflict(
                            on: date,
                            startMinute: minute,
                            durationMinutes: activity.block.durationMinutes,
                            blockedIntervalsByDayKey: blockedIntervalsByDayKey
                        )
                    else {
                        return
                    }
                    moveTimelineActivity(activity, to: date, startMinute: minute)
                },
                onMoveBlockToAllDay: { blockID, date in
                    moveBlockToAllDay(blockID, on: date)
                },
                onMoveTimelineActivityToAllDay: { activity, date in
                    moveTimelineActivityToAllDay(activity, on: date)
                },
                onBeginResizeBlock: { block, date in
                    activatePlannerUndoManager()
                    planner.beginResizeBlock(
                        block,
                        on: date,
                        calendar: calendar,
                        context: modelContext,
                        focusSessions: currentFocusSessions
                    )
                },
                onResizeBlock: { blockID, date, startMinute, durationMinutes in
                    activatePlannerUndoManager()
                    guard
                        !hasSleepConflict(
                            on: date,
                            startMinute: startMinute,
                            durationMinutes: durationMinutes,
                            blockedIntervalsByDayKey: blockedIntervalsByDayKey
                        )
                    else {
                        return
                    }
                    planner.resizeBlock(
                        blockID,
                        on: date,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        calendar: calendar,
                        context: modelContext
                    )
                },
                onEndResizeBlock: { blockID in
                    activatePlannerUndoManager()
                    planner.endResizeBlock(blockID, calendar: calendar, context: modelContext)
                },
                onDropTask: { taskID, date, minute in
                    dropTask(
                        taskID,
                        on: date,
                        startMinute: minute,
                        blockedIntervalsByDayKey: blockedIntervalsByDayKey
                    )
                },
                onDropTaskToAllDay: { taskID, date in
                    dropTaskToAllDay(taskID, on: date)
                },
                slotSidebarContent: { date, minute, draftDurationMinutes, dismiss in
                    AnyView(
                        DayPlanSlotActionSidebar(
                            date: date,
                            startMinute: minute,
                            durationMinutes: draftDurationMinutes,
                            tasks: DayPlanTaskSorting.availableTasks(from: currentTasks),
                            defaultTaskID: planner.selectedTaskID,
                            now: referenceDate,
                            calendar: calendar,
                            includesAway: includesAway,
                            onCreateTaskBlock: { taskID, durationMinutes in
                                createTaskBlock(
                                    taskID,
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onCreateTaskAndBlock: { title, durationMinutes in
                                createTaskAndBlock(
                                    title: title,
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onLogAway: { preset, title, linkedTaskID, durationMinutes in
                                logAway(
                                    preset: preset,
                                    title: title,
                                    linkedTaskID: linkedTaskID,
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onLogSleep: { durationMinutes in
                                logSleep(
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onDismiss: dismiss
                        )
                    )
                },
                dayTaskListSidebarContent: { date, dismiss in
                    AnyView(
                        DayPlanDayTaskListSidebar(
                            date: date,
                            items: calendarDayTaskListItems(date),
                            taskTint: { taskID in
                                tintsByTaskID[taskID] ?? .accentColor
                            },
                            calendar: calendar,
                            isTaskOpenable: { taskID in
                                onOpenTaskDetails != nil && currentTaskIDs.contains(taskID)
                            },
                            onConfirmAssumedDayTask: { item, date in
                                confirmAssumedDayTask(item, on: date)
                            },
                            onMarkAssumedDayTaskMissed: { item, date in
                                markAssumedDayTaskMissed(item, on: date)
                            },
                            onOpenTaskDetails: { item, _ in
                                dismiss()
                                onOpenTaskDetails?(item.taskID)
                            },
                            onDismiss: dismiss
                        )
                    )
                },
                completedTagFocusSessionID: { block in
                    #if os(macOS)
                        DayPlanFocusSessionPlannerSync.completedTagFocusSession(
                            matching: block,
                            in: currentFocusSessions
                        )?.id
                    #else
                        nil
                    #endif
                },
                tagFocusSidebarContent: { sessionID, dismiss in
                    if let session = currentFocusSessions.first(where: { $0.id == sessionID }) {
                        AnyView(
                            DayPlanTagFocusSidebar(
                                session: session,
                                calendar: calendar,
                                onDismiss: dismiss
                            )
                            .id(session.id)
                        )
                    } else {
                        AnyView(
                            ContentUnavailableView(
                                "Focus unavailable",
                                systemImage: "timer",
                                description: Text("This Focus session is no longer available.")
                            )
                            .padding(16)
                        )
                    }
                },
                isFilterSidebarPresented: isCalendarFilterSidebarPresented,
                filterSidebarContent: { dismiss in
                    AnyView(
                        DayPlanCalendarFilterSidebar(
                            filters: calendarFilters,
                            availability: filterAvailability,
                            timelineSuggestionsAvailable: showsTimelineTasksInDayPlanner,
                            onDismiss: dismiss
                        )
                    )
                },
                isDatePickerSidebarPresented: isDatePickerSidebarPresented,
                datePickerSidebarContent: { dismiss in
                    AnyView(
                        DayPlanDatePickerSidebar(
                            selectedDate: selectedDateBinding,
                            summaryTitle: planner.visibleRangeTitle(calendar: calendar),
                            blocksCount: planner.blocks.count,
                            plannedMinutes: planner.plannedMinutes,
                            calendar: calendar,
                            onDismiss: dismiss
                        )
                    )
                },
                isExternalInspectorPresented: isExternalInspectorPresented,
                onSidebarPresentationRequested: onSidebarPresentationRequested
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dayPlanLifecycle(
            planner: planner,
            dataRevision: dataSnapshotID,
            tasks: currentTasks,
            sleepSessions: currentSleepSessions,
            awaySessions: currentAwaySessions,
            focusSessions: currentFocusSessions,
            calendar: calendar
        )
        .onAppear {
            activatePlannerUndoManager()
            updateAdaptiveVisibleRangeModeFromParentWidthIfAvailable()
        }
        .onChange(of: parentAvailableWidth) { _, _ in
            updateAdaptiveVisibleRangeModeFromParentWidthIfAvailable()
        }
        .onChange(of: isExternalInspectorPresented) { _, _ in
            updateAdaptiveVisibleRangeModeFromParentWidthIfAvailable()
        }
        .onChange(of: dataSnapshotID) { _, _ in
            dayTaskResolutionOverlay.reset()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            timelinePlacementCache.requireFullValidation()
            allDayBlocksCache.requireFullValidation()
            visibleBlockContextCache.requireFullValidation()
            sleepBlocksCache.invalidate()
            awayBlocksCache.invalidate()
        }
        .onChange(of: showsTimelineTasksInDayPlanner) { _, isEnabled in
            if isEnabled {
                planner.clearFocusedUnplannedCompletedTasks()
            }
        }
        .sheet(item: selectedEventPresentationBinding) { presentation in
            NavigationStack {
                DayPlanEventDetail(eventID: presentation.id)
            }
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: {
                planner.selectedDate
            },
            set: { date in
                planner.showDate(date, calendar: calendar, context: modelContext)
            }
        )
    }

    private func updateAdaptiveVisibleRangeMode(for width: CGFloat) {
        #if os(macOS)
            planner.setAdaptiveVisibleRangeMode(
                forAvailableWidth: Double(width),
                isExternalInspectorPresented: isExternalInspectorPresented,
                calendar: calendar,
                context: modelContext
            )
        #endif
    }

    private func updateAdaptiveVisibleRangeModeFromParentWidthIfAvailable() {
        guard let parentAvailableWidth, parentAvailableWidth > 0 else { return }
        updateAdaptiveVisibleRangeMode(for: parentAvailableWidth)
    }

    private func filteredAllDayBlocks(
        _ blocks: [DayPlanAllDayBlock],
        filters: DayPlanCalendarFilterState,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> [DayPlanAllDayBlock] {
        blocks.filter { block in
            if block.isEvent {
                return includesEvents && filters.showsEvents
            }
            return filters.showsAllDayTasks
                && matchesCalendarSearch(
                    taskID: block.taskID,
                    title: block.title,
                    emoji: block.emoji,
                    matchingTaskIDs: matchingTaskIDs,
                    allTaskIDs: allTaskIDs,
                    isTaskFilterActive: isTaskFilterActive
                )
        }
    }

    private func tasksMatchingCalendarSearch(from tasks: [RoutineTask]) -> [RoutineTask] {
        guard isCalendarSearchActive else { return tasks }
        return DayPlanTaskSorting.filteredTasks(from: tasks, query: calendarSearchText)
    }

    private func filteredBlocksByDayKey(
        _ blocksByDayKey: [String: [DayPlanBlock]],
        filters: DayPlanCalendarFilterState,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> [String: [DayPlanBlock]] {
        return blocksByDayKey.mapValues { blocks in
            blocks.filter { block in
                if block.taskID == FocusSession.unassignedTaskID {
                    guard filters.showsFocus else { return false }
                } else {
                    guard filters.showsPlannedTasks else { return false }
                }
                return matchesCalendarSearch(
                    taskID: block.taskID,
                    title: block.titleSnapshot,
                    emoji: block.emojiSnapshot,
                    matchingTaskIDs: matchingTaskIDs,
                    allTaskIDs: allTaskIDs,
                    isTaskFilterActive: isTaskFilterActive
                )
            }
        }
    }

    private func filteredTimelineBlocksByDayKey(
        _ blocksByDayKey: [String: [DayPlanTimelineActivityBlock]],
        filters: DayPlanCalendarFilterState,
        includesAssumedDone: Bool = false,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        DayPlanCalendarTimelineActivityPresentationFilter.filteredBlocksByDayKey(
            blocksByDayKey,
            filters: filters,
            includesAssumedDone: includesAssumedDone,
            matchingTaskIDs: matchingTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isTaskFilterActive,
            normalizedSearchText: normalizedCalendarSearchText
        )
    }

    private func matchesCalendarSearch(
        taskID: UUID?,
        title: String,
        emoji: String?,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> Bool {
        DayPlanCalendarTaskPresentationFilter.matches(
            taskID: taskID,
            title: title,
            emoji: emoji,
            matchingTaskIDs: matchingTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isTaskFilterActive,
            normalizedSearchText: normalizedCalendarSearchText
        )
    }

    private var isCalendarSearchActive: Bool {
        !normalizedCalendarSearchText.isEmpty
    }

    private var normalizedCalendarSearchText: String {
        calendarSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func activatePlannerUndoManager() {
        RoutinaUndoSupport.setActiveUndoManager(undoManager)
        RoutinaUndoSupport.setActiveScopedUndo(
            undo: { [weak planner] in
                planner?.performPlannerUndo(calendar: calendar, context: modelContext) == true
            },
            redo: { [weak planner] in
                planner?.performPlannerRedo(calendar: calendar, context: modelContext) == true
            }
        )
    }

    private var selectedEventPresentationBinding: Binding<DayPlanEventPresentation?> {
        Binding(
            get: {
                guard includesEvents else { return nil }
                return selectedEventID.map(DayPlanEventPresentation.init(id:))
            },
            set: { presentation in
                selectedEventID = presentation?.id
            }
        )
    }

    private var activeFocusedUnplannedCompletedDate: Date? {
        showsTimelineTasksInDayPlanner ? nil : planner.focusedUnplannedCompletedDate
    }

    private func dayTaskListItems(
        on date: Date,
        source: DayPlanDayTaskListSource,
        timelineActivityBlocks: [DayPlanTimelineActivityBlock] = [],
        excludedTaskIDs: Set<UUID> = []
    ) -> [DayPlanDayTaskListItem] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return dayTaskListItemsCache.items(
            dataSnapshotID: dataSnapshotID,
            on: date,
            timedBlocks: source.plannedBlocksByDayKey[dayKey] ?? [],
            allDayBlocks: source.allDayBlocks,
            plannedDateTasks: source.plannedDateTasks,
            timelineActivityBlocks: timelineActivityBlocks,
            tasks: source.tasks,
            logs: source.logs,
            referenceDate: source.referenceDate,
            calendar: calendar,
            visibilitySignature: source.visibilitySignature,
            excludedTaskIDs: excludedTaskIDs,
            visibilityCache: plannedDateTaskVisibilityCache
        )
    }

    private func dayTimelineActivityBlocks(
        on date: Date,
        automaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]],
        unplaceableAutomaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]],
        assumedDoneSummaryBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    ) -> [DayPlanTimelineActivityBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        var blocks =
            (automaticSuggestionBlocksByDayKey[dayKey] ?? [])
            + (unplaceableAutomaticSuggestionBlocksByDayKey[dayKey] ?? [])
        let existingIDs = Set(blocks.map(\.id))
        blocks.append(
            contentsOf: (assumedDoneSummaryBlocksByDayKey[dayKey] ?? [])
                .filter { !existingIDs.contains($0.id) }
        )
        return blocks
    }

    private func moveBlockToAllDay(_ blockID: DayPlanBlock.ID, on date: Date) {
        guard let block = plannedBlock(with: blockID),
            makeTaskAllDay(block.taskID, on: date)
        else {
            return
        }

        planner.deleteBlock(blockID, calendar: calendar, context: modelContext)
    }

    private func moveTimelineActivityToAllDay(_ activity: DayPlanTimelineActivityBlock, on date: Date) {
        if !calendar.isDate(activity.block.updatedAt, inSameDayAs: date) {
            moveTimelineActivity(activity, to: date, startMinute: 0)
        }
        _ = makeTaskAllDay(activity.block.taskID, on: date)
    }

    private func moveTimelineActivity(
        _ activity: DayPlanTimelineActivityBlock,
        to date: Date,
        startMinute: Int
    ) {
        if activity.source.isSyntheticAssumedDone {
            var adjustedActivity = activity
            adjustedActivity.block = DayPlanBlock(
                id: activity.block.id,
                taskID: activity.block.taskID,
                dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar),
                startMinute: startMinute,
                durationMinutes: activity.block.durationMinutes,
                titleSnapshot: activity.block.titleSnapshot,
                emojiSnapshot: activity.block.emojiSnapshot,
                createdAt: activity.block.createdAt,
                updatedAt: activity.block.updatedAt
            )
            planner.confirmTimelineActivity(adjustedActivity, on: date, calendar: calendar, context: modelContext)
            return
        }

        _ = DayPlanTimelineTasks.moveActivity(
            activity,
            to: date,
            startMinute: startMinute,
            tasks: tasks,
            logs: logs,
            context: modelContext,
            calendar: calendar
        )
    }

    private func dropTaskToAllDay(_ taskID: UUID, on date: Date) {
        guard makeTaskAllDay(taskID, on: date) else { return }
        if let task = tasks.first(where: { $0.id == taskID }) {
            planner.selectedBlockID = nil
            planner.selectTask(task)
        }
    }

    @discardableResult
    private func makeTaskAllDay(_ taskID: UUID, on date: Date) -> Bool {
        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate<RoutineTask> { task in
                task.id == taskID
            }
        )

        do {
            guard let task = try context.fetch(descriptor).first else { return false }
            task.isAllDay = true
            if task.isOneOffTask {
                task.deadline = calendar.startOfDay(for: date)
            }
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return true
        } catch {
            NSLog("Failed to move task to all-day planner lane: \(error.localizedDescription)")
            return false
        }
    }

    private func hideTimelineActivity(_ activity: DayPlanTimelineActivityBlock) {
        let updatedStorage = DayPlanHiddenTimelineActivityStore.storageString(
            afterHiding: activity,
            in: hiddenTimelineActivityStorage
        )
        hiddenTimelineActivityStorage = updatedStorage
        CloudSettingsKeyValueSync.setString(
            updatedStorage.isEmpty ? nil : updatedStorage,
            for: .appSettingHiddenDayPlanTimelineActivityIDs
        )
    }

    private func dropTask(
        _ taskID: UUID,
        on date: Date,
        startMinute: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        let durationMinutes = task.estimatedDurationMinutes ?? planner.durationMinutes
        guard
            !hasSleepConflict(
                on: date,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                blockedIntervalsByDayKey: blockedIntervalsByDayKey
            )
        else {
            return
        }

        planner.selectSlot(on: date, startMinute: startMinute, calendar: calendar, context: modelContext)
        planner.selectTask(task)
        planner.commitBlock(task: task, calendar: calendar, context: modelContext)
    }

    private func completePlannedDayTask(_ item: DayPlanDayTaskListItem, on date: Date) {
        guard item.section == .planned,
            let task = tasks.first(where: { $0.id == item.taskID })
        else {
            return
        }
        let referenceDate = Date()
        guard
            let completedAt = DayPlanPlannedTaskCompletion.completionDate(
                for: task,
                on: date,
                placement: item.placement,
                referenceDate: referenceDate,
                logs: logs,
                calendar: calendar
            )
        else {
            return
        }

        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let previousTodoStateTitle = task.isOneOffTask ? task.todoState?.displayTitle : nil
        do {
            guard
                let update = try RoutineLogHistory.advanceTask(
                    taskID: item.taskID,
                    completedAt: completedAt,
                    referenceDate: referenceDate,
                    allowEarlyScheduledCompletion: true,
                    context: context,
                    calendar: calendar
                ), update.result == .completedRoutine
            else {
                return
            }
            if update.task.isOneOffTask,
                previousTodoStateTitle != TodoState.done.displayTitle {
                update.task.appendChangeLogEntry(
                    RoutineTaskChangeLogEntry(
                        timestamp: referenceDate,
                        kind: .stateChanged,
                        previousValue: previousTodoStateTitle,
                        newValue: TodoState.done.displayTitle
                    )
                )
                try context.save()
            }
            if NotificationCoordinator.shouldScheduleNotification(
                for: update.task,
                referenceDate: completedAt,
                calendar: calendar
            ) {
                let payload = NotificationCoordinator.notificationPayload(
                    for: update.task,
                    referenceDate: completedAt,
                    calendar: calendar
                )
                Task {
                    await NotificationCoordinator.scheduleNotification(payload)
                }
            } else {
                NotificationCoordinator.cancelNotification(item.taskID.uuidString)
            }
            dayTaskResolutionOverlay.complete(
                item,
                on: date,
                completedAt: completedAt,
                calendar: calendar
            )
            WidgetStatsService.refreshAndReload(using: context)
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Failed to complete planned planner day task: \(error.localizedDescription)")
        }
    }

    private func confirmAssumedDayTask(_ item: DayPlanDayTaskListItem, on date: Date) {
        guard item.section == .assumedDone else { return }
        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let referenceDate = Date()
        do {
            guard
                let task = try RoutineLogHistory.confirmTaskCompletions(
                    taskID: item.taskID,
                    on: [date],
                    context: context,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            else {
                return
            }
            let completedAt = RoutineAssumedCompletion.completionTimestamp(
                for: task,
                on: date,
                referenceDate: referenceDate,
                calendar: calendar
            )
            dayTaskResolutionOverlay.complete(
                item,
                on: date,
                completedAt: completedAt,
                calendar: calendar
            )
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Failed to confirm assumed planner day task: \(error.localizedDescription)")
        }
    }

    private func markAssumedDayTaskMissed(_ item: DayPlanDayTaskListItem, on date: Date) {
        guard item.section == .assumedDone else { return }
        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let referenceDate = Date()
        do {
            _ = try RoutineLogHistory.markAssumedCompletionMissed(
                taskID: item.taskID,
                on: date,
                context: context,
                referenceDate: referenceDate,
                calendar: calendar
            )
            dayTaskResolutionOverlay.markMissed(
                taskID: item.taskID,
                on: date,
                calendar: calendar
            )
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Failed to mark assumed planner day task missed: \(error.localizedDescription)")
        }
    }

    private func createTaskBlock(
        _ taskID: UUID,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return "Choose a task."
        }
        let clampedStart = DayPlanBlock.clampedStartMinute(startMinute)
        let clampedDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: clampedStart
        )

        if let conflict = plannerBlockConflict(on: date, startMinute: clampedStart, durationMinutes: clampedDuration) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        planner.selectSlot(on: date, startMinute: clampedStart, calendar: calendar, context: modelContext)
        planner.selectTask(task)
        planner.durationMinutes = clampedDuration
        planner.commitBlock(task: task, calendar: calendar, context: modelContext)
        return nil
    }

    private func createTaskAndBlock(
        title: String,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        let trimmedTitle = DayPlanSlotTaskPickerPresentation.normalizedNewTaskName(title)
        guard !trimmedTitle.isEmpty else {
            return "Name the task."
        }

        let clampedStart = DayPlanBlock.clampedStartMinute(startMinute)
        let clampedDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: clampedStart
        )

        if let conflict = plannerBlockConflict(on: date, startMinute: clampedStart, durationMinutes: clampedDuration) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let task = RoutineTask(
            name: trimmedTitle,
            plannedDate: date,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1),
            estimatedDurationMinutes: clampedDuration
        )
        context.insert(task)

        planner.selectSlot(on: date, startMinute: clampedStart, calendar: calendar, context: context)
        planner.selectTask(task)
        planner.durationMinutes = clampedDuration
        planner.commitBlock(task: task, calendar: calendar, context: context)
        NotificationCenter.default.postRoutineDidUpdate()
        return nil
    }

    private func logAway(
        preset: AwaySessionPreset,
        title: String?,
        linkedTaskID: UUID?,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        let clampedStart = DayPlanBlock.clampedStartMinute(
            startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        let clampedDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: clampedStart,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        guard let startedAt = slotDate(on: date, startMinute: clampedStart),
            let endedAt = calendar.date(byAdding: .minute, value: clampedDuration, to: startedAt)
        else {
            return "Choose a valid time."
        }
        guard endedAt <= Date() else {
            return "Away logs need an interval that has already ended."
        }
        if let conflict = plannerBlockConflict(on: date, startMinute: clampedStart, durationMinutes: clampedDuration) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        do {
            _ = try AwaySessionSupport.logAway(
                preset: preset,
                durationMinutes: clampedDuration,
                title: title,
                linkedTaskID: linkedTaskID,
                startedAt: startedAt,
                context: modelContext
            )
            return nil
        } catch {
            NSLog("Failed to log away session from planner: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    private func logSleep(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        let clampedStart = DayPlanBlock.clampedStartMinute(
            startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        let clampedDuration = min(max(durationMinutes, 5), 16 * 60)
        guard let startedAt = slotDate(on: date, startMinute: clampedStart),
            let endedAt = calendar.date(byAdding: .minute, value: clampedDuration, to: startedAt)
        else {
            return "Choose a valid time."
        }
        guard endedAt <= Date() else {
            return "Sleep logs need an interval that has already ended."
        }
        if let conflict = plannerBlockConflict(startedAt: startedAt, endedAt: endedAt) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        do {
            _ = try SleepSessionSupport.logSleep(
                durationMinutes: clampedDuration,
                startedAt: startedAt,
                context: modelContext
            )
            return nil
        } catch {
            NSLog("Failed to log sleep session from planner: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    private func hasSleepConflict(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> Bool {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        guard let intervals = blockedIntervalsByDayKey[dayKey] else { return false }
        return intervals.contains {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    private func protectedIntervalConflict(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> DayPlanBlockedInterval? {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        guard let intervals = blockedIntervalsByDayKey[dayKey] else { return nil }
        return intervals.first {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    private func plannerBlockConflict(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int
    ) -> DayPlanBlock? {
        let start = DayPlanBlock.clampedStartMinute(startMinute)
        let duration = DayPlanBlock.clampedDuration(durationMinutes, startMinute: start)
        let end = start + duration
        return DayPlanVisibleBlocks.blocks(
            planner.blocks(on: date, calendar: calendar, context: modelContext),
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            activeFocusSessions: activeTaskAndTagFocusSessions
        )
        .first { block in
            max(start, block.startMinute) < min(end, block.endMinute)
        }
    }

    private func plannerBlockConflict(startedAt: Date, endedAt: Date) -> DayPlanBlock? {
        guard endedAt > startedAt else { return nil }

        var day = calendar.startOfDay(for: startedAt)
        while day < endedAt {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let intervalStart = max(startedAt, day)
            let intervalEnd = min(endedAt, nextDay)
            if intervalEnd > intervalStart {
                let startMinute = minuteOfDay(for: intervalStart)
                let durationMinutes = max(1, Int(ceil(intervalEnd.timeIntervalSince(intervalStart) / 60)))
                if let conflict = plannerBlockConflict(
                    on: day,
                    startMinute: startMinute,
                    durationMinutes: durationMinutes
                ) {
                    return conflict
                }
            }

            day = nextDay
        }

        return nil
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private func activeTaskAndTagFocusSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions.filter { session in
            (session.isTaskFocus || session.isTagFocus)
                && session.startedAt != nil
                && session.completedAt == nil
                && session.abandonedAt == nil
        }
    }

    private var activeTaskAndTagFocusSessions: [FocusSession] {
        activeTaskAndTagFocusSessions(from: focusSessions)
    }

    private func slotDate(on date: Date, startMinute: Int) -> Date? {
        calendar.date(
            byAdding: .minute,
            value: DayPlanBlock.clampedStartMinute(
                startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            ),
            to: calendar.startOfDay(for: date)
        )
    }

    private func plannedBlock(with id: DayPlanBlock.ID) -> DayPlanBlock? {
        planner.weekBlocksByDayKey.values.lazy.compactMap { blocks in
            blocks.first { $0.id == id }
        }
        .first
            ?? planner.blocks.first { $0.id == id }
    }
}
