import SwiftUI

struct DayPlanWeekGridView: View {
    var dates: [Date]
    var selectedDate: Date
    var calendar: Calendar
    var dayWidth: CGFloat
    var timeAxis: DayPlanAdaptiveTimeAxis
    var timeColumnWidth: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<24, id: \.self) { hour in
                hourLabel(for: hour)
                hourLine(for: hour)
            }

            ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                Rectangle()
                    .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.secondary.opacity(0.035) : Color.clear)
                    .frame(width: dayWidth, height: timeAxis.contentHeight)
                    .offset(x: timeColumnWidth + CGFloat(index) * dayWidth)

                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 1, height: timeAxis.contentHeight)
                    .offset(x: timeColumnWidth + CGFloat(index) * dayWidth)
            }
        }
        .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
    }

    private func hourLabel(for hour: Int) -> some View {
        Text(DayPlanFormatting.hourText(for: hour, on: selectedDate, calendar: calendar))
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(width: timeColumnWidth - 10, alignment: .trailing)
            .offset(y: hourLabelYOffset(for: hour))
    }

    private func hourLine(for hour: Int) -> some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.22))
            .frame(width: CGFloat(dates.count) * dayWidth, height: 1)
            .offset(x: timeColumnWidth, y: timeAxis.yOffset(forMinute: hour * 60))
            .id(DayPlanScrollTarget.hour(hour))
    }

    private func hourLabelYOffset(for hour: Int) -> CGFloat {
        max(timeAxis.yOffset(forMinute: hour * 60) - 8, 0)
    }

    private var contentWidth: CGFloat {
        timeColumnWidth + (CGFloat(dates.count) * dayWidth)
    }

    private var contentHeight: CGFloat {
        timeAxis.contentHeight
    }
}
