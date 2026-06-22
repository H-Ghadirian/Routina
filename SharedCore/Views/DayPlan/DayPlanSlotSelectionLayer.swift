import SwiftUI

struct DayPlanSlotSelectionLayer: View {
    var dates: [Date]
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat
    var onSelectSlot: (Date, Int) -> Void

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
                        onSelectSlot(target.date, target.startMinute)
                    }
            )
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
