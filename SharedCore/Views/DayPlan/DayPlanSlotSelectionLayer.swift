import SwiftUI

struct DayPlanSlotSelectionLayer: View {
    var dates: [Date]
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat
    var onSelectSlot: (Date, Int) -> Void
    var onOpenSlotActions: (Date, Int) -> Void

    @State private var pendingTap: PendingSlotTap?

    var body: some View {
        Color.clear
            .frame(
                width: timeColumnWidth + (CGFloat(dates.count) * dayWidth),
                height: hourHeight * 24
            )
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let target = target(for: value.location) else { return }
                        handleTap(on: target)
                    }
            )
    }

    private func handleTap(on target: DayPlanDropTarget) {
        let now = Date()
        if let pendingTap,
           pendingTap.matches(target),
           now.timeIntervalSince(pendingTap.timestamp) <= 0.42 {
            self.pendingTap = nil
            onSelectSlot(target.date, target.startMinute)
            onOpenSlotActions(target.date, target.startMinute)
            return
        }

        pendingTap = PendingSlotTap(
            date: target.date,
            startMinute: target.startMinute,
            timestamp: now
        )
        onSelectSlot(target.date, target.startMinute)
    }

    private func target(for location: CGPoint) -> DayPlanDropTarget? {
        let daysWidth = CGFloat(dates.count) * dayWidth
        guard location.x >= timeColumnWidth,
              location.x < timeColumnWidth + daysWidth,
              location.y >= 0,
              location.y < hourHeight * 24
        else {
            return nil
        }

        return DayPlanDropTargetResolver.target(
            for: location,
            dates: dates,
            dayWidth: dayWidth,
            timeColumnWidth: timeColumnWidth,
            hourHeight: hourHeight
        )
    }
}

private struct PendingSlotTap {
    let date: Date
    let startMinute: Int
    let timestamp: Date

    func matches(_ target: DayPlanDropTarget) -> Bool {
        date == target.date && startMinute == target.startMinute
    }
}
