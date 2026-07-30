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

        #expect(result.taskCount == RoutinaScreenshotDataSeeder.taskCount)
        #expect(result.logCount >= 80)
        #expect(result.plannerBlockCount == 5)
        #expect(tasks.count == 10)
        #expect(logs.count >= 80)
        #expect(blocks.count == 5)
        #expect(focusSessions.count == 14)
        #expect(goals.count == 3)
        #expect(notes.count == 3)
        #expect(events.count == 2)
        #expect(emotions.count == 10)
        #expect(sleepSessions.count == 10)
        #expect(awaySessions.count == 4)
        #expect(focusSessions.allSatisfy { $0.state == .completed })
        #expect(sleepSessions.allSatisfy { !$0.isActive })
        #expect(awaySessions.allSatisfy { !$0.isActive })
        #expect(tasks.contains { $0.name == "Prepare product screenshots" })
        #expect(tasks.contains { $0.scheduleMode == .derivedFromChecklist })
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
        try context.save()

        _ = try RoutinaScreenshotDataSeeder.seed(
            in: context,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let firstTaskCount = try context.fetchCount(FetchDescriptor<RoutineTask>())
        let firstLogCount = try context.fetchCount(FetchDescriptor<RoutineLog>())

        let secondResult = try RoutinaScreenshotDataSeeder.seed(
            in: context,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(secondResult.totalInsertedCount == 0)
        #expect(try context.fetchCount(FetchDescriptor<RoutineTask>()) == firstTaskCount)
        #expect(try context.fetchCount(FetchDescriptor<RoutineLog>()) == firstLogCount)
        #expect(try context.fetch(FetchDescriptor<RoutineTask>()).contains { $0.id == userTask.id })
    }
}
