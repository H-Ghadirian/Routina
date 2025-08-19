import Foundation

struct FocusTimerWidgetData: Codable, Equatable, Sendable {
    let sessionID: UUID?
    let taskID: UUID?
    let taskName: String
    let taskEmoji: String
    let startedAt: Date?
    let plannedDurationSeconds: TimeInterval
    let lastUpdated: Date

    var isActive: Bool {
        sessionID != nil && startedAt != nil
    }

    var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    var endDate: Date? {
        guard let startedAt, plannedDurationSeconds > 0 else { return nil }
        return startedAt.addingTimeInterval(plannedDurationSeconds)
    }

    static let inactive = FocusTimerWidgetData(
        sessionID: nil,
        taskID: nil,
        taskName: "No focus session",
        taskEmoji: "⏱",
        startedAt: nil,
        plannedDurationSeconds: 0,
        lastUpdated: .now
    )

    static let placeholder = FocusTimerWidgetData(
        sessionID: UUID(),
        taskID: UUID(),
        taskName: "Deep work",
        taskEmoji: "🎯",
        startedAt: .now.addingTimeInterval(-8 * 60),
        plannedDurationSeconds: 25 * 60,
        lastUpdated: .now
    )
}

enum FocusTimerWidgetDataComputer {
    static func compute(
        tasks: [RoutineTask],
        sessions: [FocusSession],
        referenceDate: Date = .now
    ) -> FocusTimerWidgetData {
        guard let session = sessions
            .filter({ $0.state == .active })
            .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
            .first
        else {
            return FocusTimerWidgetData.inactive
        }

        let task = tasks.first { $0.id == session.taskID }
        let taskName = (task?.name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return FocusTimerWidgetData(
            sessionID: session.id,
            taskID: session.taskID,
            taskName: taskName.isEmpty ? "Focus session" : taskName,
            taskEmoji: task?.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "🎯",
            startedAt: session.startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds,
            lastUpdated: referenceDate
        )
    }
}
