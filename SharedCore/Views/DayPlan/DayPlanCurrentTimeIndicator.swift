import SwiftUI

struct DayPlanCurrentTimeIndicator: View {
    var dates: [Date]
    var now: Date
    var calendar: Calendar
    var dayWidth: CGFloat
    var hourHeight: CGFloat
    var timeColumnWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme

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
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background {
                Capsule(style: .continuous)
                    .fill(timeLabelBackground)
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.red.opacity(0.38), lineWidth: 0.75)
            }
            .frame(width: timeColumnWidth - 8, alignment: .trailing)
            .offset(y: timeLabelYOffset)
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

    private var timeLabelYOffset: CGFloat {
        let defaultOffset = yOffset - (timeLabelEstimatedHeight / 2)
        let nearestVisibleHour = min(max(Int((yOffset / hourHeight).rounded()), 0), 23)
        let nearestHourY = CGFloat(nearestVisibleHour) * hourHeight
        let isNearHourLabel = abs(yOffset - nearestHourY) < timeLabelCollisionDistance
        let proposedOffset: CGFloat

        if isNearHourLabel {
            let nearestHourLabelTop = nearestHourY - hourLabelTopInset
            let aboveOffset = nearestHourLabelTop - timeLabelEstimatedHeight - timeLabelCollisionGap
            let belowOffset = nearestHourLabelTop + hourLabelEstimatedHeight + timeLabelCollisionGap
            proposedOffset = yOffset < nearestHourY && aboveOffset >= 0 ? aboveOffset : belowOffset
        } else {
            proposedOffset = defaultOffset
        }

        return min(max(proposedOffset, 0), max(contentHeight - timeLabelEstimatedHeight, 0))
    }

    private var timeLabelBackground: Color {
        colorScheme == .dark ? Color.black.opacity(0.82) : Color.white.opacity(0.94)
    }

    private var timeLabelEstimatedHeight: CGFloat {
        18
    }

    private var timeLabelCollisionDistance: CGFloat {
        timeLabelEstimatedHeight + timeLabelCollisionGap
    }

    private var timeLabelCollisionGap: CGFloat {
        4
    }

    private var hourLabelTopInset: CGFloat {
        8
    }

    private var hourLabelEstimatedHeight: CGFloat {
        16
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
