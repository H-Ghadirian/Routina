import Foundation

struct HomeRoutineDisplay: Equatable, Identifiable, HomeTaskListDisplay, HomeTaskRowDisplay {
    let taskID: UUID
    var id: UUID { taskID }
    var name: String
    var emoji: String
    var notes: String?
    var hasImage: Bool
    var hasFileAttachment: Bool = false
    var placeID: UUID?
    var placeIDs: [UUID] = []
    var placeName: String?
    var locationAvailability: RoutineLocationAvailability
    var tags: [String]
    var goalIDs: [UUID] = []
    var goalTitles: [String] = []
    var steps: [String]
    var interval: Int
    var recurrenceRule: RoutineRecurrenceRule
    var scheduleMode: RoutineScheduleMode
    var createdAt: Date?
    var isSoftIntervalRoutine: Bool
    var lastDone: Date?
    var canceledAt: Date?
    var dueDate: Date?
    var plannedDate: Date? = nil
    var priority: RoutineTaskPriority
    var importance: RoutineTaskImportance
    var urgency: RoutineTaskUrgency
    var pressure: RoutineTaskPressure = .none
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var snoozedUntil: Date?
    var pinnedAt: Date?
    var daysUntilDue: Int
    var hasMissedExactTimedOccurrence: Bool = false
    var isOneOffTask: Bool
    var isCompletedOneOff: Bool
    var isCanceledOneOff: Bool
    var isDoneToday: Bool
    var isCanceledToday: Bool = false
    var isAssumedDoneToday: Bool = false
    var isPaused: Bool
    var isSnoozed: Bool
    var isPinned: Bool
    var isOngoing: Bool
    var ongoingSince: Date?
    var hasPassedSoftThreshold: Bool
    var completedStepCount: Int
    var isInProgress: Bool
    var nextStepTitle: String?
    var checklistItemCount: Int
    var completedChecklistItemCount: Int
    var dueChecklistItemCount: Int
    var hasDailyRunoutChecklistItem: Bool = false
    var nextPendingChecklistItemTitle: String?
    var nextDueChecklistItemTitle: String?
    var doneCount: Int
    var manualSectionOrders: [String: Int] = [:]
    var color: RoutineTaskColor = .none
    var todoState: TodoState? = nil
    var assignedSprintID: UUID? = nil
    var assignedSprintTitle: String? = nil
    var assignedBacklogID: UUID? = nil
    var assignedBacklogTitle: String? = nil
}

enum HomeRoutineRowTone: Equatable {
    case teal
    case blue
    case orange
    case green
    case red
}

enum HomeRoutineRowToneResolver {
    static func tone(for task: HomeRoutineDisplay, referenceDate: Date) -> HomeRoutineRowTone {
        if task.isPaused {
            return .teal
        }
        if case .away = task.locationAvailability {
            return .blue
        }
        if task.isInProgress {
            return .orange
        }
        if task.isOneOffTask {
            return task.isCompletedOneOff ? .green : (task.isCanceledOneOff ? .orange : .blue)
        }
        if task.scheduleMode.isChecklistCompletionMode
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return .orange
        }
        if task.recurrenceRule.isFixedCalendar {
            switch fixedCalendarUrgencyLevel(for: task) {
            case 3:
                return .red
            case 2, 1:
                return .orange
            default:
                return .green
            }
        }

        let progress = Double(daysSinceScheduleAnchor(task, referenceDate: referenceDate)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    private static func fixedCalendarUrgencyLevel(for task: HomeRoutineDisplay) -> Int {
        if task.hasMissedExactTimedOccurrence { return 3 }
        if task.daysUntilDue < 0 { return 3 }
        if task.daysUntilDue == 0 { return 2 }
        if task.daysUntilDue == 1 { return 1 }
        return 0
    }

    private static func daysSinceScheduleAnchor(
        _ task: HomeRoutineDisplay,
        referenceDate: Date
    ) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(
            from: task.scheduleAnchor ?? task.lastDone,
            referenceDate: referenceDate
        )
    }
}
