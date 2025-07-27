import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]

    @State private var selectedRange: DoneChartRange = .week

    private var completionDates: [Date] {
        logs.compactMap(\.timestamp)
    }

    private var totalDoneCount: Int {
        completionDates.count
    }

    private var activeRoutineCount: Int {
        tasks.filter { !$0.isPaused }.count
    }

    private var archivedRoutineCount: Int {
        tasks.filter(\.isPaused).count
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

    private var highlightedBusiestDay: DoneChartPoint? {
        guard let busiestDay, busiestDay.count > 0 else { return nil }
        return busiestDay
    }

    private var activeDayCount: Int {
        chartPoints.filter { $0.count > 0 }.count
    }

    private var averagePerDayText: String {
        averagePerDay.formatted(.number.precision(.fractionLength(1)))
    }

    private var chartSectionSubtitle: String {
        if totalCount == 0 {
            return "Your chart will fill in as you complete routines."
        }

        return "Average \(averagePerDayText) per day across \(chartPoints.count) days."
    }

    private var chartUpperBound: Double {
        let maxCount = chartPoints.map(\.count).max() ?? 0
        return Double(max(maxCount, Int(ceil(averagePerDay))) + 1)
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.04)
                ]
                : [
                    Color.white.opacity(0.98),
                    Color.white.opacity(0.88)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.accentColor.opacity(0.95),
                    Color.blue.opacity(0.7),
                    Color.black.opacity(0.92)
                ]
                : [
                    Color.accentColor.opacity(0.9),
                    Color.blue.opacity(0.6),
                    Color.white.opacity(0.96)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var pageBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.black,
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color.black
                ]
                : [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color.white,
                    Color(red: 0.93, green: 0.96, blue: 0.99)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.03)
                ]
                : [
                    Color.white.opacity(0.96),
                    Color.white.opacity(0.82)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorActiveFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.95),
                Color.blue.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    rangeSection
                    heroSection
                    summaryCards
                    chartSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, contentBottomPadding)
                .frame(maxWidth: statsContentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(pageBackground.ignoresSafeArea())
            .navigationTitle("Stats")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
        }
    }

    @ViewBuilder
    private var rangeSection: some View {
#if os(iOS)
        HStack(spacing: 10) {
            ForEach(DoneChartRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedRange = range
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(range.rawValue)
                            .font(.subheadline.weight(.semibold))

                        Text(rangeButtonSubtitle(for: range))
                            .font(.caption2.weight(.medium))
                            .opacity(selectedRange == range ? 0.9 : 0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selectedRange == range ? Color.white : Color.primary)
                    .background {
                        if selectedRange == range {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectorActiveFill)
                                .shadow(color: Color.accentColor.opacity(0.28), radius: 16, y: 8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(selectorBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
#else
        Picker("Time Range", selection: $selectedRange) {
            ForEach(DoneChartRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
#endif
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(rangeHeroLabel, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.62), in: Capsule())

                    Text(totalCount.formatted())
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(totalCount == 1 ? "completion logged" : "completions logged")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(selectedRange.periodDescription)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(activeDayCount)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(activeDayCount == 1 ? "active day" : "active days")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            sparklinePreview

            HStack(spacing: 12) {
                heroStatPill(
                    icon: "gauge.with.dots.needle.50percent",
                    title: "Daily avg",
                    value: averagePerDayText
                )

                heroStatPill(
                    icon: "bolt.fill",
                    title: "Best day",
                    value: highlightedBusiestDay.map { "\($0.count)" } ?? "0"
                )
            }
        }
        .padding(22)
        .background(heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.08), radius: 22, y: 14)
    }

    private var sparklinePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily rhythm")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                Text(sparklineCaption)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(sparklinePoints) { point in
                    Capsule(style: .continuous)
                        .fill(sparklineColor(for: point))
                        .frame(maxWidth: .infinity)
                        .frame(height: sparklineBarHeight(for: point))
                }
            }
            .frame(height: 74, alignment: .bottom)
        }
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: horizontalSizeClass == .compact ? 160 : 220,
                        maximum: 280
                    ),
                    spacing: 14
                )
            ],
            spacing: 14
        ) {
            summaryCard(
                icon: "gauge.with.dots.needle.50percent",
                accent: .mint,
                title: "Daily average",
                value: averagePerDayText,
                caption: "Across \(chartPoints.count) days"
            )

            summaryCard(
                icon: "bolt.fill",
                accent: .orange,
                title: "Best day",
                value: highlightedBusiestDay.map { "\($0.count)" } ?? "0",
                caption: highlightedBusiestDay.map(bestDayCaption(for:)) ?? "No peak day yet"
            )

            summaryCard(
                icon: "checkmark.seal.fill",
                accent: .blue,
                title: "Total dones",
                value: totalDoneCount.formatted(),
                caption: "All recorded completions"
            )

            summaryCard(
                icon: "checklist.checked",
                accent: .green,
                title: "Active routines",
                value: activeRoutineCount.formatted(),
                caption: activeRoutineCardCaption
            )

            summaryCard(
                icon: "archivebox.fill",
                accent: .teal,
                title: "Archived routines",
                value: archivedRoutineCount.formatted(),
                caption: archivedRoutineCardCaption
            )
        }
    }

    private var activeRoutineCardCaption: String {
        if tasks.isEmpty {
            return "No routines created yet"
        }

        if activeRoutineCount == 0 {
            return archivedRoutineCount == 1
                ? "Your only routine is paused"
                : "All routines are currently paused"
        }

        if archivedRoutineCount == 0 {
            return "Everything is currently in rotation"
        }

        return archivedRoutineCount == 1
            ? "1 paused routine excluded"
            : "\(archivedRoutineCount) paused routines excluded"
    }

    private var archivedRoutineCardCaption: String {
        if tasks.isEmpty {
            return "No routines created yet"
        }

        if archivedRoutineCount == 0 {
            return "No archived routines right now"
        }

        return archivedRoutineCount == 1
            ? "1 routine is paused and hidden from Home"
            : "\(archivedRoutineCount) routines are paused and hidden from Home"
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completions per day")
                        .font(.title3.weight(.semibold))

                    Text(chartSectionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                smallHighlightBadge(
                    title: "Peak",
                    value: highlightedBusiestDay.map { "\($0.count)" } ?? "0"
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(chartPoints) { point in
                        let isHighlighted = point.date == highlightedBusiestDay?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Completions", point.count)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(baseBarFill)
                        )
                        .opacity(point.count == 0 ? 0.35 : 1)
                    }

                    if averagePerDay > 0 {
                        RuleMark(y: .value("Average", averagePerDay))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(averagePerDayText)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        surfaceGradient,
                                        in: Capsule(style: .continuous)
                                    )
                            }
                    }

                    if let highlightedBusiestDay {
                        PointMark(
                            x: .value("Date", highlightedBusiestDay.date, unit: .day),
                            y: .value("Completions", highlightedBusiestDay.count)
                        )
                        .symbolSize(selectedRange == .year ? 46 : 64)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 0...chartUpperBound)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let count = value.as(Int.self) {
                                Text(count.formatted())
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
                .frame(minWidth: chartMinWidth, minHeight: 260)
                .padding(.top, 4)
            }

            HStack(spacing: 10) {
                bottomInsightPill(
                    icon: "calendar",
                    text: selectedRange.periodDescription
                )

                if let highlightedBusiestDay {
                    bottomInsightPill(
                        icon: "star.fill",
                        text: "Best: \(bestDayCaption(for: highlightedBusiestDay))"
                    )
                } else {
                    bottomInsightPill(
                        icon: "waveform.path.ecg",
                        text: "Waiting for your first completion"
                    )
                }
            }
        }
        .padding(20)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
    }

    private func heroStatPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryCard(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(colorScheme == .dark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(surfaceGradient)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.12))
                        .frame(width: 110, height: 110)
                        .blur(radius: 16)
                        .offset(x: 28, y: -32)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
    }

    private func smallHighlightBadge(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
        )
    }

    private func bottomInsightPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.04), in: Capsule(style: .continuous))
    }

    private var rangeHeroLabel: String {
        switch selectedRange {
        case .week:
            return "This week"
        case .month:
            return "This month"
        case .year:
            return "This year"
        }
    }

    private func rangeButtonSubtitle(for range: DoneChartRange) -> String {
        switch range {
        case .week:
            return "7 days"
        case .month:
            return "30 days"
        case .year:
            return "1 year"
        }
    }

    private var sparklinePoints: [DoneChartPoint] {
        let targetCount: Int

        switch selectedRange {
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

    private var sparklineCaption: String {
        guard let highlightedBusiestDay else {
            return "No peak yet"
        }

        return "Peak \(highlightedBusiestDay.count)"
    }

    private func sparklineColor(for point: DoneChartPoint) -> Color {
        if point.date == highlightedBusiestDay?.date {
            return Color.white.opacity(0.96)
        }

        return Color.white.opacity(point.count == 0 ? 0.12 : 0.3)
    }

    private func sparklineBarHeight(for point: DoneChartPoint) -> CGFloat {
        let maxCount = max(sparklinePoints.map(\.count).max() ?? 0, 1)
        let normalized = max(CGFloat(point.count) / CGFloat(maxCount), 0.12)
        return 16 + (normalized * 54)
    }

    private var chartMinWidth: CGFloat {
        switch selectedRange {
        case .week:
            return 340
        case .month:
            return 720
        case .year:
            return 2600
        }
    }

    private var statsContentMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 980 : nil
    }

    private var contentBottomPadding: CGFloat {
#if os(iOS)
        horizontalSizeClass == .compact ? 120 : 52
#else
        36
#endif
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
