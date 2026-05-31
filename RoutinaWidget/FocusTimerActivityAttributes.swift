#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation

struct FocusTimerActivityAttributes: ActivityAttributes {
    enum FocusKind: String, Codable, Hashable {
        case task
        case sprint
        case unassigned
    }

    struct ContentState: Codable, Hashable {
        let startedAt: Date
        let plannedDurationSeconds: TimeInterval
        let pausedAt: Date?
        let accumulatedPausedSeconds: TimeInterval
        let lastUpdated: Date

        var isCountUp: Bool {
            plannedDurationSeconds <= 0
        }

        var isPaused: Bool {
            pausedAt != nil
        }

        var endDate: Date? {
            guard !isPaused, plannedDurationSeconds > 0 else { return nil }
            return startedAt.addingTimeInterval(plannedDurationSeconds + max(0, accumulatedPausedSeconds))
        }

        var adjustedStartedAt: Date? {
            guard !isPaused else { return nil }
            return startedAt.addingTimeInterval(max(0, accumulatedPausedSeconds))
        }

        init(
            startedAt: Date,
            plannedDurationSeconds: TimeInterval,
            pausedAt: Date? = nil,
            accumulatedPausedSeconds: TimeInterval = 0,
            lastUpdated: Date
        ) {
            self.startedAt = startedAt
            self.plannedDurationSeconds = plannedDurationSeconds
            self.pausedAt = pausedAt
            self.accumulatedPausedSeconds = max(0, accumulatedPausedSeconds)
            self.lastUpdated = lastUpdated
        }

        func elapsedSeconds(at date: Date = .now) -> TimeInterval {
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
            case startedAt
            case plannedDurationSeconds
            case pausedAt
            case accumulatedPausedSeconds
            case lastUpdated
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            startedAt = try container.decode(Date.self, forKey: .startedAt)
            plannedDurationSeconds = try container.decode(TimeInterval.self, forKey: .plannedDurationSeconds)
            pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
            accumulatedPausedSeconds = max(
                0,
                try container.decodeIfPresent(TimeInterval.self, forKey: .accumulatedPausedSeconds) ?? 0
            )
            lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        }
    }

    let sessionID: UUID
    let focusKind: FocusKind?
    let targetID: UUID?
    let taskID: UUID?
    let taskName: String
    let taskEmoji: String
}
#endif
