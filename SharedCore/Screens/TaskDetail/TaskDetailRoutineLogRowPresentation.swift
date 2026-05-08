import SwiftUI

struct TaskDetailRoutineLogRowPresentation {
    let timestampText: String
    let compactTimeSpentText: String
    let fullTimeSpentText: String
    let statusText: String
    let statusColor: Color
    let actionTitle: String
    let actionColor: Color
    let isActionEnabled: Bool

    init(log: RoutineLog, showPersianDates: Bool) {
        self.timestampText = TaskDetailLogPresentation.timestampText(
            log.timestamp,
            showPersianDates: showPersianDates
        )
        self.compactTimeSpentText = TaskDetailLogPresentation.timeSpentText(for: log, style: .compact)
        self.fullTimeSpentText = TaskDetailLogPresentation.timeSpentText(for: log, style: .full)
        self.statusText = TaskDetailLogPresentation.statusText(for: log.kind)
        self.statusColor = TaskDetailLogPresentation.statusColor(for: log.kind)
        self.actionTitle = TaskDetailLogPresentation.actionTitle(for: log)
        self.actionColor = TaskDetailLogPresentation.statusColor(for: log.kind)
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
