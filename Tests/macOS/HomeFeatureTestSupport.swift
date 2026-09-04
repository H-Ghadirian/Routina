import ComposableArchitecture
import Foundation
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
func receiveTaskDetailNotificationStatus(
    _ store: TestStoreOf<HomeFeature>
) async {
    let isAlreadyLoaded =
        store.state.taskDetailState?.hasLoadedNotificationStatus == true
        && store.state.taskDetailState?.appNotificationsEnabled == false
        && store.state.taskDetailState?.systemNotificationsAuthorized == false
    if isAlreadyLoaded {
        await store.receive(.taskDetail(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false)))
    } else {
        await store.receive(.taskDetail(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false))) {
            $0.taskDetailState?.hasLoadedNotificationStatus = true
            $0.taskDetailState?.appNotificationsEnabled = false
            $0.taskDetailState?.systemNotificationsAuthorized = false
        }
    }
}

func makeDisplay(
    taskID: UUID,
    name: String,
    emoji: String,
    placeID: UUID? = nil,
    placeName: String? = nil,
    locationAvailability: RoutineLocationAvailability = .unrestricted,
    tags: [String] = [],
    steps: [String] = [],
    interval: Int,
    recurrenceRule: RoutineRecurrenceRule? = nil,
    scheduleMode: RoutineScheduleMode = .fixedInterval,
    cadenceEnabled: Bool = true,
    createdAt: Date? = nil,
    lastDone: Date?,
    canceledAt: Date? = nil,
    dueDate: Date? = nil,
    plannedDate: Date? = nil,
    priority: RoutineTaskPriority = .none,
    importance: RoutineTaskImportance = .level2,
    urgency: RoutineTaskUrgency = .level2,
    scheduleAnchor: Date? = nil,
    pausedAt: Date? = nil,
    snoozedUntil: Date? = nil,
    pinnedAt: Date? = nil,
    daysUntilDue: Int? = nil,
    isOneOffTask: Bool = false,
    isCompletedOneOff: Bool = false,
    isCanceledOneOff: Bool = false,
    isDoneToday: Bool,
    isPaused: Bool = false,
    completedStepCount: Int = 0,
    isInProgress: Bool = false,
    nextStepTitle: String? = nil,
    checklistItemCount: Int = 0,
    completedChecklistItemCount: Int = 0,
    dueChecklistItemCount: Int = 0,
    hasDailyRunoutChecklistItem: Bool = false,
    nextPendingChecklistItemTitle: String? = nil,
    nextDueChecklistItemTitle: String? = nil,
    doneCount: Int = 0,
    todoState: TodoState? = nil,
    assignedSprintID: UUID? = nil,
    assignedSprintTitle: String? = nil,
    assignedBacklogID: UUID? = nil,
    assignedBacklogTitle: String? = nil
) -> HomeFeature.RoutineDisplay {
    let resolvedIsPaused = isPaused || pausedAt != nil || snoozedUntil != nil
    let resolvedIsOneOffTask = isOneOffTask || scheduleMode == .oneOff
    let resolvedScheduleAnchor = scheduleAnchor ?? (resolvedIsOneOffTask ? nil : lastDone)
    let resolvedIsCompletedOneOff = isCompletedOneOff || (resolvedIsOneOffTask && lastDone != nil && !isInProgress)
    let resolvedDaysUntilDue =
        daysUntilDue ?? (resolvedIsPaused ? 0 : ((resolvedIsCompletedOneOff || isCanceledOneOff) ? Int.max : interval))
    let resolvedRecurrenceRule = recurrenceRule ?? .interval(days: interval)
    return HomeFeature.RoutineDisplay(
        taskID: taskID,
        name: name,
        emoji: emoji,
        notes: nil,
        hasImage: false,
        placeID: placeID,
        placeIDs: placeID.map { [$0] } ?? [],
        placeName: placeName,
        locationAvailability: locationAvailability,
        tags: tags,
        taskListTagSectionDescriptor: HomeTaskListTagGrouping.descriptor(for: tags),
        indexedSearchText: HomeTaskSearchIndex.make(
            name: name,
            emoji: emoji,
            taskDescription: nil,
            notes: nil,
            placeName: placeName,
            tags: tags,
            flags: [],
            goalTitles: []
        ),
        steps: steps,
        interval: interval,
        recurrenceRule: resolvedRecurrenceRule,
        scheduleMode: scheduleMode,
        cadenceEnabled: cadenceEnabled,
        createdAt: createdAt,
        isSoftIntervalRoutine: scheduleMode.isSoftIntervalRoutine,
        surfacesSoftIntervalNudges: cadenceEnabled && scheduleMode.isSoftIntervalRoutine,
        lastDone: lastDone,
        canceledAt: canceledAt,
        dueDate: dueDate,
        plannedDate: plannedDate,
        priority: priority,
        importance: importance,
        urgency: urgency,
        currentTaskLadderImportanceOverride: importance,
        currentTaskLadderUrgencyOverride: urgency,
        currentTaskLadderPressureOverride: RoutineTaskPressure.none,
        scheduleAnchor: resolvedScheduleAnchor,
        pausedAt: pausedAt,
        snoozedUntil: snoozedUntil,
        pinnedAt: pinnedAt,
        daysUntilDue: resolvedDaysUntilDue,
        isOneOffTask: resolvedIsOneOffTask,
        isCompletedOneOff: resolvedIsCompletedOneOff,
        isCanceledOneOff: isCanceledOneOff,
        isDoneToday: isDoneToday,
        isPaused: resolvedIsPaused,
        isSnoozed: snoozedUntil != nil,
        isPinned: pinnedAt != nil,
        isOngoing: false,
        ongoingSince: nil,
        hasPassedSoftThreshold: false,
        completedStepCount: completedStepCount,
        isInProgress: isInProgress,
        nextStepTitle: nextStepTitle,
        checklistItemCount: checklistItemCount,
        completedChecklistItemCount: completedChecklistItemCount,
        dueChecklistItemCount: dueChecklistItemCount,
        hasDailyRunoutChecklistItem: hasDailyRunoutChecklistItem,
        nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
        nextDueChecklistItemTitle: nextDueChecklistItemTitle,
        doneCount: doneCount,
        todoState: todoState,
        assignedSprintID: assignedSprintID,
        assignedSprintTitle: assignedSprintTitle,
        assignedBacklogID: assignedBacklogID,
        assignedBacklogTitle: assignedBacklogTitle
    )
}

func makeOneOffDisplay(
    taskID: UUID,
    name: String,
    emoji: String,
    completionDate: Date?
) -> HomeFeature.RoutineDisplay {
    var display = makeDisplay(
        taskID: taskID,
        name: name,
        emoji: emoji,
        interval: 1,
        scheduleMode: .oneOff,
        lastDone: completionDate,
        daysUntilDue: completionDate == nil ? 0 : .max,
        isOneOffTask: true,
        isCompletedOneOff: completionDate != nil,
        isDoneToday: completionDate != nil,
        doneCount: completionDate == nil ? 0 : 1
    )
    if completionDate != nil {
        display.todoState = .done
    }
    return display
}
