import ComposableArchitecture
import Foundation
import SwiftData

enum HomeTaskMoveDirection: String, Equatable, Sendable {
    case top
    case up
    case down
    case bottom
}

struct HomeTaskSectionOrderUpdate: Equatable, Sendable {
    var sectionKey: String
    var orderedTaskIDs: [UUID]
}

enum HomeTaskOrderingSupport {
    static func moveTaskInSection(
        taskID: UUID,
        sectionKey: String,
        orderedTaskIDs: [UUID],
        direction: HomeTaskMoveDirection,
        tasks: inout [RoutineTask]
    ) -> HomeTaskSectionOrderUpdate? {
        var normalizedIDs = normalizedOrderedTaskIDs(orderedTaskIDs, existingIn: tasks)
        guard normalizedIDs.count > 1,
              let currentIndex = normalizedIDs.firstIndex(of: taskID) else {
            return nil
        }

        let targetIndex: Int
        switch direction {
        case .top:
            targetIndex = 0
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        case .bottom:
            targetIndex = normalizedIDs.count - 1
        }
        guard normalizedIDs.indices.contains(targetIndex),
              targetIndex != currentIndex else { return nil }

        let movedID = normalizedIDs.remove(at: currentIndex)
        normalizedIDs.insert(movedID, at: targetIndex)

        applyManualOrder(normalizedIDs, sectionKey: sectionKey, to: &tasks)
        return HomeTaskSectionOrderUpdate(sectionKey: sectionKey, orderedTaskIDs: normalizedIDs)
    }

    static func setTaskOrderInSection(
        sectionKey: String,
        orderedTaskIDs: [UUID],
        tasks: inout [RoutineTask]
    ) -> HomeTaskSectionOrderUpdate? {
        let normalizedIDs = normalizedOrderedTaskIDs(orderedTaskIDs, existingIn: tasks)
        guard !normalizedIDs.isEmpty else { return nil }

        applyManualOrder(normalizedIDs, sectionKey: sectionKey, to: &tasks)
        return HomeTaskSectionOrderUpdate(sectionKey: sectionKey, orderedTaskIDs: normalizedIDs)
    }

    static func persistTaskOrder<Action>(
        _ update: HomeTaskSectionOrderUpdate,
        failureMessage: String,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let tasksByID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                for (order, id) in update.orderedTaskIDs.enumerated() {
                    tasksByID[id]?.setManualSectionOrder(order, for: update.sectionKey)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("\(failureMessage): \(error)")
            }
        }
    }

    private static func normalizedOrderedTaskIDs(
        _ orderedTaskIDs: [UUID],
        existingIn tasks: [RoutineTask]
    ) -> [UUID] {
        let existingTaskIDs = Set(tasks.map(\.id))
        var seen: Set<UUID> = []
        var normalizedIDs: [UUID] = []
        normalizedIDs.reserveCapacity(orderedTaskIDs.count)

        for id in orderedTaskIDs where existingTaskIDs.contains(id) {
            if seen.insert(id).inserted {
                normalizedIDs.append(id)
            }
        }
        return normalizedIDs
    }

    private static func applyManualOrder(
        _ orderedTaskIDs: [UUID],
        sectionKey: String,
        to tasks: inout [RoutineTask]
    ) {
        for (order, id) in orderedTaskIDs.enumerated() {
            guard let index = tasks.firstIndex(where: { $0.id == id }) else { continue }
            tasks[index].setManualSectionOrder(order, for: sectionKey)
        }
    }
}
