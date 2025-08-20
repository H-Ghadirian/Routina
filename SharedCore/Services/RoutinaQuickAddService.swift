import Foundation
import SwiftData
import UserNotifications

enum RoutinaQuickAddError: LocalizedError, Equatable {
    case emptyInput
    case duplicateTaskName(String)
    case taskNotFound(String?)
    case taskAlreadyCompleted(String)
    case checklistCompletionRequiresApp(String)
    case activeFocusSession(String?)
    case invalidFocusDuration

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Enter a task to add."
        case let .duplicateTaskName(name):
            return "\"\(name)\" already exists."
        case let .taskNotFound(name):
            if let name, !name.isEmpty {
                return "No task matching \"\(name)\" was found."
            }
            return "No due task was found."
        case let .taskAlreadyCompleted(name):
            return "\"\(name)\" is already done."
        case let .checklistCompletionRequiresApp(name):
            return "\"\(name)\" uses checklist steps. Open Routina to choose the items to complete."
        case let .activeFocusSession(name):
            if let name {
                return "A focus session is already active for \"\(name)\"."
            }
            return "A focus session is already active."
        case .invalidFocusDuration:
            return "Choose a focus duration from 1 to 720 minutes."
        }
    }
}

struct RoutinaQuickAddCreateResult: Equatable, Sendable {
    var taskID: UUID
    var taskName: String
    var draft: RoutinaQuickAddDraft
    var matchedPlaceName: String?
}

struct RoutinaQuickAddCompletionResult: Equatable, Sendable {
    var taskID: UUID
    var taskName: String
    var message: String
}

struct RoutinaQuickAddFocusResult: Equatable, Sendable {
    var sessionID: UUID
    var taskID: UUID
    var taskName: String
    var durationMinutes: Int
}

enum RoutinaQuickAddService {
    @MainActor
    static func createTask(
        from text: String,
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) async throws -> RoutinaQuickAddCreateResult {
        guard var draft = RoutinaQuickAddParser.parse(
            text,
            referenceDate: referenceDate,
            calendar: calendar
        ), let trimmedName = RoutineTask.trimmedName(draft.name),
           !trimmedName.isEmpty
        else {
            throw RoutinaQuickAddError.emptyInput
        }

        draft.name = trimmedName

        if try HomeDeduplicationSupport.hasDuplicateRoutineName(trimmedName, in: context) {
            throw RoutinaQuickAddError.duplicateTaskName(trimmedName)
        }

        let place = try matchedPlace(named: draft.placeName, context: context)
        let request = draft.saveRequest(placeID: place?.id)
        let goalIDs = try RoutineGoalPersistence.ensureGoals(request.goals, in: context)
        let task = HomeAddRoutineSupport.makeRoutine(
            from: request,
            name: trimmedName,
            goalIDs: goalIDs,
            scheduleAnchor: referenceDate
        )

        context.insert(task)
        for attachment in HomeAddRoutineSupport.makeAttachments(from: request, taskID: task.id) {
            context.insert(attachment)
        }

        try context.save()
        await refreshNotification(for: task, referenceDate: referenceDate, calendar: calendar)
        notifyDataChanged(using: context)

        return RoutinaQuickAddCreateResult(
            taskID: task.id,
            taskName: trimmedName,
            draft: draft,
            matchedPlaceName: place?.displayName
        )
    }

    @MainActor
    static func markBestMatchingTaskDone(
        named taskName: String?,
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) async throws -> RoutinaQuickAddCompletionResult {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        guard let task = bestTaskMatch(
            named: taskName,
            in: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            throw RoutinaQuickAddError.taskNotFound(taskName)
        }

        let name = task.displayNameForQuickAdd
        guard !task.isCompletedOneOff, !task.isCanceledOneOff else {
            throw RoutinaQuickAddError.taskAlreadyCompleted(name)
        }
        guard !task.isChecklistCompletionRoutine else {
            throw RoutinaQuickAddError.checklistCompletionRequiresApp(name)
        }

        if task.isChecklistDriven {
            guard let update = try RoutineLogHistory.markDueChecklistItemsPurchased(
                taskID: task.id,
                purchasedAt: referenceDate,
                context: context,
                calendar: calendar
            ) else {
                throw RoutinaQuickAddError.taskAlreadyCompleted(name)
            }
            await refreshNotification(for: update.task, referenceDate: referenceDate, calendar: calendar)
            notifyDataChanged(using: context)
            let itemText = update.updatedItemCount == 1 ? "item" : "items"
            return RoutinaQuickAddCompletionResult(
                taskID: update.task.id,
                taskName: name,
                message: "Marked \(update.updatedItemCount) checklist \(itemText) done for \(name)."
            )
        }

        guard let update = try RoutineLogHistory.advanceTask(
            taskID: task.id,
            completedAt: referenceDate,
            context: context,
            calendar: calendar
        ) else {
            throw RoutinaQuickAddError.taskNotFound(taskName)
        }

        switch update.result {
        case .ignoredPaused:
            throw RoutinaQuickAddError.taskNotFound(taskName)
        case .ignoredAlreadyCompletedToday:
            throw RoutinaQuickAddError.taskAlreadyCompleted(name)
        case .advancedStep, .advancedChecklist, .completedRoutine:
            await refreshNotification(for: update.task, referenceDate: referenceDate, calendar: calendar)
            notifyDataChanged(using: context)
            return RoutinaQuickAddCompletionResult(
                taskID: update.task.id,
                taskName: name,
                message: completionMessage(for: update.result, taskName: name)
            )
        }
    }

    @MainActor
    static func startFocusSession(
        taskName: String?,
        durationMinutes: Int = 25,
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) throws -> RoutinaQuickAddFocusResult {
        guard (1...720).contains(durationMinutes) else {
            throw RoutinaQuickAddError.invalidFocusDuration
        }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        if let activeSession = sessions.first(where: { $0.state == .active }) {
            let activeTaskName = tasks.first { $0.id == activeSession.taskID }?.displayNameForQuickAdd
            throw RoutinaQuickAddError.activeFocusSession(activeTaskName)
        }
        if let sprintBoardData = try? SprintBoardClient.loadLiveSnapshot(),
           let activeSprintFocusSession = sprintBoardData.activeFocusSession {
            let activeSprintTitle = sprintBoardData.sprints
                .first(where: { $0.id == activeSprintFocusSession.sprintID })?
                .title
            throw RoutinaQuickAddError.activeFocusSession(activeSprintTitle)
        }

        guard let task = focusTaskMatch(
            named: taskName,
            in: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        ) else {
            throw RoutinaQuickAddError.taskNotFound(taskName)
        }

        let session = FocusSession(
            taskID: task.id,
            startedAt: referenceDate,
            plannedDurationSeconds: TimeInterval(durationMinutes * 60)
        )
        context.insert(session)
        try context.save()
        notifyDataChanged(using: context)

        return RoutinaQuickAddFocusResult(
            sessionID: session.id,
            taskID: task.id,
            taskName: task.displayNameForQuickAdd,
            durationMinutes: durationMinutes
        )
    }

    @MainActor
    static func todaySummary(
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) throws -> String {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let activeTasks = tasks.filter { task in
            !task.isArchived(referenceDate: referenceDate, calendar: calendar)
                && !task.isCompletedOneOff
                && !task.isCanceledOneOff
        }
        let dueTasks = activeTasks.filter { task in
            !task.isSoftIntervalRoutine
                && RoutineDateMath.daysUntilDue(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) <= 0
        }
        let overdueCount = dueTasks.filter { task in
            RoutineDateMath.daysUntilDue(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ) < 0
        }.count

        guard !dueTasks.isEmpty else {
            return "Nothing is due today in Routina."
        }

        let names = dueTasks
            .sorted { taskSortKey($0, referenceDate: referenceDate, calendar: calendar) < taskSortKey($1, referenceDate: referenceDate, calendar: calendar) }
            .prefix(3)
            .map(\.displayNameForQuickAdd)
            .joined(separator: ", ")
        let overdueText = overdueCount > 0 ? " \(overdueCount) overdue." : ""
        return "\(dueTasks.count) due today.\(overdueText) Top items: \(names)."
    }

    @MainActor
    private static func matchedPlace(
        named placeName: String?,
        context: ModelContext
    ) throws -> RoutinePlace? {
        guard let placeName,
              let normalizedName = RoutinePlace.normalizedName(placeName)
        else {
            return nil
        }

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        return places.first { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }
    }

    private static func bestTaskMatch(
        named taskName: String?,
        in tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> RoutineTask? {
        if let namedMatch = namedTaskMatch(taskName, in: tasks) {
            return namedMatch
        }

        return tasks
            .filter { task in
                !task.isChecklistCompletionRoutine
                    && RoutineDateMath.canMarkDone(
                        for: task,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                    && !task.isCompletedOneOff
                    && !task.isCanceledOneOff
            }
            .sorted { taskSortKey($0, referenceDate: referenceDate, calendar: calendar) < taskSortKey($1, referenceDate: referenceDate, calendar: calendar) }
            .first
    }

    private static func focusTaskMatch(
        named taskName: String?,
        in tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> RoutineTask? {
        if let namedMatch = namedTaskMatch(taskName, in: tasks),
           !namedMatch.isArchived(referenceDate: referenceDate, calendar: calendar),
           !namedMatch.isCompletedOneOff,
           !namedMatch.isCanceledOneOff {
            return namedMatch
        }

        let candidates = tasks.filter { task in
            !task.isArchived(referenceDate: referenceDate, calendar: calendar)
                && !task.isCompletedOneOff
                && !task.isCanceledOneOff
        }

        return candidates
            .filter(\.focusModeEnabled)
            .sorted { taskSortKey($0, referenceDate: referenceDate, calendar: calendar) < taskSortKey($1, referenceDate: referenceDate, calendar: calendar) }
            .first
            ?? candidates
                .sorted { taskSortKey($0, referenceDate: referenceDate, calendar: calendar) < taskSortKey($1, referenceDate: referenceDate, calendar: calendar) }
                .first
    }

    private static func namedTaskMatch(_ taskName: String?, in tasks: [RoutineTask]) -> RoutineTask? {
        guard let taskName,
              let normalizedQuery = RoutineTask.normalizedName(taskName)
        else {
            return nil
        }

        let activeTasks = tasks.filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
        if let exact = activeTasks.first(where: { RoutineTask.normalizedName($0.name) == normalizedQuery }) {
            return exact
        }

        return activeTasks.first { task in
            guard let normalizedName = RoutineTask.normalizedName(task.name) else { return false }
            return normalizedName.contains(normalizedQuery)
        }
    }

    private static func taskSortKey(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> (Int, Int, String) {
        let dueDays = RoutineDateMath.daysUntilDue(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let priorityRank = -task.priority.sortOrder
        return (dueDays, priorityRank, task.displayNameForQuickAdd)
    }

    private static func completionMessage(
        for result: RoutineAdvanceResult,
        taskName: String
    ) -> String {
        switch result {
        case let .advancedStep(completedSteps, totalSteps):
            return "Completed step \(completedSteps) of \(totalSteps) for \(taskName)."
        case let .advancedChecklist(completedItems, totalItems):
            return "Completed checklist item \(completedItems) of \(totalItems) for \(taskName)."
        case .completedRoutine:
            return "Marked \(taskName) done."
        case .ignoredPaused, .ignoredAlreadyCompletedToday:
            return "\(taskName) was not changed."
        }
    }

    @MainActor
    private static func refreshNotification(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) async {
        if NotificationCoordinator.shouldScheduleNotification(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            await scheduleNotification(
                NotificationCoordinator.notificationPayload(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                ),
                now: referenceDate
            )
        } else {
            cancelNotification(task.id.uuidString)
        }
    }

    private static func scheduleNotification(
        _ payload: NotificationPayload,
        now: Date
    ) async {
#if SWIFT_PACKAGE
        return
#else
        guard NotificationPreferences.notificationsEnabled else { return }
        cancelNotification(payload.identifier)

        let request = UNNotificationRequest(
            identifier: payload.identifier,
            content: NotificationCoordinator.createNotificationContent(for: payload),
            trigger: NotificationCoordinator.createNotificationTrigger(for: payload, now: now)
        )
        try? await UNUserNotificationCenter.current().add(request)
#endif
    }

    private static func cancelNotification(_ identifier: String) {
#if SWIFT_PACKAGE
        return
#else
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
#endif
    }

    @MainActor
    private static func notifyDataChanged(using context: ModelContext) {
        WidgetStatsService.refreshAndReload(using: context)
        NotificationCenter.default.postRoutineDidUpdate()
    }
}

private extension RoutineTask {
    var displayNameForQuickAdd: String {
        RoutineTask.trimmedName(name).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled task"
    }
}
