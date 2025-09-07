import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(\.calendar) private var calendar
    @Query private var logs: [RoutineLog]

    @State private var selectedRange: DoneChartRange = .week

    private var completionDates: [Date] {
        logs.compactMap(\.timestamp)
    }

    private var chartPoints: [DoneChartPoint] {
        RoutineCompletionStats.points(
            for: selectedRange,
            timestamps: completionDates,
            referenceDate: Date(),
            calendar: calendar
        )
    }

    private var totalCount: Int {
        RoutineCompletionStats.totalCount(in: chartPoints)
    }

    private var averagePerDay: Double {
        RoutineCompletionStats.averageCount(in: chartPoints)
    }

    private var busiestDay: DoneChartPoint? {
        RoutineCompletionStats.busiestDay(in: chartPoints)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(DoneChartRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    summaryCards

                    chartSection
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            summaryCard(
                title: "Total dones",
                value: "\(totalCount)",
                caption: selectedRange.periodDescription
            )

            summaryCard(
                title: "Average / day",
                value: averagePerDay.formatted(.number.precision(.fractionLength(1))),
                caption: "Across \(chartPoints.count) days"
            )

            summaryCard(
                title: "Best day",
                value: busiestDay.map { "\($0.count)" } ?? "0",
                caption: busiestDay.map(bestDayCaption(for:)) ?? "No completions yet"
            )

            summaryCard(
                title: "Tracked logs",
                value: "\(completionDates.count)",
                caption: "All-time completion history"
            )
        }
    }

    private var chartSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dones per day")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(chartPoints) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Dones", point.count)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: xAxisDates) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(xAxisLabel(for: date))
                                }
                            }
                        }
                    }
                    .frame(
                        minWidth: chartMinWidth,
                        minHeight: 240
                    )
                    .padding(.top, 4)
                }

                Text(selectedRange.periodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryCard(title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var chartMinWidth: CGFloat {
        switch selectedRange {
        case .week:
            return 360
        case .month:
            return 720
        case .year:
            return 3200
        }
    }

    private var xAxisDates: [Date] {
        switch selectedRange {
        case .week:
            return chartPoints.map(\.date)

        case .month:
            return chartPoints.enumerated().compactMap { index, point in
                if index == 0 || index == chartPoints.count - 1 || index.isMultiple(of: 5) {
                    return point.date
                }
                return nil
            }

        case .year:
            let firstDate = chartPoints.first?.date
            let lastDate = chartPoints.last?.date

            return chartPoints.compactMap { point in
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
        case .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.day())
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private func bestDayCaption(for point: DoneChartPoint) -> String {
        point.date.formatted(.dateTime.month(.abbreviated).day())
    }
}
