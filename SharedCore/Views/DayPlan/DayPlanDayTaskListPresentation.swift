import Foundation

enum DayPlanDayTaskListPresentation {
    static func items(
        on date: Date,
        timedBlocks: [DayPlanBlock],
        allDayBlocks: [DayPlanAllDayBlock],
        plannedDateTasks: [RoutineTask] = [],
        timelineActivityBlocks: [DayPlanTimelineActivityBlock] = [],
        tasks: [RoutineTask] = [],
        logs: [RoutineLog] = [],
        referenceDate: Date = Date(),
        calendar: Calendar,
        excludedTaskIDs: Set<UUID> = [],
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache? = nil
    ) -> [DayPlanDayTaskListItem] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let completionContext = DayPlanDayTaskListCompletionContext(
            tasks: tasks,
            logs: logs,
            calendar: calendar
        )
        let allDayItems =
            allDayBlocks
            .enumerated()
            .compactMap { offset, allDayBlock -> DayPlanDayTaskListItem? in
                guard let taskID = allDayBlock.taskID,
                    !allDayBlock.isEvent,
                    !excludedTaskIDs.contains(taskID),
                    allDayBlockIntersects(allDayBlock, date: date, calendar: calendar)
                else {
                    return nil
                }
                guard
                    let section = completionContext.sectionForPlannerBackedTask(
                        taskID,
                        dayKey: dayKey
                    )
                else {
                    return nil
                }

                return DayPlanDayTaskListItem(
                    id: "all-day-\(taskID.uuidString)-\(offset)",
                    taskID: taskID,
                    blockID: nil,
                    title: allDayBlock.title,
                    emoji: allDayBlock.emoji,
                    section: section,
                    placement: .allDay,
                    doneOccurrence: section.isRecordedCompletion
                        ? completionContext.doneOccurrence(taskID, dayKey: dayKey)
                        : nil
                )
            }
            .sorted { lhs, rhs in
                let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id < rhs.id
            }

        let plannedTaskIDs = Set(allDayItems.map(\.taskID) + timedBlocks.map(\.taskID))
        let plannedDateItems =
            plannedDateTasks
            .compactMap { task -> DayPlanDayTaskListItem? in
                guard !plannedTaskIDs.contains(task.id),
                    !excludedTaskIDs.contains(task.id),
                    !completionContext.hasCompletion(
                        task.id,
                        dayKey: dayKey
                    ),
                    isVisiblePlannedDateTask(
                        task,
                        on: date,
                        calendar: calendar,
                        visibilityCache: visibilityCache
                    )
                else {
                    return nil
                }

                return DayPlanDayTaskListItem(
                    id: "planned-date-\(task.id.uuidString)",
                    taskID: task.id,
                    blockID: nil,
                    title: DayPlanTaskSorting.title(for: task),
                    emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                    placement: .anyTime
                )
            }
            .sorted { lhs, rhs in
                let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id < rhs.id
            }

        let timedItems =
            timedBlocks
            .compactMap { block -> DayPlanDayTaskListItem? in
                guard !excludedTaskIDs.contains(block.taskID) else { return nil }
                let section: DayPlanDayTaskListItem.Section
                if block.taskID == FocusSession.unassignedTaskID {
                    section = .done
                } else {
                    guard
                        let plannerSection = completionContext.sectionForPlannerBackedTask(
                            block.taskID,
                            dayKey: dayKey
                        )
                    else {
                        return nil
                    }
                    section = plannerSection
                }

                return DayPlanDayTaskListItem(
                    id: "timed-\(block.id.uuidString)",
                    taskID: block.taskID,
                    blockID: block.id,
                    title: block.titleSnapshot,
                    emoji: block.emojiSnapshot,
                    section: section,
                    placement: .timed(
                        startMinute: block.startMinute,
                        durationMinutes: block.durationMinutes
                    ),
                    doneOccurrence: section.isRecordedCompletion
                        ? completionContext.doneOccurrence(block.taskID, dayKey: dayKey)
                        : nil
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.placement, rhs.placement) {
                case let (.timed(lhsStart, _), .timed(rhsStart, _)) where lhsStart != rhsStart:
                    return lhsStart < rhsStart
                default:
                    let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                    if titleComparison != .orderedSame {
                        return titleComparison == .orderedAscending
                    }
                    return lhs.id < rhs.id
                }
            }

        let activityItems =
            timelineActivityBlocks
            .compactMap { activity -> DayPlanDayTaskListItem? in
                guard activity.kind == .completed else { return nil }

                let block = activity.block
                guard !excludedTaskIDs.contains(block.taskID) else { return nil }
                let section: DayPlanDayTaskListItem.Section
                let identifierPrefix: String
                if activity.source.isSyntheticAssumedDone {
                    section = .assumedDone
                    identifierPrefix = "assumed"
                } else if activity.isConfirmedAssumedDone {
                    section = .confirmedAssumedDone
                    identifierPrefix = "confirmed-assumed"
                } else {
                    section = .done
                    identifierPrefix = "done"
                }
                return DayPlanDayTaskListItem(
                    id: "\(identifierPrefix)-\(activity.id)",
                    taskID: block.taskID,
                    blockID: nil,
                    title: block.titleSnapshot,
                    emoji: block.emojiSnapshot,
                    section: section,
                    placement: activity.hasSpecificTime
                        ? .timed(
                            startMinute: block.startMinute,
                            durationMinutes: block.durationMinutes
                        )
                        : .durationOnly(durationMinutes: block.durationMinutes),
                    doneOccurrence: activity.source.isSyntheticAssumedDone
                        ? nil
                        : DayPlanDoneTaskOccurrence(
                            source: activity.source,
                            completedAt: block.updatedAt,
                            durationMinutes: block.durationMinutes,
                            hasSpecificTime: activity.hasSpecificTime
                        )
                )
            }

        let assumedDoneItems = sortedActivityItems(
            activityItems.filter { $0.section == .assumedDone }
        )
        let assumedDoneTaskIDs = Set(assumedDoneItems.map(\.taskID))
        let plannerBackedRecordedCompletionItems =
            (allDayItems.filter { $0.section.isRecordedCompletion }
            + timedItems.filter { $0.section.isRecordedCompletion })
            .map { recordedCompletionItem($0, calendar: calendar) }
        let rawRecordedCompletionItems = sortedActivityItems(
            plannerBackedRecordedCompletionItems
                + activityItems.filter { $0.section.isRecordedCompletion }
        )
        let confirmedAssumedDoneItems = rawRecordedCompletionItems.filter {
            $0.section == .confirmedAssumedDone
        }
        let rawDoneItems = rawRecordedCompletionItems.filter { $0.section == .done }
        let plannedAllDayItems = allDayItems.filter { $0.section == .planned && !assumedDoneTaskIDs.contains($0.taskID) }
        let plannedTimedItems = timedItems.filter { $0.section == .planned && !assumedDoneTaskIDs.contains($0.taskID) }
        let visibleTaskIDsBeforeFulfillmentSuppression = Set(
            (plannedAllDayItems
                + plannedDateItems
                + plannedTimedItems
                + assumedDoneItems
                + confirmedAssumedDoneItems
                + rawDoneItems)
                .map(\.taskID)
        )
        let doneItems = rawDoneItems.filter { item in
            let sourceTaskIDs = completionContext.fulfillmentSourceTaskIDs(
                for: item.taskID,
                dayKey: dayKey
            )
            guard !sourceTaskIDs.isEmpty,
                !completionContext.hasDirectCompletion(item.taskID, dayKey: dayKey),
                !sourceTaskIDs.isDisjoint(with: visibleTaskIDsBeforeFulfillmentSuppression)
            else {
                return true
            }
            return false
        }

        return
            (plannedAllDayItems
            + plannedDateItems
            + plannedTimedItems
            + assumedDoneItems
            + confirmedAssumedDoneItems
            + doneItems)
            .map { item in
                guard item.section == .planned,
                    let task = completionContext.task(item.taskID)
                else {
                    return item
                }
                var completableItem = item
                completableItem.plannedCompletionDate = DayPlanPlannedTaskCompletion.completionDate(
                    for: task,
                    on: date,
                    placement: item.placement,
                    referenceDate: referenceDate,
                    logs: logs,
                    calendar: calendar
                )
                return completableItem
            }
    }

    private static func sortedActivityItems(_ items: [DayPlanDayTaskListItem]) -> [DayPlanDayTaskListItem] {
        items.sorted { lhs, rhs in
            switch (lhs.placement, rhs.placement) {
            case let (.timed(lhsStart, _), .timed(rhsStart, _)) where lhsStart != rhsStart:
                return lhsStart < rhsStart
            default:
                let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                if titleComparison != .orderedSame {
                    return titleComparison == .orderedAscending
                }
                return lhs.id < rhs.id
            }
        }
    }

    private static func recordedCompletionItem(
        _ item: DayPlanDayTaskListItem,
        calendar: Calendar
    ) -> DayPlanDayTaskListItem {
        guard let occurrence = item.doneOccurrence else { return item }

        var recordedItem = item
        let workTiming = occurrence.workTiming(calendar: calendar)
        if occurrence.hasSpecificTime {
            recordedItem.placement = .timed(
                startMinute: workTiming.startMinute,
                durationMinutes: workTiming.durationMinutes
            )
        } else {
            recordedItem.placement = .durationOnly(
                durationMinutes: workTiming.durationMinutes
            )
        }
        return recordedItem
    }

    private static func allDayBlockIntersects(
        _ block: DayPlanAllDayBlock,
        date: Date,
        calendar: Calendar
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }
        return block.startDate < dayEnd && block.endDate > dayStart
    }

    private static func isVisiblePlannedDateTask(
        _ task: RoutineTask,
        on date: Date,
        calendar: Calendar,
        visibilityCache: DayPlanPlannedDateTaskVisibilityCache?
    ) -> Bool {
        guard let plannedDate = task.plannedDate else { return false }
        let dayStart = calendar.startOfDay(for: date)
        let isDailyRoutineForTaskList =
            visibilityCache?.isDailyRoutineForTaskList(task)
            ?? task.isDailyRoutineForTaskList
        return RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: task.scheduleMode,
            cadenceEnabled: task.cadenceEnabled,
            isDailyRoutine: isDailyRoutineForTaskList
        )
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
            && !task.isPinned
            && !task.isArchived(referenceDate: dayStart, calendar: calendar)
            && calendar.isDate(plannedDate, inSameDayAs: dayStart)
    }
}

private struct DayPlanDayTaskListCompletionContext {
    private var tasksByID: [UUID: RoutineTask] = [:]
    private var completedDayKeysByTaskID: [UUID: Set<String>] = [:]
    private var directCompletedDayKeysByTaskID: [UUID: Set<String>] = [:]
    private var confirmedAssumedDoneDayKeysByTaskID: [UUID: Set<String>] = [:]
    private var fulfillmentSourceTaskIDsByTaskIDAndDayKey: [UUID: [String: Set<UUID>]] = [:]
    private var doneOccurrencesByTaskIDAndDayKey: [UUID: [String: DayPlanDoneTaskOccurrence]] = [:]

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar
    ) {
        for task in tasks {
            tasksByID[task.id] = task
            if let lastDone = task.lastDone {
                guard let dayKey = recordCompletion(lastDone, taskID: task.id, calendar: calendar)
                else {
                    continue
                }
                recordDoneOccurrence(
                    DayPlanDoneTaskOccurrence(
                        source: .taskLastDone,
                        completedAt: lastDone,
                        durationMinutes: effectiveDurationMinutes(
                            actualDurationMinutes: task.actualDurationMinutes,
                            task: task
                        ),
                        hasSpecificTime: true
                    ),
                    taskID: task.id,
                    dayKey: dayKey
                )
            }
        }

        for log in logs where log.kind.resolvesDoneDate {
            guard let dayKey = recordCompletion(log.timestamp, taskID: log.taskID, calendar: calendar) else {
                continue
            }
            switch log.kind {
            case .completed:
                directCompletedDayKeysByTaskID[log.taskID, default: []].insert(dayKey)
                if log.isConfirmedAssumedDone {
                    confirmedAssumedDoneDayKeysByTaskID[log.taskID, default: []].insert(dayKey)
                }
                if let timestamp = log.timestamp {
                    recordDoneOccurrence(
                        DayPlanDoneTaskOccurrence(
                            source: .log(log.id),
                            completedAt: timestamp,
                            durationMinutes: effectiveDurationMinutes(
                                actualDurationMinutes: log.actualDurationMinutes,
                                task: tasksByID[log.taskID]
                            ),
                            hasSpecificTime: log.hasSpecificWorkTime ?? true
                        ),
                        taskID: log.taskID,
                        dayKey: dayKey
                    )
                }
            case .fulfilled:
                guard let sourceTaskID = log.sourceTaskID else { break }
                fulfillmentSourceTaskIDsByTaskIDAndDayKey[log.taskID, default: [:]][dayKey, default: []]
                    .insert(sourceTaskID)
            case .canceled, .missed:
                break
            }
        }
    }

    @discardableResult
    private mutating func recordCompletion(
        _ timestamp: Date?,
        taskID: UUID,
        calendar: Calendar
    ) -> String? {
        guard let timestamp else { return nil }
        let dayKey = displayDayKey(for: timestamp, taskID: taskID, calendar: calendar)
        completedDayKeysByTaskID[taskID, default: []].insert(dayKey)
        return dayKey
    }

    private func displayDayKey(
        for timestamp: Date,
        taskID: UUID,
        calendar: Calendar
    ) -> String {
        let displayDay =
            tasksByID[taskID]
            .flatMap { task in
                RoutineDateMath.completionDisplayDay(
                    for: task,
                    completionDate: timestamp,
                    calendar: calendar
                )
            }
            ?? calendar.startOfDay(for: timestamp)
        return DayPlanStorage.dayKey(for: displayDay, calendar: calendar)
    }

    func hasCompletion(
        _ taskID: UUID,
        dayKey: String
    ) -> Bool {
        completedDayKeysByTaskID[taskID]?.contains(dayKey) == true
    }

    func hasDirectCompletion(
        _ taskID: UUID,
        dayKey: String
    ) -> Bool {
        directCompletedDayKeysByTaskID[taskID]?.contains(dayKey) == true
    }

    func fulfillmentSourceTaskIDs(
        for taskID: UUID,
        dayKey: String
    ) -> Set<UUID> {
        fulfillmentSourceTaskIDsByTaskIDAndDayKey[taskID]?[dayKey] ?? []
    }

    func doneOccurrence(
        _ taskID: UUID,
        dayKey: String
    ) -> DayPlanDoneTaskOccurrence? {
        doneOccurrencesByTaskIDAndDayKey[taskID]?[dayKey]
    }

    func task(_ taskID: UUID) -> RoutineTask? {
        tasksByID[taskID]
    }

    func sectionForPlannerBackedTask(
        _ taskID: UUID,
        dayKey: String
    ) -> DayPlanDayTaskListItem.Section? {
        if hasCompletion(taskID, dayKey: dayKey) {
            return confirmedAssumedDoneDayKeysByTaskID[taskID]?.contains(dayKey) == true
                ? .confirmedAssumedDone
                : .done
        }
        if tasksByID[taskID]?.isCompletedOneOff == true {
            return nil
        }
        return .planned
    }

    private mutating func recordDoneOccurrence(
        _ occurrence: DayPlanDoneTaskOccurrence,
        taskID: UUID,
        dayKey: String
    ) {
        if let current = doneOccurrencesByTaskIDAndDayKey[taskID]?[dayKey] {
            if occurrence.completedAt < current.completedAt {
                return
            }
        }
        doneOccurrencesByTaskIDAndDayKey[taskID, default: [:]][dayKey] = occurrence
    }

    private func effectiveDurationMinutes(
        actualDurationMinutes: Int?,
        task: RoutineTask?
    ) -> Int {
        actualDurationMinutes
            ?? task?.estimatedDurationMinutes
            ?? DayPlanBlock.minimumDurationMinutes * 2
    }
}
