import Foundation

enum TaskDetailDurationTextStyle {
    case compact
    case full
}

enum TaskDetailLogPresentation {
    static func actionTitle(for log: RoutineLog) -> String {
        log.kind == .completed ? "Undo" : "Remove"
    }

    static func timestampText(
        _ timestamp: Date?,
        showPersianDates: Bool
    ) -> String {
        guard let timestamp else { return "Unknown date" }
        return PersianDateDisplay.appendingSupplementaryDate(
            to: timestamp.formatted(date: .abbreviated, time: .shortened),
            for: timestamp,
            enabled: showPersianDates
        )
    }

    static func timeSpentText(for log: RoutineLog, style: TaskDetailDurationTextStyle) -> String {
        guard let duration = log.actualDurationMinutes else { return "Add time" }
        return durationText(for: duration, style: style)
    }

    static func taskChangeTitle(
        for change: RoutineTaskChangeLogEntry,
        relatedTaskName: String
    ) -> String {
        switch change.kind {
        case .created:
            return "Task created"
        case .stateChanged:
            return "State changed from \(change.previousValue ?? "Unknown") to \(change.newValue ?? "Unknown")"
        case .linkedTaskAdded:
            return "Linked \(relatedTaskName) as \(change.relationshipKind?.title ?? "Related")"
        case .linkedTaskRemoved:
            return "Removed link to \(relatedTaskName)"
        case .timeSpentAdded:
            return "Added \(compactDurationText(for: change.durationMinutes ?? change.newValue.flatMap(Int.init))) time spent"
        case .timeSpentChanged:
            return "Changed time spent to \(compactDurationText(for: change.durationMinutes ?? change.newValue.flatMap(Int.init)))"
        case .timeSpentRemoved:
            return "Removed time spent"
        }
    }

    static func taskChangeSystemImage(for change: RoutineTaskChangeLogEntry) -> String {
        switch change.kind {
        case .created:
            return "plus.circle"
        case .stateChanged:
            return "arrow.triangle.2.circlepath"
        case .linkedTaskAdded:
            return "link.badge.plus"
        case .linkedTaskRemoved:
            return "link.badge.minus"
        case .timeSpentAdded, .timeSpentChanged, .timeSpentRemoved:
            return "clock"
        }
    }

    static func displayedLogs(_ logs: [RoutineLog], showingAll: Bool, collapsedLimit: Int = 3) -> [RoutineLog] {
        showingAll ? logs : Array(logs.prefix(collapsedLimit))
    }

    private static func compactDurationText(for minutes: Int?) -> String {
        guard let minutes else { return "time" }
        return RoutineTimeSpentFormatting.compactMinutesText(minutes)
    }

    private static func durationText(for minutes: Int, style: TaskDetailDurationTextStyle) -> String {
        switch style {
        case .compact:
            return RoutineTimeSpentFormatting.compactMinutesText(minutes)
        case .full:
            return TaskDetailHeaderBadgePresentation.durationText(for: minutes)
        }
    }
}
