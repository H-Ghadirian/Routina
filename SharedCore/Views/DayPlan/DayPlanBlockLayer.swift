import SwiftUI

struct DayPlanBlockLayer: View {
    var dates: [Date]
    var selectedBlockID: DayPlanBlock.ID?
    var focusedSleepSessionID: UUID?
    var calendar: Calendar
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat
    var blockAnimationNamespace: Namespace.ID
    var blocksForDate: (Date) -> [DayPlanBlock]
    var automaticTimelineBlocksForDate: (Date) -> [DayPlanTimelineActivityBlock] = { _ in [] }
    var eventBlocksForDate: (Date) -> [DayPlanEventBlock] = { _ in [] }
    var sleepBlocksForDate: (Date) -> [DayPlanSleepBlock] = { _ in [] }
    var awayBlocksForDate: (Date) -> [DayPlanAwayBlock] = { _ in [] }
    var sprintFocusBlocksForDate: (Date) -> [DayPlanSprintFocusBlock] = { _ in [] }
    var taskTint: (DayPlanBlock) -> Color
    var onSelectBlock: (DayPlanBlock, Date) -> Void
    var onOpenBlockDetails: (DayPlanBlock, Date) -> Void
    var onOpenTimelineTaskDetails: (UUID) -> Void = { _ in }
    var onOpenEventDetails: (UUID) -> Void = { _ in }
    var onConfirmTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onHideTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onTimelineDragProvider: (DayPlanTimelineActivityBlock, Date) -> NSItemProvider = { _, _ in
        NSItemProvider(object: "" as NSString)
    }
    var onDeleteBlock: (DayPlanBlock) -> Void
    var onResizeStarted: (DayPlanBlock, Date) -> Void
    var onResizeChanged: (DayPlanBlock, Date, DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void
    var onDragProvider: (DayPlanBlock, Date) -> NSItemProvider

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(dates.enumerated()), id: \.element) { dayIndex, date in
                let plannedBlocks = blocksForDate(date)
                let eventBlocks = eventBlocksForDate(date)
                let timedBlockPlacementsByID = timedBlockPlacementsByID(
                    plannedBlocks: plannedBlocks,
                    eventBlocks: eventBlocks
                )
                ForEach(sleepBlocksForDate(date)) { sleepBlock in
                    let block = sleepBlock.block
                    let blockHeight = blockHeight(for: block)
                    let isFocusedSleep = sleepBlock.contains(sessionID: focusedSleepSessionID)
                    DayPlanBlockCard(
                        block: block,
                        tint: .indigo,
                        style: .sleep,
                        isSelected: isFocusedSleep,
                        renderedHeight: blockHeight,
                        selectedDate: date,
                        calendar: calendar,
                        onSelect: {},
                        onOpenDetails: {},
                        onDelete: {},
                        onResizeStarted: {},
                        onResizeChanged: { _, _ in },
                        onResizeEnded: {},
                        onDragProvider: {
                            NSItemProvider(object: "" as NSString)
                        }
                    )
                    .frame(
                        width: max(dayWidth - 10, 90),
                        height: blockHeight
                    )
                    .offset(
                        x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5,
                        y: yOffset(for: block.startMinute)
                    )
                    .zIndex(isFocusedSleep ? 1.5 : 0.5)
                }

                ForEach(automaticTimelineBlocksForDate(date)) { activity in
                    let block = activity.block
                    let blockHeight = blockHeight(for: block)
                    DayPlanBlockCard(
                        block: block,
                        tint: taskTint(block),
                        style: .automatic(activity.kind),
                        isSelected: false,
                        renderedHeight: blockHeight,
                        selectedDate: date,
                        calendar: calendar,
                        onSelect: {},
                        onOpenDetails: {
                            onOpenTimelineTaskDetails(block.taskID)
                        },
                        onDelete: {},
                        onConfirmAutomatic: {
                            onConfirmTimelineActivity(activity, date)
                        },
                        onHideAutomatic: {
                            onHideTimelineActivity(activity, date)
                        },
                        onResizeStarted: {},
                        onResizeChanged: { _, _ in },
                        onResizeEnded: {},
                        onDragProvider: {
                            onTimelineDragProvider(activity, date)
                        }
                    )
                    .frame(
                        width: max(dayWidth - 10, 90),
                        height: blockHeight
                    )
                    .offset(
                        x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5,
                        y: yOffset(for: block.startMinute)
                    )
                    .zIndex(0)
                }

                ForEach(awayBlocksForDate(date)) { awayBlock in
                    let block = awayBlock.block
                    let blockHeight = blockHeight(for: block)
                    DayPlanBlockCard(
                        block: block,
                        tint: .teal,
                        style: .away,
                        isSelected: false,
                        renderedHeight: blockHeight,
                        selectedDate: date,
                        calendar: calendar,
                        onSelect: {},
                        onOpenDetails: {},
                        onDelete: {},
                        onResizeStarted: {},
                        onResizeChanged: { _, _ in },
                        onResizeEnded: {},
                        onDragProvider: {
                            NSItemProvider(object: "" as NSString)
                        }
                    )
                    .frame(
                        width: max(dayWidth - 10, 90),
                        height: blockHeight
                    )
                    .offset(
                        x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5,
                        y: yOffset(for: block.startMinute)
                    )
                    .zIndex(0.65)
                }

                ForEach(positionedEventBlocks(
                    eventBlocks,
                    placementsByID: timedBlockPlacementsByID
                )) { positionedEventBlock in
                    let eventBlock = positionedEventBlock.eventBlock
                    let block = eventBlock.block
                    let blockHeight = blockHeight(for: block)
                    DayPlanBlockCard(
                        block: block,
                        tint: .teal,
                        style: .event,
                        isSelected: false,
                        renderedHeight: blockHeight,
                        selectedDate: date,
                        calendar: calendar,
                        onSelect: {},
                        onOpenDetails: {
                            onOpenEventDetails(eventBlock.eventID)
                        },
                        onDelete: {},
                        onResizeStarted: {},
                        onResizeChanged: { _, _ in },
                        onResizeEnded: {},
                        onDragProvider: {
                            NSItemProvider(object: "" as NSString)
                        }
                    )
                    .frame(
                        width: timedBlockWidth(for: positionedEventBlock.columnCount),
                        height: blockHeight
                    )
                    .offset(
                        x: timeColumnWidth
                            + CGFloat(dayIndex) * dayWidth
                            + 5
                            + timedBlockXOffset(
                                columnIndex: positionedEventBlock.columnIndex,
                                columnCount: positionedEventBlock.columnCount
                            ),
                        y: yOffset(for: block.startMinute)
                    )
                    .zIndex(0.75)
                }

                ForEach(sprintFocusBlocksForDate(date)) { sprintFocusBlock in
                    let block = sprintFocusBlock.block
                    let blockHeight = sprintFocusBlockHeight(for: sprintFocusBlock)
                    DayPlanBlockCard(
                        block: block,
                        tint: sprintFocusBlock.isAllocatedToTask ? taskTint(block) : .teal,
                        style: .sprintFocus(
                            isActive: sprintFocusBlock.isActive,
                            isAllocated: sprintFocusBlock.isAllocatedToTask
                        ),
                        isSelected: false,
                        renderedHeight: blockHeight,
                        selectedDate: date,
                        calendar: calendar,
                        onSelect: {},
                        onOpenDetails: {
                            if sprintFocusBlock.isAllocatedToTask {
                                onOpenTimelineTaskDetails(block.taskID)
                            }
                        },
                        onDelete: {},
                        onResizeStarted: {},
                        onResizeChanged: { _, _ in },
                        onResizeEnded: {},
                        onDragProvider: {
                            NSItemProvider(object: "" as NSString)
                        }
                    )
                    .frame(
                        width: max(dayWidth - 10, 90),
                        height: blockHeight
                    )
                    .clipped(antialiased: true)
                    .offset(
                        x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5,
                        y: yOffset(for: block.startMinute)
                    )
                    .zIndex(sprintFocusBlock.isActive ? 3 : 0.85)
                }

                ForEach(positionedPlannedBlocks(
                    plannedBlocks,
                    placementsByID: timedBlockPlacementsByID
                )) { positionedBlock in
                    let block = positionedBlock.block
                    let blockHeight = blockHeight(for: block)
                    DayPlanBlockCard(
                        block: block,
                        tint: taskTint(block),
                        isSelected: block.id == selectedBlockID,
                        renderedHeight: blockHeight,
                        selectedDate: date,
                        calendar: calendar,
                        onSelect: {
                            onSelectBlock(block, date)
                        },
                        onOpenDetails: {
                            onOpenBlockDetails(block, date)
                        },
                        onDelete: {
                            onDeleteBlock(block)
                        },
                        onResizeStarted: {
                            onResizeStarted(block, date)
                        },
                        onResizeChanged: { edge, verticalDelta in
                            onResizeChanged(block, date, edge, verticalDelta)
                        },
                        onResizeEnded: onResizeEnded,
                        onDragProvider: {
                            onDragProvider(block, date)
                        }
                    )
                    .frame(
                        width: timedBlockWidth(for: positionedBlock.columnCount),
                        height: blockHeight
                    )
                    .offset(
                        x: timeColumnWidth
                            + CGFloat(dayIndex) * dayWidth
                            + 5
                            + timedBlockXOffset(
                                columnIndex: positionedBlock.columnIndex,
                                columnCount: positionedBlock.columnCount
                            ),
                        y: yOffset(for: block.startMinute)
                    )
                    .matchedGeometryEffect(
                        id: block.id,
                        in: blockAnimationNamespace,
                        properties: .frame,
                        anchor: .topLeading
                    )
                    .zIndex(block.id == selectedBlockID ? 2 : 1)
                }
            }
        }
    }

    private func yOffset(for minute: Int) -> CGFloat {
        CGFloat(minute) / 60 * hourHeight
    }

    private func blockHeight(for block: DayPlanBlock) -> CGFloat {
        max(CGFloat(block.durationMinutes) / 60 * hourHeight, 18)
    }

    private func sprintFocusBlockHeight(for sprintFocusBlock: DayPlanSprintFocusBlock) -> CGFloat {
        if sprintFocusBlock.isActive {
            return CGFloat(sprintFocusBlock.renderedDurationMinutes) / 60 * hourHeight
        }

        return blockHeight(for: sprintFocusBlock.block)
    }

    private func timedBlockPlacementsByID(
        plannedBlocks: [DayPlanBlock],
        eventBlocks: [DayPlanEventBlock]
    ) -> [String: DayPlanTimedBlockColumnPlacement] {
        let plannedItems = plannedBlocks.map { block in
            DayPlanTimedBlockColumnItem(
                id: timedBlockID(for: block),
                startMinute: block.startMinute,
                endMinute: block.endMinute
            )
        }
        let eventItems = eventBlocks.map { eventBlock in
            DayPlanTimedBlockColumnItem(
                id: timedBlockID(for: eventBlock),
                startMinute: eventBlock.block.startMinute,
                endMinute: eventBlock.block.endMinute
            )
        }

        return Dictionary(
            uniqueKeysWithValues: DayPlanTimedBlockColumnLayout
                .placements(for: plannedItems + eventItems)
                .map { ($0.id, $0) }
        )
    }

    private func positionedEventBlocks(
        _ eventBlocks: [DayPlanEventBlock],
        placementsByID: [String: DayPlanTimedBlockColumnPlacement]
    ) -> [PositionedEventBlock] {
        return eventBlocks.map { eventBlock in
            let id = timedBlockID(for: eventBlock)
            let placement = placementsByID[id] ?? DayPlanTimedBlockColumnPlacement(
                id: id,
                columnIndex: 0,
                columnCount: 1
            )
            return PositionedEventBlock(
                eventBlock: eventBlock,
                columnIndex: placement.columnIndex,
                columnCount: placement.columnCount
            )
        }
    }

    private func positionedPlannedBlocks(
        _ blocks: [DayPlanBlock],
        placementsByID: [String: DayPlanTimedBlockColumnPlacement]
    ) -> [PositionedPlannedBlock] {
        return blocks.map { block in
            let id = timedBlockID(for: block)
            let placement = placementsByID[id] ?? DayPlanTimedBlockColumnPlacement(
                id: id,
                columnIndex: 0,
                columnCount: 1
            )
            return PositionedPlannedBlock(
                block: block,
                columnIndex: placement.columnIndex,
                columnCount: placement.columnCount
            )
        }
    }

    private func timedBlockWidth(for columnCount: Int) -> CGFloat {
        guard columnCount > 1 else {
            return max(dayWidth - 10, 90)
        }

        let totalGap = CGFloat(columnCount - 1) * timedBlockColumnGap
        return max((max(dayWidth - 10, 1) - totalGap) / CGFloat(columnCount), 1)
    }

    private func timedBlockXOffset(columnIndex: Int, columnCount: Int) -> CGFloat {
        guard columnCount > 1 else { return 0 }
        return CGFloat(columnIndex)
            * (timedBlockWidth(for: columnCount) + timedBlockColumnGap)
    }

    private func timedBlockID(for block: DayPlanBlock) -> String {
        "planned-\(block.id.uuidString)"
    }

    private func timedBlockID(for eventBlock: DayPlanEventBlock) -> String {
        "event-\(eventBlock.id)"
    }

    private var timedBlockColumnGap: CGFloat {
        4
    }
}

private struct PositionedEventBlock: Identifiable {
    var eventBlock: DayPlanEventBlock
    var columnIndex: Int
    var columnCount: Int

    var id: String {
        eventBlock.id
    }
}

private struct PositionedPlannedBlock: Identifiable {
    var block: DayPlanBlock
    var columnIndex: Int
    var columnCount: Int

    var id: DayPlanBlock.ID {
        block.id
    }
}

struct DayPlanFocusSessionBlockLayer: View {
    var dates: [Date]
    var now: Date
    var calendar: Calendar
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat
    var focusSessionBlocks: [DayPlanFocusSessionBlock]
    var taskTint: (DayPlanBlock) -> Color
    var onOpenFocusTaskDetails: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(positionedFocusBlocks) { positionedBlock in
                let focusBlock = positionedBlock.focusBlock
                let block = focusBlock.block
                let blockHeight = blockHeight(for: focusBlock)
                DayPlanBlockCard(
                    block: block,
                    tint: taskTint(block),
                    style: .liveFocus,
                    displayDurationMinutes: focusBlock.durationMinutes,
                    isSelected: false,
                    renderedHeight: blockHeight,
                    selectedDate: positionedBlock.date,
                    calendar: calendar,
                    onSelect: {},
                    onOpenDetails: {
                        if focusBlock.opensTaskDetails {
                            onOpenFocusTaskDetails(block.taskID)
                        }
                    },
                    onDelete: {},
                    onResizeStarted: {},
                    onResizeChanged: { _, _ in },
                    onResizeEnded: {},
                    onDragProvider: {
                        NSItemProvider(object: "" as NSString)
                    }
                )
                .frame(
                    width: max(dayWidth - 10, 90),
                    height: blockHeight
                )
                .offset(
                    x: timeColumnWidth + CGFloat(positionedBlock.dayIndex) * dayWidth + 5,
                    y: yOffset(for: block.startMinute)
                )
                .zIndex(3)
            }
        }
        .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
    }

    private var positionedFocusBlocks: [PositionedFocusSessionBlock] {
        guard let todayIndex else { return [] }
        let today = dates[todayIndex]
        return focusSessionBlocks.map {
            PositionedFocusSessionBlock(
                dayIndex: todayIndex,
                date: today,
                focusBlock: $0
            )
        }
    }

    private var todayIndex: Int? {
        dates.firstIndex { calendar.isDate($0, inSameDayAs: now) }
    }

    private func yOffset(for minute: Int) -> CGFloat {
        CGFloat(minute) / 60 * hourHeight
    }

    private func blockHeight(for focusBlock: DayPlanFocusSessionBlock) -> CGFloat {
        let visibleMinutes = max(focusBlock.durationMinutes, 1)
        return max(CGFloat(visibleMinutes) / 60 * hourHeight, 18)
    }

    private var contentWidth: CGFloat {
        timeColumnWidth + (CGFloat(dates.count) * dayWidth)
    }

    private var contentHeight: CGFloat {
        hourHeight * 24
    }
}

private struct PositionedFocusSessionBlock: Identifiable {
    var dayIndex: Int
    var date: Date
    var focusBlock: DayPlanFocusSessionBlock

    var id: String {
        focusBlock.id
    }
}

struct DayPlanSprintFocusBlockLayer: View {
    var dates: [Date]
    var calendar: Calendar
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat
    var sprintFocusBlocks: [DayPlanSprintFocusBlock]
    var taskTint: (DayPlanBlock) -> Color
    var onOpenFocusTaskDetails: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(positionedBlocks) { positionedBlock in
                let sprintFocusBlock = positionedBlock.sprintFocusBlock
                let block = sprintFocusBlock.block
                let blockHeight = blockHeight(for: sprintFocusBlock)
                DayPlanBlockCard(
                    block: block,
                    tint: sprintFocusBlock.isAllocatedToTask ? taskTint(block) : .teal,
                    style: .sprintFocus(
                        isActive: sprintFocusBlock.isActive,
                        isAllocated: sprintFocusBlock.isAllocatedToTask
                    ),
                    isSelected: false,
                    renderedHeight: blockHeight,
                    selectedDate: positionedBlock.date,
                    calendar: calendar,
                    onSelect: {},
                    onOpenDetails: {
                        if sprintFocusBlock.isAllocatedToTask {
                            onOpenFocusTaskDetails(block.taskID)
                        }
                    },
                    onDelete: {},
                    onResizeStarted: {},
                    onResizeChanged: { _, _ in },
                    onResizeEnded: {},
                    onDragProvider: {
                        NSItemProvider(object: "" as NSString)
                    }
                )
                .frame(
                    width: max(dayWidth - 10, 90),
                    height: blockHeight
                )
                .clipped(antialiased: true)
                .offset(
                    x: timeColumnWidth + CGFloat(positionedBlock.dayIndex) * dayWidth + 5,
                    y: yOffset(for: block.startMinute)
                )
            }
        }
        .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
    }

    private var positionedBlocks: [PositionedSprintFocusBlock] {
        sprintFocusBlocks.compactMap { block in
            guard let dayIndex = dates.firstIndex(where: {
                DayPlanStorage.dayKey(for: $0, calendar: calendar) == block.block.dayKey
            }) else {
                return nil
            }

            return PositionedSprintFocusBlock(
                dayIndex: dayIndex,
                date: dates[dayIndex],
                sprintFocusBlock: block
            )
        }
    }

    private func yOffset(for minute: Int) -> CGFloat {
        CGFloat(minute) / 60 * hourHeight
    }

    private func blockHeight(for sprintFocusBlock: DayPlanSprintFocusBlock) -> CGFloat {
        if sprintFocusBlock.isActive {
            return CGFloat(sprintFocusBlock.renderedDurationMinutes) / 60 * hourHeight
        }

        return max(CGFloat(sprintFocusBlock.block.durationMinutes) / 60 * hourHeight, 18)
    }

    private var contentWidth: CGFloat {
        timeColumnWidth + (CGFloat(dates.count) * dayWidth)
    }

    private var contentHeight: CGFloat {
        hourHeight * 24
    }
}

private struct PositionedSprintFocusBlock: Identifiable {
    var dayIndex: Int
    var date: Date
    var sprintFocusBlock: DayPlanSprintFocusBlock

    var id: String {
        sprintFocusBlock.id
    }
}
