import SwiftUI

struct TaskDetailRoutineLogRowPresentation {
    let timestampText: String
    let dateTimeText: String
    let supplementaryDateText: String?
    let compactTimeSpentText: String
    let fullTimeSpentText: String
    let hasTimeSpent: Bool
    let timeSpentActionTitle: String
    let statusText: String
    let statusColor: Color
    let statusSystemImage: String
    let actionTitle: String
    let actionSystemImage: String
    let actionColor: Color
    let isDestructiveAction: Bool
    let isActionEnabled: Bool

    init(log: RoutineLog, showPersianDates: Bool, sourceTaskName: String? = nil) {
        let resolvesDoneDate = log.kind.resolvesDoneDate
        self.dateTimeText = log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date"
        self.supplementaryDateText = log.timestamp.flatMap {
            PersianDateDisplay.supplementaryText(for: $0, enabled: showPersianDates)
        }
        self.timestampText = TaskDetailLogPresentation.timestampText(
            log.timestamp,
            showPersianDates: showPersianDates
        )
        self.compactTimeSpentText = TaskDetailLogPresentation.timeSpentText(for: log, style: .compact)
        self.fullTimeSpentText = TaskDetailLogPresentation.timeSpentText(for: log, style: .full)
        self.hasTimeSpent = log.actualDurationMinutes != nil
        self.timeSpentActionTitle = log.actualDurationMinutes == nil ? "Add Time Spent" : "Edit Time Spent"
        self.statusText = TaskDetailLogPresentation.statusText(
            for: log.kind,
            sourceTaskName: sourceTaskName
        )
        self.statusColor = TaskDetailLogPresentation.statusColor(for: log.kind)
        self.statusSystemImage = TaskDetailLogPresentation.statusSystemImage(for: log.kind)
        self.actionTitle = TaskDetailLogPresentation.actionTitle(for: log)
        self.actionSystemImage = resolvesDoneDate ? "arrow.uturn.backward" : "trash"
        self.actionColor = resolvesDoneDate ? .orange : .red
        self.isDestructiveAction = !resolvesDoneDate
        self.isActionEnabled = log.timestamp != nil
    }

    func timeSpentText(style: TaskDetailDurationTextStyle) -> String {
        switch style {
        case .compact:
            compactTimeSpentText
        case .full:
            fullTimeSpentText
        }
    }
}
