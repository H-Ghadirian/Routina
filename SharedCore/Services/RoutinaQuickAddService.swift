import Foundation
import SwiftData
import UserNotifications

enum RoutinaQuickAddService {
    @MainActor
    static func createTask(
        from text: String,
        context: ModelContext,
        referenceDate: Date = .now,
        calendar: Calendar = .current,
        includingPlaces: Bool = SharedDefaults.app[.appSettingPlacesEnabled],
        reminderAt: Date? = nil,
        taskNameOverride: String? = nil,
        primaryLinkTitle: String? = nil
    ) async throws -> RoutinaQuickAddCreateResult {
        guard
            var draft = RoutinaQuickAddParser.parse(
                text,
                referenceDate: referenceDate,
                calendar: calendar,
                includingPlaces: includingPlaces
            )
        else {
            throw RoutinaQuickAddError.emptyInput
        }

        if let taskNameOverride,
            let trimmedOverride = RoutineTask.trimmedName(taskNameOverride),
            !trimmedOverride.isEmpty
        {
            draft.name = trimmedOverride
        }
        if let primaryLinkTitle,
            let firstLink = draft.linkItems.first,
            let url = URL(string: firstLink.url),
            let resolvedTitle = RoutinaQuickAddLinkSupport.resolvedLinkTitle(
                from: primaryLinkTitle,
                url: url
            )
        {
            draft.linkItems[0].title = resolvedTitle
        }

        guard let trimmedName = RoutineTask.trimmedName(draft.name),
            !trimmedName.isEmpty
        else {
            throw RoutinaQuickAddError.emptyInput
        }

        draft.name = trimmedName
        draft.reminderAt = reminderAt ?? draft.reminderAt

        if try HomeDeduplicationSupport.hasDuplicateRoutineName(trimmedName, in: context) {
            throw RoutinaQuickAddError.duplicateTaskName(trimmedName)
        }

        draft.tags = try canonicalTags(for: draft.tags, context: context)
        let place = includingPlaces ? try matchedPlace(named: draft.placeName, context: context) : nil
        let request = draft.saveRequest(placeID: place?.id, calendar: calendar)
        let goalIDs = try RoutineGoalPersistence.ensureGoals(request.goals, in: context)
        let task = HomeAddRoutineSupport.makeRoutine(
            from: request,
            name: trimmedName,
            goalIDs: goalIDs,
            scheduleAnchor: referenceDate
        )
        task.hasExplicitImportance = draft.hasExplicitPriority
        task.hasExplicitUrgency = draft.hasExplicitPriority

        context.insert(task)
        for attachment in HomeAddRoutineSupport.makeAttachments(from: request, taskID: task.id) {
            context.insert(attachment)
        }
        DeviceActivityRecorder.recordAction(
            .created,
            entity: .task,
            entityID: task.id,
            entityTitle: trimmedName,
            details: "Quick Add",
            in: context
        )

        try context.save()
        do {
            try SprintBoardClient.routeNewTodoToMatchingBacklog(task)
        } catch {
            RoutinaLog.error("Failed to route quick add task to backlog: \(error)")
        }
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
        guard
            let task = RoutinaQuickAddTaskMatcher.bestTaskMatch(
                named: taskName,
                in: tasks,
                referenceDate: referenceDate,
                calendar: calendar
            )
        else {
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
            guard
                let update = try RoutineLogHistory.markDueChecklistItemsDone(
                    taskID: task.id,
                    doneAt: referenceDate,
                    context: context,
                    calendar: calendar
                )
            else {
                throw RoutinaQuickAddError.taskAlreadyCompleted(name)
            }
            await refreshNotification(for: update.task, referenceDate: referenceDate, calendar: calendar)
            notifyDataChanged(using: context)
            let itemText = update.update.updatedItemCount == 1 ? "item" : "items"
            return RoutinaQuickAddCompletionResult(
                taskID: update.task.id,
                taskName: name,
                message: "Marked \(update.update.updatedItemCount) checklist \(itemText) done for \(name)."
            )
        }

        guard
            let update = try RoutineLogHistory.advanceTask(
                taskID: task.id,
                completedAt: referenceDate,
                context: context,
                calendar: calendar
            )
        else {
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
        guard try SleepSessionSupport.activeSession(in: context) == nil else {
            throw RoutinaQuickAddError.activeSleepSession
        }
        if SharedDefaults.app[.appSettingAwayEnabled] {
            guard try AwaySessionSupport.activeSession(in: context) == nil else {
                throw RoutinaQuickAddError.activeAwaySession
            }
        }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        if let activeSession = sessions.first(where: { $0.state == .active }) {
            let activeTaskName =
                activeSession.focusTagTitle
                ?? (activeSession.isUnassigned
                    ? "Unassigned focus"
                    : tasks.first { $0.id == activeSession.taskID }?.displayNameForQuickAdd)
            throw RoutinaQuickAddError.activeFocusSession(activeTaskName)
        }
        if let sprintBoardData = try? SprintBoardClient.loadLiveSnapshot(),
            let activeSprintFocusSession = sprintBoardData.activeFocusSession
        {
            let activeSprintTitle = sprintBoardData.sprints
                .first(where: { $0.id == activeSprintFocusSession.sprintID })?
                .title
            throw RoutinaQuickAddError.activeFocusSession(activeSprintTitle)
        }

        guard let taskName, !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let session = try FocusSessionSupport.startUnassignedFocus(
                startedAt: referenceDate,
                plannedDurationSeconds: TimeInterval(durationMinutes * 60),
                context: context
            )
            return RoutinaQuickAddFocusResult(
                sessionID: session.id,
                taskID: session.taskID,
                taskName: "Unassigned focus",
                durationMinutes: durationMinutes
            )
        }

        guard
            let task = RoutinaQuickAddTaskMatcher.focusTaskMatch(
                named: taskName,
                in: tasks,
                referenceDate: referenceDate,
                calendar: calendar
            )
        else {
            throw RoutinaQuickAddError.taskNotFound(taskName)
        }

        let session = FocusSession(
            taskID: task.id,
            startedAt: referenceDate,
            plannedDurationSeconds: TimeInterval(durationMinutes * 60)
        )
        context.insert(session)
        DeviceActivityRecorder.recordAction(
            .started,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: task.displayNameForQuickAdd,
            in: context
        )
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
        return RoutinaQuickAddTaskMatcher.todaySummary(
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
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

    @MainActor
    private static func canonicalTags(
        for tags: [String],
        context: ModelContext
    ) throws -> [String] {
        guard !tags.isEmpty else { return [] }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let notes =
            SharedDefaults.app[.appSettingNotesEnabled]
            ? try context.fetch(FetchDescriptor<RoutineNote>())
            : []
        let availableTags = RoutineTag.allTags(
            from: tasks.map(\.tags) + goals.map(\.tags) + notes.map(\.tags)
        )
        return RoutineTag.deduplicated(tags, preferredTags: availableTags)
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
            _ = now
            await NotificationCoordinator.scheduleNotification(payload)
        #endif
    }

    private static func cancelNotification(_ identifier: String) {
        #if SWIFT_PACKAGE
            return
        #else
            NotificationCoordinator.cancelNotification(identifier)
        #endif
    }

    @MainActor
    private static func notifyDataChanged(using context: ModelContext) {
        WidgetStatsService.refreshAndReload(using: context)
        NotificationCenter.default.postRoutineDidUpdate()
    }
}
