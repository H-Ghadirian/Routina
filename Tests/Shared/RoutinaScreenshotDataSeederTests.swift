import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct RoutinaScreenshotDataSeederTests {
    @Test
    func seedCreatesARepresentativeScreenshotDataset() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-07-29T10:00:00Z")

        let result = try RoutinaScreenshotDataSeeder.seed(
            in: context,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let blocks = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
        let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let notes = try context.fetch(FetchDescriptor<RoutineNote>())
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        let emotions = try context.fetch(FetchDescriptor<EmotionLog>())
        let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
        let awaySessions = try context.fetch(FetchDescriptor<AwaySession>())
        let preferences = try #require(
            try context.fetch(FetchDescriptor<RoutinaUserPreferences>()).first
        )
        let customSections = HomeCustomTaskSectionStorage.decoded(
            from: preferences.customTaskSections
        )

        #expect(result.taskCount == RoutinaScreenshotDataSeeder.taskCount)
        #expect(result.sectionCount == 5)
        #expect(result.logCount >= 80)
        #expect(result.plannerBlockCount == 5)
        #expect(tasks.count == 16)
        #expect(customSections.count == 5)
        #expect(customSections.filter { $0.surface == .radar }.count == 3)
        #expect(customSections.filter { $0.surface == .backlog }.count == 2)
        #expect(customSections.filter { $0.parentSectionID != nil }.count == 2)
        #expect(logs.count >= 80)
        #expect(blocks.count == 5)
        #expect(focusSessions.count == 14)
        #expect(goals.count == 3)
        #expect(notes.count == 3)
        #expect(events.isEmpty)
        #expect(emotions.isEmpty)
        #expect(sleepSessions.count == 10)
        #expect(awaySessions.count == 4)
        #expect(focusSessions.allSatisfy { $0.state == .completed })
        #expect(sleepSessions.allSatisfy { !$0.isActive })
        #expect(awaySessions.allSatisfy { !$0.isActive })
        #expect(tasks.contains { $0.name == "Prepare App Store screenshots" })
        #expect(tasks.contains { $0.scheduleMode == .derivedFromChecklist })
        #expect(tasks.contains { $0.scheduleMode == .fixedInterval })
        #expect(tasks.contains { $0.scheduleMode == .softInterval })
        #expect(tasks.contains { !$0.cadenceEnabled && $0.autoPauseAfterCompletion })
        #expect(tasks.contains { $0.temporalWeightRule != nil })
        #expect(tasks.contains { !$0.relationships.isEmpty })
        #expect(tasks.contains { !$0.flags.isEmpty })
        #expect(tasks.contains { $0.hasDestination })
        #expect(tasks.contains { $0.linkItems.contains { $0.title != nil } })
        #expect(
            tasks.contains { task in
                guard let sectionID = task.customTaskSectionID else { return false }
                return customSections.contains {
                    $0.id == sectionID && $0.surface == .backlog
                }
            }
        )
        #expect(tasks.contains { $0.todoState == .blocked })
        #expect(
            blocks.allSatisfy {
                $0.dayKey == DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            }
        )
    }

    @Test
    func seedIsIdempotentAndPreservesExistingUserData() throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let referenceDate = makeDate("2026-07-29T10:00:00Z")
        let userTask = RoutineTask(name: "My existing task", scheduleMode: .oneOff)
        context.insert(userTask)
        let userSection = HomeCustomTaskSection(title: "My own section")
        let preferences = try RoutinaUserPreferencesStore.fetchOrCreate(in: context)
        preferences.customTaskSections = HomeCustomTaskSectionStorage.encoded([userSection])
        try context.save()

        _ = try RoutinaScreenshotDataSeeder.seed(
            in: context,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let firstTaskCount = try context.fetchCount(FetchDescriptor<RoutineTask>())
        let firstLogCount = try context.fetchCount(FetchDescriptor<RoutineLog>())
        let seededScreenshotTask = try #require(
            try context.fetch(FetchDescriptor<RoutineTask>()).first {
                $0.name == "Prepare App Store screenshots"
            }
        )
        seededScreenshotTask.name = "Outdated screenshot task"
        seededScreenshotTask.deadline = makeDate("2025-01-01T18:00:00Z")
        try context.save()

        let nextReferenceDate = makeDate("2026-07-30T10:00:00Z")

        let secondResult = try RoutinaScreenshotDataSeeder.seed(
            in: context,
            referenceDate: nextReferenceDate,
            calendar: calendar
        )

        #expect(secondResult.totalInsertedCount == 0)
        #expect(secondResult.refreshedRecordCount > 0)
        #expect(try context.fetchCount(FetchDescriptor<RoutineTask>()) == firstTaskCount)
        #expect(try context.fetchCount(FetchDescriptor<RoutineLog>()) == firstLogCount)
        let refreshedTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(refreshedTasks.contains { $0.id == userTask.id && $0.name == "My existing task" })
        let refreshedScreenshotTask = try #require(
            refreshedTasks.first { $0.id == seededScreenshotTask.id }
        )
        #expect(refreshedScreenshotTask.name == "Prepare App Store screenshots")
        #expect(
            refreshedScreenshotTask.deadline
                == calendar.date(bySettingHour: 18, minute: 0, second: 0, of: nextReferenceDate)
        )

        let refreshedPreferences = try #require(
            try context.fetch(FetchDescriptor<RoutinaUserPreferences>()).first
        )
        let refreshedSections = HomeCustomTaskSectionStorage.decoded(
            from: refreshedPreferences.customTaskSections
        )
        #expect(refreshedSections.count == 6)
        #expect(refreshedSections.contains { $0.id == userSection.id })
    }

    @Test
    func seedRetiresOnlyFixtureOwnedEmotionLogs() throws {
        let context = makeInMemoryContext()
        let retiredID = try #require(RoutinaScreenshotDataSeeder.retiredEmotionIDs.first)
        let retiredEmotion = EmotionLog(
            id: retiredID,
            family: .calm,
            label: "calm",
            valence: 0.4,
            arousal: -0.3,
            intensity: 2
        )
        let userEmotion = EmotionLog(
            family: .joy,
            label: "grateful",
            valence: 0.7,
            arousal: 0.2,
            intensity: 4
        )
        context.insert(retiredEmotion)
        context.insert(userEmotion)
        try context.save()

        let result = try RoutinaScreenshotDataSeeder.seed(
            in: context,
            referenceDate: makeDate("2026-07-29T10:00:00Z"),
            calendar: makeTestCalendar()
        )

        let remainingEmotions = try context.fetch(FetchDescriptor<EmotionLog>())
        #expect(result.removedRecordCount == 1)
        #expect(!remainingEmotions.contains { $0.id == retiredID })
        #expect(remainingEmotions.contains { $0.id == userEmotion.id })
    }

    @Test
    func seedRetiresOnlyFixtureOwnedEvents() throws {
        let context = makeInMemoryContext()
        let retiredID = try #require(RoutinaScreenshotDataSeeder.retiredEventIDs.first)
        let retiredEvent = RoutineEvent(id: retiredID, title: "Retired fixture event")
        let userEvent = RoutineEvent(title: "My development event")
        context.insert(retiredEvent)
        context.insert(userEvent)
        try context.save()

        let result = try RoutinaScreenshotDataSeeder.seed(
            in: context,
            referenceDate: makeDate("2026-07-29T10:00:00Z"),
            calendar: makeTestCalendar()
        )

        let remainingEvents = try context.fetch(FetchDescriptor<RoutineEvent>())
        #expect(result.removedRecordCount == 1)
        #expect(!remainingEvents.contains { $0.id == retiredID })
        #expect(remainingEvents.contains { $0.id == userEvent.id })
    }
}
