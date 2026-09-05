import SwiftUI

enum StatsFocusChartGrouping: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: Self { self }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }

    var sectionTitle: String {
        "Focus time per \(title.lowercased())"
    }

    var peakBadgeTitle: String {
        "Peak \(title.lowercased())"
    }

    var unitName: String {
        title.lowercased()
    }

    var systemImage: String {
        switch self {
        case .day:
            return "calendar"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar.circle"
        }
    }

    var axisValueName: String {
        switch self {
        case .day:
            return "Date"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }

    var chartUnit: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        }
    }

    func points(
        from dailyPoints: [FocusDurationChartPoint],
        calendar: Calendar
    ) -> [FocusDurationChartPoint] {
        switch self {
        case .day:
            return dailyPoints
        case .week:
            return FocusDurationStats.groupedPoints(
                from: dailyPoints,
                by: .weekOfYear,
                calendar: calendar
            )
        case .month:
            return FocusDurationStats.groupedPoints(
                from: dailyPoints,
                by: .month,
                calendar: calendar
            )
        }
    }

    func usesHorizontalScroll(
        pointCount: Int,
        chartPresentation: StatsChartPresentation
    ) -> Bool {
        switch self {
        case .day:
            return chartPresentation.usesHorizontalChartScroll
        case .week:
            return pointCount > (chartPresentation.isCompact ? 8 : 18)
        case .month:
            return pointCount > (chartPresentation.isCompact ? 6 : 12)
        }
    }

    func chartMinWidth(
        pointCount: Int,
        chartPresentation: StatsChartPresentation
    ) -> CGFloat {
        switch self {
        case .day:
            return chartPresentation.chartMinWidth
        case .week:
            return max(chartPresentation.isCompact ? 420 : 640, CGFloat(max(pointCount, 1)) * 48)
        case .month:
            return max(chartPresentation.isCompact ? 420 : 560, CGFloat(max(pointCount, 1)) * 72)
        }
    }

    func xAxisDates(
        from points: [FocusDurationChartPoint],
        chartPresentation: StatsChartPresentation
    ) -> [Date] {
        switch self {
        case .day:
            return chartPresentation.focusDayXAxisDates(from: points.map(\.date))
        case .week:
            return sampledDates(from: points, targetCount: chartPresentation.isCompact ? 8 : 14)
        case .month:
            return sampledDates(from: points, targetCount: 12)
        }
    }

    func axisLabel(
        for date: Date,
        labeledDates: [Date],
        chartPresentation: StatsChartPresentation,
        calendar: Calendar
    ) -> String {
        switch self {
        case .day:
            return chartPresentation.focusDayXAxisLabel(
                for: date,
                in: labeledDates,
                calendar: calendar
            )
        case .week:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .month:
            let includeYear = chartPresentation.selectedRange == .year
            return includeYear
                ? date.formatted(.dateTime.month(.abbreviated).year())
                : date.formatted(.dateTime.month(.abbreviated))
        }
    }

    func detailTitle(for date: Date, calendar: Calendar) -> String {
        switch self {
        case .day:
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .week:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: date),
                let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end)
            else {
                return date.formatted(.dateTime.month(.abbreviated).day())
            }
            return
                "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) - \(endDate.formatted(.dateTime.month(.abbreviated).day()))"
        case .month:
            return date.formatted(.dateTime.month(.wide).year())
        }
    }

    private func sampledDates(
        from points: [FocusDurationChartPoint],
        targetCount: Int
    ) -> [Date] {
        let activePoints = points.filter { $0.seconds > 0 }
        let labelPoints = activePoints.isEmpty ? points : activePoints
        guard labelPoints.count > targetCount, targetCount > 1 else {
            return labelPoints.map(\.date)
        }

        let step = Double(labelPoints.count - 1) / Double(targetCount - 1)
        return (0..<targetCount).map { index in
            let pointIndex = min(Int((Double(index) * step).rounded()), labelPoints.count - 1)
            return labelPoints[pointIndex].date
        }
    }
}
