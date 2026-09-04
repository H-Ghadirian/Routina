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

    @State private var isDropTargeted = false
    @State private var isCompletingDrop = false
    @State private var dropPreview: DayPlanDropPreview?
    @State private var draggedBlockID: DayPlanBlock.ID?
    @State private var draggedTimelineActivity: DayPlanTimelineActivityBlock?
    @State private var draggedBlockDurationMinutes: Int?
    @State private var resizeSession: DayPlanResizeSession?
    @State private var selectedSlotDraft: DayPlanSelectedSlotDraft?
    @State private var selectedDayTaskListDate: Date?
    @State private var selectedTagFocusSessionID: UUID?
    @State private var draftResizeBaseline: DayPlanSelectedSlotDraft?
    @State private var frozenTimeAxis: DayPlanAdaptiveTimeAxis?
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

    private func beginResize(
        _ block: DayPlanBlock,
        _ date: Date,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        clearDropState()
        draggedBlockID = nil
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = nil
        frozenTimeAxis = timeAxis
        onSelectBlock(block, date)
        onBeginResizeBlock(block, date)
        resizeSession = DayPlanResizeSession(
            blockID: block.id,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes,
            contentLayoutHeight: blockHeight(for: block, timeAxis: timeAxis)
        )
    }

    private func resize(
        _ block: DayPlanBlock,
        _ date: Date,
        edge: DayPlanResizeEdge,
        verticalDelta: CGFloat,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) {
        let session =
            resizeSession
            ?? DayPlanResizeSession(
                blockID: block.id,
                startMinute: block.startMinute,
                durationMinutes: block.durationMinutes,
                contentLayoutHeight: blockHeight(for: block, timeAxis: timeAxis)
            )
        guard session.blockID == block.id else { return }

        let originalStart = session.startMinute
        let originalEnd = originalStart + session.durationMinutes
        let deltaMinutes = timeAxis.minuteDelta(
            forVerticalDelta: verticalDelta,
            fromMinute: edge == .top ? originalStart : originalEnd
        )
        let startMinute: Int
        let durationMinutes: Int

        switch edge {
        case .top:
            let minStart = 0
            let maxStart = originalEnd - DayPlanBlock.minimumStoredDurationMinutes
            startMinute = min(max(originalStart + deltaMinutes, minStart), maxStart)
            durationMinutes = originalEnd - startMinute
        case .bottom:
            let minEnd = originalStart + DayPlanBlock.minimumStoredDurationMinutes
            let maxEnd = DayPlanBlock.minutesPerDay
            let endMinute = min(max(originalEnd + deltaMinutes, minEnd), maxEnd)
            startMinute = originalStart
            durationMinutes = endMinute - originalStart
        }

        guard startMinute != block.startMinute || durationMinutes != block.durationMinutes else { return }
        onResizeBlock(block.id, date, startMinute, durationMinutes)
    }

    private func endResize() {
        let blockID = resizeSession?.blockID
        resizeSession = nil
        frozenTimeAxis = nil
        onEndResizeBlock(blockID)
    }

    private var timedBlockLayerIdentity: String {
        dates.map { date in
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let blockSignature = blocksForDate(date)
                .map { block in
                    [
                        block.id.uuidString,
                        block.dayKey,
                    ].joined(separator: ":")
                }
                .joined(separator: ",")
            return "\(dayKey)=\(blockSignature)"
        }
        .joined(separator: "|")
    }

    private var adaptiveTimeAxisIntervals: [DayPlanAdaptiveTimeAxis.Interval] {
        guard calendarTaskViewMode == .schedule else { return [] }

        var intervals: [DayPlanAdaptiveTimeAxis.Interval] = []
        intervals.reserveCapacity(dates.count * 8)

        for date in dates {
            intervals.append(
                contentsOf: blocksForDate(date).map {
                    adaptiveInterval(for: $0)
                }
            )
            intervals.append(
                contentsOf: automaticTimelineBlocksForDate(date).map {
                    adaptiveInterval(for: $0.block)
                }
            )
            intervals.append(
                contentsOf: eventBlocksForDate(date).map {
                    adaptiveInterval(for: $0.block)
                }
            )
            intervals.append(
                contentsOf: sleepBlocksForDate(date).map {
                    adaptiveInterval(for: $0.block)
                }
            )
            intervals.append(
                contentsOf: awayBlocksForDate(date).map {
                    adaptiveInterval(for: $0.block)
                }
            )
            intervals.append(
                contentsOf: sprintFocusBlocksForDate(date).map { sprintBlock in
                    DayPlanAdaptiveTimeAxis.Interval(
                        groupID: sprintBlock.block.dayKey,
                        startMinute: sprintBlock.block.startMinute,
                        durationMinutes: sprintBlock.isActive
                            ? sprintBlock.renderedDurationMinutes
                            : sprintBlock.block.durationMinutes
                    )
                }
            )
        }

        if let selectedSlotDraft {
            if dates.contains(where: {
                calendar.isDate($0, inSameDayAs: selectedSlotDraft.date)
            }) {
                intervals.append(
                    DayPlanAdaptiveTimeAxis.Interval(
                        groupID: DayPlanStorage.dayKey(
                            for: selectedSlotDraft.date,
                            calendar: calendar
                        ),
                        startMinute: selectedSlotDraft.startMinute,
                        durationMinutes: selectedSlotDraft.durationMinutes
                    )
                )
            }
        }

        return intervals
    }

    private func adaptiveInterval(
        for block: DayPlanBlock
    ) -> DayPlanAdaptiveTimeAxis.Interval {
        DayPlanAdaptiveTimeAxis.Interval(
            groupID: block.dayKey,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes
        )
    }

    private func blockHeight(
        for block: DayPlanBlock,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) -> CGFloat {
        max(
            timeAxis.height(
                startMinute: block.startMinute,
                durationMinutes: block.durationMinutes
            ),
            DayPlanAdaptiveTimeAxis.minimumInteractiveBlockHeight
        )
    }

    private func clearDropState() {
        isDropTargeted = false
        dropPreview = nil
    }

    private func releaseFrozenTimeAxisAfterDragIfNeeded() {
        guard draggedBlockID == nil,
            draggedTimelineActivity == nil,
            resizeSession == nil,
            draftResizeBaseline == nil
        else {
            return
        }

        frozenTimeAxis = nil
    }

    private func dismissScheduleInteractionState() {
        selectedSlotDraft = nil
        selectedTagFocusSessionID = nil
        draftResizeBaseline = nil
        isCompletingDrop = false
        draggedBlockID = nil
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = nil
        frozenTimeAxis = nil
        clearDropState()
        endResize()
    }

    private func dragProvider(
        for block: DayPlanBlock,
        on date: Date,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) -> NSItemProvider {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        isCompletingDrop = false
        clearDropState()
        endResize()
        draggedBlockID = block.id
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = block.durationMinutes
        frozenTimeAxis = timeAxis
        onSelectBlock(block, date)
        return NSItemProvider(object: DayPlanBlockDragPayload.text(for: block.id) as NSString)
    }

    private func dragProvider(
        for activity: DayPlanTimelineActivityBlock,
        on date: Date,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) -> NSItemProvider {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        isCompletingDrop = false
        clearDropState()
        endResize()
        draggedBlockID = nil
        draggedTimelineActivity = activity
        draggedBlockDurationMinutes = activity.block.durationMinutes
        frozenTimeAxis = timeAxis
        return NSItemProvider(object: "day-plan-timeline-activity:\(activity.id)" as NSString)
    }

    private func presentSlotSidebar(on date: Date, startMinute: Int) {
        guard slotSidebarContent != nil else { return }
        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        draftResizeBaseline = nil
        selectedDayTaskListDate = nil
        selectedTagFocusSessionID = nil
        let clampedStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        selectedSlotDraft = DayPlanSelectedSlotDraft(
            date: calendar.startOfDay(for: date),
            startMinute: clampedStartMinute,
            durationMinutes: defaultSlotDraftDuration(startMinute: clampedStartMinute)
        )
    }

    private func updateSelectedSlotDraft(on date: Date, startMinute: Int) {
        guard var draft = selectedSlotDraft else { return }

        let clampedStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        draft.date = calendar.startOfDay(for: date)
        draft.startMinute = clampedStartMinute
        draft.durationMinutes = DayPlanBlock.clampedDuration(
            draft.durationMinutes,
            startMinute: clampedStartMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        selectedSlotDraft = draft
    }

    private func presentDayTaskListSidebar(on date: Date) {
        guard dayTaskListSidebarContent != nil else { return }
        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        selectedSlotDraft = nil
        selectedTagFocusSessionID = nil
        draftResizeBaseline = nil
        selectedDayTaskListDate = calendar.startOfDay(for: date)
    }

    @discardableResult
    private func presentTagFocusSidebar(for block: DayPlanBlock) -> Bool {
        guard tagFocusSidebarContent != nil,
            let sessionID = completedTagFocusSessionID(block)
        else {
            return false
        }

        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        selectedSlotDraft = nil
        selectedDayTaskListDate = nil
        draftResizeBaseline = nil
        selectedTagFocusSessionID = sessionID
        return true
    }

    @ViewBuilder
    private func selectedSlotDraftLayer(
        dayWidth: CGFloat,
        timeAxis: DayPlanAdaptiveTimeAxis,
        timeColumnWidth: CGFloat,
        contentWidth: CGFloat,
        contentHeight: CGFloat
    ) -> some View {
        if let selectedSlotDraft {
            if let dayIndex = dates.firstIndex(where: {
                calendar.isDate($0, inSameDayAs: selectedSlotDraft.date)
            }) {
                let draftX = timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5
                let draftWidth = max(dayWidth - 10, 90)
                let draftY = timeAxis.yOffset(forMinute: selectedSlotDraft.startMinute)
                let draftHeight = draftBlockHeight(for: selectedSlotDraft, timeAxis: timeAxis)

                ZStack(alignment: .topLeading) {
                    DayPlanSlotDraftBlock(
                        date: selectedSlotDraft.date,
                        startMinute: selectedSlotDraft.startMinute,
                        durationMinutes: selectedSlotDraft.durationMinutes,
                        renderedHeight: draftHeight,
                        calendar: calendar,
                        onResizeStarted: {
                            beginDraftResize(timeAxis: timeAxis)
                        },
                        onResizeChanged: { edge, verticalDelta in
                            resizeDraft(
                                edge: edge,
                                verticalDelta: verticalDelta,
                                timeAxis: timeAxis
                            )
                        },
                        onResizeEnded: endDraftResize
                    )
                    .frame(width: draftWidth, height: draftHeight)
                    .position(x: draftX + (draftWidth / 2), y: draftY + (draftHeight / 2))
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .zIndex(70)
            }
        }
    }

    @ViewBuilder
    private var plannerRightSidebar: some View {
        if isRightSidebarPresented {
            Divider()

            ScrollView {
                plannerRightSidebarContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.visible)
            .frame(width: DayPlanSlotSidebarPresentation.width)
            .background(Color.secondary.opacity(0.045))
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private var isRightSidebarPresented: Bool {
        !isExternalInspectorPresented
            && ((selectedSlotDraft != nil && slotSidebarContent != nil)
                || (selectedDayTaskListDate != nil && dayTaskListSidebarContent != nil)
                || (selectedTagFocusSessionID != nil && tagFocusSidebarContent != nil)
                || (isFilterSidebarPresented.wrappedValue && filterSidebarContent != nil)
                || (isDatePickerSidebarPresented.wrappedValue && datePickerSidebarContent != nil))
    }

    @ViewBuilder
    private var plannerRightSidebarContent: some View {
        if let selectedSlotDraft, let slotSidebarContent {
            slotSidebarContent(
                selectedSlotDraft.date,
                selectedSlotDraft.startMinute,
                selectedSlotDurationBinding(for: selectedSlotDraft),
                dismissSelectedSlotSidebar
            )
        } else if let selectedDayTaskListDate, let dayTaskListSidebarContent {
            dayTaskListSidebarContent(
                selectedDayTaskListDate,
                dismissDayTaskListSidebar
            )
        } else if let selectedTagFocusSessionID, let tagFocusSidebarContent {
            tagFocusSidebarContent(
                selectedTagFocusSessionID,
                dismissTagFocusSidebar
            )
        } else if isFilterSidebarPresented.wrappedValue, let filterSidebarContent {
            filterSidebarContent(dismissFilterSidebar)
        } else if isDatePickerSidebarPresented.wrappedValue, let datePickerSidebarContent {
            datePickerSidebarContent(dismissDatePickerSidebar)
        }
    }

    private func dismissSelectedSlotSidebar() {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
    }

    private func dismissDayTaskListSidebar() {
        selectedDayTaskListDate = nil
    }

    private func dismissTagFocusSidebar() {
        selectedTagFocusSessionID = nil
    }

    private func dismissFilterSidebar() {
        isFilterSidebarPresented.wrappedValue = false
    }

    private func dismissDatePickerSidebar() {
        isDatePickerSidebarPresented.wrappedValue = false
    }

    private func dismissPlannerRightSidebar() {
        selectedSlotDraft = nil
        selectedDayTaskListDate = nil
        selectedTagFocusSessionID = nil
        draftResizeBaseline = nil
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
    }

    private func clearDayTaskListIfOutsideVisibleDates() {
        guard let selectedDayTaskListDate else { return }
        guard !dates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDayTaskListDate) }) else {
            return
        }
        self.selectedDayTaskListDate = nil
    }

    private func selectedSlotDurationBinding(for selection: DayPlanSelectedSlotDraft) -> Binding<Int> {
        Binding(
            get: {
                selectedSlotDraft?.durationMinutes ?? selection.durationMinutes
            },
            set: { newValue in
                guard var draft = selectedSlotDraft else { return }
                draft.durationMinutes = clampedSlotDraftDuration(newValue)
                selectedSlotDraft = draft
            }
        )
    }

    private func defaultSlotDraftDuration(startMinute: Int) -> Int {
        DayPlanBlock.clampedDuration(
            max(dropDurationMinutes, DayPlanBlock.minimumDurationMinutes),
            startMinute: startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumDurationMinutes
        )
    }

    private func clampedSlotDraftDuration(_ durationMinutes: Int) -> Int {
        min(
            max(durationMinutes, DayPlanBlock.minimumStoredDurationMinutes),
            16 * 60
        )
    }

    private func beginDraftResize(timeAxis: DayPlanAdaptiveTimeAxis) {
        draftResizeBaseline = selectedSlotDraft
        frozenTimeAxis = timeAxis
    }

    private func resizeDraft(
        edge: DayPlanResizeEdge,
        verticalDelta: CGFloat,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) {
        guard let baseline = draftResizeBaseline ?? selectedSlotDraft else { return }

        let originalStart = baseline.startMinute
        let visualOriginalEnd = min(
            DayPlanBlock.minutesPerDay,
            originalStart
                + max(
                    baseline.durationMinutes,
                    DayPlanBlock.minimumStoredDurationMinutes
                )
        )
        let deltaMinutes = timeAxis.minuteDelta(
            forVerticalDelta: verticalDelta,
            fromMinute: edge == .top ? originalStart : visualOriginalEnd,
            snappingTo: 15
        )
        let startMinute: Int
        let durationMinutes: Int

        switch edge {
        case .top:
            let maxStart = visualOriginalEnd - DayPlanBlock.minimumStoredDurationMinutes
            startMinute = min(max(originalStart + deltaMinutes, 0), maxStart)
            durationMinutes = visualOriginalEnd - startMinute
        case .bottom:
            let minEnd = originalStart + DayPlanBlock.minimumStoredDurationMinutes
            let endMinute = min(max(visualOriginalEnd + deltaMinutes, minEnd), DayPlanBlock.minutesPerDay)
            startMinute = originalStart
            durationMinutes = endMinute - originalStart
        }

        guard var draft = selectedSlotDraft else { return }
        draft.startMinute = DayPlanBlock.clampedStartMinute(startMinute)
        draft.durationMinutes = clampedSlotDraftDuration(durationMinutes)
        selectedSlotDraft = draft
    }

    private func endDraftResize() {
        draftResizeBaseline = nil
        frozenTimeAxis = nil
    }

    private func draftBlockHeight(
        for selection: DayPlanSelectedSlotDraft,
        timeAxis: DayPlanAdaptiveTimeAxis
    ) -> CGFloat {
        let visibleDurationMinutes = min(
            max(selection.durationMinutes, DayPlanBlock.minimumStoredDurationMinutes),
            DayPlanBlock.minutesPerDay - selection.startMinute
        )
        return max(
            timeAxis.height(
                startMinute: selection.startMinute,
                durationMinutes: visibleDurationMinutes
            ),
            DayPlanAdaptiveTimeAxis.minimumInteractiveBlockHeight
        )
    }

}
