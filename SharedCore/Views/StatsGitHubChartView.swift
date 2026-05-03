import Charts
import Foundation
import SwiftUI

struct StatsGitHubChartView: View {
    let points: [DoneChartPoint]
    let averageCount: Double
    let busiestDay: DoneChartPoint?
    let yAxisLabel: String
    let averageLabel: String
    let selectedRange: DoneChartRange
    let colorScheme: ColorScheme
    let calendar: Calendar
    let yearMinWidth: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(points) { point in
                    let isHighlighted = point.date == busiestDay?.date

                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value(yAxisLabel, point.count)
                    )
                    .cornerRadius(7)
                    .foregroundStyle(
                        isHighlighted
                            ? AnyShapeStyle(highlightBarFill)
                            : AnyShapeStyle(baseBarFill)
                    )
                    .opacity(point.count == 0 ? 0.35 : 1)
                }

                if averageCount > 0 {
                    RuleMark(y: .value(averageLabel, averageCount))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .foregroundStyle(Color.secondary.opacity(0.65))
                }
            }
            .chartYScale(domain: 0...chartUpperBound)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: xAxisDates) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.12))
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04))
                    )
            }
            .frame(minWidth: chartMinWidth, minHeight: 220)
            .padding(.top, 4)
        }
        .defaultScrollAnchor(.trailing)
    }

    private var baseBarFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(colorScheme == .dark ? 0.75 : 0.6),
                Color.blue.opacity(colorScheme == .dark ? 0.55 : 0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var highlightBarFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.95),
                Color.yellow.opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var chartMinWidth: CGFloat {
        switch selectedRange {
        case .today:
            return 260
        case .week:
            return 340
        case .month:
            return 720
        case .year:
            return yearMinWidth
        }
    }

    private var chartUpperBound: Double {
        let maxCount = points.map(\.count).max() ?? 0
        return Double(max(maxCount, Int(ceil(averageCount))) + 1)
    }

    private var xAxisDates: [Date] {
        switch selectedRange {
        case .today, .week:
            return points.map(\.date)
        case .month:
            return points.enumerated().compactMap { index, point in
                if index == 0 || index == points.count - 1 || index.isMultiple(of: 5) {
                    return point.date
                }
                return nil
            }
        case .year:
            let firstDate = points.first?.date
            let lastDate = points.last?.date
            return points.compactMap { point in
                let day = calendar.component(.day, from: point.date)
                if point.date == firstDate || point.date == lastDate || day == 1 {
                    return point.date
                }
                return nil
            }
        }
    }

    private func xAxisLabel(for date: Date) -> String {
        switch selectedRange {
        case .today, .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.day())
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }
}

enum StatsGitHubChartPresentation {
    static func bestDayCaption(for point: DoneChartPoint) -> String {
        point.date.formatted(.dateTime.month(.abbreviated).day())
    }
}
