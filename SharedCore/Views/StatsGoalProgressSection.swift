import SwiftUI

struct StatsGoalProgressSection: View {
    let points: [GoalProgressChartPoint]
    let selectedRange: DoneChartRange
    let chartPresentation: StatsChartPresentation
    let surfaceGradient: LinearGradient
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StatsSectionHeader(
                title: "Goal momentum",
                subtitle: subtitle
            ) {
                StatsSmallHighlightBadge(
                    title: "Top focus",
                    value: chartPresentation.focusDurationText(topFocusPoint?.focusSeconds ?? 0),
                    colorScheme: colorScheme,
                    surfaceGradient: surfaceGradient
                )
            }

            if points.isEmpty {
                StatsEmptyChartStateView(
                    systemImage: "target",
                    message: "Link tasks to active goals to see completed work and focus time by goal.",
                    colorScheme: colorScheme
                )
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(points) { point in
                        goalRow(point)

                        if point.id != points.last?.id {
                            Divider()
                                .opacity(colorScheme == .dark ? 0.22 : 0.34)
                        }
                    }
                }
                .padding(.top, 2)
            }

            StatsChartInsightRow(
                insights: insights,
                colorScheme: colorScheme
            )
        }
        .statsChartCard(surfaceGradient: surfaceGradient, colorScheme: colorScheme)
    }

    private var topFocusPoint: GoalProgressChartPoint? {
        points.max { lhs, rhs in
            if lhs.focusSeconds == rhs.focusSeconds {
                return lhs.completionCount < rhs.completionCount
            }
            return lhs.focusSeconds < rhs.focusSeconds
        }
    }

    private var subtitle: String {
        if points.isEmpty {
            return "Goal-linked work will appear here when matching tasks are active."
        }

        let goalWord = points.count == 1 ? "goal" : "goals"
        return "\(points.count) active \(goalWord) with linked tasks in \(selectedRange.periodDescription.lowercased())."
    }

    private var insights: [StatsChartInsight] {
        [
            StatsChartInsight(
                systemImage: "checkmark.circle",
                text: "\(points.reduce(0) { $0 + $1.completionCount }) done across linked goals"
            ),
            topFocusPoint.map {
                StatsChartInsight(
                    systemImage: "timer",
                    text: "Most focused: \($0.title) with \(chartPresentation.focusDurationText($0.focusSeconds))"
                )
            } ?? StatsChartInsight(
                systemImage: "target",
                text: "Waiting for focus on goal-linked tasks"
            )
        ]
    }

    private func goalRow(_ point: GoalProgressChartPoint) -> some View {
        let accent = point.color.swiftUIColor ?? Color.accentColor

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(point.emoji)
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(accent.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(point.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        if let targetText = targetText(for: point) {
                            Text(targetText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Text(rowCaption(for: point))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(chartPresentation.focusDurationText(point.focusSeconds))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accent.opacity(colorScheme == .dark ? 0.18 : 0.10), in: Capsule())
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.12))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(colorScheme == .dark ? 0.85 : 0.72),
                                    Color.green.opacity(colorScheme == .dark ? 0.78 : 0.62)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth(for: point, totalWidth: proxy.size.width))
                }
            }
            .frame(height: 9)
            .accessibilityLabel("\(point.title) goal progress")
            .accessibilityValue(rowCaption(for: point))
        }
    }

    private func rowCaption(for point: GoalProgressChartPoint) -> String {
        let completedTasks = point.completedTaskCount == 1 ? "1 linked task" : "\(point.completedTaskCount) linked tasks"
        let totalTasks = point.linkedTaskCount == 1 ? "1 total" : "\(point.linkedTaskCount) total"
        let done = point.completionCount == 1 ? "1 done" : "\(point.completionCount) done"
        return "\(completedTasks) completed of \(totalTasks) • \(done)"
    }

    private func targetText(for point: GoalProgressChartPoint) -> String? {
        point.targetDate.map { "by \($0.formatted(.dateTime.month(.abbreviated).day()))" }
    }

    private func progressWidth(for point: GoalProgressChartPoint, totalWidth: CGFloat) -> CGFloat {
        guard point.completionRatio > 0 else { return 0 }
        return max(5, totalWidth * CGFloat(point.completionRatio))
    }
}
