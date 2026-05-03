import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct DayPlanTaskAvatar: View {
    var emoji: String?
    var tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.16))
            if let emoji = CalendarTaskImportSupport.displayEmoji(for: emoji) {
                Text(emoji)
                    .font(.title3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 34, height: 34)
    }
}

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

private enum DayPlanResizeEdge {
    case top
    case bottom
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

private struct DayPlanCurrentTimeIndicator: View {
    var dates: [Date]
    var now: Date
    var calendar: Calendar
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat

    var body: some View {
        Group {
            if let todayIndex {
                ZStack(alignment: .topLeading) {
                    lineCanvas(todayIndex: todayIndex)
                    timeLabel
                    todayDot(todayIndex: todayIndex)
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .allowsHitTesting(false)
                .zIndex(20)
            }
        }
    }

    private var timeLabel: some View {
        Text(DayPlanFormatting.timeText(for: currentMinute, on: now, calendar: calendar))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.red)
            .monospacedDigit()
            .frame(width: timeColumnWidth - 8, alignment: .trailing)
            .offset(y: max(yOffset - 8, 0))
    }

    private func todayDot(todayIndex: Int) -> some View {
        Circle()
            .fill(.red)
            .frame(width: 7, height: 7)
            .offset(x: todayColumnX(todayIndex: todayIndex) - 3.5, y: yOffset - 3.5)
    }

    private func lineCanvas(todayIndex: Int) -> some View {
        Canvas { context, size in
            let y = min(max(yOffset, 0), size.height)

            for index in todayIndex..<dates.count {
                let x = timeColumnWidth + (CGFloat(index) * dayWidth)
                let isToday = index == todayIndex
                let thickness: CGFloat = isToday ? 2.5 : 1
                let opacity: Double = isToday ? 1 : 0.42
                let rect = CGRect(
                    x: x,
                    y: y - (thickness / 2),
                    width: dayWidth,
                    height: thickness
                )

                context.fill(Path(rect), with: .color(.red.opacity(opacity)))
            }
        }
        .frame(width: contentWidth, height: contentHeight)
    }

    private var todayIndex: Int? {
        dates.firstIndex { calendar.isDate($0, inSameDayAs: now) }
    }

    private var currentMinute: Int {
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return min(max(minute, 0), DayPlanBlock.minutesPerDay)
    }

    private var yOffset: CGFloat {
        CGFloat(currentMinute) / 60 * hourHeight
    }

    private var contentWidth: CGFloat {
        timeColumnWidth + (CGFloat(dates.count) * dayWidth)
    }

    private var contentHeight: CGFloat {
        hourHeight * 24
    }

    private func todayColumnX(todayIndex: Int) -> CGFloat {
        timeColumnWidth + (CGFloat(todayIndex) * dayWidth)
    }
}

private struct DayPlanWeekDayHeader: View {
    var date: Date
    var isSelected: Bool
    var isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(date.formatted(.dateTime.day()))
                .font(.title3.weight(.semibold))
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .padding(.horizontal, isToday ? 8 : 0)
                .padding(.vertical, isToday ? 3 : 0)
                .background {
                    if isToday {
                        Capsule()
                            .fill(Color.accentColor)
                    }
                }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
        }
    }
}

private struct DayPlanBlockCard: View {
    var block: DayPlanBlock
    var tint: Color
    var isSelected: Bool
    var renderedHeight: CGFloat
    var selectedDate: Date
    var calendar: Calendar
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void
    var onDragProvider: () -> NSItemProvider

    var body: some View {
        Button(action: onSelect) {
            cardContent
                .padding(contentInsets)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(isSelected ? 0.22 : 0.14))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(isSelected ? 0.75 : 0.35), lineWidth: isSelected ? 2 : 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onDrag(onDragProvider)
        .overlay(alignment: .top) {
            DayPlanResizeHandle(
                edge: .top,
                isSelected: isSelected,
                onResizeStarted: onResizeStarted,
                onResizeChanged: onResizeChanged,
                onResizeEnded: onResizeEnded
            )
        }
        .overlay(alignment: .bottom) {
            DayPlanResizeHandle(
                edge: .bottom,
                isSelected: isSelected,
                onResizeStarted: onResizeStarted,
                onResizeChanged: onResizeChanged,
                onResizeEnded: onResizeEnded
            )
        }
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if renderedHeight < 36 {
            HStack(spacing: 5) {
                miniIcon

                Text(block.titleSnapshot)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(block.durationMinutes)m")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        } else if renderedHeight < 48 {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    miniIcon

                    Text(block.titleSnapshot)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }

                Text(rangeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                DayPlanTaskAvatar(emoji: block.emojiSnapshot, tint: tint)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(block.titleSnapshot)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(rangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 6)
            }
        }
    }

    private var miniIcon: some View {
        Group {
            if let emoji = CalendarTaskImportSupport.displayEmoji(for: block.emojiSnapshot) {
                Text(emoji)
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(tint)
            }
        }
        .font(.caption2.weight(.semibold))
        .frame(width: 13, height: 13)
        .lineLimit(1)
    }

    private var contentInsets: EdgeInsets {
        if renderedHeight < 36 {
            EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6)
        } else if renderedHeight < 48 {
            EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)
        } else {
            EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        }
    }

    private var rangeText: String {
        let start = DayPlanFormatting.timeText(for: block.startMinute, on: selectedDate, calendar: calendar)
        let end = DayPlanFormatting.timeText(for: block.endMinute, on: selectedDate, calendar: calendar)
        let duration = DayPlanFormatting.durationText(block.durationMinutes)
        return "\(start)-\(end)  \(duration)"
    }
}

private struct DayPlanResizeHandle: View {
    var edge: DayPlanResizeEdge
    var isSelected: Bool
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void

    @State private var isHovering = false
    @State private var isResizing = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                marker
                    .opacity(isSelected || isHovering || isResizing ? 1 : 0)
            }
            .dayPlanVerticalResizeCursor()
            .onHover { isHovering = $0 }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if !isResizing {
                            isResizing = true
                            onResizeStarted()
                        }
                        onResizeChanged(edge, value.translation.height)
                    }
                    .onEnded { _ in
                        isResizing = false
                        onResizeEnded()
                    }
            )
            .padding(.top, edge == .top ? -6 : 0)
            .padding(.bottom, edge == .bottom ? -6 : 0)
    }

    private var marker: some View {
        VStack(spacing: -3) {
            Image(systemName: "chevron.up")
            Capsule()
                .frame(width: 18, height: 3)
            Image(systemName: "chevron.down")
        }
        .font(.system(size: 7, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.black.opacity(0.48), in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

#if os(macOS)
private struct DayPlanVerticalResizeCursorModifier: ViewModifier {
    @State private var didPushCursor = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering, !didPushCursor {
                    NSCursor.resizeUpDown.push()
                    didPushCursor = true
                } else if !isHovering, didPushCursor {
                    NSCursor.pop()
                    didPushCursor = false
                }
            }
            .onDisappear {
                if didPushCursor {
                    NSCursor.pop()
                    didPushCursor = false
                }
            }
    }
}

private extension View {
    func dayPlanVerticalResizeCursor() -> some View {
        modifier(DayPlanVerticalResizeCursorModifier())
    }
}
#else
private extension View {
    func dayPlanVerticalResizeCursor() -> some View {
        self
    }
}
#endif
