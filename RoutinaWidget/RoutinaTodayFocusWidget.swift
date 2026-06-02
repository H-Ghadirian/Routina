#if os(macOS)
import SwiftUI
import WidgetKit

struct RoutinaTodayFocusWidget: Widget {
    static let kind = "RoutinaTodayFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RoutinaStatsProvider()) { entry in
            RoutinaTodayFocusWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Today Focus")
        .description("Shows today's total Routina focus time.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct RoutinaTodayFocusWidgetView: View {
    let entry: StatsEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        default:
            mediumLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 0)
            focusDurationText(size: 34, weight: .bold)
            Text(TodayFocusWidgetFormatting.sessionText(entry.stats.focusSessionsToday))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if entry.stats.hasActiveFocusToday {
                livePill
            }
        }
        .padding(12)
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Spacer(minLength: 0)
                focusDurationText(size: 38, weight: .bold)
                Text("Focused today")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                metricRow(
                    icon: "number",
                    title: "Sessions",
                    value: "\(entry.stats.focusSessionsToday)"
                )
                metricRow(
                    icon: "clock",
                    title: "Updated",
                    value: TodayFocusWidgetFormatting.timeText(entry.stats.lastUpdated)
                )
                if entry.stats.hasActiveFocusToday {
                    livePill
                }
            }
            .frame(width: 112, alignment: .leading)
        }
        .padding(14)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.teal)
            Text("Routina")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func focusDurationText(size: CGFloat, weight: Font.Weight) -> some View {
        if entry.stats.hasActiveFocusToday {
            TimelineView(.periodic(from: entry.date, by: 60)) { context in
                durationText(at: context.date, size: size, weight: weight)
            }
        } else {
            durationText(at: entry.date, size: size, weight: weight)
        }
    }

    private func durationText(at date: Date, size: CGFloat, weight: Font.Weight) -> some View {
        Text(TodayFocusWidgetFormatting.durationText(seconds: entry.stats.focusSecondsToday(at: date)))
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.58)
    }

    private func metricRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.teal)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }

    private var livePill: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(.green)
            Text("Live")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 7)
        .background(.green.opacity(0.1), in: Capsule())
    }
}

private enum TodayFocusWidgetFormatting {
    static func durationText(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        guard totalMinutes >= 60 else {
            return "\(totalMinutes)m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    static func sessionText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "session" : "sessions")"
    }

    static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

#Preview(as: .systemSmall) {
    RoutinaTodayFocusWidget()
} timeline: {
    StatsEntry(
        date: .now,
        stats: WidgetStats(
            tasksDueToday: 6,
            completedToday: 3,
            completedThisWeek: 17,
            totalCompleted: 820,
            currentStreak: 9,
            focusSecondsToday: 7_860,
            focusSessionsToday: 4,
            activeFocusIncrementStartedAt: Date(),
            lastUpdated: Date()
        )
    )
}

#Preview(as: .systemMedium) {
    RoutinaTodayFocusWidget()
} timeline: {
    StatsEntry(
        date: .now,
        stats: WidgetStats(
            tasksDueToday: 6,
            completedToday: 3,
            completedThisWeek: 17,
            totalCompleted: 820,
            currentStreak: 9,
            focusSecondsToday: 7_860,
            focusSessionsToday: 4,
            activeFocusIncrementStartedAt: Date(),
            lastUpdated: Date()
        )
    )
}
#endif
