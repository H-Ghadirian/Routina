import SwiftUI
import WidgetKit

struct GitHubActivityWidgetView: View {
    let entry: GitHubActivityEntry

    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    private var displayedWeeks: [GitHubWidgetData.Week] {
        guard let weeks = entry.widgetData?.weeks else { return [] }
        return weeks
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerView
            gridView
                .layoutPriority(1)
            footerView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        if let data = entry.widgetData {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("@\(data.login)")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
                Text("\(data.totalContributions) contributions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("GitHub Activity")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private var gridView: some View {
        if let weeks = entry.widgetData?.weeks {
            Canvas { context, size in
                let weekCount = max(weeks.count, 1)
                let cellW = (size.width - CGFloat(weekCount - 1) * gap) / CGFloat(weekCount)
                let cellH = (size.height - 6 * gap) / 7
                let cell = min(cellW, cellH)
                let radius = max(1, cell * 0.25)
                let gridWidth = CGFloat(weekCount) * cell + CGFloat(weekCount - 1) * gap
                let gridHeight = 7 * cell + 6 * gap
                let offsetX = (size.width - gridWidth) / 2
                let offsetY = (size.height - gridHeight) / 2

                for (weekIndex, week) in weeks.enumerated() {
                    for (dayIndex, day) in week.days.enumerated() {
                        let x = offsetX + CGFloat(weekIndex) * (cell + gap)
                        let y = offsetY + CGFloat(dayIndex) * (cell + gap)
                        let rect = CGRect(x: x, y: y, width: cell, height: cell)
                        let path = Path(roundedRect: rect, cornerRadius: radius)
                        context.fill(path, with: .color(cellColor(count: day.count)))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Open Routina to load\nyour GitHub contribution graph.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerView: some View {
        if entry.widgetData != nil {
            HStack(spacing: 6) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cellColor(count: sampleCount(for: level)))
                        .frame(width: 9, height: 9)
                }
                Text("More")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private var gap: CGFloat { 2 }

    private func sampleCount(for level: Int) -> Int {
        switch level {
        case 0: return 0
        case 1: return 2
        case 2: return 5
        case 3: return 8
        default: return 12
        }
    }

    // MARK: - Color

    private func cellColor(count: Int) -> Color {
        switch count {
        case 0:
            return colorScheme == .dark ? Color(white: 0.20) : Color(white: 0.90)
        case 1...3:
            return Color(red: 0.60, green: 0.87, blue: 0.47)
        case 4...6:
            return Color(red: 0.25, green: 0.73, blue: 0.35)
        case 7...9:
            return Color(red: 0.14, green: 0.55, blue: 0.24)
        default:
            return Color(red: 0.08, green: 0.38, blue: 0.15)
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
