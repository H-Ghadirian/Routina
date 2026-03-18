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
    emoji: String?,
    placeID: UUID? = nil,
    tags: [String] = [],
    steps: [RoutineStep] = [],
    scheduleAnchor: Date? = nil,
    pausedAt: Date? = nil
) -> RoutineTask {
    let task = RoutineTask(
        name: name,
        emoji: emoji,
        placeID: placeID,
        tags: tags,
        steps: steps,
        interval: interval,
        lastDone: lastDone,
        scheduleAnchor: scheduleAnchor,
        pausedAt: pausedAt
    )
    context.insert(task)
    do {
        try context.save()
    } catch {
        fatalError("Failed to save task fixture: \(error)")
    }
    return task
}

@MainActor
func makePlace(
    in context: ModelContext,
    name: String,
    latitude: Double = 52.5200,
    longitude: Double = 13.4050,
    radiusMeters: Double = 150
) -> RoutinePlace {
    let place = RoutinePlace(
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters
    )
    context.insert(place)
    do {
        try context.save()
    } catch {
        fatalError("Failed to save place fixture: \(error)")
    }
    return place
}

@MainActor
func makeLog(
    in context: ModelContext,
    task: RoutineTask,
    timestamp: Date?
) -> RoutineLog {
    let log = RoutineLog(timestamp: timestamp, taskID: task.id)
    context.insert(log)
    do {
        try context.save()
    } catch {
        fatalError("Failed to save log fixture: \(error)")
    }
    return log
}

func makeDate(_ value: String) -> Date {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: value) else {
        fatalError("Invalid ISO date string: \(value)")
    }
    return date
}
