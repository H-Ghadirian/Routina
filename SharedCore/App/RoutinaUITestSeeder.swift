import Foundation
import SwiftData

enum RoutinaUITestSeeder {
    private static let performanceTaskCount = 360
    private static let searchPerformanceTaskCount = 12_000
    private static let guidedReviewPerformanceTaskCount = 360
    private static let guidedReviewPerformanceTimelineEntryCount = 1_200

    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard let profile = AppEnvironment.uiTestSeedProfile else { return }

        do {
            switch profile {
            case "performance":
                try seedPerformanceProfile(in: context)
            case "search-performance":
                try seedSearchPerformanceProfile(in: context)
            case "stats-performance":
                try seedStatsPerformanceProfile(in: context)
            case "guided-review-performance":
                try seedGuidedReviewPerformanceProfile(in: context)
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

    @MainActor
    private static func seedSearchPerformanceProfile(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<RoutineTask>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let referenceDate = Date()
        for index in 1...searchPerformanceTaskCount {
            context.insert(
                RoutineTask(
                    name: String(format: "Search Stress Task %05d", index),
                    emoji: "square.and.pencil",
                    notes: "Large search performance fixture with deliberately varied metadata \(index)",
                    priority: priority(for: index),
                    importance: importance(for: index),
                    urgency: urgency(for: index),
                    tags: tags(for: index),
                    scheduleMode: .oneOff,
                    createdAt: referenceDate.addingTimeInterval(TimeInterval(-index * 30)),
                    todoStateRawValue: todoStateRawValue(for: index),
                    estimatedDurationMinutes: 15 + (index % 6) * 10,
                    storyPoints: (index % 8) + 1
                )
            )
        }
        try context.save()
    }

    @MainActor
    private static func seedStatsPerformanceProfile(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<RoutineTask>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let referenceDate = Date()
        let tasks = performanceTasks(referenceDate: referenceDate)
        tasks.forEach(context.insert)

        for index in 0..<12_000 {
            let task = tasks[index % tasks.count]
            let dayOffset = index % 365
            let hourOffset = (index * 7) % 24
            let timestamp =
                Calendar.current.date(
                    byAdding: DateComponents(day: -dayOffset, hour: -hourOffset),
                    to: referenceDate
                ) ?? referenceDate.addingTimeInterval(TimeInterval(-dayOffset * 86_400))
            let kind: RoutineLogKind =
                switch index % 10 {
                case 0:
                    .missed
                case 1:
                    .canceled
                default:
                    .completed
                }
            context.insert(
                RoutineLog(
                    timestamp: timestamp,
                    taskID: task.id,
                    kind: kind,
                    actualDurationMinutes: kind == .completed ? 5 + (index % 120) : nil
                )
            )
        }

        try context.save()
    }

    @MainActor
    private static func seedGuidedReviewPerformanceProfile(in context: ModelContext) throws {
        var descriptor = FetchDescriptor<RoutineTask>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let referenceDate = Date()
        let tasks = (1...guidedReviewPerformanceTaskCount).map { index in
            RoutineTask(
                name: String(format: "Guided Review Task %03d", index),
                emoji: index.isMultiple(of: 3) ? "square.and.pencil" : "checklist",
                notes: "Seeded guided-review performance task \(index)",
                tags: tags(for: index),
                scheduleMode: index.isMultiple(of: 5) ? .oneOff : .fixedInterval,
                interval: Int16((index % 5) + 1),
                createdAt: referenceDate.addingTimeInterval(TimeInterval(-index * 300)),
                todoStateRawValue: index.isMultiple(of: 5) ? TodoState.ready.rawValue : nil,
                estimatedDurationMinutes: 15 + (index % 6) * 10,
                storyPoints: (index % 8) + 1
            )
        }
        tasks.forEach(context.insert)

        for index in 0..<guidedReviewPerformanceTimelineEntryCount {
            let task = tasks[index % tasks.count]
            let dayOffset = index % 365
            let timestamp =
                Calendar.current.date(
                    byAdding: .day,
                    value: -dayOffset,
                    to: referenceDate
                ) ?? referenceDate.addingTimeInterval(TimeInterval(-dayOffset * 86_400))
            context.insert(
                RoutineLog(
                    timestamp: timestamp,
                    taskID: task.id,
                    kind: .completed,
                    actualDurationMinutes: 5 + (index % 120)
                )
            )
        }
        try context.save()
    }

    private static func performanceTasks(referenceDate: Date) -> [RoutineTask] {
        (1...performanceTaskCount).map { index in
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
            "Writing",
        ]
        let secondaryTags = [
            "Morning",
            "Afternoon",
            "Evening",
            "Weekly",
            "Energy",
            "Quick",
            "Offline",
            "Calls",
        ]

        var tags = [
            primaryTags[index % primaryTags.count],
            secondaryTags[(index / 2) % secondaryTags.count],
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
