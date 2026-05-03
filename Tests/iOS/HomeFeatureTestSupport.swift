import ComposableArchitecture
import Foundation
@testable @preconcurrency import Routina

@MainActor
func receiveTaskDetailNotificationStatus(
    _ store: TestStoreOf<HomeFeature>
) async {
    let isAlreadyLoaded = store.state.taskDetailState?.hasLoadedNotificationStatus == true
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
    lastDone: Date?,
    canceledAt: Date? = nil,
    dueDate: Date? = nil,
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
    nextPendingChecklistItemTitle: String? = nil,
    nextDueChecklistItemTitle: String? = nil,
    doneCount: Int = 0
) -> HomeFeature.RoutineDisplay {
    let resolvedScheduleAnchor = scheduleAnchor ?? lastDone
    let resolvedIsPaused = isPaused || pausedAt != nil || snoozedUntil != nil
    let resolvedIsOneOffTask = isOneOffTask || scheduleMode == .oneOff
    let resolvedIsCompletedOneOff = isCompletedOneOff || (resolvedIsOneOffTask && lastDone != nil && !isInProgress)
    let resolvedDaysUntilDue = daysUntilDue ?? (resolvedIsPaused ? 0 : ((resolvedIsCompletedOneOff || isCanceledOneOff) ? Int.max : interval))
    let resolvedRecurrenceRule = recurrenceRule ?? .interval(days: interval)
    return HomeFeature.RoutineDisplay(
        taskID: taskID,
        name: name,
        emoji: emoji,
        notes: nil,
        hasImage: false,
        placeID: placeID,
        placeName: placeName,
        locationAvailability: locationAvailability,
        tags: tags,
        steps: steps,
        interval: interval,
        recurrenceRule: resolvedRecurrenceRule,
        scheduleMode: scheduleMode,
        isSoftIntervalRoutine: scheduleMode == .softInterval,
        lastDone: lastDone,
        canceledAt: canceledAt,
        dueDate: dueDate,
        priority: priority,
        importance: importance,
        urgency: urgency,
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
        nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
        nextDueChecklistItemTitle: nextDueChecklistItemTitle,
        doneCount: doneCount
    )
}
