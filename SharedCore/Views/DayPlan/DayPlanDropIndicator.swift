import SwiftUI

struct DayPlanDropPreview: Equatable {
    let dayIndex: Int
    let startMinute: Int
    let durationMinutes: Int
}

struct DayPlanDropIndicator: View {
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
