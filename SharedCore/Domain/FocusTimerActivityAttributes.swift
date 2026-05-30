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
        let lastUpdated: Date

        var isCountUp: Bool {
            plannedDurationSeconds <= 0
        }

        var endDate: Date? {
            guard plannedDurationSeconds > 0 else { return nil }
            return startedAt.addingTimeInterval(plannedDurationSeconds)
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
