import Foundation
import SwiftUI

extension DayPlanWeekCalendarView {
    func beginResize(
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

    func resize(
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

    func endResize() {
        let blockID = resizeSession?.blockID
        resizeSession = nil
        frozenTimeAxis = nil
        onEndResizeBlock(blockID)
    }

    var timedBlockLayerIdentity: String {
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

    var adaptiveTimeAxisIntervals: [DayPlanAdaptiveTimeAxis.Interval] {
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

    func adaptiveInterval(
        for block: DayPlanBlock
    ) -> DayPlanAdaptiveTimeAxis.Interval {
        DayPlanAdaptiveTimeAxis.Interval(
            groupID: block.dayKey,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes
        )
    }

    func blockHeight(
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

    func clearDropState() {
        isDropTargeted = false
        dropPreview = nil
    }

    func releaseFrozenTimeAxisAfterDragIfNeeded() {
        guard draggedBlockID == nil,
            draggedTimelineActivity == nil,
            resizeSession == nil,
            draftResizeBaseline == nil
        else {
            return
        }

        frozenTimeAxis = nil
    }

    func dismissScheduleInteractionState() {
        selectedSlotDraft = nil
        selectedDayTaskListDate = nil
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

    func dragProvider(
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

    func dragProvider(
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
}
