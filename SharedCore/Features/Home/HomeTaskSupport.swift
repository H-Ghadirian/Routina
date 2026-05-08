import Foundation
import SwiftData

struct HomeDoneStats: Equatable {
    var totalCount: Int = 0
    var countsByTaskID: [UUID: Int] = [:]
    var canceledTotalCount: Int = 0
    var canceledCountsByTaskID: [UUID: Int] = [:]
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
        now: Date,
        calendar: Calendar
    ) {
        guard !detailState.isEditSheetPresented else { return }

        let task = detailState.task
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

        guard let placeID = task.placeID,
              let place = places.first(where: { $0.id == placeID }) else {
            detailState.availablePlaces = []
            return
        }

        let linkedRoutineCount = tasks.reduce(into: 0) { count, candidate in
            if candidate.placeID == placeID {
                count += 1
            }
        }
        detailState.availablePlaces = [place.summary(linkedRoutineCount: linkedRoutineCount)]
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
        let countsByTaskID = logs.reduce(into: [UUID: Int]()) { partialResult, log in
            guard taskIDs.contains(log.taskID) else { return }
            guard log.kind == .completed else { return }
            partialResult[log.taskID, default: 0] += 1
        }
        let canceledCountsByTaskID = logs.reduce(into: [UUID: Int]()) { partialResult, log in
            guard taskIDs.contains(log.taskID) else { return }
            guard log.kind == .canceled else { return }
            partialResult[log.taskID, default: 0] += 1
        }
        return HomeDoneStats(
            totalCount: countsByTaskID.values.reduce(0, +),
            countsByTaskID: countsByTaskID,
            canceledTotalCount: canceledCountsByTaskID.values.reduce(0, +),
            canceledCountsByTaskID: canceledCountsByTaskID
        )
    }
}
