import Foundation

typealias TaskRankingRowTone = TaskRowSemanticTone
typealias TaskRankingRowPresentation = TaskRowSemanticPresentation

extension TaskRowSemanticPresentation {
    static func make(
        task: RoutineTask,
        isContainerGroup: Bool,
        flagRules: [RoutineFlagRule],
        referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        guard !isContainerGroup else {
            return Self(
                id: task.id,
                name: RoutineTask.trimmedName(task.name) ?? "Untitled group",
                emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "📁",
                hasImage: false,
                isPinned: false,
                taskType: nil,
                color: task.color,
                status: nil,
                scheduleText: nil,
                pressureText: nil,
                progressText: nil,
                stepsText: nil,
                placeText: nil,
                tags: [],
                flags: [],
                hidingFlags: []
            )
        }

        return Self.make(
            task: task,
            flagRules: flagRules,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }
}
