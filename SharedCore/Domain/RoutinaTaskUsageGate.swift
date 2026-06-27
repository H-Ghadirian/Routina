import Foundation
import SwiftData

struct RoutinaTaskLimitSnapshot: Equatable, Sendable {
    var activeTaskCount: Int
    var freeTaskLimit: Int

    var remainingFreeTasks: Int {
        max(freeTaskLimit - activeTaskCount, 0)
    }

    var isAtOrOverLimit: Bool {
        activeTaskCount >= freeTaskLimit
    }
}

struct RoutinaTaskLimitError: LocalizedError, Equatable {
    var snapshot: RoutinaTaskLimitSnapshot

    var errorDescription: String? {
        "Free Routina supports up to \(snapshot.freeTaskLimit) active tasks. Upgrade to add more."
    }
}

enum RoutinaTaskUsageGate {
    static let freeActiveTaskLimit = 10

    static func activeTaskCount(
        in tasks: [RoutineTask],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        tasks.filter {
            countsTowardActiveTaskLimit(
                $0,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
        .count
    }

    static func countsTowardActiveTaskLimit(
        _ task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard !task.isArchived(referenceDate: referenceDate, calendar: calendar) else {
            return false
        }

        if task.isOneOffTask {
            return task.todoState != .done
        }

        return true
    }

    static func limitSnapshot(
        for tasks: [RoutineTask],
        entitlement: RoutinaSubscriptionEntitlement,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> RoutinaTaskLimitSnapshot? {
        guard !entitlement.hasUnlimitedTasks else { return nil }
        let activeTaskCount = activeTaskCount(
            in: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let snapshot = RoutinaTaskLimitSnapshot(
            activeTaskCount: activeTaskCount,
            freeTaskLimit: freeActiveTaskLimit
        )
        return snapshot.isAtOrOverLimit ? snapshot : nil
    }

    @MainActor
    static func ensureCanCreateActiveTask(
        in context: ModelContext,
        entitlement: RoutinaSubscriptionEntitlement,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        if let snapshot = limitSnapshot(
            for: tasks,
            entitlement: entitlement,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            throw RoutinaTaskLimitError(snapshot: snapshot)
        }
    }
}

