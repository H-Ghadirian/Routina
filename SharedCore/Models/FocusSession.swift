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
    var tagName: String?

    var isUnassigned: Bool {
        taskID == Self.unassignedTaskID && focusTagName == nil
    }

    var isTagFocus: Bool {
        focusTagName != nil
    }

    var isTaskFocus: Bool {
        taskID != Self.unassignedTaskID && !isTagFocus
    }

    var focusTagName: String? {
        RoutineTag.cleaned(tagName ?? "")
    }

    var focusTagTitle: String? {
        focusTagName.map { "#\($0)" }
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
        accumulatedPausedSeconds: TimeInterval = 0,
        tagName: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.startedAt = startedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.completedAt = completedAt
        self.abandonedAt = abandonedAt
        self.pausedAt = pausedAt
        self.accumulatedPausedSeconds = max(0, accumulatedPausedSeconds)
        self.tagName = RoutineTag.cleaned(tagName ?? "")
    }
}

extension FocusSession: Identifiable, Equatable {
    static func == (lhs: FocusSession, rhs: FocusSession) -> Bool {
        lhs.id == rhs.id
    }
}

enum FocusSessionTagRecency {
    static func orderedAvailableTags(
        _ availableTags: [String],
        focusSessions: [FocusSession]
    ) -> [String] {
        let latestStartByTag = focusSessions.reduce(into: [String: Date]()) { latestStartByTag, session in
            guard
                let tag = session.focusTagName,
                let normalizedTag = RoutineTag.normalized(tag),
                let startedAt = session.startedAt
            else {
                return
            }

            latestStartByTag[normalizedTag] = max(
                latestStartByTag[normalizedTag] ?? .distantPast,
                startedAt
            )
        }

        return availableTags.sorted { lhs, rhs in
            let lhsMostRecentStart = RoutineTag.normalized(lhs).flatMap { latestStartByTag[$0] }
            let rhsMostRecentStart = RoutineTag.normalized(rhs).flatMap { latestStartByTag[$0] }

            switch (lhsMostRecentStart, rhsMostRecentStart) {
            case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
                return lhsDate > rhsDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        }
    }
}

struct FocusSessionStartDefaults: Equatable {
    static let rememberedDurationDefaultsKey = "macFocusTimerLastChoiceDuration"
    static let fallbackDuration: TimeInterval = 25 * 60
    static let standardDurationOptions: [TimeInterval] = [
        0,
        15 * 60,
        25 * 60,
        45 * 60,
        60 * 60,
        90 * 60,
    ]

    let duration: TimeInterval
    let tagName: String?

    static func rememberedDuration(
        defaults: UserDefaults = SharedDefaults.app
    ) -> TimeInterval? {
        guard let storedValue = defaults.object(forKey: rememberedDurationDefaultsKey) as? NSNumber else {
            return nil
        }

        let duration = storedValue.doubleValue
        guard duration.isFinite, duration >= 0 else { return nil }
        return duration
    }

    static func rememberDuration(
        _ duration: TimeInterval,
        defaults: UserDefaults = SharedDefaults.app
    ) {
        guard duration.isFinite, duration >= 0 else { return }
        defaults.set(duration, forKey: rememberedDurationDefaultsKey)
    }

    static func latest(
        focusSessions: [FocusSession],
        availableTags: [String],
        rememberedDuration: TimeInterval? = nil
    ) -> Self {
        let latestSession = focusSessions
            .filter { $0.isTaskFocus || $0.isTagFocus }
            .compactMap { session -> (session: FocusSession, startedAt: Date)? in
                guard let startedAt = session.startedAt else { return nil }
                return (session, startedAt)
            }
            .max { lhs, rhs in
                lhs.startedAt < rhs.startedAt
            }?
            .session

        let validRememberedDuration = rememberedDuration.flatMap { value in
            value.isFinite && value >= 0 ? value : nil
        }
        guard let latestSession else {
            return Self(duration: validRememberedDuration ?? fallbackDuration, tagName: nil)
        }

        let historyDuration = latestSession.plannedDurationSeconds.isFinite
            ? max(0, latestSession.plannedDurationSeconds)
            : fallbackDuration
        let duration = validRememberedDuration ?? historyDuration
        let tagName = latestSession.focusTagName.flatMap { recentTag in
            availableTags.first { availableTag in
                RoutineTag.normalized(availableTag) == RoutineTag.normalized(recentTag)
            }
        }
        return Self(duration: duration, tagName: tagName)
    }

    static func durationOptions(including selectedDuration: TimeInterval) -> [TimeInterval] {
        guard selectedDuration.isFinite, selectedDuration > 0 else {
            return standardDurationOptions
        }
        guard !standardDurationOptions.contains(selectedDuration) else {
            return standardDurationOptions
        }

        return [0] + (standardDurationOptions.dropFirst() + [selectedDuration]).sorted()
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
