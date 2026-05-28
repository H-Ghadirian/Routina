import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct DayPlanWeekCalendarView: View {
    var dates: [Date]
    var selectedBlockID: DayPlanBlock.ID?
    var selectedDate: Date
    var focusedUnplannedCompletedDate: Date?
    var calendar: Calendar
    var dropDurationMinutes: Int
    var showsUnplannedCompletedBadges: Bool
    var blocksForDate: (Date) -> [DayPlanBlock]
    var automaticTimelineBlocksForDate: (Date) -> [DayPlanTimelineActivityBlock] = { _ in [] }
    var eventBlocksForDate: (Date) -> [DayPlanEventBlock] = { _ in [] }
    var sleepBlocksForDate: (Date) -> [DayPlanSleepBlock] = { _ in [] }
    var blockedIntervalsForDate: (Date) -> [DayPlanBlockedInterval] = { _ in [] }
    var activeFocusSessionBlocks: (Date) -> [DayPlanFocusSessionBlock] = { _ in [] }
    var allDayBlocks: [DayPlanAllDayBlock] = []
    var unplannedCompletedCount: (Date) -> Int
    var taskTint: (DayPlanBlock) -> Color
    var allDayTint: (DayPlanAllDayBlock) -> Color = { _ in .accentColor }
    var onSelectUnplannedCompletedDate: (Date) -> Void
    var onSelectSlot: (Date, Int) -> Void
    var onSelectBlock: (DayPlanBlock, Date) -> Void
    var onOpenBlockDetails: (DayPlanBlock, Date) -> Void
    var onOpenTimelineTaskDetails: (UUID) -> Void = { _ in }
    var onOpenEventDetails: (UUID) -> Void = { _ in }
    var onOpenFocusTaskDetails: (UUID) -> Void = { _ in }
    var onOpenAllDayTaskDetails: (UUID) -> Void = { _ in }
    var onDeleteBlock: (DayPlanBlock) -> Void
    var onConfirmTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onHideTimelineActivity: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onMoveBlock: (DayPlanBlock.ID, Date, Int) -> Void
    var onMoveTimelineActivity: (DayPlanTimelineActivityBlock, Date, Int) -> Void = { _, _, _ in }
    var onMoveBlockToAllDay: (DayPlanBlock.ID, Date) -> Void = { _, _ in }
    var onMoveTimelineActivityToAllDay: (DayPlanTimelineActivityBlock, Date) -> Void = { _, _ in }
    var onResizeBlock: (DayPlanBlock.ID, Date, Int, Int) -> Void
    var onDropTask: (UUID, Date, Int) -> Void
    var onDropTaskToAllDay: (UUID, Date) -> Void = { _, _ in }

    @State private var isDropTargeted = false
    @State private var isCompletingDrop = false
    @State private var dropPreview: DayPlanDropPreview?
    @State private var draggedBlockID: DayPlanBlock.ID?
    @State private var draggedTimelineActivity: DayPlanTimelineActivityBlock?
    @State private var draggedBlockDurationMinutes: Int?
    @State private var resizeSession: DayPlanResizeSession?
    @Namespace private var blockAnimationNamespace

    private let hourHeight: CGFloat = 64
    private let timeColumnWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            DayPlanWeekHeaderRow(
                dates: dates,
                selectedDate: selectedDate,
                focusedUnplannedCompletedDate: focusedUnplannedCompletedDate,
                calendar: calendar,
                timeColumnWidth: timeColumnWidth,
                showsUnplannedCompletedBadges: showsUnplannedCompletedBadges,
                unplannedCompletedCount: unplannedCompletedCount,
                onSelectUnplannedCompletedDate: onSelectUnplannedCompletedDate
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
                        let dayWidth = max((proxy.size.width - timeColumnWidth) / CGFloat(max(dates.count, 1)), 120)
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
                                onSelectSlot: onSelectSlot
                            )
                            DayPlanBlockLayer(
                                dates: dates,
                                selectedBlockID: selectedBlockID,
                                calendar: calendar,
                                dayWidth: dayWidth,
                                hourHeight: hourHeight,
                                timeColumnWidth: timeColumnWidth,
                                blockAnimationNamespace: blockAnimationNamespace,
                                blocksForDate: blocksForDate,
                                automaticTimelineBlocksForDate: automaticTimelineBlocksForDate,
                                eventBlocksForDate: eventBlocksForDate,
                                sleepBlocksForDate: sleepBlocksForDate,
                                taskTint: taskTint,
                                onSelectBlock: onSelectBlock,
                                onOpenBlockDetails: onOpenBlockDetails,
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
                            SwiftUI.TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                                ZStack(alignment: .topLeading) {
                                    DayPlanFocusSessionBlockLayer(
                                        dates: dates,
                                        now: timeline.date,
                                        calendar: calendar,
                                        dayWidth: dayWidth,
                                        hourHeight: hourHeight,
                                        timeColumnWidth: timeColumnWidth,
                                        focusSessionBlocks: activeFocusSessionBlocks(timeline.date),
                                        taskTint: taskTint,
                                        onOpenFocusTaskDetails: onOpenFocusTaskDetails
                                    )
                                    .zIndex(3)

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
                    scrollToCurrentTime(with: scrollProxy)
                }
                .onChange(of: dates) { _, _ in
                    scrollToCurrentTime(with: scrollProxy)
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isDropTargeted ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.18), lineWidth: isDropTargeted ? 1.5 : 1)
        }
    }

    private func beginResize(_ block: DayPlanBlock, _ date: Date) {
        clearDropState()
        draggedBlockID = nil
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = nil
        onSelectBlock(block, date)
        resizeSession = DayPlanResizeSession(
            blockID: block.id,
            startMinute: block.startMinute,
            durationMinutes: block.durationMinutes
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
            durationMinutes: block.durationMinutes
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
        resizeSession = nil
    }

    private func minuteDelta(for verticalDelta: CGFloat) -> Int {
        let rawMinutes = (verticalDelta / hourHeight) * 60
        return Int(rawMinutes.rounded())
    }

    private func clearDropState() {
        isDropTargeted = false
        dropPreview = nil
    }

    private func dragProvider(for block: DayPlanBlock, on date: Date) -> NSItemProvider {
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
            return Color.accentColor.opacity(0.08)
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
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.72))
                .frame(width: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(tint.opacity(0.45), lineWidth: 1)
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
}
