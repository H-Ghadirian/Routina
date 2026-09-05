import SwiftUI

struct PositionedEventBlock: Identifiable {
    var eventBlock: DayPlanEventBlock
    var columnIndex: Int
    var columnCount: Int

    var id: String {
        eventBlock.id
    }
}

struct PositionedPlannedBlock: Identifiable {
    var id: String
    var block: DayPlanBlock
    var columnIndex: Int
    var columnCount: Int
}

extension DayPlanBlockLayer {
    func timedBlockPlacementsByID(
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
            uniqueKeysWithValues:
                DayPlanTimedBlockColumnLayout
                .placements(for: plannedItems + eventItems)
                .map { ($0.id, $0) }
        )
    }

    func positionedEventBlocks(
        _ eventBlocks: [DayPlanEventBlock],
        placementsByID: [String: DayPlanTimedBlockColumnPlacement]
    ) -> [PositionedEventBlock] {
        return eventBlocks.map { eventBlock in
            let id = timedBlockID(for: eventBlock)
            let placement =
                placementsByID[id]
                ?? DayPlanTimedBlockColumnPlacement(
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

    func positionedPlannedBlocks(
        _ blocks: [DayPlanBlock],
        placementsByID: [String: DayPlanTimedBlockColumnPlacement]
    ) -> [PositionedPlannedBlock] {
        return blocks.map { block in
            let id = timedBlockID(for: block)
            let placement =
                placementsByID[id]
                ?? DayPlanTimedBlockColumnPlacement(
                    id: id,
                    columnIndex: 0,
                    columnCount: 1
                )
            return PositionedPlannedBlock(
                id: id,
                block: block,
                columnIndex: placement.columnIndex,
                columnCount: placement.columnCount
            )
        }
    }

    func timedBlockWidth(for columnCount: Int) -> CGFloat {
        guard columnCount > 1 else {
            return max(dayWidth - 10, 90)
        }

        let totalGap = CGFloat(columnCount - 1) * timedBlockColumnGap
        return max((max(dayWidth - 10, 1) - totalGap) / CGFloat(columnCount), 1)
    }

    func timedBlockXOffset(columnIndex: Int, columnCount: Int) -> CGFloat {
        guard columnCount > 1 else { return 0 }
        return CGFloat(columnIndex)
            * (timedBlockWidth(for: columnCount) + timedBlockColumnGap)
    }

    func timedBlockID(for block: DayPlanBlock) -> String {
        if block.taskID == FocusSession.unassignedTaskID {
            return [
                "planned-focus",
                block.dayKey,
                block.id.uuidString,
                String(block.startMinute),
                String(Int(block.createdAt.timeIntervalSince1970 * 1_000)),
            ].joined(separator: "-")
        }

        return "planned-\(block.id.uuidString)"
    }

    func timedBlockID(for eventBlock: DayPlanEventBlock) -> String {
        "event-\(eventBlock.id)"
    }

    var timedBlockColumnGap: CGFloat {
        4
    }

    var contentWidth: CGFloat {
        timeColumnWidth + (CGFloat(dates.count) * dayWidth)
    }

    var contentHeight: CGFloat {
        timeAxis.contentHeight
    }
}

struct DayPlanFocusSessionBlockLayer: View {
    var dates: [Date]
    var calendar: Calendar
    var dayWidth: CGFloat
    var timeAxis: DayPlanAdaptiveTimeAxis
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
        focusSessionBlocks.compactMap { focusBlock in
            guard
                let dayIndex = dates.firstIndex(where: { date in
                    DayPlanStorage.dayKey(for: date, calendar: calendar) == focusBlock.block.dayKey
                })
            else {
                return nil
            }

            return PositionedFocusSessionBlock(
                dayIndex: dayIndex,
                date: dates[dayIndex],
                focusBlock: focusBlock
            )
        }
    }

    private func yOffset(for minute: Int) -> CGFloat {
        timeAxis.yOffset(forMinute: minute)
    }

    private func blockHeight(for focusBlock: DayPlanFocusSessionBlock) -> CGFloat {
        let visibleMinutes = max(focusBlock.durationMinutes, 1)
        return max(
            timeAxis.height(
                startMinute: focusBlock.block.startMinute,
                durationMinutes: visibleMinutes
            ),
            DayPlanAdaptiveTimeAxis.minimumInteractiveBlockHeight
        )
    }

    private var contentWidth: CGFloat {
        timeColumnWidth + (CGFloat(dates.count) * dayWidth)
    }

    private var contentHeight: CGFloat {
        timeAxis.contentHeight
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
    var timeAxis: DayPlanAdaptiveTimeAxis
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
            guard
                let dayIndex = dates.firstIndex(where: {
                    DayPlanStorage.dayKey(for: $0, calendar: calendar) == block.block.dayKey
                })
            else {
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
        timeAxis.yOffset(forMinute: minute)
    }

    private func blockHeight(for sprintFocusBlock: DayPlanSprintFocusBlock) -> CGFloat {
        if sprintFocusBlock.isActive {
            return max(
                timeAxis.height(
                    startMinute: sprintFocusBlock.block.startMinute,
                    durationMinutes: sprintFocusBlock.renderedDurationMinutes
                ),
                DayPlanAdaptiveTimeAxis.minimumInteractiveBlockHeight
            )
        }

        return max(
            timeAxis.height(
                startMinute: sprintFocusBlock.block.startMinute,
                durationMinutes: sprintFocusBlock.block.durationMinutes
            ),
            DayPlanAdaptiveTimeAxis.minimumInteractiveBlockHeight
        )
    }

    private var contentWidth: CGFloat {
        timeColumnWidth + (CGFloat(dates.count) * dayWidth)
    }

    private var contentHeight: CGFloat {
        timeAxis.contentHeight
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
