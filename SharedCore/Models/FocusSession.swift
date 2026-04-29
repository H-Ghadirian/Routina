import Foundation
import SwiftData

enum FocusSessionState: String, Codable, Equatable, Sendable {
    case active
    case completed
    case abandoned
}

@Model
final class FocusSession {
    var id: UUID = UUID()
    var taskID: UUID = UUID()
    var startedAt: Date?
    var plannedDurationSeconds: TimeInterval = 25 * 60
    var completedAt: Date?
    var abandonedAt: Date?

    var state: FocusSessionState {
        if completedAt != nil { return .completed }
        if abandonedAt != nil { return .abandoned }
        return .active
    }

    var finishedAt: Date? {
        completedAt ?? abandonedAt
    }

    var actualDurationSeconds: TimeInterval {
        guard let startedAt else { return 0 }
        let endDate = finishedAt ?? Date()
        return max(0, endDate.timeIntervalSince(startedAt))
    }

    init(
        id: UUID = UUID(),
        taskID: UUID,
        startedAt: Date? = Date(),
        plannedDurationSeconds: TimeInterval = 25 * 60,
        completedAt: Date? = nil,
        abandonedAt: Date? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.startedAt = startedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.completedAt = completedAt
        self.abandonedAt = abandonedAt
    }
}

extension FocusSession: Identifiable, Equatable {
    static func == (lhs: FocusSession, rhs: FocusSession) -> Bool {
        lhs.id == rhs.id
    }
}

enum FocusSessionFormatting {
    static func durationText(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func compactDurationText(seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int((seconds / 60).rounded()))
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}

enum RoutineTimeSpentFormatting {
    static func compactMinutesText(_ minutes: Int) -> String {
        FocusSessionFormatting.compactDurationText(seconds: TimeInterval(max(minutes, 1) * 60))
    }
}
