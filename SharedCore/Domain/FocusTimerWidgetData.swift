import Foundation

struct FocusTimerWidgetData: Codable, Equatable, Sendable {
    let sessionID: UUID?
    let taskID: UUID?
    let taskName: String
    let taskEmoji: String
    let startedAt: Date?
    let plannedDurationSeconds: TimeInterval
    let pausedAt: Date?
    let accumulatedPausedSeconds: TimeInterval
    let lastUpdated: Date

    var isActive: Bool {
        sessionID != nil && startedAt != nil
    }

    var isPaused: Bool {
        isActive && pausedAt != nil
    }

    var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    var endDate: Date? {
        guard !isPaused, let startedAt, plannedDurationSeconds > 0 else { return nil }
        return startedAt.addingTimeInterval(plannedDurationSeconds + max(0, accumulatedPausedSeconds))
    }

    var adjustedStartedAt: Date? {
        guard !isPaused, let startedAt else { return nil }
        return startedAt.addingTimeInterval(max(0, accumulatedPausedSeconds))
    }

    init(
        sessionID: UUID?,
        taskID: UUID?,
        taskName: String,
        taskEmoji: String,
        startedAt: Date?,
        plannedDurationSeconds: TimeInterval,
        pausedAt: Date? = nil,
        accumulatedPausedSeconds: TimeInterval = 0,
        lastUpdated: Date
    ) {
        self.sessionID = sessionID
        self.taskID = taskID
        self.taskName = taskName
        self.taskEmoji = taskEmoji
        self.startedAt = startedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = max(0, accumulatedPausedSeconds)
        self.lastUpdated = lastUpdated
    }

    func elapsedSeconds(at date: Date = .now) -> TimeInterval {
        guard let startedAt else { return 0 }
        let endDate = pausedAt ?? date
        return max(0, endDate.timeIntervalSince(startedAt) - max(0, accumulatedPausedSeconds))
    }

    func remainingSeconds(at date: Date = .now) -> TimeInterval {
        max(0, plannedDurationSeconds - elapsedSeconds(at: date))
    }

    func progress(at date: Date = .now) -> Double {
        guard plannedDurationSeconds > 0 else { return 1 }
        return min(1, max(0, elapsedSeconds(at: date) / plannedDurationSeconds))
    }

    enum CodingKeys: String, CodingKey {
        case sessionID
        case taskID
        case taskName
        case taskEmoji
        case startedAt
        case plannedDurationSeconds
        case pausedAt
        case accumulatedPausedSeconds
        case lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decodeIfPresent(UUID.self, forKey: .sessionID)
        taskID = try container.decodeIfPresent(UUID.self, forKey: .taskID)
        taskName = try container.decode(String.self, forKey: .taskName)
        taskEmoji = try container.decode(String.self, forKey: .taskEmoji)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        plannedDurationSeconds = try container.decode(TimeInterval.self, forKey: .plannedDurationSeconds)
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        accumulatedPausedSeconds = max(
            0,
            try container.decodeIfPresent(TimeInterval.self, forKey: .accumulatedPausedSeconds) ?? 0
        )
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
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

        let task = session.isTaskFocus ? tasks.first { $0.id == session.taskID } : nil
        let taskName = (task?.name ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = session.focusTagTitle ?? (taskName.isEmpty ? "Unassigned focus" : taskName)

        return FocusTimerWidgetData(
            sessionID: session.id,
            taskID: session.isTaskFocus ? session.taskID : nil,
            taskName: displayName,
            taskEmoji: task?.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "🎯",
            startedAt: session.startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds,
            pausedAt: session.pausedAt,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds,
            lastUpdated: referenceDate
        )
    }
}
