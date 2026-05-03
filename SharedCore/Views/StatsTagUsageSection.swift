import Charts
import Foundation
import SwiftUI

struct StatsTagUsageSection: View {
    let points: [TagUsageChartPoint]
    let subtitle: String
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    private var maxValue: Int {
        max(points.map(\.bubbleValue).max() ?? 1, 1)
    }

    private var columns: Int {
        chartPresentation.tagUsageColumnCount(for: points.count)
    }

    private var rows: Int {
        max(Int(ceil(Double(max(points.count, 1)) / Double(columns))), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Tag usage",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Tags",
                    value: points.count.formatted(),
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            if points.isEmpty {
                StatsEmptyChartStateView(
                    systemImage: "tag",
                    message: "Tags will appear here after matching routines are completed.",
                    colorScheme: colorScheme
                )
            } else {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        PointMark(
                            x: .value("Column", chartPresentation.tagUsageColumn(for: index, columns: columns)),
                            y: .value("Row", chartPresentation.tagUsageRow(for: index, columns: columns, rows: rows))
                        )
                        .symbolSize(chartPresentation.tagUsageSymbolSize(for: point, maxValue: maxValue))
                        .foregroundStyle(tagUsageBubbleColor(for: point))
                        .annotation(position: .overlay) {
                            VStack(spacing: 2) {
                                Text("#\(point.name)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)

                                Text(chartPresentation.tagUsageValueText(for: point))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                            .minimumScaleFactor(0.72)
                            .frame(width: chartPresentation.tagUsageLabelWidth(for: point, maxValue: maxValue))
                            .shadow(color: .black.opacity(0.22), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                .chartXScale(domain: (-0.5)...(Double(columns) - 0.5))
                .chartYScale(domain: (-0.5)...(Double(rows) - 0.5))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { plotArea in
                    plotArea.statsChartPlotBackground(colorScheme: colorScheme)
                }
                .frame(minHeight: chartPresentation.tagUsageChartHeight(rows: rows))
                .accessibilityLabel("Tag usage bubble chart")
            }
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private func tagUsageBubbleColor(for point: TagUsageChartPoint) -> Color {
        Color(routineTagHex: point.colorHex)
            ?? Color.accentColor.opacity(colorScheme == .dark ? 0.78 : 0.68)
    }
}
