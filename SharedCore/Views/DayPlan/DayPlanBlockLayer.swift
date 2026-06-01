import SwiftUI

struct DayPlanBlockLayer: View {
    var dates: [Date]
    var selectedBlockID: DayPlanBlock.ID?
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
                ForEach(sleepBlocksForDate(date)) { sleepBlock in
                    let block = sleepBlock.block
                    let blockHeight = blockHeight(for: block)
                    DayPlanBlockCard(
                        block: block,
                        tint: .indigo,
                        style: .sleep,
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
                    .zIndex(0.5)
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

                ForEach(eventBlocksForDate(date)) { eventBlock in
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
                        width: max(dayWidth - 10, 90),
                        height: blockHeight
                    )
                    .offset(
                        x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5,
                        y: yOffset(for: block.startMinute)
                    )
                    .zIndex(0.75)
                }

                ForEach(blocksForDate(date)) { block in
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
                        width: max(dayWidth - 10, 90),
                        height: blockHeight
                    )
                    .offset(
                        x: timeColumnWidth + CGFloat(dayIndex) * dayWidth + 5,
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
                        onOpenFocusTaskDetails(block.taskID)
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
