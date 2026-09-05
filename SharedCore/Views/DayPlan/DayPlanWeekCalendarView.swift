import SwiftUI
import UniformTypeIdentifiers

struct DayPlanWeekCalendarView: View {
    var dates: [Date]
    var selectedBlockID: DayPlanBlock.ID?
    var highlightedBlockID: DayPlanBlock.ID?
    var highlightedBlockScrollMinute: Int?
    var selectedDate: Date
    var focusedUnplannedCompletedDate: Date?
    var focusedSleep: DayPlanFocusedSleep?
    var calendar: Calendar
    var hourHeight: CGFloat = 64
    var dropDurationMinutes: Int
    var calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule
    var showsUnplannedCompletedBadges: Bool
    var showsHourSpacingControls = false
    var canDecreaseHourSpacing = false
    var canIncreaseHourSpacing = false
    var hourSpacingAccessibilityValue = ""
    var blocksForDate: (Date) -> [DayPlanBlock]
    var automaticTimelineBlocksForDate: (Date) -> [DayPlanTimelineActivityBlock] = { _ in [] }
    var unplaceableAutomaticTimelineBlocksForDate: (Date) -> [DayPlanTimelineActivityBlock] = { _ in [] }
    var eventBlocksForDate: (Date) -> [DayPlanEventBlock] = { _ in [] }
    var sleepBlocksForDate: (Date) -> [DayPlanSleepBlock] = { _ in [] }
    var awayBlocksForDate: (Date) -> [DayPlanAwayBlock] = { _ in [] }
    var sprintFocusBlocksForDate: (Date) -> [DayPlanSprintFocusBlock] = { _ in [] }
    var blockedIntervalsForDate: (Date) -> [DayPlanBlockedInterval] = { _ in [] }
    var showsActiveFocusBlocks = false
    var showsActiveSprintFocusBlocks = false
    var onCalendarWidthChanged: (CGFloat) -> Void = { _ in }
    var activeFocusSessionBlocks: (Date) -> [DayPlanFocusSessionBlock] = { _ in [] }
    var activeSprintFocusBlocks: (Date) -> [DayPlanSprintFocusBlock] = { _ in [] }
    var allDayBlocks: [DayPlanAllDayBlock] = []
    var unplannedCompletedCount: (Date) -> Int
    var taskTint: (DayPlanBlock) -> Color
    var allDayTint: (DayPlanAllDayBlock) -> Color = { _ in .accentColor }
    var onSelectUnplannedCompletedDate: (Date) -> Void
    var dayTaskCounts: (Date) -> DayPlanDayTaskCounts = { _ in DayPlanDayTaskCounts() }
    var dayTaskListItems: (Date) -> [DayPlanDayTaskListItem] = { _ in [] }
    var dayTaskTint: (UUID) -> Color = { _ in .accentColor }
    var isDayTaskOpenable: (UUID) -> Bool = { _ in false }
    var onOpenDayTaskDetails: (DayPlanDayTaskListItem, Date) -> Void = { _, _ in }
    var onCompletePlannedDayTask: (DayPlanDayTaskListItem, Date) -> Void = { _, _ in }
    var onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void = { _, _ in }
    var onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void = { _, _ in }
    var onSelectSlot: (Date, Int) -> Void
    var onSelectBlock: (DayPlanBlock, Date) -> Void
    var onOpenBlockDetails: (DayPlanBlock, Date) -> Void
    var onOpenTimelineTaskDetails: (UUID) -> Void = { _ in }
    var onOpenEventDetails: (UUID) -> Void = { _ in }
    var onOpenFocusTaskDetails: (UUID) -> Void = { _ in }
    var onOpenAllDayTaskDetails: (UUID) -> Void = { _ in }
    var onDeleteBlock: (DayPlanBlock) -> Void
    var onDecreaseHourSpacing: () -> Void = {}
    var onIncreaseHourSpacing: () -> Void = {}
    var onConfirmTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onHideTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onMoveBlock: (DayPlanBlock.ID, Date, Int) -> Void
    var onDuplicateBlock: (DayPlanBlock.ID, Date, Int) -> Void = { _, _, _ in }
    var onMoveTimelineActivity: (DayPlanTimelineActivityBlock, Date, Int) -> Void = { _, _, _ in }
    var onMoveBlockToAllDay: (DayPlanBlock.ID, Date) -> Void = { _, _ in }
    var onMoveTimelineActivityToAllDay: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onBeginResizeBlock: (DayPlanBlock, Date) -> Void = { _, _ in }
    var onResizeBlock: (DayPlanBlock.ID, Date, Int, Int) -> Void
    var onEndResizeBlock: (DayPlanBlock.ID?) -> Void = { _ in }
    var onDropTask: (UUID, Date, Int) -> Void
    var onDropTaskToAllDay: (UUID, Date) -> Void = { _, _ in }
    var slotSidebarContent: ((Date, Int, Binding<Int>, @escaping () -> Void) -> AnyView)?
    var dayTaskListSidebarContent: ((Date, @escaping () -> Void) -> AnyView)?
    var completedTagFocusSessionID: (DayPlanBlock) -> UUID? = { _ in nil }
    var tagFocusSidebarContent: ((UUID, @escaping () -> Void) -> AnyView)?
    var isFilterSidebarPresented: Binding<Bool> = .constant(false)
    var filterSidebarContent: ((@escaping () -> Void) -> AnyView)?
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var datePickerSidebarContent: ((@escaping () -> Void) -> AnyView)?
    var isExternalInspectorPresented = false
    var onSidebarPresentationRequested: (() -> Void)?

    @State var isDropTargeted = false
    @State var isCompletingDrop = false
    @State var dropPreview: DayPlanDropPreview?
    @State var draggedBlockID: DayPlanBlock.ID?
    @State var draggedTimelineActivity: DayPlanTimelineActivityBlock?
    @State var draggedBlockDurationMinutes: Int?
    @State var resizeSession: DayPlanResizeSession?
    @State var selectedSlotDraft: DayPlanSelectedSlotDraft?
    @State var selectedDayTaskListDate: Date?
    @State var selectedTagFocusSessionID: UUID?
    @State var draftResizeBaseline: DayPlanSelectedSlotDraft?
    @State var frozenTimeAxis: DayPlanAdaptiveTimeAxis?
    @StateObject private var adaptiveTimeAxisCache = DayPlanAdaptiveTimeAxisCache()
    @Namespace private var blockAnimationNamespace

    private let timeColumnWidth: CGFloat = DayPlanWeekCalendarSizing.timeColumnWidth

    var body: some View {
        let resolvedTimeAxis = adaptiveTimeAxisCache.axis(
            baseHourHeight: hourHeight,
            intervals: adaptiveTimeAxisIntervals
        )
        let timeAxis = frozenTimeAxis ?? resolvedTimeAxis

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                DayPlanWeekHeaderRow(
                    dates: dates,
                    selectedDate: selectedDate,
                    focusedUnplannedCompletedDate: focusedUnplannedCompletedDate,
                    focusedPlannedTasksDate: selectedDayTaskListDate,
                    calendar: calendar,
                    timeColumnWidth: timeColumnWidth,
                    timeHeaderTitle: calendarTaskViewMode == .list ? "Tasks" : "Time",
                    showsDayTaskButtons: calendarTaskViewMode == .schedule,
                    showsUnplannedCompletedBadges: showsUnplannedCompletedBadges,
                    showsHourSpacingControls: calendarTaskViewMode == .schedule && showsHourSpacingControls,
                    canDecreaseHourSpacing: canDecreaseHourSpacing,
                    canIncreaseHourSpacing: canIncreaseHourSpacing,
                    hourSpacingAccessibilityValue: hourSpacingAccessibilityValue,
                    dayTaskCounts: dayTaskCounts,
                    unplannedCompletedCount: unplannedCompletedCount,
                    onDecreaseHourSpacing: onDecreaseHourSpacing,
                    onIncreaseHourSpacing: onIncreaseHourSpacing,
                    onSelectPlannedTasksDate: { date in
                        presentDayTaskListSidebar(on: date)
                    },
                    onSelectUnplannedCompletedDate: onSelectUnplannedCompletedDate
                )

                if calendarTaskViewMode == .list {
                    DayPlanDayTaskColumnsView(
                        dates: dates,
                        selectedDate: selectedDate,
                        calendar: calendar,
                        timeColumnWidth: timeColumnWidth,
                        isExternalInspectorPresented: isExternalInspectorPresented,
                        dayTaskListItems: dayTaskListItems,
                        taskTint: dayTaskTint,
                        isTaskOpenable: isDayTaskOpenable,
                        onOpenTaskDetails: onOpenDayTaskDetails,
                        onCompletePlannedDayTask: onCompletePlannedDayTask,
                        onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                        onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed
                    )
                } else {
                    DayPlanUnplaceableActivityLaneView(
                        dates: dates,
                        selectedDate: selectedDate,
                        calendar: calendar,
                        timeColumnWidth: timeColumnWidth,
                        blocksForDate: unplaceableAutomaticTimelineBlocksForDate,
                        taskTint: taskTint,
                        onOpenTimelineTaskDetails: onOpenTimelineTaskDetails,
                        onConfirmTimelineActivity: onConfirmTimelineActivity,
                        onHideTimelineActivity: onHideTimelineActivity,
                        onTimelineDragProvider: { activity, date in
                            dragProvider(for: activity, on: date, timeAxis: timeAxis)
                        }
                    )

                    DayPlanAllDayLaneView(
                        dates: dates,
                        selectedDate: selectedDate,
                        calendar: calendar,
                        timeColumnWidth: timeColumnWidth,
                        allDayBlocks: allDayBlocks,
                        allDayTint: allDayTint,
                        draggedBlockID: $draggedBlockID,
                        draggedTimelineActivity: $draggedTimelineActivity,
                        onOpenTaskDetails: onOpenAllDayTaskDetails,
                        onOpenEventDetails: onOpenEventDetails,
                        onMoveBlockToAllDay: onMoveBlockToAllDay,
                        onMoveTimelineActivityToAllDay: onMoveTimelineActivityToAllDay,
                        onDropTaskToAllDay: onDropTaskToAllDay
                    )

                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical) {
                            GeometryReader { proxy in
                                let dayWidth = DayPlanWeekCalendarSizing.dayWidth(
                                    availableWidth: proxy.size.width,
                                    dayCount: max(dates.count, 1),
                                    isExternalInspectorPresented: isExternalInspectorPresented
                                )
                                let contentWidth = timeColumnWidth + (CGFloat(dates.count) * dayWidth)
                                let contentHeight = timeAxis.contentHeight

                                ZStack(alignment: .topLeading) {
                                    DayPlanWeekGridView(
                                        dates: dates,
                                        selectedDate: selectedDate,
                                        calendar: calendar,
                                        dayWidth: dayWidth,
                                        timeAxis: timeAxis,
                                        timeColumnWidth: timeColumnWidth
                                    )
                                    DayPlanSlotSelectionLayer(
                                        dates: dates,
                                        dayWidth: dayWidth,
                                        timeAxis: timeAxis,
                                        timeColumnWidth: timeColumnWidth,
                                        onSelectSlot: { date, minute in
                                            updateSelectedSlotDraft(on: date, startMinute: minute)
                                            onSelectSlot(date, minute)
                                        },
                                        onOpenSlotActions: { date, minute in
                                            presentSlotSidebar(on: date, startMinute: minute)
                                            onSelectSlot(date, minute)
                                        }
                                    )
                                    selectedSlotDraftLayer(
                                        dayWidth: dayWidth,
                                        timeAxis: timeAxis,
                                        timeColumnWidth: timeColumnWidth,
                                        contentWidth: contentWidth,
                                        contentHeight: contentHeight
                                    )
                                    DayPlanBlockLayer(
                                        dates: dates,
                                        selectedBlockID: selectedBlockID,
                                        resizingBlockID: resizeSession?.blockID,
                                        resizingContentLayoutHeight: resizeSession?.contentLayoutHeight,
                                        highlightedBlockID: highlightedBlockID,
                                        focusedSleepSessionID: focusedSleep?.sessionID,
                                        calendar: calendar,
                                        dayWidth: dayWidth,
                                        timeAxis: timeAxis,
                                        timeColumnWidth: timeColumnWidth,
                                        blockAnimationNamespace: blockAnimationNamespace,
                                        blocksForDate: blocksForDate,
                                        automaticTimelineBlocksForDate: automaticTimelineBlocksForDate,
                                        eventBlocksForDate: eventBlocksForDate,
                                        sleepBlocksForDate: sleepBlocksForDate,
                                        awayBlocksForDate: awayBlocksForDate,
                                        sprintFocusBlocksForDate: sprintFocusBlocksForDate,
                                        taskTint: taskTint,
                                        onSelectBlock: { block, date in
                                            selectedSlotDraft = nil
                                            onSelectBlock(block, date)
                                        },
                                        onOpenBlockDetails: { block, date in
                                            selectedSlotDraft = nil
                                            if !presentTagFocusSidebar(for: block) {
                                                onOpenBlockDetails(block, date)
                                            }
                                        },
                                        onOpenTimelineTaskDetails: onOpenTimelineTaskDetails,
                                        onOpenEventDetails: onOpenEventDetails,
                                        onConfirmTimelineActivity: onConfirmTimelineActivity,
                                        onHideTimelineActivity: onHideTimelineActivity,
                                        onTimelineDragProvider: { activity, date in
                                            dragProvider(for: activity, on: date, timeAxis: timeAxis)
                                        },
                                        onDeleteBlock: onDeleteBlock,
                                        onResizeStarted: { block, date in
                                            beginResize(block, date, timeAxis: timeAxis)
                                        },
                                        onResizeChanged: { block, date, edge, verticalDelta in
                                            resize(
                                                block,
                                                date,
                                                edge: edge,
                                                verticalDelta: verticalDelta,
                                                timeAxis: timeAxis
                                            )
                                        },
                                        onResizeEnded: endResize,
                                        onDragProvider: { block, date in
                                            dragProvider(for: block, on: date, timeAxis: timeAxis)
                                        }
                                    )
                                    .id(timedBlockLayerIdentity)
                                    if let dropPreview, isDropTargeted, !isCompletingDrop {
                                        DayPlanDropIndicator(
                                            preview: dropPreview,
                                            dates: dates,
                                            calendar: calendar,
                                            dayWidth: dayWidth,
                                            timeAxis: timeAxis,
                                            timeColumnWidth: timeColumnWidth
                                        )
                                    }
                                    DayPlanCurrentTimeScrollAnchor(
                                        dates: dates,
                                        calendar: calendar,
                                        timeAxis: timeAxis,
                                        timeColumnWidth: timeColumnWidth
                                    )
                                    if let focusedSleep {
                                        DayPlanMinuteScrollAnchor(
                                            target: .focusedSleep(focusedSleep.scrollTargetID),
                                            minute: focusedSleep.startMinute,
                                            timeAxis: timeAxis,
                                            timeColumnWidth: timeColumnWidth
                                        )
                                    }
                                    if let highlightedBlockID, let highlightedBlockScrollMinute {
                                        DayPlanMinuteScrollAnchor(
                                            target: .plannerBlock(highlightedBlockID),
                                            minute: highlightedBlockScrollMinute,
                                            timeAxis: timeAxis,
                                            timeColumnWidth: timeColumnWidth
                                        )
                                    }
                                    SwiftUI.TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                                        ZStack(alignment: .topLeading) {
                                            if showsActiveFocusBlocks {
                                                DayPlanFocusSessionBlockLayer(
                                                    dates: dates,
                                                    calendar: calendar,
                                                    dayWidth: dayWidth,
                                                    timeAxis: timeAxis,
                                                    timeColumnWidth: timeColumnWidth,
                                                    focusSessionBlocks: activeFocusSessionBlocks(timeline.date),
                                                    taskTint: taskTint,
                                                    onOpenFocusTaskDetails: onOpenFocusTaskDetails
                                                )
                                                .zIndex(3)
                                            }

                                            if showsActiveSprintFocusBlocks {
                                                DayPlanSprintFocusBlockLayer(
                                                    dates: dates,
                                                    calendar: calendar,
                                                    dayWidth: dayWidth,
                                                    timeAxis: timeAxis,
                                                    timeColumnWidth: timeColumnWidth,
                                                    sprintFocusBlocks: activeSprintFocusBlocks(timeline.date),
                                                    taskTint: taskTint,
                                                    onOpenFocusTaskDetails: onOpenFocusTaskDetails
                                                )
                                                .zIndex(3.5)
                                            }

                                            DayPlanCurrentTimeIndicator(
                                                dates: dates,
                                                now: timeline.date,
                                                calendar: calendar,
                                                dayWidth: dayWidth,
                                                timeAxis: timeAxis,
                                                timeColumnWidth: timeColumnWidth
                                            )
                                            .zIndex(20)
                                        }
                                        .frame(
                                            width: timeColumnWidth + (CGFloat(dates.count) * dayWidth),
                                            height: timeAxis.contentHeight,
                                            alignment: .topLeading
                                        )
                                    }
                                }
                                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                                .contentShape(Rectangle())
                                .onDrop(
                                    of: [.text],
                                    delegate: DayPlanTaskDropDelegate(
                                        dates: dates,
                                        dayWidth: dayWidth,
                                        timeColumnWidth: timeColumnWidth,
                                        timeAxis: timeAxis,
                                        dropDurationMinutes: dropDurationMinutes,
                                        draggedBlockID: $draggedBlockID,
                                        draggedTimelineActivity: $draggedTimelineActivity,
                                        draggedBlockDurationMinutes: $draggedBlockDurationMinutes,
                                        isCompletingDrop: $isCompletingDrop,
                                        isDropTargeted: $isDropTargeted,
                                        dropPreview: $dropPreview,
                                        blockedIntervalsForDate: blockedIntervalsForDate,
                                        onMoveBlock: onMoveBlock,
                                        onDuplicateBlock: onDuplicateBlock,
                                        onMoveTimelineActivity: onMoveTimelineActivity,
                                        onDropTask: onDropTask
                                    )
                                )
                            }
                            .frame(height: timeAxis.contentHeight)
                        }
                        .onAppear {
                            scrollToInitialTarget(with: scrollProxy)
                        }
                        .onChange(of: dates) { _, _ in
                            clearDayTaskListIfOutsideVisibleDates()
                            if !scrollToPlannerHighlight(with: scrollProxy) {
                                scrollToInitialTarget(with: scrollProxy)
                            }
                        }
                        .onChange(of: hourHeight) { _, _ in
                            scrollToInitialTarget(with: scrollProxy)
                        }
                        .onChange(of: focusedSleep) { _, _ in
                            scrollToFocusedSleep(with: scrollProxy)
                        }
                        .onChange(of: highlightedBlockID) { _, _ in
                            scrollToPlannerHighlight(with: scrollProxy)
                        }
                        .onChange(of: highlightedBlockScrollMinute) { _, _ in
                            scrollToPlannerHighlight(with: scrollProxy)
                        }
                    }
                }
            }
            .frame(
                minWidth: DayPlanWeekCalendarSizing.minimumCalendarWidth(
                    isExternalInspectorPresented: isExternalInspectorPresented
                )
            )
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            onCalendarWidthChanged(proxy.size.width)
                        }
                        .onChange(of: proxy.size.width) { _, width in
                            onCalendarWidthChanged(width)
                        }
                }
            }

            plannerRightSidebar
        }
        .animation(.easeInOut(duration: 0.16), value: selectedSlotDraft)
        .animation(.easeInOut(duration: 0.16), value: isRightSidebarPresented)
        .onChange(of: draggedBlockID) { _, _ in
            releaseFrozenTimeAxisAfterDragIfNeeded()
        }
        .onChange(of: draggedTimelineActivity?.id) { _, _ in
            releaseFrozenTimeAxisAfterDragIfNeeded()
        }
        .onChange(of: isFilterSidebarPresented.wrappedValue) { _, isPresented in
            guard isPresented else { return }
            onSidebarPresentationRequested?()
            isDatePickerSidebarPresented.wrappedValue = false
            selectedSlotDraft = nil
            selectedDayTaskListDate = nil
            selectedTagFocusSessionID = nil
            draftResizeBaseline = nil
        }
        .onChange(of: isDatePickerSidebarPresented.wrappedValue) { _, isPresented in
            guard isPresented else { return }
            onSidebarPresentationRequested?()
            isFilterSidebarPresented.wrappedValue = false
            selectedSlotDraft = nil
            selectedDayTaskListDate = nil
            selectedTagFocusSessionID = nil
            draftResizeBaseline = nil
        }
        .onChange(of: isExternalInspectorPresented) { _, isPresented in
            guard isPresented else { return }
            dismissPlannerRightSidebar()
        }
        .onChange(of: calendarTaskViewMode) { _, mode in
            guard mode == .list else { return }
            dismissScheduleInteractionState()
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isDropTargeted ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.18), lineWidth: isDropTargeted ? 1.5 : 1)
        }
    }
}
