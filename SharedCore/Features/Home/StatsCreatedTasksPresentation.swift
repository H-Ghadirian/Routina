import Foundation

struct StatsCreatedTasksPresentation {
    let taskTypeFilter: StatsTaskTypeFilter
    let selectedRange: DoneChartRange

    var chartTitle: String {
        switch selectedRange.kind {
        case .today:
            return String(localized: "Tasks created per day")
        case .week:
            return String(localized: "Tasks created per week")
        case .month:
            return String(localized: "Tasks created per month")
        case .year:
            return String(localized: "Tasks created per year")
        case .custom:
            return String(localized: "Tasks created per day")
        }
    }

    func chartSubtitle(totalCount: Int, activeDayCount: Int) -> String {
        if totalCount == 0 {
            return "New \(noun(count: 2)) will appear here as you add them."
        }

        return "\(totalCount.formatted()) \(noun(count: totalCount)) created across \(activeDayCount) \(activeDayCount == 1 ? "day" : "days")."
    }

    func createdInPeriodInsight(totalCount: Int) -> String {
        "\(noun(count: totalCount).capitalized) created in \(selectedRange.periodDescription.lowercased())"
    }

    var waitingInsight: String {
        "Waiting for created \(noun(count: 2))"
    }

    func noun(count: Int) -> String {
        switch taskTypeFilter {
        case .all:
            return count == 1 ? "task" : "tasks"
        case .routines:
            return count == 1 ? "repeating task" : "repeating tasks"
        case .todos:
            return count == 1 ? "one-time task" : "one-time tasks"
        }
    }
}
