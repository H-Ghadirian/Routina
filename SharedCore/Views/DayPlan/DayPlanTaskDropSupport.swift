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

struct DayPlanTaskDropDelegate: DropDelegate {
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
