import Foundation
import SwiftData
@testable @preconcurrency import Routina

@MainActor
private var retainedInMemoryControllers: [PersistenceController] = []

@MainActor
func makeInMemoryContext() -> ModelContext {
    let controller = PersistenceController(inMemory: true)
    retainedInMemoryControllers.append(controller)
    return controller.container.mainContext
}

@MainActor
func makeTask(
    in context: ModelContext,
    name: String?,
    interval: Int16,
    lastDone: Date?,
    emoji: String?
) -> RoutineTask {
    let task = RoutineTask(name: name, emoji: emoji, interval: interval, lastDone: lastDone)
    context.insert(task)
    return task
}

@MainActor
func makeLog(
    in context: ModelContext,
    task: RoutineTask,
    timestamp: Date?
) -> RoutineLog {
    let log = RoutineLog(timestamp: timestamp, taskID: task.id)
    context.insert(log)
    return log
}

func makeDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: value) else {
        fatalError("Invalid ISO date string: \(value)")
    }
    return date
}
