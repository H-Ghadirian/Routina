import SwiftUI
import UniformTypeIdentifiers

enum DayPlanWeekCalendarSizing {
    static let timeColumnWidth: CGFloat = 64
    static let regularMinimumCalendarWidth: CGFloat = 420
    static let inspectorMinimumCalendarWidth: CGFloat = 360
    static let inspectorMultiDayMinimumCalendarWidth: CGFloat = 860
    static let regularMinimumDayWidth: CGFloat = 120
    static let inspectorMinimumDayWidth: CGFloat = 96
    static let detailPadding: CGFloat = 20
    static let detailHorizontalPadding: CGFloat = detailPadding * 2
    static let dayTaskListColumnPadding: CGFloat = 10

    private static let dayTaskListRowHorizontalPadding: CGFloat = 20
    private static let dayTaskListAvatarWidth: CGFloat = 34
    private static let dayTaskListAvatarSpacing: CGFloat = 10
    private static let dayTaskListTrailingTextReserve: CGFloat = 16
    private static let minimumDayTaskListTextWidthWithAvatar: CGFloat = 88

    static func minimumCalendarWidth(isExternalInspectorPresented: Bool) -> CGFloat {
        isExternalInspectorPresented ? inspectorMinimumCalendarWidth : regularMinimumCalendarWidth
    }

    static func minimumDetailWidth(isExternalInspectorPresented: Bool) -> CGFloat {
        minimumCalendarWidth(isExternalInspectorPresented: isExternalInspectorPresented) + detailHorizontalPadding
    }

    static func dayWidth(
        availableWidth: CGFloat,
        dayCount: Int,
        isExternalInspectorPresented: Bool
    ) -> CGFloat {
        let dayCount = max(dayCount, 1)
        let minimumDayWidth = isExternalInspectorPresented
            ? inspectorMinimumDayWidth
            : regularMinimumDayWidth
        let availableDayWidth = max(availableWidth - timeColumnWidth, 0) / CGFloat(dayCount)
        return max(availableDayWidth, minimumDayWidth)
    }

    static func showsDayTaskListAvatar(rowWidth: CGFloat?) -> Bool {
        guard let rowWidth, rowWidth.isFinite else { return true }

        let reservedWidth = dayTaskListRowHorizontalPadding
            + dayTaskListAvatarWidth
            + dayTaskListAvatarSpacing
            + dayTaskListTrailingTextReserve

        return rowWidth - reservedWidth >= minimumDayTaskListTextWidthWithAvatar
    }
}

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
    var onOpenDayTaskDetails: (UUID) -> Void = { _ in }
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
    var onMoveTimelineActivity: (DayPlanTimelineActivityBlock, Date, Int) -> Void = { _, _, _ in }
    var onMoveBlockToAllDay: (DayPlanBlock.ID, Date) -> Void = { _, _ in }
    var onMoveTimelineActivityToAllDay: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onBeginResizeBlock: (DayPlanBlock, Date) -> Void = { _, _ in }
    var onResizeBlock: (DayPlanBlock.ID, Date, Int, Int) -> Void
    var onEndResizeBlock: (DayPlanBlock.ID?) -> Void = { _ in }
    var onDropTask: (UUID, Date, Int) -> Void
    var onDropTaskToAllDay: (UUID, Date) -> Void = { _, _ in }
    var slotSidebarContent: ((Date, Int, Binding<Int>, @escaping () -> Void) -> AnyView)? = nil
    var dayTaskListSidebarContent: ((Date, @escaping () -> Void) -> AnyView)? = nil
    var isFilterSidebarPresented: Binding<Bool> = .constant(false)
    var filterSidebarContent: ((@escaping () -> Void) -> AnyView)? = nil
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var datePickerSidebarContent: ((@escaping () -> Void) -> AnyView)? = nil
    var isExternalInspectorPresented = false
    var onSidebarPresentationRequested: (() -> Void)? = nil

    @State private var isDropTargeted = false
    @State private var isCompletingDrop = false
    @State private var dropPreview: DayPlanDropPreview?
    @State private var draggedBlockID: DayPlanBlock.ID?
    @State private var draggedTimelineActivity: DayPlanTimelineActivityBlock?
    @State private var draggedBlockDurationMinutes: Int?
    @State private var resizeSession: DayPlanResizeSession?
    @State private var selectedSlotDraft: DayPlanSelectedSlotDraft?
    @State private var selectedDayTaskListDate: Date?
    @State private var draftResizeBaseline: DayPlanSelectedSlotDraft?
    @Namespace private var blockAnimationNamespace

    private let timeColumnWidth: CGFloat = DayPlanWeekCalendarSizing.timeColumnWidth

    var body: some View {
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
                        dragProvider(for: activity, on: date)
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
                            let contentHeight = hourHeight * 24

                            ZStack(alignment: .topLeading) {
                                DayPlanWeekGridView(
                                    dates: dates,
                                    selectedDate: selectedDate,
                                    calendar: calendar,
                                    dayWidth: dayWidth,
                                    hourHeight: hourHeight,
                                    timeColumnWidth: timeColumnWidth
                                )
                                DayPlanSlotSelectionLayer(
                                    dates: dates,
                                    dayWidth: dayWidth,
                                    hourHeight: hourHeight,
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
                                    hourHeight: hourHeight,
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
                                    hourHeight: hourHeight,
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
                                        onOpenBlockDetails(block, date)
                                    },
                                    onOpenTimelineTaskDetails: onOpenTimelineTaskDetails,
                                    onOpenEventDetails: onOpenEventDetails,
                                    onConfirmTimelineActivity: onConfirmTimelineActivity,
                                    onHideTimelineActivity: onHideTimelineActivity,
                                    onTimelineDragProvider: { activity, date in
                                        dragProvider(for: activity, on: date)
                                    },
                                    onDeleteBlock: onDeleteBlock,
                                    onResizeStarted: { block, date in
                                        beginResize(block, date)
                                    },
                                    onResizeChanged: { block, date, edge, verticalDelta in
                                        resize(block, date, edge: edge, verticalDelta: verticalDelta)
                                    },
                                    onResizeEnded: endResize,
                                    onDragProvider: { block, date in
                                        dragProvider(for: block, on: date)
                                    }
                                )
                                .id(timedBlockLayerIdentity)
                            if let dropPreview, isDropTargeted, !isCompletingDrop {
                                DayPlanDropIndicator(
                                    preview: dropPreview,
                                    dates: dates,
                                    calendar: calendar,
                                    dayWidth: dayWidth,
                                    hourHeight: hourHeight,
                                    timeColumnWidth: timeColumnWidth
                                )
                            }
                            DayPlanCurrentTimeScrollAnchor(
                                dates: dates,
                                calendar: calendar,
                                hourHeight: hourHeight,
                                timeColumnWidth: timeColumnWidth
                            )
                            if let focusedSleep {
                                DayPlanMinuteScrollAnchor(
                                    target: .focusedSleep(focusedSleep.scrollTargetID),
                                    minute: focusedSleep.startMinute,
                                    hourHeight: hourHeight,
                                    timeColumnWidth: timeColumnWidth
                                )
                            }
                            if let highlightedBlockID, let highlightedBlockScrollMinute {
                                DayPlanMinuteScrollAnchor(
                                    target: .plannerBlock(highlightedBlockID),
                                    minute: highlightedBlockScrollMinute,
                                    hourHeight: hourHeight,
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
                                            hourHeight: hourHeight,
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
                                            hourHeight: hourHeight,
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
                                        hourHeight: hourHeight,
                                        timeColumnWidth: timeColumnWidth
                                    )
                                    .zIndex(20)
                                }
                                .frame(
                                    width: timeColumnWidth + (CGFloat(dates.count) * dayWidth),
                                    height: hourHeight * 24,
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
                                hourHeight: hourHeight,
                                dropDurationMinutes: dropDurationMinutes,
                                draggedBlockID: $draggedBlockID,
                                draggedTimelineActivity: $draggedTimelineActivity,
                                draggedBlockDurationMinutes: $draggedBlockDurationMinutes,
                                isCompletingDrop: $isCompletingDrop,
                                isDropTargeted: $isDropTargeted,
                                dropPreview: $dropPreview,
                                blockedIntervalsForDate: blockedIntervalsForDate,
                                onMoveBlock: onMoveBlock,
                                onMoveTimelineActivity: onMoveTimelineActivity,
                                onDropTask: onDropTask
                            )
                        )
                    }
                    .frame(height: hourHeight * 24)
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
        .onChange(of: isFilterSidebarPresented.wrappedValue) { _, isPresented in
            guard isPresented else { return }
            onSidebarPresentationRequested?()
            isDatePickerSidebarPresented.wrappedValue = false
            selectedSlotDraft = nil
            selectedDayTaskListDate = nil
            draftResizeBaseline = nil
        }
        .onChange(of: isDatePickerSidebarPresented.wrappedValue) { _, isPresented in
            guard isPresented else { return }
            onSidebarPresentationRequested?()
            isFilterSidebarPresented.wrappedValue = false
            selectedSlotDraft = nil
            selectedDayTaskListDate = nil
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
                .stroke(isDropTargeted ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.18), lineWidth: isDropTargeted ? 1.5 : 1)
        }
    }

    private func beginResize(_ block: DayPlanBlock, _ date: Date) {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        clearDropState()
        draggedBlockID = nil
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = nil
        onSelectBlock(block, date)
        onBeginResizeBlock(block, date)
        resizeSession = DayPlanResizeSession(
            blockID: block.id,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes,
            contentLayoutHeight: blockHeight(forDurationMinutes: block.durationMinutes)
        )
    }

    private func resize(
        _ block: DayPlanBlock,
        _ date: Date,
        edge: DayPlanResizeEdge,
        verticalDelta: CGFloat
    ) {
        let session = resizeSession ?? DayPlanResizeSession(
            blockID: block.id,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes,
            contentLayoutHeight: blockHeight(forDurationMinutes: block.durationMinutes)
        )
        guard session.blockID == block.id else { return }

        let deltaMinutes = minuteDelta(for: verticalDelta)
        let originalStart = session.startMinute
        let originalEnd = originalStart + session.durationMinutes
        let startMinute: Int
        let durationMinutes: Int

        switch edge {
        case .top:
            let minStart = 0
            let maxStart = originalEnd - DayPlanBlock.minimumDurationMinutes
            startMinute = min(max(originalStart + deltaMinutes, minStart), maxStart)
            durationMinutes = originalEnd - startMinute
        case .bottom:
            let minEnd = originalStart + DayPlanBlock.minimumDurationMinutes
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
        onEndResizeBlock(blockID)
    }

    private func minuteDelta(for verticalDelta: CGFloat) -> Int {
        let rawMinutes = (verticalDelta / hourHeight) * 60
        return Int(rawMinutes.rounded())
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

    private func blockHeight(forDurationMinutes durationMinutes: Int) -> CGFloat {
        max(CGFloat(durationMinutes) / 60 * hourHeight, 18)
    }

    private func clearDropState() {
        isDropTargeted = false
        dropPreview = nil
    }

    private func dismissScheduleInteractionState() {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        isCompletingDrop = false
        draggedBlockID = nil
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = nil
        clearDropState()
        endResize()
    }

    private func dragProvider(for block: DayPlanBlock, on date: Date) -> NSItemProvider {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        isCompletingDrop = false
        clearDropState()
        endResize()
        draggedBlockID = block.id
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = block.durationMinutes
        onSelectBlock(block, date)
        return NSItemProvider(object: DayPlanBlockDragPayload.text(for: block.id) as NSString)
    }

    private func dragProvider(for activity: DayPlanTimelineActivityBlock, on date: Date) -> NSItemProvider {
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        isCompletingDrop = false
        clearDropState()
        endResize()
        draggedBlockID = nil
        draggedTimelineActivity = activity
        draggedBlockDurationMinutes = activity.block.durationMinutes
        return NSItemProvider(object: "day-plan-timeline-activity:\(activity.id)" as NSString)
    }

    private func scrollToCurrentTime(with proxy: ScrollViewProxy) {
        guard dates.contains(where: { calendar.isDateInToday($0) }) else { return }

        DispatchQueue.main.async {
            proxy.scrollTo(DayPlanScrollTarget.currentTime, anchor: .center)
        }
    }

    private func scrollToInitialTarget(with proxy: ScrollViewProxy) {
        if !scrollToPlannerHighlight(with: proxy), !scrollToFocusedSleep(with: proxy) {
            scrollToCurrentTime(with: proxy)
        }
    }

    @discardableResult
    private func scrollToFocusedSleep(with proxy: ScrollViewProxy) -> Bool {
        guard let focusedSleep else { return false }

        DispatchQueue.main.async {
            proxy.scrollTo(DayPlanScrollTarget.focusedSleep(focusedSleep.scrollTargetID), anchor: .center)
        }
        return true
    }

    @discardableResult
    private func scrollToPlannerHighlight(with proxy: ScrollViewProxy) -> Bool {
        guard let highlightedBlockID else { return false }

        DispatchQueue.main.async {
            proxy.scrollTo(DayPlanScrollTarget.plannerBlock(highlightedBlockID), anchor: .center)
        }
        return true
    }

    private func presentSlotSidebar(on date: Date, startMinute: Int) {
        guard slotSidebarContent != nil else { return }
        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        draftResizeBaseline = nil
        selectedDayTaskListDate = nil
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
            minimumDurationMinutes: DayPlanBlock.minimumDurationMinutes
        )
        selectedSlotDraft = draft
    }

    private func presentDayTaskListSidebar(on date: Date) {
        guard dayTaskListSidebarContent != nil else { return }
        onSidebarPresentationRequested?()
        isFilterSidebarPresented.wrappedValue = false
        isDatePickerSidebarPresented.wrappedValue = false
        selectedSlotDraft = nil
        draftResizeBaseline = nil
        selectedDayTaskListDate = calendar.startOfDay(for: date)
    }

    @ViewBuilder
    private func selectedSlotDraftLayer(
        dayWidth: CGFloat,
        hourHeight: CGFloat,
        timeColumnWidth: CGFloat,
        contentWidth: CGFloat,
        contentHeight: CGFloat
    ) -> some View {
        if let selectedSlotDraft,
           dates.contains(where: { calendar.isDate($0, inSameDayAs: selectedSlotDraft.date) }),
           let dayIndex = dates.firstIndex(where: { calendar.isDate($0, inSameDayAs: selectedSlotDraft.date) }) {
            let draftX = timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5
            let draftWidth = max(dayWidth - 10, 90)
            let draftY = yOffset(for: selectedSlotDraft.startMinute, hourHeight: hourHeight)
            let draftHeight = draftBlockHeight(for: selectedSlotDraft, hourHeight: hourHeight)

            ZStack(alignment: .topLeading) {
                DayPlanSlotDraftBlock(
                    date: selectedSlotDraft.date,
                    startMinute: selectedSlotDraft.startMinute,
                    durationMinutes: selectedSlotDraft.durationMinutes,
                    renderedHeight: draftHeight,
                    calendar: calendar,
                    onResizeStarted: beginDraftResize,
                    onResizeChanged: resizeDraft,
                    onResizeEnded: endDraftResize
                )
                .frame(width: draftWidth, height: draftHeight)
                .position(x: draftX + (draftWidth / 2), y: draftY + (draftHeight / 2))
            }
            .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
            .zIndex(70)
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

    private func dismissFilterSidebar() {
        isFilterSidebarPresented.wrappedValue = false
    }

    private func dismissDatePickerSidebar() {
        isDatePickerSidebarPresented.wrappedValue = false
    }

    private func dismissPlannerRightSidebar() {
        selectedSlotDraft = nil
        selectedDayTaskListDate = nil
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
        min(max(durationMinutes, 5), 16 * 60)
    }

    private func beginDraftResize() {
        draftResizeBaseline = selectedSlotDraft
    }

    private func resizeDraft(edge: DayPlanResizeEdge, verticalDelta: CGFloat) {
        guard let baseline = draftResizeBaseline ?? selectedSlotDraft else { return }

        let deltaMinutes = snappedMinuteDelta(for: verticalDelta)
        let originalStart = baseline.startMinute
        let visualOriginalEnd = min(
            DayPlanBlock.minutesPerDay,
            originalStart + max(baseline.durationMinutes, DayPlanBlock.minimumDurationMinutes)
        )
        let startMinute: Int
        let durationMinutes: Int

        switch edge {
        case .top:
            let maxStart = visualOriginalEnd - DayPlanBlock.minimumDurationMinutes
            startMinute = min(max(originalStart + deltaMinutes, 0), maxStart)
            durationMinutes = visualOriginalEnd - startMinute
        case .bottom:
            let minEnd = originalStart + DayPlanBlock.minimumDurationMinutes
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
    }

    private func snappedMinuteDelta(for verticalDelta: CGFloat) -> Int {
        let rawMinutes = (verticalDelta / hourHeight) * 60
        return Int((rawMinutes / 15).rounded()) * 15
    }

    private func yOffset(for minute: Int, hourHeight: CGFloat) -> CGFloat {
        CGFloat(minute) / 60 * hourHeight
    }

    private func draftBlockHeight(
        for selection: DayPlanSelectedSlotDraft,
        hourHeight: CGFloat
    ) -> CGFloat {
        let visibleDurationMinutes = min(
            max(selection.durationMinutes, 5),
            DayPlanBlock.minutesPerDay - selection.startMinute
        )
        return max(CGFloat(visibleDurationMinutes) / 60 * hourHeight, 18)
    }

}

struct DayPlanSlotSidebarPresentation {
    static let width: CGFloat = 400
}

private struct DayPlanSelectedSlotDraft: Equatable {
    var date: Date
    var startMinute: Int
    var durationMinutes: Int
}

private struct DayPlanSlotDraftBlock: View {
    var date: Date
    var startMinute: Int
    var durationMinutes: Int
    var renderedHeight: CGFloat
    var calendar: Calendar
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void

    private var tint: Color {
        .accentColor
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tint.opacity(0.88))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Block")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Label(intervalText, systemImage: "clock")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .overlay(alignment: .top) {
                resizeHandle(edge: .top)
            }
            .overlay(alignment: .bottom) {
                resizeHandle(edge: .bottom)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.28), radius: 10, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityLabel("New block, \(intervalText)")
    }

    private var intervalText: String {
        guard let startDate = calendar.date(
            byAdding: .minute,
            value: startMinute,
            to: calendar.startOfDay(for: date)
        ),
              let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate)
        else {
            return "\(DayPlanFormatting.timeText(for: startMinute, on: date, calendar: calendar)) - \(DayPlanFormatting.timeText(for: startMinute + durationMinutes, on: date, calendar: calendar))"
        }

        let startText = startDate.formatted(date: .omitted, time: .shortened)
        let endText: String
        if calendar.isDate(endDate, inSameDayAs: startDate) {
            endText = endDate.formatted(date: .omitted, time: .shortened)
        } else {
            endText = endDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return "\(startText) - \(endText)"
    }

    private func resizeHandle(edge: DayPlanResizeEdge) -> some View {
        DayPlanResizeHandle(
            edge: edge,
            isSelected: true,
            hitHeight: resizeHandleHitHeight,
            outwardOverlap: resizeHandleHitHeight >= 16 ? 6 : 0,
            onResizeStarted: onResizeStarted,
            onResizeChanged: onResizeChanged,
            onResizeEnded: onResizeEnded
        )
    }

    private var resizeHandleHitHeight: CGFloat {
        let preferredHitHeight: CGFloat = 16
        let minimumMoveDragArea: CGFloat = 8
        guard renderedHeight < preferredHitHeight * 2 + minimumMoveDragArea else {
            return preferredHitHeight
        }

        return max(5, (renderedHeight - minimumMoveDragArea) / 2)
    }
}

private struct DayPlanDayTaskColumnsView: View {
    var dates: [Date]
    var selectedDate: Date
    var calendar: Calendar
    var timeColumnWidth: CGFloat
    var isExternalInspectorPresented: Bool
    var dayTaskListItems: (Date) -> [DayPlanDayTaskListItem]
    var taskTint: (UUID) -> Color
    var isTaskOpenable: (UUID) -> Bool
    var onOpenTaskDetails: (UUID) -> Void
    var onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    var onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void

    var body: some View {
        GeometryReader { proxy in
            let dayWidth = DayPlanWeekCalendarSizing.dayWidth(
                availableWidth: proxy.size.width,
                dayCount: max(dates.count, 1),
                isExternalInspectorPresented: isExternalInspectorPresented
            )
            let contentWidth = timeColumnWidth + (CGFloat(dates.count) * dayWidth)

            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    Color.clear
                        .frame(width: timeColumnWidth)
                        .frame(minHeight: proxy.size.height)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 1)
                        }

                    ForEach(dates, id: \.self) { date in
                        DayPlanDayTaskColumnView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            columnWidth: dayWidth,
                            items: dayTaskListItems(date),
                            taskTint: taskTint,
                            calendar: calendar,
                            isTaskOpenable: isTaskOpenable,
                            onOpenTaskDetails: onOpenTaskDetails,
                            onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                            onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed
                        )
                        .frame(width: dayWidth, alignment: .topLeading)
                        .frame(minHeight: proxy.size.height, alignment: .topLeading)
                    }
                }
                .frame(width: contentWidth, alignment: .topLeading)
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
            }
            .background(Color.secondary.opacity(0.035))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DayPlanDayTaskColumnView: View {
    var date: Date
    var isSelected: Bool
    var columnWidth: CGFloat
    var items: [DayPlanDayTaskListItem]
    var taskTint: (UUID) -> Color
    var calendar: Calendar
    var isTaskOpenable: (UUID) -> Bool
    var onOpenTaskDetails: (UUID) -> Void
    var onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    var onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                emptyState
            } else {
                DayPlanDayTaskListContentView(
                    items: items,
                    taskTint: taskTint,
                    date: date,
                    calendar: calendar,
                    isTaskOpenable: isTaskOpenable,
                    onOpenTaskDetails: onOpenTaskDetails,
                    onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                    onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                    availableRowWidth: availableRowWidth,
                    sectionSpacing: 12
                )
            }
        }
        .padding(DayPlanWeekCalendarSizing.dayTaskListColumnPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isSelected ? Color.secondary.opacity(0.045) : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
        }
    }

    private var availableRowWidth: CGFloat {
        max(columnWidth - (DayPlanWeekCalendarSizing.dayTaskListColumnPadding * 2), 0)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title3)
                .foregroundStyle(.tertiary)

            Text("No tasks")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }
}

struct DayPlanDayTaskListContentView: View {
    let items: [DayPlanDayTaskListItem]
    let taskTint: (UUID) -> Color
    let date: Date
    let calendar: Calendar
    let isTaskOpenable: (UUID) -> Bool
    let onOpenTaskDetails: (UUID) -> Void
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    var onDragProvider: ((DayPlanDayTaskListItem) -> NSItemProvider)? = nil
    var availableRowWidth: CGFloat? = nil
    var sectionSpacing: CGFloat = 14

    var body: some View {
        LazyVStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(DayPlanDayTaskListItem.Section.allCases, id: \.self) { section in
                let sectionItems = items(in: section)
                if !sectionItems.isEmpty {
                    DayPlanDayTaskListContentSectionView(
                        title: section.title,
                        count: sectionItems.count,
                        items: sectionItems,
                        taskTint: taskTint,
                        date: date,
                        calendar: calendar,
                        isTaskOpenable: isTaskOpenable,
                        onOpenTaskDetails: onOpenTaskDetails,
                        onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                        onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                        onDragProvider: onDragProvider,
                        availableRowWidth: availableRowWidth
                    )
                }
            }
        }
    }

    private func items(in section: DayPlanDayTaskListItem.Section) -> [DayPlanDayTaskListItem] {
        items.filter { $0.section == section }
    }
}

private struct DayPlanDayTaskListContentSectionView: View {
    let title: String
    let count: Int
    let items: [DayPlanDayTaskListItem]
    let taskTint: (UUID) -> Color
    let date: Date
    let calendar: Calendar
    let isTaskOpenable: (UUID) -> Bool
    let onOpenTaskDetails: (UUID) -> Void
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    let onDragProvider: ((DayPlanDayTaskListItem) -> NSItemProvider)?
    let availableRowWidth: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.10))
                    )

                Spacer(minLength: 0)
            }

            ForEach(items) { item in
                DayPlanDayTaskListContentRow(
                    item: item,
                    tint: taskTint(item.taskID),
                    date: date,
                    calendar: calendar,
                    isOpenable: isTaskOpenable(item.taskID),
                    onOpenTaskDetails: onOpenTaskDetails,
                    onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                    onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                    onDragProvider: onDragProvider,
                    availableRowWidth: availableRowWidth
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DayPlanDayTaskListContentRow: View {
    let item: DayPlanDayTaskListItem
    let tint: Color
    let date: Date
    let calendar: Calendar
    let isOpenable: Bool
    let onOpenTaskDetails: (UUID) -> Void
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    let onDragProvider: ((DayPlanDayTaskListItem) -> NSItemProvider)?
    let availableRowWidth: CGFloat?

    @State private var isHovered = false

    var body: some View {
        Group {
            if isOpenable && item.section != .assumedDone {
                Button {
                    onOpenTaskDetails(item.taskID)
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .help("Open \(item.title)")
                .onHover { isHovered = $0 }
            } else {
                rowContent
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture {
                        if isOpenable {
                            onOpenTaskDetails(item.taskID)
                        }
                    }
                    .help(isOpenable ? "Open \(item.title)" : "")
                    .onHover { isHovered = $0 }
            }
        }
        .dayPlanDayTaskDrag(dragProvider)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsAvatar {
                DayPlanTaskAvatar(emoji: item.emoji, tint: tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Label(placementText, systemImage: placementSystemImage)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(
            cornerRadius: 8,
            tint: tint,
            tintOpacity: 0.08,
            interactive: isOpenable
        )
        .overlay(alignment: .trailing) {
            if item.section == .assumedDone {
                assumedDoneActions
                    .padding(.trailing, 8)
            }
        }
    }

    private var showsAvatar: Bool {
        DayPlanWeekCalendarSizing.showsDayTaskListAvatar(rowWidth: availableRowWidth)
    }

    private var dragProvider: (() -> NSItemProvider)? {
        guard let onDragProvider else { return nil }
        return {
            onDragProvider(item)
        }
    }

    private var assumedDoneActions: some View {
        HStack(spacing: 5) {
            assumedDoneButton(
                systemImage: "checkmark",
                tint: .green,
                accessibilityLabel: "I did it"
            ) {
                onConfirmAssumedDayTask(item, date)
            }

            assumedDoneButton(
                systemImage: "xmark",
                tint: .red,
                accessibilityLabel: "I didn't do it"
            ) {
                onMarkAssumedDayTaskMissed(item, date)
            }
        }
        .padding(4)
        .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private func assumedDoneButton(
        systemImage: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tint, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
        .contentShape(Circle())
    }

    private var placementText: String {
        switch item.placement {
        case .allDay:
            return "All day"
        case let .timed(startMinute, durationMinutes):
            let endMinute = startMinute + durationMinutes
            let startText = DayPlanFormatting.timeText(for: startMinute, on: date, calendar: calendar)
            let endText = DayPlanFormatting.timeText(for: endMinute, on: date, calendar: calendar)
            return "\(startText) - \(endText), \(DayPlanFormatting.durationText(durationMinutes))"
        }
    }

    private var placementSystemImage: String {
        switch item.placement {
        case .allDay:
            return "sun.max"
        case .timed:
            return "clock"
        }
    }
}

private extension View {
    @ViewBuilder
    func dayPlanDayTaskDrag(_ provider: (() -> NSItemProvider)?) -> some View {
        if let provider {
            onDrag(provider)
        } else {
            self
        }
    }
}

private struct DayPlanUnplaceableActivityLaneView: View {
    private struct DayBlocks {
        var date: Date
        var blocks: [DayPlanTimelineActivityBlock]
    }

    var dates: [Date]
    var selectedDate: Date
    var calendar: Calendar
    var timeColumnWidth: CGFloat
    var blocksForDate: (Date) -> [DayPlanTimelineActivityBlock]
    var taskTint: (DayPlanBlock) -> Color
    var onOpenTimelineTaskDetails: (UUID) -> Void
    var onConfirmTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void
    var onHideTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void
    var onTimelineDragProvider: (DayPlanTimelineActivityBlock, Date) -> NSItemProvider

    private let rowHeight: CGFloat = 30
    private let rowSpacing: CGFloat = 4
    private let verticalPadding: CGFloat = 6

    private func laneHeight(maxRows: Int) -> CGFloat {
        guard maxRows > 0 else { return 0 }
        return verticalPadding * 2
            + CGFloat(maxRows) * rowHeight
            + CGFloat(max(maxRows - 1, 0)) * rowSpacing
    }

    var body: some View {
        let dayBlocks = dates.map { date in
            DayBlocks(date: date, blocks: blocksForDate(date))
        }
        let maxRows = dayBlocks.map { $0.blocks.count }.max() ?? 0
        let laneHeight = laneHeight(maxRows: maxRows)

        if maxRows > 0 {
            GeometryReader { proxy in
                let dayCount = max(dates.count, 1)
                let dayWidth = max((proxy.size.width - timeColumnWidth) / CGFloat(dayCount), 1)
                let daysWidth = dayWidth * CGFloat(dayCount)

                HStack(spacing: 0) {
                    Text("Needs Time")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth - 10, alignment: .trailing)
                        .padding(.trailing, 10)
                        .padding(.top, verticalPadding + 6)
                        .frame(width: timeColumnWidth, height: laneHeight, alignment: .topTrailing)

                    ZStack(alignment: .topLeading) {
                        laneBackground(dayWidth: dayWidth, laneHeight: laneHeight)

                        ForEach(Array(dayBlocks.enumerated()), id: \.element.date) { dayIndex, day in
                            ForEach(Array(day.blocks.enumerated()), id: \.element.id) { rowIndex, activity in
                                let block = activity.block
                                DayPlanBlockCard(
                                    block: block,
                                    tint: taskTint(block),
                                    style: .automatic(activity.kind),
                                    isSelected: false,
                                    renderedHeight: rowHeight,
                                    showsResizeHandles: false,
                                    selectedDate: day.date,
                                    calendar: calendar,
                                    onSelect: {},
                                    onOpenDetails: {
                                        onOpenTimelineTaskDetails(block.taskID)
                                    },
                                    onDelete: {},
                                    onConfirmAutomatic: {
                                        onConfirmTimelineActivity(activity, day.date)
                                    },
                                    onHideAutomatic: {
                                        onHideTimelineActivity(activity, day.date)
                                    },
                                    onResizeStarted: {},
                                    onResizeChanged: { _, _ in },
                                    onResizeEnded: {},
                                    onDragProvider: {
                                        onTimelineDragProvider(activity, day.date)
                                    }
                                )
                                .frame(
                                    width: max(dayWidth - 10, 90),
                                    height: rowHeight
                                )
                                .offset(
                                    x: CGFloat(dayIndex) * dayWidth + 5,
                                    y: verticalPadding + CGFloat(rowIndex) * (rowHeight + rowSpacing)
                                )
                            }
                        }
                    }
                    .frame(width: daysWidth, height: laneHeight, alignment: .topLeading)
                }
            }
            .frame(height: laneHeight)
            .background(Color.secondary.opacity(0.035))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 1)
            }
        }
    }

    private func laneBackground(dayWidth: CGFloat, laneHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                Rectangle()
                    .fill(backgroundFill(for: date))
                    .frame(width: dayWidth, height: laneHeight)
                    .offset(x: CGFloat(index) * dayWidth)

                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 1, height: laneHeight)
                    .offset(x: CGFloat(index) * dayWidth)
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1, height: laneHeight)
                .offset(x: CGFloat(dates.count) * dayWidth - 1)
        }
    }

    private func backgroundFill(for date: Date) -> Color {
        calendar.isDate(date, inSameDayAs: selectedDate)
            ? Color.secondary.opacity(0.045)
            : Color.clear
    }
}

private struct DayPlanAllDayLaneView: View {
    var dates: [Date]
    var selectedDate: Date
    var calendar: Calendar
    var timeColumnWidth: CGFloat
    var allDayBlocks: [DayPlanAllDayBlock]
    var allDayTint: (DayPlanAllDayBlock) -> Color
    @Binding var draggedBlockID: DayPlanBlock.ID?
    @Binding var draggedTimelineActivity: DayPlanTimelineActivityBlock?
    var onOpenTaskDetails: (UUID) -> Void
    var onOpenEventDetails: (UUID) -> Void
    var onMoveBlockToAllDay: (DayPlanBlock.ID, Date) -> Void
    var onMoveTimelineActivityToAllDay: (DayPlanTimelineActivityBlock, Date) -> Void
    var onDropTaskToAllDay: (UUID, Date) -> Void

    @State private var targetedDayIndex: Int?

    private let rowHeight: CGFloat = 28
    private let rowSpacing: CGFloat = 4
    private let verticalPadding: CGFloat = 6

    var body: some View {
        let positionedBlocks = DayPlanAllDayLaneLayout.positionedBlocks(
            allDayBlocks,
            dates: dates,
            calendar: calendar
        )
        let rowCount = max((positionedBlocks.map(\.row).max() ?? -1) + 1, 1)
        let laneHeight = verticalPadding * 2
            + rowHeight
            + CGFloat(max(rowCount - 1, 0)) * (rowHeight + rowSpacing)

        GeometryReader { proxy in
            let dayCount = max(dates.count, 1)
            let dayWidth = max((proxy.size.width - timeColumnWidth) / CGFloat(dayCount), 1)
            let daysWidth = dayWidth * CGFloat(dayCount)

            HStack(spacing: 0) {
                Text("All Day")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: timeColumnWidth - 10, alignment: .trailing)
                    .padding(.trailing, 10)
                    .padding(.top, verticalPadding + 5)
                    .frame(width: timeColumnWidth, height: laneHeight, alignment: .topTrailing)

                ZStack(alignment: .topLeading) {
                    allDayBackground(dayWidth: dayWidth, laneHeight: laneHeight)

                    ForEach(positionedBlocks) { positionedBlock in
                        DayPlanAllDayPill(
                            block: positionedBlock.block,
                            tint: allDayTint(positionedBlock.block),
                            startsBeforeVisibleRange: positionedBlock.startsBeforeVisibleRange,
                            endsAfterVisibleRange: positionedBlock.endsAfterVisibleRange
                        )
                        .frame(
                            width: max(CGFloat(positionedBlock.span) * dayWidth - 10, 44),
                            height: rowHeight
                        )
                        .offset(
                            x: CGFloat(positionedBlock.startIndex) * dayWidth + 5,
                            y: verticalPadding + CGFloat(positionedBlock.row) * (rowHeight + rowSpacing)
                        )
                        .onTapGesture {
                            if let eventID = positionedBlock.block.eventID {
                                onOpenEventDetails(eventID)
                            } else if let taskID = positionedBlock.block.taskID {
                                onOpenTaskDetails(taskID)
                            }
                        }
                    }
                }
                .frame(width: daysWidth, height: laneHeight, alignment: .topLeading)
                .contentShape(Rectangle())
                .onDrop(
                    of: [.text],
                    delegate: DayPlanAllDayDropDelegate(
                        dates: dates,
                        dayWidth: dayWidth,
                        draggedBlockID: $draggedBlockID,
                        draggedTimelineActivity: $draggedTimelineActivity,
                        targetedDayIndex: $targetedDayIndex,
                        onMoveBlockToAllDay: onMoveBlockToAllDay,
                        onMoveTimelineActivityToAllDay: onMoveTimelineActivityToAllDay,
                        onDropTaskToAllDay: onDropTaskToAllDay
                    )
                )
            }
        }
        .frame(height: laneHeight)
        .background(Color.secondary.opacity(0.05))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 1)
        }
    }

    private func allDayBackground(dayWidth: CGFloat, laneHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                let isTargeted = targetedDayIndex == index
                Rectangle()
                    .fill(allDayBackgroundFill(for: date, isTargeted: isTargeted))
                    .frame(width: dayWidth, height: laneHeight)
                    .offset(x: CGFloat(index) * dayWidth)

                if isTargeted {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color.accentColor.opacity(0.75),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .frame(width: max(dayWidth - 8, 1), height: max(laneHeight - 8, 1))
                        .offset(x: CGFloat(index) * dayWidth + 4, y: 4)
                }

                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 1, height: laneHeight)
                    .offset(x: CGFloat(index) * dayWidth)
            }

            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1, height: laneHeight)
                .offset(x: CGFloat(dates.count) * dayWidth - 1)
        }
    }

    private func allDayBackgroundFill(for date: Date, isTargeted: Bool) -> Color {
        if isTargeted {
            return Color.accentColor.opacity(0.16)
        }
        if calendar.isDate(date, inSameDayAs: selectedDate) {
            return Color.secondary.opacity(0.045)
        }
        return Color.clear
    }
}

private struct DayPlanAllDayPill: View {
    var block: DayPlanAllDayBlock
    var tint: Color
    var startsBeforeVisibleRange: Bool
    var endsAfterVisibleRange: Bool

    var body: some View {
        HStack(spacing: 5) {
            if startsBeforeVisibleRange {
                Image(systemName: "chevron.left")
                    .font(.caption2.weight(.bold))
            }

            if let emoji = CalendarTaskImportSupport.displayEmoji(for: block.emoji) {
                Text(emoji)
                    .font(.caption2)
                    .frame(width: 14)
            }

            Text(block.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            if block.isEvent {
                Image(systemName: "calendar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if block.isLegacyDateOnlyCalendarTask {
                Image(systemName: "calendar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if endsAfterVisibleRange {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.075))
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.055))
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.72))
                .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.32), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .help(block.isEvent ? "All-day event" : "All-day task")
        .accessibilityLabel("\(block.title), \(block.isEvent ? "all-day event" : "all-day task")")
    }
}

private struct DayPlanPositionedAllDayBlock: Identifiable {
    var block: DayPlanAllDayBlock
    var startIndex: Int
    var endIndex: Int
    var row: Int
    var startsBeforeVisibleRange: Bool
    var endsAfterVisibleRange: Bool

    var span: Int {
        max(endIndex - startIndex, 1)
    }

    var id: String {
        "\(block.id.uuidString)-\(startIndex)-\(endIndex)"
    }
}

private enum DayPlanAllDayLaneLayout {
    static func positionedBlocks(
        _ blocks: [DayPlanAllDayBlock],
        dates: [Date],
        calendar: Calendar
    ) -> [DayPlanPositionedAllDayBlock] {
        guard let firstDate = dates.first,
              let lastDate = dates.last,
              let visibleEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: lastDate)
              )
        else { return [] }

        let visibleStart = calendar.startOfDay(for: firstDate)
        let sortedSegments = blocks.compactMap { block -> DayPlanPositionedAllDayBlock? in
            let startDate = calendar.startOfDay(for: block.startDate)
            let endDate = normalizedEndDate(for: block, calendar: calendar)
            guard endDate > visibleStart, startDate < visibleEnd else { return nil }

            let clampedStartDate = max(startDate, visibleStart)
            let clampedEndDate = min(endDate, visibleEnd)
            let startIndex = max(calendar.dateComponents([.day], from: visibleStart, to: clampedStartDate).day ?? 0, 0)
            let endIndex = min(
                max(calendar.dateComponents([.day], from: visibleStart, to: clampedEndDate).day ?? 0, startIndex + 1),
                dates.count
            )

            return DayPlanPositionedAllDayBlock(
                block: block,
                startIndex: startIndex,
                endIndex: max(endIndex, startIndex + 1),
                row: 0,
                startsBeforeVisibleRange: startDate < visibleStart,
                endsAfterVisibleRange: endDate > visibleEnd
            )
        }
        .sorted { lhs, rhs in
            if lhs.startIndex != rhs.startIndex {
                return lhs.startIndex < rhs.startIndex
            }
            if lhs.span != rhs.span {
                return lhs.span > rhs.span
            }
            return lhs.block.title.localizedCaseInsensitiveCompare(rhs.block.title) == .orderedAscending
        }

        var rowEndIndices: [Int] = []
        return sortedSegments.map { segment in
            var positionedSegment = segment
            let row = rowEndIndices.firstIndex { $0 <= segment.startIndex } ?? rowEndIndices.count
            positionedSegment.row = row
            if row == rowEndIndices.count {
                rowEndIndices.append(segment.endIndex)
            } else {
                rowEndIndices[row] = segment.endIndex
            }
            return positionedSegment
        }
    }

    private static func normalizedEndDate(
        for block: DayPlanAllDayBlock,
        calendar: Calendar
    ) -> Date {
        let startDate = calendar.startOfDay(for: block.startDate)
        let endDate = calendar.startOfDay(for: block.endDate)
        guard endDate > startDate else {
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        }
        return endDate
    }
}

private struct DayPlanResizeSession: Equatable {
    let blockID: DayPlanBlock.ID
    let startMinute: Int
    let durationMinutes: Int
    let contentLayoutHeight: CGFloat
}
