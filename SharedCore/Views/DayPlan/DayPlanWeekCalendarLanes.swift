import SwiftUI
import UniformTypeIdentifiers

struct DayPlanUnplaceableActivityLaneView: View {
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

struct DayPlanAllDayLaneView: View {
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
        let laneHeight =
            verticalPadding * 2
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
