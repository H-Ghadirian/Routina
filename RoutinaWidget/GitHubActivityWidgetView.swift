import SwiftUI
import WidgetKit

struct GitHubActivityWidgetView: View {
    let entry: GitHubActivityEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var cellSize: CGFloat { 4 }
    private var gap: CGFloat { 1 }

    private var displayedWeeks: [GitHubWidgetData.Week] {
        guard let weeks = entry.widgetData?.weeks else { return [] }
        return family == .systemMedium ? Array(weeks.suffix(26)) : weeks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerView
            gridView
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        if let data = entry.widgetData {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("@\(data.login)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(data.totalContributions) contributions")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("GitHub Activity")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var gridView: some View {
        if entry.widgetData != nil {
            HStack(alignment: .top, spacing: gap) {
                ForEach(Array(displayedWeeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: gap) {
                        ForEach(Array(week.days.enumerated()), id: \.offset) { _, day in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(cellColor(count: day.count))
                                .frame(width: cellSize, height: cellSize)
                        }
                        ForEach(0..<(7 - week.days.count), id: \.self) { _ in
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        } else {
            Text("Open Routina to load\nyour GitHub contribution graph.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Color

    private func cellColor(count: Int) -> Color {
        switch count {
        case 0:
            return colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.88)
        case 1...3:
            return Color(red: 0.40, green: 0.80, blue: 0.50)
        case 4...6:
            return Color(red: 0.20, green: 0.65, blue: 0.35)
        case 7...9:
            return Color(red: 0.10, green: 0.52, blue: 0.25)
        default:
            return Color(red: 0.05, green: 0.38, blue: 0.17)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    GitHubActivityWidget()
} timeline: {
    GitHubActivityEntry(date: .now, widgetData: nil)
}

#Preview(as: .systemLarge) {
    GitHubActivityWidget()
} timeline: {
    GitHubActivityEntry(date: .now, widgetData: nil)
}
