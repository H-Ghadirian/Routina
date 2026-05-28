import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum DayPlanMotion {
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

enum DayPlanBlockDragPayload {
    private static let prefix = "day-plan-block:"

    static func text(for blockID: DayPlanBlock.ID) -> String {
        prefix + blockID.uuidString
    }

    static func blockID(from text: String) -> DayPlanBlock.ID? {
        guard text.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(text.dropFirst(prefix.count)))
    }
}

struct DayPlanDropTarget: Equatable {
    let dayIndex: Int
    let date: Date
    let startMinute: Int
}

struct DayPlanAllDayDropTarget: Equatable {
    let dayIndex: Int
    let date: Date
}

enum DayPlanDropTargetResolver {
    static func target(
        for location: CGPoint,
        dates: [Date],
        dayWidth: CGFloat,
        timeColumnWidth: CGFloat,
        hourHeight: CGFloat
    ) -> DayPlanDropTarget? {
        guard !dates.isEmpty, dayWidth > 0, hourHeight > 0 else { return nil }

        let dayX = max(location.x - timeColumnWidth, 0)
        let dayIndex = min(max(Int(dayX / dayWidth), 0), dates.count - 1)
        let timelineHeight = hourHeight * 24
        let boundedY = min(max(location.y, 0), max(timelineHeight - 1, 0))
        let rawMinute = Int((boundedY / hourHeight) * 60)
        let quarterHourMinute = (rawMinute / 15) * 15

        return DayPlanDropTarget(
            dayIndex: dayIndex,
            date: dates[dayIndex],
            startMinute: DayPlanBlock.clampedStartMinute(quarterHourMinute)
        )
    }
}

enum DayPlanAllDayDropTargetResolver {
    static func target(
        for location: CGPoint,
        dates: [Date],
        dayWidth: CGFloat
    ) -> DayPlanAllDayDropTarget? {
        guard !dates.isEmpty, dayWidth > 0 else { return nil }

        let dayIndex = min(max(Int(max(location.x, 0) / dayWidth), 0), dates.count - 1)
        return DayPlanAllDayDropTarget(dayIndex: dayIndex, date: dates[dayIndex])
    }
}

struct DayPlanTaskDropDelegate: DropDelegate {
    let dates: [Date]
    let dayWidth: CGFloat
    let timeColumnWidth: CGFloat
    let hourHeight: CGFloat
    let dropDurationMinutes: Int
    @Binding var draggedBlockID: DayPlanBlock.ID?
    @Binding var draggedTimelineActivity: DayPlanTimelineActivityBlock?
    @Binding var draggedBlockDurationMinutes: Int?
    @Binding var isCompletingDrop: Bool
    @Binding var isDropTargeted: Bool
    @Binding var dropPreview: DayPlanDropPreview?
    let blockedIntervalsForDate: (Date) -> [DayPlanBlockedInterval]
    let onMoveBlock: (DayPlanBlock.ID, Date, Int) -> Void
    let onMoveTimelineActivity: (DayPlanTimelineActivityBlock, Date, Int) -> Void
    let onDropTask: (UUID, Date, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard let target = dropTarget(for: info.location),
              draggedBlockID != nil
                || draggedTimelineActivity != nil
                || info.hasItemsConforming(to: [.text])
        else {
            return false
        }

        return !isBlocked(target, durationMinutes: previewDuration(for: info))
    }

    func dropEntered(info: DropInfo) {
        prepareForActiveDrop()
        updatePreview(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        prepareForActiveDrop()
        guard validateDrop(info: info) else {
            clearDropState()
            return nil
        }

        guard updatePreview(for: info) else {
            return nil
        }
        return DropProposal(operation: draggedBlockID == nil && draggedTimelineActivity == nil ? .copy : .move)
    }

    func dropExited(info: DropInfo) {
        clearDropState()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let target = dropTarget(for: info.location),
              !isBlocked(target, durationMinutes: previewDuration(for: info))
        else {
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

        if let draggedTimelineActivity {
            finishDrop()
            withAnimation(DayPlanMotion.dropCommit) {
                onMoveTimelineActivity(draggedTimelineActivity, target.date, target.startMinute)
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

    @discardableResult
    private func updatePreview(for info: DropInfo) -> Bool {
        guard let target = dropTarget(for: info.location) else {
            clearDropState()
            return false
        }

        let durationMinutes = previewDuration(for: info)
        guard !isBlocked(target, durationMinutes: durationMinutes) else {
            clearDropState()
            return false
        }

        let nextPreview = DayPlanDropPreview(
            dayIndex: target.dayIndex,
            startMinute: target.startMinute,
            durationMinutes: durationMinutes
        )
        if isDropTargeted, dropPreview == nextPreview {
            return true
        }

        isDropTargeted = true
        dropPreview = nextPreview
        return true
    }

    private func prepareForActiveDrop() {
        if isCompletingDrop {
            isCompletingDrop = false
        }
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
        if isDropTargeted {
            isDropTargeted = false
        }
        if dropPreview != nil {
            dropPreview = nil
        }
    }

    private func clearDragState() {
        draggedBlockID = nil
        draggedTimelineActivity = nil
        draggedBlockDurationMinutes = nil
        clearDropState()
    }

    private func previewDuration(for info: DropInfo) -> Int {
        if draggedBlockID != nil {
            return draggedBlockDurationMinutes ?? dropDurationMinutes
        }
        if draggedTimelineActivity != nil {
            return draggedBlockDurationMinutes ?? dropDurationMinutes
        }
        return dropDurationMinutes
    }

    private func dropTarget(for location: CGPoint) -> DayPlanDropTarget? {
        DayPlanDropTargetResolver.target(
            for: location,
            dates: dates,
            dayWidth: dayWidth,
            timeColumnWidth: timeColumnWidth,
            hourHeight: hourHeight
        )
    }

    private func isBlocked(_ target: DayPlanDropTarget, durationMinutes: Int) -> Bool {
        blockedIntervalsForDate(target.date).contains {
            $0.overlaps(startMinute: target.startMinute, durationMinutes: durationMinutes)
        }
    }
}

struct DayPlanAllDayDropDelegate: DropDelegate {
    let dates: [Date]
    let dayWidth: CGFloat
    @Binding var draggedBlockID: DayPlanBlock.ID?
    @Binding var draggedTimelineActivity: DayPlanTimelineActivityBlock?
    @Binding var targetedDayIndex: Int?
    let onMoveBlockToAllDay: (DayPlanBlock.ID, Date) -> Void
    let onMoveTimelineActivityToAllDay: (DayPlanTimelineActivityBlock, Date) -> Void
    let onDropTaskToAllDay: (UUID, Date) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        dropTarget(for: info.location) != nil
            && (draggedBlockID != nil || draggedTimelineActivity != nil || info.hasItemsConforming(to: [.text]))
    }

    func dropEntered(info: DropInfo) {
        updateTarget(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else {
            clearTarget()
            return nil
        }
        updateTarget(for: info)
        return DropProposal(operation: draggedBlockID == nil && draggedTimelineActivity == nil ? .copy : .move)
    }

    func dropExited(info: DropInfo) {
        clearTarget()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let target = dropTarget(for: info.location) else {
            clearTarget()
            return false
        }

        if let draggedBlockID {
            finishDrop()
            withAnimation(DayPlanMotion.dropCommit) {
                onMoveBlockToAllDay(draggedBlockID, target.date)
            }
            return true
        }

        if let draggedTimelineActivity {
            finishDrop()
            withAnimation(DayPlanMotion.dropCommit) {
                onMoveTimelineActivityToAllDay(draggedTimelineActivity, target.date)
            }
            return true
        }

        guard let provider = info.itemProviders(for: [.text]).first else {
            clearTarget()
            return false
        }

        finishDrop()
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let text = object as? NSString else { return }

            let payloadText = text as String
            DispatchQueue.main.async {
                if let blockID = DayPlanBlockDragPayload.blockID(from: payloadText) {
                    withAnimation(DayPlanMotion.dropCommit) {
                        onMoveBlockToAllDay(blockID, target.date)
                    }
                } else if let taskID = UUID(uuidString: payloadText) {
                    withAnimation(DayPlanMotion.dropCommit) {
                        onDropTaskToAllDay(taskID, target.date)
                    }
                }
            }
        }
        return true
    }

    private func updateTarget(for info: DropInfo) {
        targetedDayIndex = dropTarget(for: info.location)?.dayIndex
    }

    private func finishDrop() {
        draggedBlockID = nil
        draggedTimelineActivity = nil
        clearTarget()
    }

    private func clearTarget() {
        targetedDayIndex = nil
    }

    private func dropTarget(for location: CGPoint) -> DayPlanAllDayDropTarget? {
        DayPlanAllDayDropTargetResolver.target(
            for: location,
            dates: dates,
            dayWidth: dayWidth
        )
    }
}
