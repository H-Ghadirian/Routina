import Foundation
import SwiftData

enum FocusSessionState: String, Codable, Equatable, Sendable {
    case active
    case completed
    case abandoned
}

@Model
final class FocusSession {
    static let unassignedTaskID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    var id: UUID = UUID()
    var taskID: UUID = UUID()
    var startedAt: Date?
    var plannedDurationSeconds: TimeInterval = 25 * 60
    var completedAt: Date?
    var abandonedAt: Date?
    var pausedAt: Date?
    var accumulatedPausedSeconds: TimeInterval = 0

    var isUnassigned: Bool {
        taskID == Self.unassignedTaskID
    }

    var state: FocusSessionState {
        if completedAt != nil { return .completed }
        if abandonedAt != nil { return .abandoned }
        return .active
    }

    var finishedAt: Date? {
        completedAt ?? abandonedAt
    }

    var isPaused: Bool {
        state == .active && pausedAt != nil
    }

    var actualDurationSeconds: TimeInterval {
        activeDurationSeconds()
    }

    func activeDurationSeconds(at date: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        let endDate = finishedAt ?? pausedAt ?? date
        var pausedSeconds = max(0, accumulatedPausedSeconds)
        if let pausedAt,
           let finishedAt,
           finishedAt > pausedAt {
            pausedSeconds += finishedAt.timeIntervalSince(pausedAt)
        }
        return max(0, endDate.timeIntervalSince(startedAt) - pausedSeconds)
    }

    @discardableResult
    func pause(at date: Date = Date()) -> Bool {
        guard state == .active, pausedAt == nil else { return false }
        if let startedAt {
            pausedAt = max(date, startedAt)
        } else {
            pausedAt = date
        }
        return true
    }

    @discardableResult
    func resume(at date: Date = Date()) -> Bool {
        guard state == .active, let pausedAt else { return false }
        let resumedAt = max(date, pausedAt)
        accumulatedPausedSeconds = max(0, accumulatedPausedSeconds) + resumedAt.timeIntervalSince(pausedAt)
        self.pausedAt = nil
        return true
    }

    func closePauseIfNeeded(at date: Date = Date()) {
        _ = resume(at: date)
    }

    func clearPauseTracking() {
        pausedAt = nil
        accumulatedPausedSeconds = 0
    }

    init(
        id: UUID = UUID(),
        taskID: UUID,
        startedAt: Date? = Date(),
        plannedDurationSeconds: TimeInterval = 25 * 60,
        completedAt: Date? = nil,
        abandonedAt: Date? = nil,
        pausedAt: Date? = nil,
        accumulatedPausedSeconds: TimeInterval = 0
    ) {
        self.id = id
        self.taskID = taskID
        self.startedAt = startedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.completedAt = completedAt
        self.abandonedAt = abandonedAt
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = max(0, accumulatedPausedSeconds)
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

enum FocusBlockProgress {
    static let blockDurationSeconds: TimeInterval = 5 * 60
    static let defaultVisibleSessionBlocks = 12

    static func filledBlockCount(for seconds: TimeInterval) -> Int {
        guard seconds.isFinite else { return 0 }
        return Int(max(0, seconds) / blockDurationSeconds)
    }

    static func visibleSessionBlockCount(for seconds: TimeInterval) -> Int {
        max(defaultVisibleSessionBlocks, filledBlockCount(for: seconds) + 1)
    }

    static func secondsUntilNextBlock(for seconds: TimeInterval) -> TimeInterval {
        guard seconds.isFinite else { return blockDurationSeconds }

        let elapsedSeconds = max(0, seconds)
        let remainder = elapsedSeconds.truncatingRemainder(dividingBy: blockDurationSeconds)
        guard remainder > 0 else { return blockDurationSeconds }
        return blockDurationSeconds - remainder
    }

    static func blockCountText(_ count: Int) -> String {
        let safeCount = max(0, count)
        return "\(safeCount.formatted()) \(safeCount == 1 ? "block" : "blocks")"
    }
}

enum RoutineTimeSpentFormatting {
    static func compactMinutesText(_ minutes: Int) -> String {
        FocusSessionFormatting.compactDurationText(seconds: TimeInterval(max(minutes, 1) * 60))
    }
}
