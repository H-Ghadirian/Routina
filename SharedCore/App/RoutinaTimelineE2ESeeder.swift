import Foundation
import SwiftData

extension RoutinaUITestSeeder {
    private static let timelineE2EPrefix = "Timeline E2E"

    @MainActor
    static func seedTimelineE2EProfile(in context: ModelContext) throws {
        try deleteExistingTimelineE2ESeedData(in: context)

        let timing = TimelineE2ETiming()
        let seededTasks = makeTimelineE2ETasks(timing: timing)
        seededTasks.all.forEach(context.insert)
        context.insert(
            RoutineLog(
                timestamp: timing.staleOlderCompletion,
                taskID: seededTasks.staleLogFallback.id,
                kind: .completed
            )
        )
        try context.save()

        try completeTimelineE2ETasks(seededTasks, timing: timing, context: context)
        let report = try timelineE2EReport(
            seededTasks: seededTasks,
            timing: timing,
            context: context
        )
        writeTimelineE2EReport(report)
        NSLog(
            "Routina timeline E2E verification passed: \(report.taskCount) task types visible in Timeline."
        )
    }

    private static func makeTimelineE2ETasks(
        timing: TimelineE2ETiming
    ) -> TimelineE2ETasks {
        let standard = RoutineTask(
            name: "\(timelineE2EPrefix) Standard Routine",
            emoji: "checkmark.circle",
            tags: ["TimelineE2E", "Routine"],
            scheduleMode: .fixedInterval,
            interval: 2,
            createdAt: timing.createdAt
        )
        let todo = RoutineTask(
            name: "\(timelineE2EPrefix) One-Off Todo",
            emoji: "square.and.pencil",
            tags: ["TimelineE2E", "Todo"],
            scheduleMode: .oneOff,
            interval: 1,
            createdAt: timing.createdAt,
            todoStateRawValue: TodoState.ready.rawValue
        )
        let runout = RoutineTask(
            name: "\(timelineE2EPrefix) Runout Checklist",
            emoji: "cart",
            tags: ["TimelineE2E", "Checklist"],
            checklistItems: [
                RoutineChecklistItem(title: "Bread", intervalDays: 3, createdAt: timing.createdAt),
                RoutineChecklistItem(title: "Milk", intervalDays: 7, createdAt: timing.createdAt),
            ],
            scheduleMode: .derivedFromChecklist,
            interval: 1,
            createdAt: timing.createdAt
        )
        let shoesID = UUID()
        let towelID = UUID()
        let checklist = RoutineTask(
            name: "\(timelineE2EPrefix) Completion Checklist",
            emoji: "checklist",
            tags: ["TimelineE2E", "Checklist"],
            checklistItems: [
                RoutineChecklistItem(id: shoesID, title: "Shoes", intervalDays: 3, createdAt: timing.createdAt),
                RoutineChecklistItem(id: towelID, title: "Towel", intervalDays: 3, createdAt: timing.createdAt),
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 1,
            createdAt: timing.createdAt
        )
        let fallbackOnly = RoutineTask(
            name: "\(timelineE2EPrefix) LastDone Fallback",
            emoji: "clock.arrow.circlepath",
            tags: ["TimelineE2E", "Fallback"],
            scheduleMode: .fixedInterval,
            interval: 1,
            lastDone: timing.fallbackDoneAt,
            createdAt: timing.createdAt
        )
        let staleLogFallback = RoutineTask(
            name: "\(timelineE2EPrefix) Stale Log Fallback",
            emoji: "clock.badge.exclamationmark",
            tags: ["TimelineE2E", "Fallback"],
            scheduleMode: .fixedInterval,
            interval: 1,
            lastDone: timing.staleLogDoneAt,
            createdAt: timing.createdAt
        )
        return TimelineE2ETasks(
            standard: standard,
            todo: todo,
            runout: runout,
            checklist: checklist,
            fallbackOnly: fallbackOnly,
            staleLogFallback: staleLogFallback,
            shoesID: shoesID,
            towelID: towelID
        )
    }

    @MainActor
    private static func completeTimelineE2ETasks(
        _ tasks: TimelineE2ETasks,
        timing: TimelineE2ETiming,
        context: ModelContext
    ) throws {
        guard
            try RoutineLogHistory.advanceTask(
                taskID: tasks.standard.id,
                completedAt: timing.standardDoneAt,
                context: context,
                calendar: timing.calendar
            ) != nil
        else {
            throw TimelineE2EFailure("Standard routine was not completed.")
        }
        guard
            try RoutineLogHistory.advanceTask(
                taskID: tasks.todo.id,
                completedAt: timing.todoDoneAt,
                context: context,
                calendar: timing.calendar
            ) != nil
        else {
            throw TimelineE2EFailure("One-off todo was not completed.")
        }
        guard
            try RoutineLogHistory.markDueChecklistItemsDone(
                taskID: tasks.runout.id,
                doneAt: timing.runoutDoneAt,
                context: context,
                calendar: timing.calendar
            ) != nil
        else {
            throw TimelineE2EFailure("Runout checklist was not completed.")
        }
        _ = try RoutineLogHistory.advanceChecklistItem(
            taskID: tasks.checklist.id,
            itemID: tasks.shoesID,
            completedAt: timing.checklistFirstDoneAt,
            context: context,
            calendar: timing.calendar
        )
        guard
            try RoutineLogHistory.advanceChecklistItem(
                taskID: tasks.checklist.id,
                itemID: tasks.towelID,
                completedAt: timing.checklistDoneAt,
                context: context,
                calendar: timing.calendar
            )?.result == .completedRoutine
        else {
            throw TimelineE2EFailure("Completion checklist did not finish after the final item.")
        }
    }

    @MainActor
    private static func timelineE2EReport(
        seededTasks: TimelineE2ETasks,
        timing: TimelineE2ETiming,
        context: ModelContext
    ) throws -> TimelineE2EReport {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let entries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            range: .today,
            filterType: .all,
            now: timing.now,
            calendar: timing.calendar
        )
        let expectedTaskIDs = seededTasks.expectedTaskIDs
        let visibleTaskIDs = Set(entries.compactMap(\.taskID))
        let missingNames = expectedTaskIDs.compactMap { taskID -> String? in
            visibleTaskIDs.contains(taskID)
                ? nil
                : tasks.first(where: { $0.id == taskID })?.name
        }
        guard missingNames.isEmpty else {
            throw TimelineE2EFailure(
                "Missing timeline entries: \(missingNames.joined(separator: ", "))."
            )
        }

        let fallbackHasPersistedLog = logs.contains { log in
            guard log.taskID == seededTasks.fallbackOnly.id,
                log.kind == .completed,
                let timestamp = log.timestamp
            else {
                return false
            }
            return timing.calendar.isDate(timestamp, inSameDayAs: timing.fallbackDoneAt)
        }
        guard !fallbackHasPersistedLog else {
            throw TimelineE2EFailure(
                "Fallback-only task unexpectedly has a persisted completion log."
            )
        }

        return TimelineE2EReport(
            passed: true,
            verifiedAt: timing.now,
            taskCount: expectedTaskIDs.count,
            logCount: logs.filter { expectedTaskIDs.contains($0.taskID) }.count,
            timelineEntryCount: entries.filter { entry in
                entry.taskID.map { expectedTaskIDs.contains($0) } ?? false
            }.count,
            taskNames: expectedTaskIDs.compactMap { taskID in
                tasks.first(where: { $0.id == taskID })?.name
            }
        )
    }

    @MainActor
    private static func deleteExistingTimelineE2ESeedData(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let e2eTasks = tasks.filter { task in
            (task.name ?? "").hasPrefix(timelineE2EPrefix)
        }
        let taskIDs = Set(e2eTasks.map(\.id))
        if !taskIDs.isEmpty {
            let logs = try context.fetch(FetchDescriptor<RoutineLog>())
            for log in logs where taskIDs.contains(log.taskID) {
                context.delete(log)
            }
            for task in e2eTasks {
                context.delete(task)
            }
            try context.save()
        }
    }

    private static func writeTimelineE2EReport(_ report: TimelineE2EReport) {
        guard let path = AppEnvironment.uiTestReportPath else { return }
        do {
            let url = URL(fileURLWithPath: path)
            let data = try JSONEncoder.routinaTimelineE2E.encode(report)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Routina timeline E2E report write failed: \(error.localizedDescription)")
        }
    }
}

private struct TimelineE2ETiming {
    let calendar: Calendar
    let now: Date
    let createdAt: Date
    let standardDoneAt: Date
    let todoDoneAt: Date
    let runoutDoneAt: Date
    let checklistFirstDoneAt: Date
    let checklistDoneAt: Date
    let fallbackDoneAt: Date
    let staleLogDoneAt: Date
    let staleOlderCompletion: Date

    init(now: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        self.calendar = calendar
        self.now = now
        self.createdAt =
            calendar.date(byAdding: .day, value: -5, to: now)
            ?? now.addingTimeInterval(-432_000)
        self.standardDoneAt = now.addingTimeInterval(-1_200)
        self.todoDoneAt = now.addingTimeInterval(-900)
        self.runoutDoneAt = now.addingTimeInterval(-600)
        self.checklistFirstDoneAt = now.addingTimeInterval(-360)
        self.checklistDoneAt = now.addingTimeInterval(-300)
        self.fallbackDoneAt = now.addingTimeInterval(-120)
        self.staleLogDoneAt = now.addingTimeInterval(-60)
        self.staleOlderCompletion =
            calendar.date(byAdding: .day, value: -2, to: now)
            ?? now.addingTimeInterval(-172_800)
    }
}

private struct TimelineE2ETasks {
    let standard: RoutineTask
    let todo: RoutineTask
    let runout: RoutineTask
    let checklist: RoutineTask
    let fallbackOnly: RoutineTask
    let staleLogFallback: RoutineTask
    let shoesID: UUID
    let towelID: UUID

    var all: [RoutineTask] {
        [standard, todo, runout, checklist, fallbackOnly, staleLogFallback]
    }

    var expectedTaskIDs: [UUID] {
        all.map(\.id)
    }
}

private struct TimelineE2EFailure: LocalizedError {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private struct TimelineE2EReport: Codable {
    var passed: Bool
    var verifiedAt: Date
    var taskCount: Int
    var logCount: Int
    var timelineEntryCount: Int
    var taskNames: [String]
}

private extension JSONEncoder {
    static var routinaTimelineE2E: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
