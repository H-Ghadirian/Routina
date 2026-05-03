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
            dayHeaderRow

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    GeometryReader { proxy in
                        let dayWidth = max((proxy.size.width - timeColumnWidth) / CGFloat(max(dates.count, 1)), 120)

                        ZStack(alignment: .topLeading) {
                            weekGrid(dayWidth: dayWidth)
                            selectionButtons(dayWidth: dayWidth)
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
                            currentTimeScrollAnchor()
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

    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            Text("Time")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: 56)

            ForEach(dates, id: \.self) { date in
                DayPlanWeekDayHeader(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date)
                )
            }
        }
        .background(Color.secondary.opacity(0.08))
    }

    private func weekGrid(dayWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<24, id: \.self) { hour in
                hourLabel(for: hour)
                hourLine(for: hour, dayWidth: dayWidth)
            }

            ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                Rectangle()
                    .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.08) : Color.clear)
                    .frame(width: dayWidth, height: hourHeight * 24)
                    .offset(x: timeColumnWidth + CGFloat(index) * dayWidth)

                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 1, height: hourHeight * 24)
                    .offset(x: timeColumnWidth + CGFloat(index) * dayWidth)
            }
        }
    }

    private func hourLabel(for hour: Int) -> some View {
        Text(DayPlanFormatting.hourText(for: hour, on: selectedDate, calendar: calendar))
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(width: timeColumnWidth - 10, alignment: .trailing)
            .offset(y: hourLabelYOffset(for: hour))
    }

    private func hourLine(for hour: Int, dayWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.22))
            .frame(width: CGFloat(dates.count) * dayWidth, height: 1)
            .offset(x: timeColumnWidth, y: CGFloat(hour) * hourHeight)
            .id(DayPlanScrollTarget.hour(hour))
    }

    @ViewBuilder
    private func currentTimeScrollAnchor() -> some View {
        if dates.contains(where: { calendar.isDateInToday($0) }) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: currentTimeYOffset(for: Date()))

                Color.clear
                    .frame(width: 1, height: 1)
                    .id(DayPlanScrollTarget.currentTime)

                Spacer(minLength: 0)
            }
            .frame(width: 1, height: hourHeight * 24)
            .offset(x: timeColumnWidth)
        }
    }

    private func hourLabelYOffset(for hour: Int) -> CGFloat {
        max((CGFloat(hour) * hourHeight) - 8, 0)
    }

    private func selectionButtons(dayWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(dates.enumerated()), id: \.element) { dayIndex, date in
                ForEach(0..<24, id: \.self) { hour in
                    Button {
                        onSelectSlot(date, hour * 60)
                    } label: {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: dayWidth, height: hourHeight)
                    .offset(
                        x: timeColumnWidth + CGFloat(dayIndex) * dayWidth,
                        y: CGFloat(hour) * hourHeight
                    )
                }
            }
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

    private func currentTimeYOffset(for date: Date) -> CGFloat {
        CGFloat(currentMinute(for: date)) / 60 * hourHeight
    }

    private func currentMinute(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return min(max(minute, 0), DayPlanBlock.minutesPerDay)
    }
}

private struct DayPlanDropPreview: Equatable {
    let dayIndex: Int
    let startMinute: Int
    let durationMinutes: Int
}

private enum DayPlanScrollTarget: Hashable {
    case hour(Int)
    case currentTime
}

private enum DayPlanMotion {
    static let dropPreview = Animation.interactiveSpring(
        response: 0.2,
        dampingFraction: 0.86,
        blendDuration: 0.04
    )

    static let dropCommit = Animation.spring(
        response: 0.28,
        dampingFraction: 0.88,
        blendDuration: 0.06
    )
}

private struct DayPlanResizeSession: Equatable {
    let blockID: DayPlanBlock.ID
    let startMinute: Int
    let durationMinutes: Int
}

private enum DayPlanBlockDragPayload {
    private static let prefix = "day-plan-block:"

    static func text(for blockID: DayPlanBlock.ID) -> String {
        prefix + blockID.uuidString
    }

    static func blockID(from text: String) -> DayPlanBlock.ID? {
        guard text.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(text.dropFirst(prefix.count)))
    }
}

private struct DayPlanDropIndicator: View {
    var preview: DayPlanDropPreview
    var dates: [Date]
    var calendar: Calendar
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            Color.accentColor.opacity(0.75),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                )
                .frame(width: indicatorWidth, height: indicatorHeight)
                .offset(x: indicatorX, y: indicatorY)

            insertionLine
                .frame(width: indicatorWidth)
                .offset(x: indicatorX, y: max(indicatorY - 2, 0))

            if indicatorHeight >= 28 {
                Text(timeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThickMaterial, in: Capsule(style: .continuous))
                    .offset(x: indicatorX + 8, y: indicatorY + 6)
            }
        }
        .allowsHitTesting(false)
        .zIndex(12)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }

    private var insertionLine: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)

            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 3)
        }
        .padding(.horizontal, 4)
    }

    private var indicatorWidth: CGFloat {
        max(dayWidth - 10, 90)
    }

    private var indicatorHeight: CGFloat {
        CGFloat(preview.durationMinutes) / 60 * hourHeight
    }

    private var indicatorX: CGFloat {
        timeColumnWidth + (CGFloat(preview.dayIndex) * dayWidth) + 5
    }

    private var indicatorY: CGFloat {
        CGFloat(preview.startMinute) / 60 * hourHeight
    }

    private var timeText: String {
        guard dates.indices.contains(preview.dayIndex) else { return "" }
        return DayPlanFormatting.timeText(
            for: preview.startMinute,
            on: dates[preview.dayIndex],
            calendar: calendar
        )
    }
}

private struct DayPlanTaskDropDelegate: DropDelegate {
    let dates: [Date]
    let dayWidth: CGFloat
    let timeColumnWidth: CGFloat
    let hourHeight: CGFloat
    let dropDurationMinutes: Int
    @Binding var draggedBlockID: DayPlanBlock.ID?
    @Binding var draggedBlockDurationMinutes: Int?
    @Binding var isCompletingDrop: Bool
    @Binding var isDropTargeted: Bool
    @Binding var dropPreview: DayPlanDropPreview?
    let onMoveBlock: (DayPlanBlock.ID, Date, Int) -> Void
    let onDropTask: (UUID, Date, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        !isCompletingDrop
            && dropTarget(for: info.location) != nil
            && (draggedBlockID != nil || info.hasItemsConforming(to: [.text]))
    }

    func dropEntered(info: DropInfo) {
        guard !isCompletingDrop else {
            clearDropState()
            return
        }

        updatePreview(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard !isCompletingDrop, validateDrop(info: info) else {
            clearDropState()
            return nil
        }

        updatePreview(for: info)
        return DropProposal(operation: draggedBlockID == nil ? .copy : .move)
    }

    func dropExited(info: DropInfo) {
        clearDropState()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let target = dropTarget(for: info.location) else {
            clearDropState()
            return false
        }

        if let draggedBlockID {
            finishDrop()
            withAnimation(DayPlanMotion.dropCommit) {
                onMoveBlock(draggedBlockID, target.date, target.startMinute)
            }
            return true
        }

        guard let provider = info.itemProviders(for: [.text]).first else {
            clearDropState()
            return false
        }

        finishDrop()

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard
                let text = object as? NSString
            else { return }

            let payloadText = text as String
            DispatchQueue.main.async {
                if let blockID = DayPlanBlockDragPayload.blockID(from: payloadText) {
                    withAnimation(DayPlanMotion.dropCommit) {
                        onMoveBlock(blockID, target.date, target.startMinute)
                    }
                } else if let taskID = UUID(uuidString: payloadText) {
                    withAnimation(DayPlanMotion.dropCommit) {
                        onDropTask(taskID, target.date, target.startMinute)
                    }
                }
            }
        }
        return true
    }

    private func updatePreview(for info: DropInfo) {
        guard !isCompletingDrop else {
            clearDropState()
            return
        }

        guard let target = dropTarget(for: info.location) else {
            dropPreview = nil
            isDropTargeted = false
            return
        }

        isDropTargeted = true
        dropPreview = DayPlanDropPreview(
            dayIndex: target.dayIndex,
            startMinute: target.startMinute,
            durationMinutes: previewDuration(for: info)
        )
    }

    private func finishDrop() {
        isCompletingDrop = true
        clearDragState()

        DispatchQueue.main.async {
            clearDragState()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            clearDragState()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            isCompletingDrop = false
            clearDragState()
        }
    }

    private func clearDropState() {
        isDropTargeted = false
        dropPreview = nil
    }

    private func clearDragState() {
        draggedBlockID = nil
        draggedBlockDurationMinutes = nil
        clearDropState()
    }

    private func previewDuration(for info: DropInfo) -> Int {
        if draggedBlockID != nil {
            return draggedBlockDurationMinutes ?? dropDurationMinutes
        }
        return dropDurationMinutes
    }

    private func dropTarget(for location: CGPoint) -> (dayIndex: Int, date: Date, startMinute: Int)? {
        guard !dates.isEmpty else { return nil }

        let dayX = location.x - timeColumnWidth
        guard dayX >= 0 else { return nil }

        let dayIndex = min(max(Int(dayX / dayWidth), 0), dates.count - 1)
        let boundedY = min(max(location.y, 0), (hourHeight * 24) - 1)
        let rawMinute = Int((boundedY / hourHeight) * 60)
        let quarterHourMinute = (rawMinute / 15) * 15

        return (
            dayIndex: dayIndex,
            date: dates[dayIndex],
            startMinute: DayPlanBlock.clampedStartMinute(quarterHourMinute)
        )
    }
}
