import Foundation
import SwiftData

enum RoutinaUITestSeeder {
    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard let profile = AppEnvironment.uiTestSeedProfile else { return }

        do {
            switch profile {
            case "performance":
                try seedPerformanceProfile(in: context)
            case "timeline-e2e":
                try seedTimelineE2EProfile(in: context)
            default:
                return
            }
            if AppEnvironment.exitsAfterUITestSeed {
                Foundation.exit(EXIT_SUCCESS)
            }
        } catch {
            NSLog("Routina UI test seeding failed: \(error.localizedDescription)")
            if AppEnvironment.exitsAfterUITestSeed {
                Foundation.exit(EXIT_FAILURE)
            }
        }
    }

    @MainActor
    private static func seedPerformanceProfile(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<RoutineTask>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        for task in performanceTasks(referenceDate: Date()) {
            context.insert(task)
        }
        try context.save()
    }

    private static func performanceTasks(referenceDate: Date) -> [RoutineTask] {
        (1...150).map { index in
            let isTodo = index.isMultiple(of: 3)
            let isPinned = index == 1 || index.isMultiple(of: 7)
            let isDone = index.isMultiple(of: 10)

            return RoutineTask(
                name: String(format: "Seed Task %02d", index),
                emoji: isTodo ? "square.and.pencil" : "checklist",
                notes: "Seeded UI performance task \(index)",
                priority: priority(for: index),
                importance: importance(for: index),
                urgency: urgency(for: index),
                tags: tags(for: index),
                scheduleMode: isTodo ? .oneOff : .fixedInterval,
                interval: Int16((index % 5) + 1),
                lastDone: isDone ? referenceDate.addingTimeInterval(-3_600) : nil,
                pinnedAt: isPinned ? referenceDate.addingTimeInterval(TimeInterval(-index)) : nil,
                createdAt: referenceDate.addingTimeInterval(TimeInterval(-index * 300)),
                todoStateRawValue: isTodo ? todoStateRawValue(for: index) : nil,
                estimatedDurationMinutes: 15 + (index % 6) * 10,
                storyPoints: (index % 8) + 1
            )
        }
    }

    private static func tags(for index: Int) -> [String] {
        let primaryTags = [
            "Focus",
            "Health",
            "Admin",
            "Deep Work",
            "Errands",
            "Home",
            "Planning",
            "Learning",
            "Finance",
            "Writing"
        ]
        let secondaryTags = [
            "Morning",
            "Afternoon",
            "Evening",
            "Weekly",
            "Energy",
            "Quick",
            "Offline",
            "Calls"
        ]

        var tags = [
            primaryTags[index % primaryTags.count],
            secondaryTags[(index / 2) % secondaryTags.count]
        ]

        if index.isMultiple(of: 5) {
            tags.append("Review")
        }
        if index.isMultiple(of: 9) {
            tags.append("Blocked")
        }

        return tags
    }

    private static func priority(for index: Int) -> RoutineTaskPriority {
        switch index % 4 {
        case 0: return .low
        case 1: return .medium
        case 2: return .high
        default: return .urgent
        }
    }

    private static func importance(for index: Int) -> RoutineTaskImportance {
        switch index % 4 {
        case 0: return .level1
        case 1: return .level2
        case 2: return .level3
        default: return .level4
        }
    }

    private static func urgency(for index: Int) -> RoutineTaskUrgency {
        switch index % 4 {
        case 0: return .level4
        case 1: return .level3
        case 2: return .level2
        default: return .level1
        }
    }

    private static func todoStateRawValue(for index: Int) -> String {
        switch index % 4 {
        case 0: return TodoState.inProgress.rawValue
        case 1: return TodoState.blocked.rawValue
        default: return TodoState.ready.rawValue
        }
    }
}

private extension RoutinaUITestSeeder {
    static let timelineE2EPrefix = "Timeline E2E"

    @MainActor
    static func seedTimelineE2EProfile(in context: ModelContext) throws {
        try deleteExistingTimelineE2ESeedData(in: context)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = Date()
        let createdAt = calendar.date(byAdding: .day, value: -5, to: now) ?? now.addingTimeInterval(-432_000)

        let standardDoneAt = now.addingTimeInterval(-1_200)
        let todoDoneAt = now.addingTimeInterval(-900)
        let runoutDoneAt = now.addingTimeInterval(-600)
        let checklistFirstDoneAt = now.addingTimeInterval(-360)
        let checklistDoneAt = now.addingTimeInterval(-300)
        let fallbackDoneAt = now.addingTimeInterval(-120)
        let staleLogDoneAt = now.addingTimeInterval(-60)
        let staleOlderCompletion = calendar.date(byAdding: .day, value: -2, to: now) ?? now.addingTimeInterval(-172_800)

        let standard = RoutineTask(
            name: "\(timelineE2EPrefix) Standard Routine",
            emoji: "checkmark.circle",
            tags: ["TimelineE2E", "Routine"],
            scheduleMode: .fixedInterval,
            interval: 2,
            createdAt: createdAt
        )
        let todo = RoutineTask(
            name: "\(timelineE2EPrefix) One-Off Todo",
            emoji: "square.and.pencil",
            tags: ["TimelineE2E", "Todo"],
            scheduleMode: .oneOff,
            interval: 1,
            createdAt: createdAt,
            todoStateRawValue: TodoState.ready.rawValue
        )
        let runout = RoutineTask(
            name: "\(timelineE2EPrefix) Runout Checklist",
            emoji: "cart",
            tags: ["TimelineE2E", "Checklist"],
            checklistItems: [
                RoutineChecklistItem(title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(title: "Milk", intervalDays: 7, createdAt: createdAt),
            ],
            scheduleMode: .derivedFromChecklist,
            interval: 1,
            createdAt: createdAt
        )
        let shoesID = UUID()
        let towelID = UUID()
        let checklist = RoutineTask(
            name: "\(timelineE2EPrefix) Completion Checklist",
            emoji: "checklist",
            tags: ["TimelineE2E", "Checklist"],
            checklistItems: [
                RoutineChecklistItem(id: shoesID, title: "Shoes", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: towelID, title: "Towel", intervalDays: 3, createdAt: createdAt),
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 1,
            createdAt: createdAt
        )
        let fallbackOnly = RoutineTask(
            name: "\(timelineE2EPrefix) LastDone Fallback",
            emoji: "clock.arrow.circlepath",
            tags: ["TimelineE2E", "Fallback"],
            scheduleMode: .fixedInterval,
            interval: 1,
            lastDone: fallbackDoneAt,
            createdAt: createdAt
        )
        let staleLogFallback = RoutineTask(
            name: "\(timelineE2EPrefix) Stale Log Fallback",
            emoji: "clock.badge.exclamationmark",
            tags: ["TimelineE2E", "Fallback"],
            scheduleMode: .fixedInterval,
            interval: 1,
            lastDone: staleLogDoneAt,
            createdAt: createdAt
        )

        [standard, todo, runout, checklist, fallbackOnly, staleLogFallback].forEach(context.insert)
        context.insert(RoutineLog(timestamp: staleOlderCompletion, taskID: staleLogFallback.id, kind: .completed))
        try context.save()

        guard try RoutineLogHistory.advanceTask(
            taskID: standard.id,
            completedAt: standardDoneAt,
            context: context,
            calendar: calendar
        ) != nil else {
            throw TimelineE2EFailure("Standard routine was not completed.")
        }
        guard try RoutineLogHistory.advanceTask(
            taskID: todo.id,
            completedAt: todoDoneAt,
            context: context,
            calendar: calendar
        ) != nil else {
            throw TimelineE2EFailure("One-off todo was not completed.")
        }
        guard try RoutineLogHistory.markDueChecklistItemsDone(
            taskID: runout.id,
            doneAt: runoutDoneAt,
            context: context,
            calendar: calendar
        ) != nil else {
            throw TimelineE2EFailure("Runout checklist was not completed.")
        }
        _ = try RoutineLogHistory.advanceChecklistItem(
            taskID: checklist.id,
            itemID: shoesID,
            completedAt: checklistFirstDoneAt,
            context: context,
            calendar: calendar
        )
        guard try RoutineLogHistory.advanceChecklistItem(
            taskID: checklist.id,
            itemID: towelID,
            completedAt: checklistDoneAt,
            context: context,
            calendar: calendar
        )?.result == .completedRoutine else {
            throw TimelineE2EFailure("Completion checklist did not finish after the final item.")
        }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let entries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            range: .today,
            filterType: .all,
            now: now,
            calendar: calendar
        )
        let expectedTaskIDs = [
            standard.id,
            todo.id,
            runout.id,
            checklist.id,
            fallbackOnly.id,
            staleLogFallback.id,
        ]
        let visibleTaskIDs = Set(entries.compactMap(\.taskID))
        let missingNames = expectedTaskIDs.compactMap { taskID -> String? in
            visibleTaskIDs.contains(taskID)
                ? nil
                : tasks.first(where: { $0.id == taskID })?.name
        }
        guard missingNames.isEmpty else {
            throw TimelineE2EFailure("Missing timeline entries: \(missingNames.joined(separator: ", ")).")
        }

        let fallbackHasPersistedLog = logs.contains { log in
            guard log.taskID == fallbackOnly.id,
                  log.kind == .completed,
                  let timestamp = log.timestamp
            else {
                return false
            }
            return calendar.isDate(timestamp, inSameDayAs: fallbackDoneAt)
        }
        guard !fallbackHasPersistedLog else {
            throw TimelineE2EFailure("Fallback-only task unexpectedly has a persisted completion log.")
        }

        writeTimelineE2EReport(
            TimelineE2EReport(
                passed: true,
                verifiedAt: now,
                taskCount: expectedTaskIDs.count,
                logCount: logs.filter { expectedTaskIDs.contains($0.taskID) }.count,
                timelineEntryCount: entries.filter { entry in
                    entry.taskID.map { expectedTaskIDs.contains($0) } ?? false
                }.count,
                taskNames: expectedTaskIDs.compactMap { taskID in
                    tasks.first(where: { $0.id == taskID })?.name
                }
            )
        )
        NSLog("Routina timeline E2E verification passed: \(expectedTaskIDs.count) task types visible in Timeline.")
    }

    @MainActor
    static func deleteExistingTimelineE2ESeedData(in context: ModelContext) throws {
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

    static func writeTimelineE2EReport(_ report: TimelineE2EReport) {
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
