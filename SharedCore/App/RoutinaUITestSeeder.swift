import Foundation
import SwiftData

enum RoutinaUITestSeeder {
    @MainActor
    static func seedIfRequested(in context: ModelContext) {
        guard AppEnvironment.uiTestSeedProfile == "performance" else { return }

        do {
            var descriptor = FetchDescriptor<RoutineTask>()
            descriptor.fetchLimit = 1
            guard try context.fetch(descriptor).isEmpty else { return }

            for task in performanceTasks(referenceDate: Date()) {
                context.insert(task)
            }
            try context.save()
        } catch {
            NSLog("Routina UI test seeding failed: \(error.localizedDescription)")
        }
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
