import Foundation

extension RoutinaScreenshotDataSeeder {
    static func makeProjectUpdateTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(8),
            name: "Send project update",
            emoji: "✉️",
            taskDescription: "Summarize progress without burying the next concrete action.",
            notes: "Share progress, current risks, and the next milestone.",
            deadline: context.dates.at(dayOffset: 1, hour: 16),
            plannedDate: context.dates.at(dayOffset: 0, hour: 16),
            customTaskSectionID: context.launchSectionID,
            priority: .high,
            importance: .level3,
            urgency: .level3,
            tags: ["Work", "Communication"],
            goalIDs: [],
            scheduleMode: .oneOff,
            color: .blue,
            createdAt: context.dates.at(dayOffset: -4, hour: 11),
            todoStateRawValue: TodoState.ready.rawValue,
            estimatedDurationMinutes: 30,
            storyPoints: 2
        )
    }

    static func makeDentistAppointmentTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(9),
            name: "Book dentist appointment",
            emoji: "🦷",
            taskDescription: "A short personal task with a deadline and reminder.",
            notes: "Call the nearby clinic and choose a morning appointment.",
            deadline: context.dates.at(dayOffset: 5, hour: 17),
            customTaskSectionID: context.personalSectionID,
            reminderAt: context.dates.at(dayOffset: 3, hour: 10),
            priority: .medium,
            importance: .level3,
            urgency: .level2,
            tags: ["Personal", "Health"],
            scheduleMode: .oneOff,
            color: .pink,
            createdAt: context.dates.at(dayOffset: -3, hour: 12),
            todoStateRawValue: TodoState.ready.rawValue,
            estimatedDurationMinutes: 15,
            storyPoints: 1
        )
    }

    static func makeAutumnWeekendTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(13),
            name: "Plan an autumn weekend",
            emoji: "🍂",
            taskDescription: "A later idea with a broad availability window instead of a false deadline.",
            notes: "Choose a quiet destination once the release is finished.",
            customTaskSectionID: context.laterSectionID,
            availabilityStartDate: context.dates.at(dayOffset: 30, hour: 0),
            availabilityEndDate: context.dates.at(dayOffset: 45, hour: 23, minute: 59),
            priority: .low,
            importance: .level2,
            urgency: .level1,
            thinkingNeeded: .medium,
            tags: ["Personal", "Travel"],
            scheduleMode: .oneOff,
            color: .orange,
            createdAt: context.dates.at(dayOffset: -10, hour: 17),
            todoStateRawValue: TodoState.ready.rawValue,
            estimatedDurationMinutes: 30
        )
    }

    static func makeStandingDeskResearchTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(14),
            name: "Compare ergonomic standing desks for a calmer workspace",
            emoji: "🪑",
            taskDescription: "Research kept out of the daily list until it is deliberately promoted.",
            notes: "Compare stability, usable depth, warranty, and delivery instead of price alone.",
            customTaskSectionID: context.researchSectionID,
            priority: .low,
            importance: .level2,
            urgency: .level1,
            thinkingNeeded: .high,
            tags: ["Research", "Workspace"],
            scheduleMode: .oneOff,
            color: .blue,
            createdAt: context.dates.at(dayOffset: -9, hour: 14),
            todoStateRawValue: TodoState.ready.rawValue,
            estimatedDurationMinutes: 45,
            storyPoints: 2
        )
    }

    static func makeFamilyCallTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(15),
            name: "Call family",
            emoji: "☎️",
            taskDescription: "A gentle weekly rhythm measured from the last completed call.",
            notes: "Make time for an unhurried conversation.",
            customTaskSectionID: context.personalSectionID,
            priority: .medium,
            importance: .level4,
            urgency: .level2,
            thinkingNeeded: .low,
            tags: ["Personal", "Family"],
            scheduleMode: .softInterval,
            interval: 7,
            recurrenceRule: .interval(
                days: 7,
                at: RoutineTimeOfDay(hour: 19, minute: 0)
            ),
            lastDone: context.dates.at(dayOffset: -6, hour: 19),
            color: .pink,
            createdAt: context.dates.at(dayOffset: -50, hour: 12),
            estimatedDurationMinutes: 30,
            showsTaskDetailHistory: true
        )
    }

    static func makeFriendMeetupTask(_ context: ScreenshotTaskFixtureContext) -> RoutineTask {
        return RoutineTask(
            id: seedID(16),
            name: "Meet a friend at Brandenburg Gate",
            emoji: "☕️",
            taskDescription: "A one-time plan with a real destination and a visible reminder.",
            notes: "Meet by the east side before walking to a nearby café.",
            deadline: context.dates.at(dayOffset: 2, hour: 20),
            plannedDate: context.dates.at(dayOffset: 2, hour: 18),
            customTaskSectionID: context.personalSectionID,
            reminderAt: context.dates.at(dayOffset: 2, hour: 16),
            importance: .level3,
            urgency: .level2,
            thinkingNeeded: .low,
            destinationAddress: "Brandenburg Gate, Pariser Platz, 10117 Berlin",
            destinationLatitude: 52.5162746,
            destinationLongitude: 13.3777041,
            tags: ["Personal", "Friends"],
            scheduleMode: .oneOff,
            color: .teal,
            createdAt: context.dates.at(dayOffset: -2, hour: 12),
            todoStateRawValue: TodoState.ready.rawValue,
            estimatedDurationMinutes: 90
        )
    }

}
