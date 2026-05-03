import SwiftUI

struct StatsHeroSectionView: View {
    let selectedRange: DoneChartRange
    let totalCount: Int
    let activeDayCount: Int
    let averagePerDay: Double
    let highlightedBusiestDay: DoneChartPoint?
    let sparklinePoints: [DoneChartPoint]
    let sparklineMaxCount: Int
    let periodDescription: String
    let chartPresentation: StatsChartPresentation
    let colorScheme: ColorScheme
    let heroGradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if selectedRange != .today {
                sparklinePreview
                metricPills
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

    private var header: some View {
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

                Text(periodDescription)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 0)

            if selectedRange != .today {
                activeDayBadge
            }
        }
    }

    private var activeDayBadge: some View {
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
        .background(
            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private var sparklinePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily rhythm")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                Text(chartPresentation.sparklineCaption(highlightedBusiestDay: highlightedBusiestDay))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(sparklinePoints) { point in
                    Capsule(style: .continuous)
                        .fill(chartPresentation.sparklineColor(for: point, highlightedBusiestDay: highlightedBusiestDay))
                        .frame(maxWidth: .infinity)
                        .frame(height: chartPresentation.sparklineBarHeight(for: point, maxCount: sparklineMaxCount))
                }
            }
            .frame(height: 74, alignment: .bottom)
        }
    }

    private var metricPills: some View {
        HStack(spacing: 12) {
            heroStatPill(
                icon: "gauge.with.dots.needle.50percent",
                title: "Daily avg",
                value: chartPresentation.averagePerDayText(for: averagePerDay)
            )

            heroStatPill(
                icon: "bolt.fill",
                title: "Best day",
                value: highlightedBusiestDay.map { "\($0.count)" } ?? "0"
            )
        }
    }

    private var rangeHeroLabel: String {
        switch selectedRange {
        case .today:
            return "Today"
        case .week:
            return "This week"
        case .month:
            return "This month"
        case .year:
            return "This year"
        }
    }

    private func heroStatPill(icon: String, title: String, value: String) -> some View {
        StatsHeroStatPill(icon: icon, title: title, value: value, colorScheme: colorScheme)
    }
}
