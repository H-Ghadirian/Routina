import ComposableArchitecture
import Foundation
import SwiftData

struct HomeTaskDeletionUpdate: Equatable, Sendable {
    var uniqueIDs: [UUID]

    var idSet: Set<UUID> {
        Set(uniqueIDs)
    }
}

struct HomeTaskDeletionCoordinator<Action> {
    var modelContext: @MainActor @Sendable () -> ModelContext
    var saveSprintBoardData: @Sendable (SprintBoardData) async -> Void
    var cancelNotification: @Sendable (String) async -> Void

    func deleteTasks(
        ids: [UUID],
        tasks: inout [RoutineTask],
        doneStats: inout HomeDoneStats,
        sprintBoardData: inout SprintBoardData?
    ) -> Effect<Action>? {
        guard let update = HomeTaskDeletionSupport.prepareDeleteTasks(
            ids: ids,
            tasks: &tasks,
            doneStats: &doneStats
        ) else {
            return nil
        }

        if var boardData = sprintBoardData {
            HomeTaskDeletionSupport.removeSprintAssignments(
                targeting: update.uniqueIDs,
                from: &boardData
            )
            sprintBoardData = boardData
        }

        return HomeTaskDeletionSupport.deleteTasks(
            update,
            sprintBoardData: sprintBoardData,
            modelContext: modelContext,
            saveSprintBoardData: saveSprintBoardData,
            cancelNotification: cancelNotification
        )
    }
}

enum HomeTaskDeletionSupport {
    static func prepareDeleteTasks(
        ids: [UUID],
        tasks: inout [RoutineTask],
        doneStats: inout HomeDoneStats
    ) -> HomeTaskDeletionUpdate? {
        let uniqueIDs = HomeTaskSupport.uniqueTaskIDs(ids)
        guard !uniqueIDs.isEmpty else { return nil }

        let idSet = Set(uniqueIDs)
        RoutineTask.removeRelationships(targeting: idSet, from: tasks)
        tasks.removeAll { idSet.contains($0.id) }

        var removedDoneCount = 0
        var removedCanceledCount = 0
        for id in uniqueIDs {
            removedDoneCount += doneStats.countsByTaskID[id, default: 0]
            removedCanceledCount += doneStats.canceledCountsByTaskID[id, default: 0]
            doneStats.countsByTaskID.removeValue(forKey: id)
            doneStats.canceledCountsByTaskID.removeValue(forKey: id)
        }
        doneStats.totalCount = max(doneStats.totalCount - removedDoneCount, 0)
        doneStats.canceledTotalCount = max(doneStats.canceledTotalCount - removedCanceledCount, 0)

        return HomeTaskDeletionUpdate(uniqueIDs: uniqueIDs)
    }

    static func removeSprintAssignments(
        targeting uniqueIDs: [UUID],
        from sprintBoardData: inout SprintBoardData
    ) {
        let idSet = Set(uniqueIDs)
        sprintBoardData.assignments.removeAll { idSet.contains($0.todoID) }
    }

    static func deleteTasks<Action>(
        _ update: HomeTaskDeletionUpdate,
        sprintBoardData: SprintBoardData?,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        saveSprintBoardData: @escaping @Sendable (SprintBoardData) async -> Void,
        cancelNotification: @escaping @Sendable (String) async -> Void
    ) -> Effect<Action> {
        .run { @MainActor _ in
            let context = modelContext()
            let allTasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
            RoutineTask.removeRelationships(targeting: update.idSet, from: allTasks)
            for id in update.uniqueIDs {
                let descriptor = FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == id
                    }
                )
                if let task = try context.fetch(descriptor).first {
                    context.delete(task)
                }
                let logs = try context.fetch(HomeTaskSupport.logsDescriptor(for: id))
                for log in logs {
                    context.delete(log)
                }
                await cancelNotification(id.uuidString)
            }
            try? context.save()
            if let sprintBoardData {
                await saveSprintBoardData(sprintBoardData)
            }
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }
}
