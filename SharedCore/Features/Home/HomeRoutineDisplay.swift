import Foundation

struct HomeRoutineDisplay: Equatable, Identifiable, HomeTaskListDisplay, HomeTaskRowDisplay {
    let taskID: UUID
    var id: UUID { taskID }
    var name: String
    var emoji: String
    var notes: String?
    var hasImage: Bool
    var placeID: UUID?
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
    var priority: RoutineTaskPriority
    var importance: RoutineTaskImportance
    var urgency: RoutineTaskUrgency
    var pressure: RoutineTaskPressure = .none
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var snoozedUntil: Date?
    var pinnedAt: Date?
    var daysUntilDue: Int
    var isOneOffTask: Bool
    var isCompletedOneOff: Bool
    var isCanceledOneOff: Bool
    var isDoneToday: Bool
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
