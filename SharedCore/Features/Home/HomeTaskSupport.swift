import Foundation
import SwiftData

struct HomeDoneStats: Equatable {
    var totalCount: Int = 0
    var countsByTaskID: [UUID: Int] = [:]
    var canceledTotalCount: Int = 0
    var canceledCountsByTaskID: [UUID: Int] = [:]
    var canceledDatesByTaskID: [UUID: Set<Date>] = [:]
    var missedDatesByTaskID: [UUID: Set<Date>] = [:]

    var missedTotalCount: Int {
        missedDatesByTaskID.values.reduce(0) { $0 + $1.count }
    }

    func hasResolvedMissedDate(
        taskID: UUID,
        missedDate: Date,
        calendar: Calendar
    ) -> Bool {
        if let missedDates = missedDatesByTaskID[taskID],
           missedDates.contains(where: { calendar.isDate($0, inSameDayAs: missedDate) }) {
            return true
        }
        if let canceledDates = canceledDatesByTaskID[taskID],
           canceledDates.contains(where: { calendar.isDate($0, inSameDayAs: missedDate) }) {
            return true
        }
        return false
    }
}

enum HomeTaskSupport {
    static func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }

    static func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }

    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        RoutineLogHistory.detailLogs(taskID: taskID, context: context)
    }

    static func focusSessionsDescriptor(for taskID: UUID) -> FetchDescriptor<FocusSession> {
        FetchDescriptor<FocusSession>(
            predicate: #Predicate { session in
                session.taskID == taskID
            }
        )
    }

    static func makeTaskDetailState(
        for task: RoutineTask,
        now: Date,
        calendar: Calendar
    ) -> TaskDetailFeature.State {
        let detailTask = task.detachedCopy()
        let defaultSelectedDate = (detailTask.isCompletedOneOff || detailTask.isCanceledOneOff)
            ? calendar.startOfDay(for: detailTask.lastDone ?? detailTask.canceledAt ?? now)
            : calendar.startOfDay(for: now)
        return TaskDetailFeature.State(
            task: detailTask,
            logs: [],
            selectedDate: defaultSelectedDate,
            daysSinceLastRoutine: RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailTask.lastDone,
                referenceDate: now
            ),
            overdueDays: detailTask.isArchived(referenceDate: now, calendar: calendar)
                ? 0
                : RoutineDateMath.overdueDays(for: detailTask, referenceDate: now, calendar: calendar),
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false,
            isAssumedDoneToday: RoutineAssumedCompletion.isAssumedDone(
                for: detailTask,
                on: now,
                logs: []
            )
        )
    }

    static func populateTaskDetailDisplayContext(
        _ detailState: inout TaskDetailFeature.State,
        tasks: [RoutineTask],
        places: [RoutinePlace],
        goals: [RoutineGoal],
        now: Date,
        calendar: Calendar
    ) {
        guard !detailState.isEditSheetPresented else { return }

        let task = detailState.task
        detailState.availableGoals = RoutineGoalSummary.summaries(from: goals)
        let directRelationshipTargetIDs = Set(task.relationships.map(\.targetTaskID))
        let relatedTasks = tasks.filter { candidate in
            guard candidate.id != task.id else { return false }
            if directRelationshipTargetIDs.contains(candidate.id) {
                return true
            }
            return candidate.relationships.contains { $0.targetTaskID == task.id }
        }
        detailState.availableRelationshipTasks = RoutineTaskRelationshipCandidate.from(
            relatedTasks,
            excluding: task.id,
            referenceDate: now,
            calendar: calendar
        )

        let selectedPlaceIDs = Set(task.placeIDs)
        let linkedPlaces = places.filter { selectedPlaceIDs.contains($0.id) }
        guard !linkedPlaces.isEmpty else {
            detailState.availablePlaces = []
            return
        }

        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, candidate in
            for placeID in candidate.placeIDs {
                partialResult[placeID, default: 0] += 1
            }
        }
        detailState.availablePlaces = linkedPlaces.map { place in
            place.summary(linkedRoutineCount: linkedCounts[place.id, default: 0])
        }
    }

    static func availableTags(from tasks: [RoutineTask]) -> [String] {
        RoutineTag.allTags(from: tasks.map(\.tags))
    }

    static func uniqueTaskIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    static func existingRoutineNames(from tasks: [RoutineTask]) -> [String] {
        tasks.compactMap(\.name)
    }

    static func makeDoneStats(tasks: [RoutineTask], logs: [RoutineLog]) -> HomeDoneStats {
        let taskIDs = Set(tasks.map(\.id))
        var totalCount = 0
        var countsByTaskID: [UUID: Int] = [:]
        var canceledTotalCount = 0
        var canceledCountsByTaskID: [UUID: Int] = [:]
        var canceledDatesByTaskID: [UUID: Set<Date>] = [:]
        var missedDatesByTaskID: [UUID: Set<Date>] = [:]

        for log in logs {
            guard taskIDs.contains(log.taskID) else { continue }

            switch log.kind {
            case .completed:
                totalCount += 1
                countsByTaskID[log.taskID, default: 0] += 1
            case .canceled:
                canceledTotalCount += 1
                canceledCountsByTaskID[log.taskID, default: 0] += 1
                if let timestamp = log.timestamp {
                    canceledDatesByTaskID[log.taskID, default: []].insert(timestamp)
                }
            case .missed:
                if let timestamp = log.timestamp {
                    missedDatesByTaskID[log.taskID, default: []].insert(timestamp)
                }
            }
        }

        return HomeDoneStats(
            totalCount: totalCount,
            countsByTaskID: countsByTaskID,
            canceledTotalCount: canceledTotalCount,
            canceledCountsByTaskID: canceledCountsByTaskID,
            canceledDatesByTaskID: canceledDatesByTaskID,
            missedDatesByTaskID: missedDatesByTaskID
        )
    }
}
