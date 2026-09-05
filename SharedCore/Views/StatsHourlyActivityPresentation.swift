import SwiftUI

enum StatsHourlyActivityHourFormatting {
    static func label(for hour: Int) -> String {
        let normalizedHour = ((hour % 24) + 24) % 24
        switch normalizedHour {
        case 0:
            return "12 AM"
        case 1..<12:
            return "\(normalizedHour) AM"
        case 12:
            return "12 PM"
        default:
            return "\(normalizedHour - 12) PM"
        }
    }

    static func rangeLabel(for hour: Int) -> String {
        "\(label(for: hour))-\(label(for: hour + 1))"
    }
}

enum StatsHourlyActivityMetric: String, CaseIterable, Identifiable {
    case focus
    case done
    case created
    case activity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .done:
            return "Done"
        case .created:
            return "Created"
        case .activity:
            return "Activity"
        }
    }

    var axisLabel: String {
        switch self {
        case .focus:
            return "Focus time"
        case .done:
            return "Done tasks"
        case .created:
            return "Created tasks"
        case .activity:
            return "Timeline activity"
        }
    }

    var axisValueName: String {
        switch self {
        case .focus:
            return "Focus minutes"
        case .done:
            return "Done"
        case .created:
            return "Created"
        case .activity:
            return "Activity"
        }
    }

    var totalLabel: String {
        switch self {
        case .focus:
            return "Total focus"
        case .done:
            return "Done"
        case .created:
            return "Created"
        case .activity:
            return "Activity"
        }
    }

    var systemImage: String {
        switch self {
        case .focus:
            return "timer"
        case .done:
            return "checkmark.seal.fill"
        case .created:
            return "plus.circle.fill"
        case .activity:
            return "chart.bar.fill"
        }
    }

    var tint: Color {
        switch self {
        case .focus:
            return .accentColor
        case .done:
            return .green
        case .created:
            return .teal
        case .activity:
            return .indigo
        }
    }

    func value(in point: HourlyActivityChartPoint) -> Double {
        switch self {
        case .focus:
            return point.focusMinutes
        case .done:
            return Double(point.doneCount)
        case .created:
            return Double(point.createdCount)
        case .activity:
            return Double(point.activityCount)
        }
    }

    func fill(colorScheme: ColorScheme) -> AnyShapeStyle {
        switch self {
        case .focus:
            return AnyShapeStyle(StatsChartFill.focusBar(colorScheme: colorScheme))
        case .done:
            return AnyShapeStyle(Color.green.opacity(colorScheme == .dark ? 0.82 : 0.68))
        case .created:
            return AnyShapeStyle(StatsDashboardPalette.createdBarFill(colorScheme: colorScheme))
        case .activity:
            return AnyShapeStyle(Color.indigo.opacity(colorScheme == .dark ? 0.82 : 0.68))
        }
    }

    func formattedValue(_ value: Double, chartPresentation: StatsChartPresentation) -> String {
        switch self {
        case .focus:
            return chartPresentation.focusDurationText(TimeInterval(value.rounded() * 60))
        case .done, .created, .activity:
            return Int(value.rounded()).formatted()
        }
    }

    func detailText(value: Double, selectedRange: DoneChartRange) -> String {
        let rangeText = selectedRange.hourlyActivityRangePhrase

        switch self {
        case .focus:
            if value <= 0 {
                return "No focus landed in this hour bucket \(rangeText)."
            }
            return "Focus sessions are split by clock hour, then totaled \(rangeText)."
        case .done:
            if value <= 0 {
                return "No completed work was timestamped in this hour \(rangeText)."
            }
            return "Completed work timestamped in this hour \(rangeText)."
        case .created:
            if value <= 0 {
                return "No tasks were created in this hour \(rangeText)."
            }
            return "Tasks created in this hour \(rangeText)."
        case .activity:
            if value <= 0 {
                return "No timeline entries were timestamped in this hour \(rangeText)."
            }
            return "Timeline entries timestamped in this hour \(rangeText)."
        }
    }
}

extension DoneChartRange {
    var hourlyActivityRangePhrase: String {
        switch kind {
        case .today:
            return "today"
        case .week, .month, .year, .custom:
            return "across the \(periodDescription.lowercased())"
        }
    }
}
