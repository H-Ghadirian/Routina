import Foundation

extension RoutinaScreenshotDataSeeder {
    static func makeScreenshotPreparationTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(7),
            name: "Prepare App Store screenshots",
            emoji: "🖼️",
            taskDescription: "Prepare the accurate product views used to introduce Routina on both platforms.",
            notes: "Capture clean Home, Planner, Backlog, Task Ladder, Task Details, Timeline, and Stats views.",
            links: ["https://developer.apple.com/app-store/product-page/"],
            deadline: context.dates.at(dayOffset: 0, hour: 18),
            plannedDate: context.dates.at(dayOffset: 0, hour: 14),
            customTaskSectionID: context.appStoreSectionID,
            priority: .urgent,
            importance: .level4,
            urgency: .level4,
            pressure: .medium,
            pressureUpdatedAt: context.dates.at(dayOffset: -1, hour: 10),
            thinkingNeeded: .high,
            tags: ["Routina", "Creative", "Release"],
            goalIDs: [],
            relationships: [
                RoutineTaskRelationship(
                    targetTaskID: context.releaseSubmissionID,
                    kind: .blocks
                )
            ],
            steps: [
                RoutineStep(title: "Prepare realistic sample data"),
                RoutineStep(title: "Capture iPhone release screens"),
                RoutineStep(title: "Capture Mac release screens"),
                RoutineStep(title: "Review every image at App Store size"),
            ],
            scheduleMode: .oneOff,
            pinnedAt: context.dates.at(dayOffset: -2, hour: 9),
            color: .indigo,
            createdAt: context.dates.at(dayOffset: -6, hour: 10),
            todoStateRawValue: TodoState.inProgress.rawValue,
            estimatedDurationMinutes: 90,
            storyPoints: 5,
            focusModeEnabled: true,
            hasExplicitImportance: true,
            hasExplicitUrgency: true,
            comments: [
                RoutineTaskComment(
                    id: seedID(71),
                    body: "Use one coherent dataset across both platforms.",
                    createdAt: context.dates.at(dayOffset: -1, hour: 16)
                )
            ]
        )
    }

    static func makeSoftwareRenewalTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(10),
            name: "Renew design software",
            emoji: "💳",
            taskDescription: "Resolve an overdue renewal before it interrupts release work.",
            notes: "Compare annual pricing before the trial ends.",
            deadline: context.dates.at(dayOffset: -1, hour: 17),
            customTaskSectionID: context.launchSectionID,
            priority: .high,
            importance: .level3,
            urgency: .level4,
            pressure: .high,
            pressureUpdatedAt: context.dates.at(dayOffset: -2, hour: 9),
            tags: ["Admin", "Routina"],
            goalIDs: [],
            scheduleMode: .oneOff,
            color: .red,
            createdAt: context.dates.at(dayOffset: -7, hour: 9),
            todoStateRawValue: TodoState.blocked.rawValue,
            estimatedDurationMinutes: 20,
            storyPoints: 1
        )
    }

    static func makeReleaseSubmissionTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: context.releaseSubmissionID,
            name: "Submit the release candidate",
            emoji: "🚀",
            taskDescription: "The final submission remains blocked until its release evidence is ready.",
            notes: "Upload both platforms only after screenshots and backup verification are complete.",
            deadline: context.dates.at(dayOffset: 2, hour: 16),
            customTaskSectionID: context.appStoreSectionID,
            priority: .urgent,
            importance: .level4,
            urgency: .level4,
            pressure: .high,
            pressureUpdatedAt: context.dates.at(dayOffset: -1, hour: 11),
            thinkingNeeded: .high,
            tags: ["Routina", "Release"],
            goalIDs: [],
            relationships: [
                RoutineTaskRelationship(targetTaskID: seedID(7), kind: .blockedBy),
                RoutineTaskRelationship(targetTaskID: context.verifyBackupID, kind: .blockedBy),
            ],
            scheduleMode: .oneOff,
            color: .red,
            createdAt: context.dates.at(dayOffset: -5, hour: 9),
            todoStateRawValue: TodoState.blocked.rawValue,
            estimatedDurationMinutes: 60,
            storyPoints: 3,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
    }

    static func makeBackupVerificationTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: context.verifyBackupID,
            name: "Verify the release backup",
            emoji: "🛟",
            taskDescription: "Audit a portable backup before treating it as a recovery path.",
            notes: "Check the receipt, attachments, isolated restore, and semantic round trip.",
            deadline: context.dates.at(dayOffset: 0, hour: 15),
            plannedDate: context.dates.at(dayOffset: 0, hour: 13),
            customTaskSectionID: context.appStoreSectionID,
            priority: .high,
            importance: .level4,
            urgency: .level3,
            pressure: .medium,
            pressureUpdatedAt: context.dates.at(dayOffset: -1, hour: 12),
            thinkingNeeded: .high,
            tags: ["Routina", "Release", "Backup"],
            goalIDs: [],
            relationships: [
                RoutineTaskRelationship(targetTaskID: context.releaseSubmissionID, kind: .blocks)
            ],
            steps: [
                RoutineStep(title: "Export verified package"),
                RoutineStep(title: "Run isolated restore audit"),
                RoutineStep(title: "Confirm recovery receipt"),
            ],
            scheduleMode: .oneOff,
            color: .teal,
            createdAt: context.dates.at(dayOffset: -4, hour: 9),
            todoStateRawValue: TodoState.inProgress.rawValue,
            estimatedDurationMinutes: 40,
            storyPoints: 3
        )
    }

}
