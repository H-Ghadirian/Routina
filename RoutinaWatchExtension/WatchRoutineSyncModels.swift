import Foundation

struct RoutinaWatchRoutine: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let name: String
    let emoji: String
    let intervalDays: Int
    let isOneOffTask: Bool
    let isChecklistDriven: Bool
    let isChecklistCompletionRoutine: Bool
    let steps: [String]
    var checklistItemCount: Int
    var completedChecklistItemCount: Int
    var nextPendingChecklistItemTitle: String?
    var dueDate: Date?
    var dueChecklistItemCount: Int
    var nextDueChecklistItemTitle: String?
    var lastDone: Date?
    var completedStepCount: Int

    var isInProgress: Bool {
        !steps.isEmpty && completedStepCount > 0 && completedStepCount < steps.count
    }

    var isCompletedOneOff: Bool {
        isOneOffTask && lastDone != nil && !isInProgress
    }

    var nextStepTitle: String? {
        guard !steps.isEmpty, completedStepCount < steps.count else { return nil }
        return steps[completedStepCount]
    }

    func daysUntilDue(from now: Date) -> Int {
        if isOneOffTask {
            return isCompletedOneOff ? Int.max : 0
        }
        let calendar = Calendar.current
        let dueDate = dueDate ?? {
            guard let lastDone else { return now }
            return calendar.date(byAdding: .day, value: max(intervalDays, 1), to: lastDone) ?? now
        }()
        let startNow = calendar.startOfDay(for: now)
        let startDue = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: startNow, to: startDue).day ?? 0
    }

    func isDoneToday(referenceDate: Date = Date()) -> Bool {
        guard let lastDone else { return false }
        return Calendar.current.isDate(lastDone, inSameDayAs: referenceDate)
    }

    func canMarkDone(referenceDate: Date = Date()) -> Bool {
        if isOneOffTask {
            return !isCompletedOneOff
        }
        if isChecklistDriven {
            return dueChecklistItemCount > 0
        }
        if isChecklistCompletionRoutine {
            return false
        }
        return !(isDoneToday(referenceDate: referenceDate) && !isInProgress)
    }

    func advancedLocally(at completionDate: Date) -> RoutinaWatchRoutine {
        if isChecklistDriven {
            return RoutinaWatchRoutine(
                id: id,
                name: name,
                emoji: emoji,
                intervalDays: intervalDays,
                isOneOffTask: isOneOffTask,
                isChecklistDriven: true,
                isChecklistCompletionRoutine: false,
                steps: steps,
                checklistItemCount: checklistItemCount,
                completedChecklistItemCount: completedChecklistItemCount,
                nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
                dueDate: dueDate,
                dueChecklistItemCount: 0,
                nextDueChecklistItemTitle: nextDueChecklistItemTitle,
                lastDone: completionDate,
                completedStepCount: completedStepCount
            )
        }

        if isChecklistCompletionRoutine {
            return self
        }

        guard !steps.isEmpty else {
            return RoutinaWatchRoutine(
                id: id,
                name: name,
                emoji: emoji,
                intervalDays: intervalDays,
                isOneOffTask: isOneOffTask,
                isChecklistDriven: false,
                isChecklistCompletionRoutine: false,
                steps: steps,
                checklistItemCount: checklistItemCount,
                completedChecklistItemCount: completedChecklistItemCount,
                nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
                dueDate: dueDate,
                dueChecklistItemCount: dueChecklistItemCount,
                nextDueChecklistItemTitle: nextDueChecklistItemTitle,
                lastDone: completionDate,
                completedStepCount: 0
            )
        }

        let nextCompletedStepCount = min(completedStepCount + 1, steps.count)
        if nextCompletedStepCount < steps.count {
            return RoutinaWatchRoutine(
                id: id,
                name: name,
                emoji: emoji,
                intervalDays: intervalDays,
                isOneOffTask: isOneOffTask,
                isChecklistDriven: false,
                isChecklistCompletionRoutine: false,
                steps: steps,
                checklistItemCount: checklistItemCount,
                completedChecklistItemCount: completedChecklistItemCount,
                nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
                dueDate: dueDate,
                dueChecklistItemCount: dueChecklistItemCount,
                nextDueChecklistItemTitle: nextDueChecklistItemTitle,
                lastDone: lastDone,
                completedStepCount: nextCompletedStepCount
            )
        }

        return RoutinaWatchRoutine(
            id: id,
            name: name,
            emoji: emoji,
            intervalDays: intervalDays,
            isOneOffTask: isOneOffTask,
            isChecklistDriven: false,
            isChecklistCompletionRoutine: false,
            steps: steps,
            checklistItemCount: checklistItemCount,
            completedChecklistItemCount: completedChecklistItemCount,
            nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
            dueDate: dueDate,
            dueChecklistItemCount: dueChecklistItemCount,
            nextDueChecklistItemTitle: nextDueChecklistItemTitle,
            lastDone: completionDate,
            completedStepCount: 0
        )
    }
}

struct RoutinaWatchPlace: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let name: String
}

enum RoutinaWatchPlaceActivity: String, Equatable, Sendable, Codable {
    case work
    case commute
    case errands
    case exercise
    case rest
    case social
    case other

    var title: String {
        switch self {
        case .work:
            return "Work"
        case .commute:
            return "Commute"
        case .errands:
            return "Errands"
        case .exercise:
            return "Exercise"
        case .rest:
            return "Rest"
        case .social:
            return "Social"
        case .other:
            return "Other"
        }
    }
}

struct RoutinaWatchPlaceCheckIn: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let placeID: UUID?
    let placeName: String
    let activity: RoutinaWatchPlaceActivity?
    let startedAt: Date

    func elapsedSeconds(at date: Date = .now) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }
}

struct RoutinaWatchSleepSession: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let startedAt: Date
    let targetWakeAt: Date?
    let targetDurationMinutes: Int

    func elapsedSeconds(at date: Date = .now) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }
}

enum RoutinaWatchFocusKind: String, Sendable, Codable {
    case task
    case sprint
    case unassigned

    var deepLinkPath: String? {
        switch self {
        case .task, .sprint:
            return rawValue
        case .unassigned:
            return nil
        }
    }

    var displayTitle: String {
        switch self {
        case .task:
            return "Focus"
        case .sprint:
            return "Sprint Focus"
        case .unassigned:
            return "Focus"
        }
    }

    var systemImage: String {
        switch self {
        case .task:
            return "timer"
        case .sprint:
            return "flag.checkered"
        case .unassigned:
            return "stopwatch"
        }
    }
}

struct RoutinaWatchFocusSession: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let focusKind: RoutinaWatchFocusKind?
    let targetID: UUID?
    let taskID: UUID?
    let taskName: String
    let taskEmoji: String
    let startedAt: Date
    let plannedDurationSeconds: TimeInterval
    let pausedAt: Date?
    let accumulatedPausedSeconds: TimeInterval

    var resolvedFocusKind: RoutinaWatchFocusKind {
        focusKind ?? .task
    }

    var deepLinkTargetID: UUID? {
        targetID ?? taskID
    }

    var deepLinkURL: URL? {
        guard let deepLinkPath = resolvedFocusKind.deepLinkPath,
              let deepLinkTargetID else {
            return nil
        }
        return WatchRoutineDeepLinkURL.url(path: deepLinkPath, targetID: deepLinkTargetID)
    }

    var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    var isPaused: Bool {
        pausedAt != nil
    }

    var canPause: Bool {
        resolvedFocusKind != .sprint
    }

    var endDate: Date? {
        guard plannedDurationSeconds > 0 else { return nil }
        return startedAt.addingTimeInterval(plannedDurationSeconds + max(0, accumulatedPausedSeconds))
    }

    func elapsedSeconds(at date: Date = .now) -> TimeInterval {
        let endDate = pausedAt ?? date
        return max(0, endDate.timeIntervalSince(startedAt) - max(0, accumulatedPausedSeconds))
    }

    func remainingSeconds(at date: Date = .now) -> TimeInterval {
        max(0, plannedDurationSeconds - elapsedSeconds(at: date))
    }

    func pausing(at date: Date = .now) -> RoutinaWatchFocusSession {
        guard canPause, pausedAt == nil else { return self }
        return RoutinaWatchFocusSession(
            id: id,
            focusKind: focusKind,
            targetID: targetID,
            taskID: taskID,
            taskName: taskName,
            taskEmoji: taskEmoji,
            startedAt: startedAt,
            plannedDurationSeconds: plannedDurationSeconds,
            pausedAt: max(date, startedAt),
            accumulatedPausedSeconds: accumulatedPausedSeconds
        )
    }

    func resuming(at date: Date = .now) -> RoutinaWatchFocusSession {
        guard let pausedAt else { return self }
        let resumedAt = max(date, pausedAt)
        return RoutinaWatchFocusSession(
            id: id,
            focusKind: focusKind,
            targetID: targetID,
            taskID: taskID,
            taskName: taskName,
            taskEmoji: taskEmoji,
            startedAt: startedAt,
            plannedDurationSeconds: plannedDurationSeconds,
            pausedAt: nil,
            accumulatedPausedSeconds: max(0, accumulatedPausedSeconds) + resumedAt.timeIntervalSince(pausedAt)
        )
    }
}

extension WatchRoutineSyncStore {
    typealias WatchRoutine = RoutinaWatchRoutine
    typealias WatchPlace = RoutinaWatchPlace
    typealias WatchPlaceActivity = RoutinaWatchPlaceActivity
    typealias WatchPlaceCheckIn = RoutinaWatchPlaceCheckIn
    typealias WatchSleepSession = RoutinaWatchSleepSession
    typealias WatchFocusKind = RoutinaWatchFocusKind
    typealias WatchFocusSession = RoutinaWatchFocusSession
}

private enum WatchRoutineDeepLinkURL {
    private static let productionScheme = "routina"
    private static let sandboxScheme = "routina-dev"

    static func url(path: String, targetID: UUID) -> URL {
        URL(string: "\(scheme)://\(path)/\(targetID.uuidString)")!
    }

    private static var scheme: String {
        if let configuredScheme = Bundle.main.infoDictionary?["RoutinaDeepLinkURLScheme"] as? String {
            let cleanedScheme = configuredScheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanedScheme.isEmpty {
                return cleanedScheme
            }
        }

        let bundleID = Bundle.main.bundleIdentifier?.lowercased()
        return bundleID?.contains(".dev") == true ? sandboxScheme : productionScheme
    }
}
