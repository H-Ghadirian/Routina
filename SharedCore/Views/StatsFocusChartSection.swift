import Charts
import SwiftUI

struct StatsFocusChartSection: View {
    @Environment(\.calendar) private var calendar

    let subtitle: String
    let peakValue: String
    let focusChartPoints: [FocusDurationChartPoint]
    let focusWeekdayAveragePoints: [FocusWeekdayAverageChartPoint]
    let highlightedFocusDay: FocusDurationChartPoint?
    let highlightedFocusWeekdayAverage: FocusWeekdayAverageChartPoint?
    let averageFocusSecondsPerDay: TimeInterval
    let focusChartUpperBound: Double
    let focusWeekdayAverageUpperBound: Double
    let xAxisDates: [Date]
    let chartPresentation: StatsChartPresentation
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme
    let insights: [StatsChartInsight]

    @State private var selectedGrouping: StatsFocusChartGrouping = .day
    @State private var selectedFocusPointID: Date?

    var body: some View {
        let displayPoints = selectedGrouping.points(from: focusChartPoints, calendar: calendar)
        let cumulativePoints = FocusDurationStats.cumulativePoints(from: focusChartPoints)
        let selectedPoint = selectedPoint(in: displayPoints)
        let peakPoint = FocusDurationStats.busiestDay(in: displayPoints)
        let focusBarXAxisDates = selectedGrouping.xAxisDates(from: displayPoints, chartPresentation: chartPresentation)
        let focusBarXAxisDateSet = Set(focusBarXAxisDates)
        let averageSeconds = averageSeconds(in: displayPoints)
        let focusAxisUpperBound = StatsChartTimeAxis.upperBound(for: displayUpperBound(in: displayPoints, averageSeconds: averageSeconds))
        let usesHorizontalScroll = selectedGrouping.usesHorizontalScroll(
            pointCount: displayPoints.count,
            chartPresentation: chartPresentation
        )
        let focusYAxisPosition: AxisMarkPosition = usesHorizontalScroll ? .trailing : .leading

        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: selectedGrouping.sectionTitle,
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: selectedGrouping.peakBadgeTitle,
                    value: peakPoint.map { chartPresentation.focusDurationText($0.seconds) } ?? peakValue,
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            Picker("Focus chart period", selection: $selectedGrouping) {
                ForEach(StatsFocusChartGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .accessibilityIdentifier("stats.focus.groupingPicker")

            StatsFocusChartContainer(
                usesHorizontalScroll: usesHorizontalScroll,
                minWidth: selectedGrouping.chartMinWidth(
                    pointCount: displayPoints.count,
                    chartPresentation: chartPresentation
                ),
                minHeight: 240
            ) {
                Chart {
                    ForEach(displayPoints) { point in
                        let isSelected = point.date == selectedPoint?.date
                        let isHighlighted = point.date == peakPoint?.date

                        BarMark(
                            x: .value(selectedGrouping.axisValueName, point.date, unit: selectedGrouping.chartUnit),
                            y: .value("Minutes", point.minutes)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isSelected || isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
                        )
                        .opacity(point.seconds == 0 ? 0.28 : 1)
                        .accessibilityLabel(selectedGrouping.detailTitle(for: point.date, calendar: calendar))
                        .accessibilityValue(accessibilityValue(for: point))
                    }

                    if averageSeconds > 0 {
                        RuleMark(y: .value("Average", averageSeconds / 60))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(chartPresentation.focusDurationText(averageSeconds))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(surfaceGradient, in: Capsule(style: .continuous))
                            }
                    }

                    if let selectedPoint {
                        RuleMark(
                            x: .value(
                                "Selected \(selectedGrouping.title)",
                                selectedPoint.date,
                                unit: selectedGrouping.chartUnit
                            )
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                        .foregroundStyle(Color.white.opacity(0.48))
                        .annotation(position: .top, alignment: .center, spacing: 8) {
                            StatsFocusPointDetailPopover(
                                point: selectedPoint,
                                grouping: selectedGrouping,
                                chartPresentation: chartPresentation,
                                calendar: calendar,
                                colorScheme: colorScheme
                            )
                        }
                    }
                }
                .chartYScale(domain: 0...focusAxisUpperBound)
                .chartYAxis {
                    AxisMarks(
                        position: focusYAxisPosition,
                        values: StatsChartTimeAxis.values(upperBound: focusAxisUpperBound)
                    ) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(StatsChartTimeAxis.label(for: minutes))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    if selectedGrouping == .day {
                        AxisMarks(values: xAxisDates) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                                .foregroundStyle(Color.secondary.opacity(0.12))
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self),
                                   !focusBarXAxisDateSet.contains(date) {
                                    Text(chartPresentation.xAxisLabel(for: date))
                                }
                            }
                        }
                    }
                    AxisMarks(values: focusBarXAxisDates) { value in
                        AxisTick()
                            .foregroundStyle(Color.secondary.opacity(0.35))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(selectedGrouping.axisLabel(for: date, chartPresentation: chartPresentation, calendar: calendar))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.75))
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
                .chartYAxisLabel("Focus time")
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelectedPoint(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry,
                                            points: displayPoints
                                        )
                                    }
                            )
                        #if os(macOS)
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    updateSelectedPoint(
                                        at: location,
                                        proxy: proxy,
                                        geometry: geometry,
                                        points: displayPoints
                                    )
                                case .ended:
                                    selectedFocusPointID = nil
                                }
                            }
                        #endif
                    }
                }
            }

            StatsFocusCumulativeChart(
                points: cumulativePoints,
                chartPresentation: chartPresentation,
                surfaceGradient: surfaceGradient,
                colorScheme: colorScheme
            )

            if chartPresentation.showsFocusWeekdayAverages {
                StatsFocusWeekdayAverageChart(
                    points: focusWeekdayAveragePoints,
                    highlightedPoint: highlightedFocusWeekdayAverage,
                    upperBound: focusWeekdayAverageUpperBound,
                    chartPresentation: chartPresentation,
                    highlightBarFill: highlightBarFill,
                    surfaceGradient: surfaceGradient,
                    colorScheme: colorScheme
                )
            }

            StatsChartInsightRow(
                insights: visibleInsights(in: displayPoints, peakPoint: peakPoint),
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
        .onChange(of: selectedGrouping) { _, _ in
            selectedFocusPointID = nil
        }
    }

    private func selectedPoint(in points: [FocusDurationChartPoint]) -> FocusDurationChartPoint? {
        guard let selectedFocusPointID else { return nil }
        return points.first { $0.date == selectedFocusPointID }
    }

    private func averageSeconds(in points: [FocusDurationChartPoint]) -> TimeInterval {
        guard !points.isEmpty else { return 0 }
        return FocusDurationStats.totalSeconds(in: points) / Double(points.count)
    }

    private func displayUpperBound(
        in points: [FocusDurationChartPoint],
        averageSeconds: TimeInterval
    ) -> Double {
        let maxDisplayMinutes = points.map(\.minutes).max() ?? 0
        return max(10, ceil(max(maxDisplayMinutes, averageSeconds / 60)) + 5)
    }

    private func accessibilityValue(for point: FocusDurationChartPoint) -> String {
        var value = FocusSessionFormatting.durationText(seconds: point.seconds)
        let contributionSummary = point.contributions.prefix(3).map {
            "\($0.title) \(FocusSessionFormatting.durationText(seconds: $0.seconds))"
        }.joined(separator: ", ")
        if !contributionSummary.isEmpty {
            value += ". \(contributionSummary)"
        }
        return value
    }

    private func visibleInsights(
        in points: [FocusDurationChartPoint],
        peakPoint: FocusDurationChartPoint?
    ) -> [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: selectedGrouping.systemImage,
                text: "\(insights.first?.text ?? chartPresentation.selectedRange.periodDescription) by \(selectedGrouping.title.lowercased())"
            ),
            peakPoint.map {
                StatsChartInsight(
                    systemImage: "timer",
                    text: "Best \(selectedGrouping.unitName): \(chartPresentation.focusDurationText($0.seconds))"
                )
            } ?? StatsChartInsight(
                systemImage: "stopwatch",
                text: "Waiting for your first focus session"
            )
        ]
    }

    private func updateSelectedPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        points: [FocusDurationChartPoint]
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedFocusPointID = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            selectedFocusPointID = nil
            return
        }

        let xPosition = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
              let nearestPoint = nearestPoint(to: date, in: points) else {
            selectedFocusPointID = nil
            return
        }

        selectedFocusPointID = nearestPoint.date
    }

    private func nearestPoint(
        to date: Date,
        in points: [FocusDurationChartPoint]
    ) -> FocusDurationChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }
}

private enum StatsFocusChartGrouping: String, CaseIterable, Identifiable {
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
            return chartPresentation.focusBarXAxisDates(from: points)
        case .week:
            return sampledDates(from: points, targetCount: chartPresentation.isCompact ? 8 : 14)
        case .month:
            return sampledDates(from: points, targetCount: 12)
        }
    }

    func axisLabel(
        for date: Date,
        chartPresentation: StatsChartPresentation,
        calendar: Calendar
    ) -> String {
        switch self {
        case .day:
            return chartPresentation.focusBarXAxisLabel(for: date)
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
                  let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
                return date.formatted(.dateTime.month(.abbreviated).day())
            }
            return "\(interval.start.formatted(.dateTime.month(.abbreviated).day())) - \(endDate.formatted(.dateTime.month(.abbreviated).day()))"
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

private struct StatsFocusChartContainer<Content: View>: View {
    let usesHorizontalScroll: Bool
    let minWidth: CGFloat
    let minHeight: CGFloat
    let content: () -> Content

    var body: some View {
        Group {
            if usesHorizontalScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    content()
                        .frame(minWidth: minWidth, minHeight: minHeight)
                        .padding(.top, 4)
                }
                .defaultScrollAnchor(.trailing)
            } else {
                content()
                    .frame(maxWidth: .infinity, minHeight: minHeight)
                    .padding(.top, 4)
            }
        }
    }
}

private struct StatsFocusPointDetailPopover: View {
    let point: FocusDurationChartPoint
    let grouping: StatsFocusChartGrouping
    let chartPresentation: StatsChartPresentation
    let calendar: Calendar
    let colorScheme: ColorScheme

    private var visibleContributions: [FocusDurationContribution] {
        Array(point.contributions.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 3) {
                Text(grouping.detailTitle(for: point.date, calendar: calendar))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(FocusSessionFormatting.durationText(seconds: point.seconds))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
            }

            if visibleContributions.isEmpty {
                Text("No task detail")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleContributions) { contribution in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(contribution.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text(FocusSessionFormatting.durationText(seconds: contribution.seconds))
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    let hiddenCount = point.contributions.count - visibleContributions.count
                    if hiddenCount > 0 {
                        Text("+ \(hiddenCount) more")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(width: 230, alignment: .leading)
        .padding(12)
        .routinaGlassCard(cornerRadius: 16, tint: .accentColor, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 8)
    }
}

private struct StatsFocusCumulativeChart: View {
    @State private var selectedPointID: Date?

    let points: [FocusCumulativeChartPoint]
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    private var selectedPoint: FocusCumulativeChartPoint? {
        guard let selectedPointID else { return nil }
        return points.first { $0.date == selectedPointID }
    }

    private var totalSeconds: TimeInterval {
        points.last?.cumulativeSeconds ?? 0
    }

    private var axisUpperBound: Double {
        let maxMinutes = points.map(\.cumulativeMinutes).max() ?? 0
        return StatsChartTimeAxis.upperBound(for: max(10, maxMinutes + 5))
    }

    private var xAxisDates: [Date] {
        let activePoints = points.filter { $0.dailySeconds > 0 }
        let labelPoints = activePoints.isEmpty ? points : activePoints
        let targetCount: Int

        switch chartPresentation.selectedRange {
        case .today:
            targetCount = 1
        case .week:
            targetCount = 7
        case .month:
            targetCount = 10
        case .year:
            targetCount = 18
        }

        guard labelPoints.count > targetCount, targetCount > 1 else {
            return labelPoints.map(\.date)
        }

        let step = Double(labelPoints.count - 1) / Double(targetCount - 1)
        return (0..<targetCount).map { index in
            let pointIndex = min(Int((Double(index) * step).rounded()), labelPoints.count - 1)
            return labelPoints[pointIndex].date
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Cumulative focus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                StatsSmallHighlightBadge(
                    title: "Total",
                    value: chartPresentation.focusDurationText(totalSeconds),
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            StatsFocusChartContainer(
                usesHorizontalScroll: chartPresentation.usesHorizontalChartScroll,
                minWidth: chartPresentation.chartMinWidth,
                minHeight: 190
            ) {
                Chart {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Cumulative minutes", point.cumulativeMinutes)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(cumulativeAreaFill)

                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Cumulative minutes", point.cumulativeMinutes)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Color.teal.opacity(colorScheme == .dark ? 0.92 : 0.78))
                        .accessibilityLabel(point.date.formatted(.dateTime.month(.abbreviated).day()))
                        .accessibilityValue(accessibilityValue(for: point))
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected day", selectedPoint.date, unit: .day))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(Color.white.opacity(0.48))
                            .annotation(position: .top, alignment: .center, spacing: 8) {
                                StatsFocusCumulativePointPopover(
                                    point: selectedPoint,
                                    colorScheme: colorScheme
                                )
                            }

                        PointMark(
                            x: .value("Selected day", selectedPoint.date, unit: .day),
                            y: .value("Cumulative minutes", selectedPoint.cumulativeMinutes)
                        )
                        .symbolSize(54)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 0...axisUpperBound)
                .chartYAxis {
                    AxisMarks(
                        position: chartPresentation.usesHorizontalChartScroll ? .trailing : .leading,
                        values: StatsChartTimeAxis.values(upperBound: axisUpperBound)
                    ) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(StatsChartTimeAxis.label(for: minutes))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: xAxisDates) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(chartPresentation.focusBarXAxisLabel(for: date))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxisLabel("Cumulative focus")
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelectedPoint(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry
                                        )
                                    }
                            )
                        #if os(macOS)
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    updateSelectedPoint(
                                        at: location,
                                        proxy: proxy,
                                        geometry: geometry
                                    )
                                case .ended:
                                    selectedPointID = nil
                                }
                            }
                        #endif
                    }
                }
            }
        }
        .padding(.top, 2)
    }

    private var cumulativeAreaFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.teal.opacity(colorScheme == .dark ? 0.26 : 0.18),
                Color.teal.opacity(0.02)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func accessibilityValue(for point: FocusCumulativeChartPoint) -> String {
        let total = FocusSessionFormatting.durationText(seconds: point.cumulativeSeconds)
        let daily = FocusSessionFormatting.durationText(seconds: point.dailySeconds)
        return "\(total) total, \(daily) that day"
    }

    private func updateSelectedPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else {
            selectedPointID = nil
            return
        }

        let frame = geometry[plotFrame]
        guard frame.contains(location) else {
            selectedPointID = nil
            return
        }

        let xPosition = location.x - frame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
              let nearestPoint = nearestPoint(to: date) else {
            selectedPointID = nil
            return
        }

        selectedPointID = nearestPoint.date
    }

    private func nearestPoint(to date: Date) -> FocusCumulativeChartPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }
}

private struct StatsFocusCumulativePointPopover: View {
    let point: FocusCumulativeChartPoint
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(point.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(FocusSessionFormatting.durationText(seconds: point.cumulativeSeconds))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)

            Text("Day: \(FocusSessionFormatting.durationText(seconds: point.dailySeconds))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 170, alignment: .leading)
        .padding(12)
        .routinaGlassCard(cornerRadius: 16, tint: .teal, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 12, y: 8)
    }
}

private struct StatsFocusWeekdayAverageChart: View {
    let points: [FocusWeekdayAverageChartPoint]
    let highlightedPoint: FocusWeekdayAverageChartPoint?
    let upperBound: Double
    let chartPresentation: StatsChartPresentation
    let highlightBarFill: LinearGradient
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        let averageAxisUpperBound = StatsChartTimeAxis.upperBound(for: upperBound)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Average by weekday")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if let highlightedPoint {
                    StatsSmallHighlightBadge(
                        title: "Top avg",
                        value: chartPresentation.focusDurationText(highlightedPoint.seconds),
                        colorScheme: colorScheme,
                        surfaceGradient: surfaceGradient
                    )
                }
            }

            Chart {
                ForEach(points) { point in
                    let isHighlighted = point.weekday == highlightedPoint?.weekday

                    BarMark(
                        x: .value("Weekday", point.shortSymbol),
                        y: .value("Average minutes", point.minutes)
                    )
                    .cornerRadius(7)
                    .foregroundStyle(
                        isHighlighted
                            ? AnyShapeStyle(highlightBarFill)
                            : AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
                    )
                    .opacity(point.seconds == 0 ? 0.35 : 1)
                    .accessibilityLabel(point.symbol)
                    .accessibilityValue(chartPresentation.focusDurationText(point.seconds))
                }
            }
            .frame(height: 170)
            .chartYScale(domain: 0...averageAxisUpperBound)
            .chartYAxis {
                AxisMarks(
                    position: .leading,
                    values: StatsChartTimeAxis.values(upperBound: averageAxisUpperBound)
                ) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            Text(StatsChartTimeAxis.label(for: minutes))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisTick()
                    AxisValueLabel {
                        if let weekday = value.as(String.self) {
                            Text(weekday)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.statsChartPlotBackground(colorScheme: colorScheme)
            }
            .chartYAxisLabel("Avg focus")
        }
        .padding(.top, 2)
    }
}
