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
        #expect(draft.hasExplicitPriority)
        #expect(draft.estimatedDurationMinutes == 25)
        #expect(draft.focusModeEnabled)
    }

    @Test
    func parseIgnoresPlaceSyntaxWhenPlacesAreDisabled() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Water plants every Saturday at 9am #home @Balcony !high 25m",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar(),
            includingPlaces: false
        ))

        #expect(draft.name == "Water plants @Balcony")
        #expect(draft.tags == ["home"])
        #expect(draft.placeName == nil)
        #expect(draft.estimatedDurationMinutes == 25)
    }

    @Test
    func parseBareHourAfterAtAsExactTime() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Water plants every Sat at 9 #home",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        #expect(draft.name == "Water plants")
        #expect(draft.recurrenceRule.kind == .weekly)
        #expect(draft.recurrenceRule.weekday == 7)
        #expect(draft.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 9, minute: 0))
        #expect(draft.tags == ["home"])
    }

    @Test
    func parsePartOfDayAsExactTime() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Check if I have paracetamol every day night",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        #expect(draft.name == "Check if I have paracetamol")
        #expect(draft.recurrenceRule.kind == .dailyTime)
        #expect(draft.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 21, minute: 0))
    }

    @Test
    func parseTomorrowTodoWithExactAvailability() throws {
        let calendar = makeTestCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Pay rent tomorrow at 8pm #finance",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: calendar
        ))
        let expectedAvailability = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: 24
        )))

        #expect(draft.name == "Pay rent")
        #expect(draft.scheduleMode == .oneOff)
        #expect(draft.availabilityStartDate == expectedAvailability)
        #expect(draft.availabilityEndDate == nil)
        #expect(draft.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 20, minute: 0))
        #expect(draft.deadline == nil)
        #expect(draft.reminderAt == nil)
        #expect(draft.tags == ["finance"])
    }

    @Test
    func parseWeekdayDayMonthAndBare24HourTimeAsTodoAvailability() throws {
        let calendar = makeTestCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Physiotherapist Tuesday, 25 August 15:00",
            referenceDate: makeDate("2026-08-20T10:00:00Z"),
            calendar: calendar
        ))
        let expectedAvailability = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 25
        )))
        let expectedEvent = RoutineTimeOfDay(hour: 15, minute: 0)
            .date(on: expectedAvailability, calendar: calendar)

        #expect(draft.name == "Physiotherapist")
        #expect(draft.scheduleMode == .oneOff)
        #expect(draft.availabilityStartDate == expectedAvailability)
        #expect(draft.availabilityEndDate == nil)
        #expect(draft.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 15, minute: 0))
        #expect(draft.exactAvailabilityDate(calendar: calendar) == expectedEvent)
        #expect(draft.deadline == nil)
        #expect(draft.reminderAt == nil)
        #expect(draft.hasDetectedSchedule)
    }

    @Test
    func parseDayMonthWithoutYearUsesItsNextOccurrence() throws {
        let calendar = makeTestCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Dentist 5 January at 09:30",
            referenceDate: makeDate("2026-08-20T10:00:00Z"),
            calendar: calendar
        ))
        let expectedAvailability = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2027,
            month: 1,
            day: 5
        )))

        #expect(draft.name == "Dentist")
        #expect(draft.availabilityStartDate == expectedAvailability)
        #expect(draft.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 9, minute: 30))
        #expect(draft.deadline == nil)
        #expect(draft.reminderAt == nil)
    }

    @Test
    func parseWeekdayDisambiguatesTheInferredYear() throws {
        let calendar = makeTestCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Physiotherapist Wednesday, 25 August 15:00",
            referenceDate: makeDate("2026-08-26T10:00:00Z"),
            calendar: calendar
        ))
        let expectedAvailability = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2027,
            month: 8,
            day: 25
        )))

        #expect(draft.name == "Physiotherapist")
        #expect(draft.availabilityStartDate == expectedAvailability)
        #expect(draft.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 15, minute: 0))
    }

    @Test
    func parseExplicitDueDateAsDeadlineWithoutAddingReminder() throws {
        let calendar = makeTestCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Submit claim by 25 August 15:00",
            referenceDate: makeDate("2026-08-20T10:00:00Z"),
            calendar: calendar
        ))
        let expectedDeadline = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 25,
            hour: 15,
            minute: 0
        )))

        #expect(draft.name == "Submit claim")
        #expect(draft.availabilityStartDate == nil)
        #expect(draft.deadline == expectedDeadline)
        #expect(draft.reminderAt == nil)
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
    func parseGentleRoutineFromSoftSyntax() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Clean desk every 2 days softly",
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        #expect(draft.name == "Clean desk")
        #expect(draft.scheduleMode == .softInterval)
        #expect(draft.summaryText == "Gentle routine · Every 2 days")
    }

    @Test
    func parseEveryOtherTuesdayAsAdvancedWeeklyRule() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Physical therapy every other Tuesday at 9am",
            referenceDate: makeDate("2026-07-22T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        let advanced = try #require(draft.recurrenceRule.advanced)
        #expect(draft.name == "Physical therapy")
        #expect(advanced.frequency == .weekly)
        #expect(advanced.interval == 2)
        #expect(advanced.weekdays == [3])
    }

    @Test
    func parseEveryThreeSaturdaysAsAdvancedWeeklyRule() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Deep clean every 3 Sat",
            referenceDate: makeDate("2026-07-22T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        let advanced = try #require(draft.recurrenceRule.advanced)
        #expect(draft.name == "Deep clean")
        #expect(advanced.frequency == .weekly)
        #expect(advanced.interval == 3)
        #expect(advanced.weekdays == [7])
    }

    @Test
    func parseOrdinalWeekdayInAlternatingMonths() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Review accounts every 2 months on first Friday",
            referenceDate: makeDate("2026-07-22T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        let advanced = try #require(draft.recurrenceRule.advanced)
        #expect(draft.name == "Review accounts")
        #expect(advanced.frequency == .monthly)
        #expect(advanced.interval == 2)
        #expect(advanced.monthlyPattern == .ordinalWeekday)
        #expect(advanced.weekdayOrdinal == .first)
        #expect(advanced.ordinalWeekday == 6)
    }

    @Test
    func parseHourlyMedicineCadenceWithoutTreatingItAsDuration() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Take medicine every 6 hours during the day at 7am",
            referenceDate: makeDate("2026-07-22T10:00:00Z"),
            calendar: makeTestCalendar()
        ))

        let advanced = try #require(draft.recurrenceRule.advanced)
        #expect(draft.name == "Take medicine")
        #expect(draft.estimatedDurationMinutes == nil)
        #expect(advanced.frequency == .hourly)
        #expect(advanced.interval == 6)
        #expect(advanced.hourlyMode == .dailyWindow)
        #expect(RoutineTimeOfDay.from(advanced.startDate, calendar: makeTestCalendar()) == RoutineTimeOfDay(hour: 7, minute: 0))
    }

    @Test
    func createTaskUsesSharedSavePath() async throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Balcony")
        _ = makeTask(in: context, name: "Existing home tag", interval: 1, lastDone: nil, emoji: "🏠", tags: ["Home"])

        let result = try await RoutinaQuickAddService.createTask(
            from: "Water plants every Saturday at 9am #home @Balcony !high 25m",
            context: context,
            referenceDate: makeDate("2026-04-23T10:00:00Z"),
            calendar: makeTestCalendar(),
            includingPlaces: true
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let task = try #require(tasks.first { $0.id == result.taskID })

        #expect(task.name == "Water plants")
        #expect(task.placeID == place.id)
        #expect(task.tags == ["Home"])
        #expect(task.scheduleMode == .fixedInterval)
        #expect(task.recurrenceRule.kind == .weekly)
        #expect(task.recurrenceRule.weekday == 7)
        #expect(task.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 9, minute: 0))
        #expect(task.estimatedDurationMinutes == 25)
        #expect(task.focusModeEnabled)
        #expect(task.priority == .high)
        #expect(result.matchedPlaceName == "Balcony")
    }

    @Test
    func createTaskPersistsExactAvailabilityAndChosenReminderWithoutDeadline() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let expectedAvailability = try #require(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 8,
            day: 25
        )))
        let eventDate = RoutineTimeOfDay(hour: 15, minute: 0)
            .date(on: expectedAvailability, calendar: calendar)
        let reminderAt = eventDate.addingTimeInterval(-60 * 60)

        let result = try await RoutinaQuickAddService.createTask(
            from: "Physiotherapist Tuesday, 25 August 15:00",
            context: context,
            referenceDate: makeDate("2026-08-20T10:00:00Z"),
            calendar: calendar,
            reminderAt: reminderAt
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let task = try #require(tasks.first { $0.id == result.taskID })

        #expect(task.name == "Physiotherapist")
        #expect(task.availabilityStartDate == expectedAvailability)
        #expect(task.availabilityEndDate == nil)
        #expect(task.recurrenceRule.timeOfDay == RoutineTimeOfDay(hour: 15, minute: 0))
        #expect(task.deadline == nil)
        #expect(task.reminderAt == reminderAt)
    }

    @Test
    func createTaskWithoutPrioritySyntaxKeepsPriorityUnset() async throws {
        let context = makeInMemoryContext()

        let result = try await RoutinaQuickAddService.createTask(
            from: "test2 #test",
            context: context,
            referenceDate: makeDate("2026-07-25T10:00:00Z"),
            calendar: makeTestCalendar()
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let task = try #require(tasks.first { $0.id == result.taskID })

        #expect(!result.draft.hasExplicitPriority)
        #expect(task.importance == .level2)
        #expect(task.urgency == .level2)
        #expect(task.priority == .none)
        #expect(!TaskDetailOptionalControlVisibility.showsPriority(for: task))
    }

    @Test
    func createTaskWithExplicitMediumPriorityKeepsPriorityVisible() async throws {
        let context = makeInMemoryContext()

        let result = try await RoutinaQuickAddService.createTask(
            from: "Review notes !medium",
            context: context,
            referenceDate: makeDate("2026-07-25T10:00:00Z"),
            calendar: makeTestCalendar()
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let task = try #require(tasks.first { $0.id == result.taskID })

        #expect(result.draft.hasExplicitPriority)
        #expect(task.priority == .medium)
        #expect(task.showsTaskDetailPriority)
        #expect(TaskDetailOptionalControlVisibility.showsPriority(for: task))
    }
}
