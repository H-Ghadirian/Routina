import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct DayPlanWeekCalendarView: View {
    var dates: [Date]
    var selectedBlockID: DayPlanBlock.ID?
    var selectedDate: Date
    var calendar: Calendar
    var dropDurationMinutes: Int
    var blocksForDate: (Date) -> [DayPlanBlock]
    var taskTint: (DayPlanBlock) -> Color
    var onSelectSlot: (Date, Int) -> Void
    var onSelectBlock: (DayPlanBlock, Date) -> Void
    var onDeleteBlock: (DayPlanBlock) -> Void
    var onMoveBlock: (DayPlanBlock.ID, Date, Int) -> Void
    var onResizeBlock: (DayPlanBlock.ID, Date, Int, Int) -> Void
    var onDropTask: (UUID, Date, Int) -> Void

    @State private var isDropTargeted = false
    @State private var isCompletingDrop = false
    @State private var dropPreview: DayPlanDropPreview?
    @State private var draggedBlockID: DayPlanBlock.ID?
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
                calendar: calendar,
                timeColumnWidth: timeColumnWidth
            )

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    GeometryReader { proxy in
                        let dayWidth = max((proxy.size.width - timeColumnWidth) / CGFloat(max(dates.count, 1)), 120)

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
                            weekBlocks(dayWidth: dayWidth)
                            if let dropPreview, isDropTargeted, !isCompletingDrop {
                                DayPlanDropIndicator(
                                    preview: dropPreview,
                                    dates: dates,
                                    calendar: calendar,
                                    dayWidth: dayWidth,
                                    hourHeight: hourHeight,
                                    timeColumnWidth: timeColumnWidth
                                )
                                .animation(DayPlanMotion.dropPreview, value: dropPreview)
                            }
                            DayPlanCurrentTimeScrollAnchor(
                                dates: dates,
                                calendar: calendar,
                                hourHeight: hourHeight,
                                timeColumnWidth: timeColumnWidth
                            )
                            SwiftUI.TimelineView(.periodic(from: Date(), by: 60)) { timeline in
                                DayPlanCurrentTimeIndicator(
                                    dates: dates,
                                    now: timeline.date,
                                    calendar: calendar,
                                    dayWidth: dayWidth,
                                    hourHeight: hourHeight,
                                    timeColumnWidth: timeColumnWidth
                                )
                            }
                        }
                        .onDrop(
                            of: [.text],
                            delegate: DayPlanTaskDropDelegate(
                                dates: dates,
                                dayWidth: dayWidth,
                                timeColumnWidth: timeColumnWidth,
                                hourHeight: hourHeight,
                                dropDurationMinutes: dropDurationMinutes,
                                draggedBlockID: $draggedBlockID,
                                draggedBlockDurationMinutes: $draggedBlockDurationMinutes,
                                isCompletingDrop: $isCompletingDrop,
                                isDropTargeted: $isDropTargeted,
                                dropPreview: $dropPreview,
                                onMoveBlock: onMoveBlock,
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

    private func weekBlocks(dayWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(dates.enumerated()), id: \.element) { dayIndex, date in
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
                        onDelete: {
                            onDeleteBlock(block)
                        },
                        onResizeStarted: {
                            beginResize(block, on: date)
                        },
                        onResizeChanged: { edge, verticalDelta in
                            resize(block, on: date, edge: edge, verticalDelta: verticalDelta)
                        },
                        onResizeEnded: {
                            endResize()
                        },
                        onDragProvider: {
                            isCompletingDrop = false
                            clearDropState()
                            endResize()
                            draggedBlockID = block.id
                            draggedBlockDurationMinutes = block.durationMinutes
                            onSelectBlock(block, date)
                            return NSItemProvider(object: DayPlanBlockDragPayload.text(for: block.id) as NSString)
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
        CGFloat(block.durationMinutes) / 60 * hourHeight
    }

    private func beginResize(_ block: DayPlanBlock, on date: Date) {
        clearDropState()
        draggedBlockID = nil
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
        on date: Date,
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

    private func scrollToCurrentTime(with proxy: ScrollViewProxy) {
        guard dates.contains(where: { calendar.isDateInToday($0) }) else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(DayPlanScrollTarget.currentTime, anchor: .center)
            }
        }
    }

}

private struct DayPlanResizeSession: Equatable {
    let blockID: DayPlanBlock.ID
    let startMinute: Int
    let durationMinutes: Int
}
