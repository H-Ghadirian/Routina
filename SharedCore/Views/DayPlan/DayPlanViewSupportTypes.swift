import Foundation
import SwiftUI

struct DayPlanDayTaskListSource {
    let plannedBlocksByDayKey: [String: [DayPlanBlock]]
    let allDayBlocks: [DayPlanAllDayBlock]
    let plannedDateTasks: [RoutineTask]
    let tasks: [RoutineTask]
    let logs: [RoutineLog]
    let referenceDate: Date
    let visibilitySignature: DayPlanDayTaskListVisibilitySignature
}

struct DayPlanTimelineDateJumpRequest: Equatable, Identifiable {
    let id = UUID()
    let date: Date
}

enum DayPlanTimelineDateJumpTarget {
    static func matchingSectionDate(
        for requestedDate: Date?,
        in sectionDates: [Date],
        calendar: Calendar
    ) -> Date? {
        guard let requestedDate else { return nil }
        let requestedDay = calendar.startOfDay(for: requestedDate)
        return sectionDates.first { sectionDate in
            calendar.isDate(sectionDate, inSameDayAs: requestedDay)
        }
    }
}

enum DayPlanSidebarDateAvailability {
    static func dayStarts(for activityDates: [Date], calendar: Calendar) -> Set<Date> {
        Set(activityDates.map { calendar.startOfDay(for: $0) })
    }

    static func contains(_ date: Date, in activityDayStarts: Set<Date>, calendar: Calendar) -> Bool {
        activityDayStarts.contains(calendar.startOfDay(for: date))
    }
}

enum DayPlanHeaderRangePickerVisibility {
    static let segmentedControlSpacing: CGFloat = 16
    static let displayModePickerWidth: CGFloat = 220
    static let compactDisplayModePickerWidth: CGFloat = 124
    static let calendarTaskViewModePickerWidth: CGFloat = 190
    static let compactCalendarTaskViewModePickerWidth: CGFloat = 112
    static let visibleRangeModePickerWidth: CGFloat = 234
    static let compactVisibleRangeModePickerWidth: CGFloat = 96
    static let dateButtonTransitionReserveWidth: Double = 120
    static let minimumRegularCalendarHeaderAvailableWidth: Double = 1520

    static func effectiveAvailableWidth(
        parentWidth: Double?,
        measuredWidth: Double
    ) -> Double {
        let positiveMeasuredWidth = measuredWidth > 0 ? measuredWidth : nil
        let positiveParentWidth = parentWidth.flatMap { $0 > 0 ? $0 : nil }

        switch (positiveParentWidth, positiveMeasuredWidth) {
        case let (.some(parentWidth), .some(measuredWidth)):
            return min(parentWidth, measuredWidth)
        case let (.some(parentWidth), .none):
            return parentWidth
        case let (.none, .some(measuredWidth)):
            return measuredWidth
        case (.none, .none):
            return 0
        }
    }

    static func shouldUseCompactDateButtonForFit(
        availableWidth: Double,
        expandedControlsWidth: Double,
        showsCalendarControlSet: Bool = true
    ) -> Bool {
        guard availableWidth > 0 else { return false }
        if showsCalendarControlSet,
            availableWidth < minimumRegularCalendarHeaderAvailableWidth
        {
            return true
        }
        guard expandedControlsWidth > 0 else { return false }
        return expandedControlsWidth + dateButtonTransitionReserveWidth > availableWidth + 0.5
    }

    static func shouldUseIconOnlyDatePickerButton(
        needsCompactDateButtonForFit: Bool
    ) -> Bool {
        needsCompactDateButtonForFit
    }
}

enum DayPlanSlotActionMode: String, CaseIterable, Hashable {
    case task
    case away

    var title: String {
        switch self {
        case .task:
            return "Task"
        case .away:
            return "Away"
        }
    }

    static func visibleCases(includingAway: Bool) -> [DayPlanSlotActionMode] {
        includingAway ? [.task, .away] : [.task]
    }

    static func showsModePicker(includingAway: Bool) -> Bool {
        visibleCases(includingAway: includingAway).count > 1
    }
}

enum DayPlanSlotTaskPickerPresentation {
    static func filteredTasks(
        _ tasks: [RoutineTask],
        matching query: String
    ) -> [RoutineTask] {
        let normalizedQuery = normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else { return tasks }

        return tasks.filter { task in
            normalizedSearchText(DayPlanTaskSorting.title(for: task)).contains(normalizedQuery)
        }
    }

    static func creatableTaskName(
        from query: String,
        tasks: [RoutineTask]
    ) -> String? {
        let name = normalizedNewTaskName(query)
        guard !name.isEmpty else { return nil }
        let normalizedName = normalizedSearchText(name)
        let alreadyExists = tasks.contains { task in
            normalizedSearchText(DayPlanTaskSorting.title(for: task)) == normalizedName
        }
        return alreadyExists ? nil : name
    }

    static func normalizedNewTaskName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func normalizedSearchText(_ value: String) -> String {
        normalizedNewTaskName(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
