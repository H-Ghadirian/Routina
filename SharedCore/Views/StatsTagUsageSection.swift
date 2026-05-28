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

    private var bubbleGridColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 124, maximum: 164),
                spacing: 12,
                alignment: .center
            )
        ]
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
                LazyVGrid(columns: bubbleGridColumns, alignment: .center, spacing: 12) {
                    ForEach(points) { point in
                        tagBubble(for: point)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .statsChartPlotBackground(colorScheme: colorScheme)
                .accessibilityLabel("Tag usage bubble chart")
            }
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private func tagBubble(for point: TagUsageChartPoint) -> some View {
        let diameter = chartPresentation.tagUsageBubbleDiameter(for: point, maxValue: maxValue)

        return ZStack {
            Circle()
                .fill(tagUsageBubbleColor(for: point))
                .frame(width: diameter, height: diameter)
                .shadow(color: tagUsageBubbleColor(for: point).opacity(0.22), radius: 8, y: 4)

            VStack(spacing: 2) {
                Text("#\(point.name)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(chartPresentation.tagUsageValueText(for: point))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .minimumScaleFactor(0.72)
            .frame(width: chartPresentation.tagUsageLabelWidth(for: point, maxValue: maxValue))
            .shadow(color: .black.opacity(0.22), radius: 1, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity, minHeight: 124)
    }

    private func tagUsageBubbleColor(for point: TagUsageChartPoint) -> Color {
        Color(routineTagHex: point.colorHex)
            ?? Color.accentColor.opacity(colorScheme == .dark ? 0.78 : 0.68)
    }
}
