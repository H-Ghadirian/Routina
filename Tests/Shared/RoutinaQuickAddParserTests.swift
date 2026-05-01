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
struct RoutinaQuickAddParserTests {
    @Test
    func parseWeeklyRoutineWithMetadata() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Water plants every Saturday at 9am #home @Balcony !high 25m",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        #expect(draft.name == "Water plants")
        #expect(draft.scheduleMode == .fixedInterval)
        #expect(draft.frequencyInDays == 7)
        #expect(draft.recurrenceRule.kind == .weekly)
        #expect(draft.recurrenceRule.weekday == 7)
        #expect(draft.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 9, minute: 0))
        #expect(draft.tags == ["home"])
        #expect(draft.placeName == "Balcony")
        #expect(draft.importance == .level3)
        #expect(draft.urgency == .level3)
        #expect(draft.estimatedDurationMinutes == 25)
        #expect(draft.focusModeEnabled)
    }

    @Test
    func parseTomorrowTodoWithDeadline() throws {
        let calendar = makeTestCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Pay rent tomorrow at 8pm #finance",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: calendar
        ))
        let expectedDeadline = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 24,
            hour: 20,
            minute: 0
        )))

        #expect(draft.name == "Pay rent")
        #expect(draft.scheduleMode == .oneOff)
        #expect(draft.deadline == expectedDeadline)
        #expect(draft.reminderAt == expectedDeadline)
        #expect(draft.tags == ["finance"])
    }

    @Test
    func parseFixedIntervalRoutine() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Buy coffee beans every 20 days",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        #expect(draft.name == "Buy coffee beans")
        #expect(draft.scheduleMode == .fixedInterval)
        #expect(draft.frequencyInDays == 20)
        #expect(draft.recurrenceRule == .interval(days: 20))
    }

    @Test
    func createTaskUsesSharedSavePath() async throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Balcony")
        let result = try await RoutinaQuickAddService.createTask(
            from: "Water plants every Saturday at 9am #home @Balcony !high 25m",
            context: context,
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar()
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let task = try #require(tasks.first { $0.id == result.taskID })

        #expect(task.name == "Water plants")
        #expect(task.placeID == place.id)
        #expect(task.tags == ["home"])
        #expect(task.scheduleMode == .fixedInterval)
        #expect(task.recurrenceRule.kind == .weekly)
        #expect(task.recurrenceRule.weekday == 7)
        #expect(task.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 9, minute: 0))
        #expect(task.estimatedDurationMinutes == 25)
        #expect(task.focusModeEnabled)
        #expect(result.matchedPlaceName == "Balcony")
    }
}
