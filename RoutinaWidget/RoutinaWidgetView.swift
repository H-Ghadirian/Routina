import SwiftUI
import WidgetKit

struct RoutinaWidgetView: View {
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

    // MARK: - Small (2×2 grid)

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                StatTile(value: entry.stats.tasksDueToday, label: "Due Today", icon: "checklist", color: .orange)
                StatTile(value: entry.stats.completedToday, label: "Done Today", icon: "checkmark.circle.fill", color: .green)
                StatTile(value: entry.stats.completedThisWeek, label: "This Week", icon: "calendar.badge.checkmark", color: .blue)
                StatTile(value: entry.stats.currentStreak, label: "Streak", icon: "flame.fill", color: .red)
            }
        }
        .padding(10)
    }

    // MARK: - Medium (horizontal row)

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(spacing: 0) {
                StatColumn(value: entry.stats.tasksDueToday, label: "Due Today", icon: "checklist", color: .orange)
                StatColumn(value: entry.stats.completedToday, label: "Done Today", icon: "checkmark.circle.fill", color: .green)
                StatColumn(value: entry.stats.completedThisWeek, label: "This Week", icon: "calendar.badge.checkmark", color: .blue)
                StatColumn(value: entry.stats.totalCompleted, label: "Total", icon: "trophy.fill", color: .purple)
                StatColumn(value: entry.stats.currentStreak, label: "Streak", icon: "flame.fill", color: .red)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Routina")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Subviews

private struct StatTile: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(5)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct StatColumn: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    RoutinaStatsWidget()
} timeline: {
    StatsEntry(
        date: .now, stats: WidgetStats(tasksDueToday: 83, completedToday: 2, completedThisWeek: 42, totalCompleted: 1240, currentStreak: 36, lastUpdated: Date())
    )
}

#Preview(as: .systemSmall) {
    RoutinaStatsWidget()
} timeline: {
    StatsEntry(
        date: .now, stats: WidgetStats(tasksDueToday: 83, completedToday: 2, completedThisWeek: 42, totalCompleted: 1240, currentStreak: 36, lastUpdated: Date())
    )
}
