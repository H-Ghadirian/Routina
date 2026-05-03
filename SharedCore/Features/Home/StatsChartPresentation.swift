import SwiftUI

struct StatsChartPresentation {
    let selectedRange: DoneChartRange
    let isCompact: Bool

    func sampledSparklinePoints(from chartPoints: [DoneChartPoint]) -> [DoneChartPoint] {
        let targetCount: Int

        switch selectedRange {
        case .today:
            targetCount = 1
        case .week:
            targetCount = 7
        case .month:
            targetCount = 15
        case .year:
            targetCount = 24
        }

        guard chartPoints.count > targetCount, targetCount > 1 else {
            return chartPoints
        }

        let step = Double(chartPoints.count - 1) / Double(targetCount - 1)

        return (0..<targetCount).map { index in
            let pointIndex = min(Int((Double(index) * step).rounded()), chartPoints.count - 1)
            return chartPoints[pointIndex]
        }
    }

    func sparklineCaption(highlightedBusiestDay: DoneChartPoint?) -> String {
        guard let highlightedBusiestDay else {
            return "No peak yet"
        }

        return "Peak \(highlightedBusiestDay.count)"
    }

    func sparklineColor(for point: DoneChartPoint, highlightedBusiestDay: DoneChartPoint?) -> Color {
        if point.date == highlightedBusiestDay?.date {
            return Color.white.opacity(0.96)
        }

        return Color.white.opacity(point.count == 0 ? 0.12 : 0.3)
    }

    func sparklineBarHeight(for point: DoneChartPoint, maxCount: Int) -> CGFloat {
        let normalized = max(CGFloat(point.count) / CGFloat(max(maxCount, 1)), 0.12)
        return 16 + (normalized * 54)
    }

    var chartMinWidth: CGFloat {
        switch selectedRange {
        case .today:
            return 260
        case .week:
            return 340
        case .month:
            return 720
        case .year:
            return 2600
        }
    }

    func averagePerDayText(for averagePerDay: Double) -> String {
        averagePerDay.formatted(.number.precision(.fractionLength(1)))
    }

    func focusDurationText(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0m" }
        return FocusSessionFormatting.compactDurationText(seconds: seconds)
    }

    func chartSectionSubtitle(totalCount: Int, averagePerDay: Double, dayCount: Int) -> String {
        if totalCount == 0 {
            return "Your chart will fill in as you complete routines."
        }

        return "Average \(averagePerDayText(for: averagePerDay)) per day across \(dayCount) days."
    }

    func focusChartSectionSubtitle(totalFocusSeconds: TimeInterval, activeDayCount: Int) -> String {
        if totalFocusSeconds == 0 {
            return "Your chart will fill in as you finish focus sessions."
        }

        return "\(focusDurationText(totalFocusSeconds)) focused across \(activeDayCount) \(activeDayCount == 1 ? "day" : "days")."
    }

    func tagUsageSectionSubtitle(points: [TagUsageChartPoint], periodDescription: String) -> String {
        let completionTotal = points.reduce(0) { $0 + $1.completionCount }
        if completionTotal > 0 {
            return "Bubbles scale by completions for matching tags in \(periodDescription.lowercased())."
        }
        if !points.isEmpty {
            return "No completions yet, so bubbles scale by matching routines per tag."
        }
        return "Complete tagged routines to see which themes are getting the most attention."
    }

    func tagUsageValueText(for point: TagUsageChartPoint) -> String {
        if point.completionCount > 0 {
            return point.completionCount == 1 ? "1 done" : "\(point.completionCount) done"
        }
        return point.linkedRoutineCount == 1 ? "1 routine" : "\(point.linkedRoutineCount) routines"
    }

    func tagUsageColumnCount(for count: Int) -> Int {
        min(isCompact ? 3 : 4, max(count, 1))
    }

    func tagUsageColumn(for index: Int, columns: Int) -> Double {
        Double(index % columns)
    }

    func tagUsageRow(for index: Int, columns: Int, rows: Int) -> Double {
        Double(rows - 1 - (index / columns))
    }

    func tagUsageSymbolSize(for point: TagUsageChartPoint, maxValue: Int) -> CGFloat {
        let normalized = sqrt(Double(point.bubbleValue) / Double(max(maxValue, 1)))
        return 1_900 + CGFloat(normalized) * 5_900
    }

    func tagUsageLabelWidth(for point: TagUsageChartPoint, maxValue: Int) -> CGFloat {
        let normalized = sqrt(Double(point.bubbleValue) / Double(max(maxValue, 1)))
        return 58 + CGFloat(normalized) * 36
    }

    func tagUsageChartHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * 118 + 18
    }

    func xAxisLabel(for date: Date) -> String {
        switch selectedRange {
        case .today, .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.day())
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    func bestDayCaption(for point: DoneChartPoint) -> String {
        point.date.formatted(.dateTime.month(.abbreviated).day())
    }
}
