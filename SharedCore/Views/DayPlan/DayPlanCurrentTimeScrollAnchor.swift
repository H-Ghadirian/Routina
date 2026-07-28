import SwiftUI

struct DayPlanCurrentTimeScrollAnchor: View {
    var dates: [Date]
    var calendar: Calendar
    var timeAxis: DayPlanAdaptiveTimeAxis
    var timeColumnWidth: CGFloat

    var body: some View {
        Group {
            if dates.contains(where: { calendar.isDateInToday($0) }) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: currentTimeYOffset(for: Date()))

                    Color.clear
                        .frame(width: 1, height: 1)
                        .id(DayPlanScrollTarget.currentTime)

                    Spacer(minLength: 0)
                }
                .frame(width: 1, height: timeAxis.contentHeight)
                .offset(x: timeColumnWidth)
            }
        }
    }

    private func currentTimeYOffset(for date: Date) -> CGFloat {
        timeAxis.yOffset(forMinute: currentMinute(for: date))
    }

    private func currentMinute(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return min(max(minute, 0), DayPlanBlock.minutesPerDay)
    }
}

struct DayPlanMinuteScrollAnchor: View {
    var target: DayPlanScrollTarget
    var minute: Int
    var timeAxis: DayPlanAdaptiveTimeAxis
    var timeColumnWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: yOffset)

            Color.clear
                .frame(width: 1, height: 1)
                .id(target)

            Spacer(minLength: 0)
        }
        .frame(width: 1, height: timeAxis.contentHeight)
        .offset(x: timeColumnWidth)
    }

    private var yOffset: CGFloat {
        let clampedMinute = min(max(minute, 0), DayPlanBlock.minutesPerDay)
        return timeAxis.yOffset(forMinute: clampedMinute)
    }
}
