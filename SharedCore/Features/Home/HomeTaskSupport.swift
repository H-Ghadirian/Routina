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
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        )
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
