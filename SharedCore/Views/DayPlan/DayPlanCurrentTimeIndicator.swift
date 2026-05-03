import SwiftUI

struct DayPlanCurrentTimeIndicator: View {
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
