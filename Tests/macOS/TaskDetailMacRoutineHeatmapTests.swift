import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct TaskDetailMacRoutineHeatmapTests {
    @Test
    func weeksCoverTrailingYearIncludingReferenceDate() {
        var calendar = gregorianUTC
        calendar.firstWeekday = 2
        let referenceDate = date(year: 2026, month: 7, day: 13, calendar: calendar)

        let weeks = TaskDetailMacRoutineHeatmapPresentation.weeks(
            doneDates: [],
            referenceDate: referenceDate,
            calendar: calendar
        )
        let visibleDays = weeks.flatMap(\.days).compactMap(\.self)

        #expect(visibleDays.count == TaskDetailMacRoutineHeatmapPresentation.visibleDayCount)
        #expect(visibleDays.first?.date == date(year: 2025, month: 7, day: 14, calendar: calendar))
        #expect(visibleDays.last?.date == referenceDate)
    }

    @Test
    func doneDatesIncludeFulfilledLogsAndLastDone() {
        let calendar = gregorianUTC
        let task = RoutineTask(
            name: "Exercise",
            scheduleMode: .fixedInterval,
            lastDone: date(year: 2026, month: 7, day: 12, calendar: calendar)
        )
        let logs = [
            RoutineLog(
                timestamp: date(year: 2026, month: 7, day: 10, calendar: calendar),
                taskID: task.id,
                kind: .fulfilled
            ),
            RoutineLog(
                timestamp: date(year: 2026, month: 7, day: 11, calendar: calendar),
                taskID: task.id,
                kind: .completed
            ),
            RoutineLog(
                timestamp: date(year: 2026, month: 7, day: 9, calendar: calendar),
                taskID: task.id,
                kind: .missed
            )
        ]

        let doneDates = TaskDetailMacRoutineHeatmapPresentation.doneDates(
            logs: logs,
            task: task,
            calendar: calendar
        )

        #expect(doneDates.contains(date(year: 2026, month: 7, day: 10, calendar: calendar)))
        #expect(doneDates.contains(date(year: 2026, month: 7, day: 11, calendar: calendar)))
        #expect(doneDates.contains(date(year: 2026, month: 7, day: 12, calendar: calendar)))
        #expect(!doneDates.contains(date(year: 2026, month: 7, day: 9, calendar: calendar)))
    }

    @Test
    func completedDayCountDeduplicatesSameDayLogsAndIgnoresOlderDays() {
        let calendar = gregorianUTC
        let referenceDate = date(year: 2026, month: 7, day: 13, calendar: calendar)
        let task = RoutineTask(name: "Practice", scheduleMode: .fixedInterval)
        let logs = [
            RoutineLog(
                timestamp: date(year: 2026, month: 7, day: 12, calendar: calendar),
                taskID: task.id,
                kind: .completed
            ),
            RoutineLog(
                timestamp: date(year: 2026, month: 7, day: 12, calendar: calendar),
                taskID: task.id,
                kind: .fulfilled
            ),
            RoutineLog(
                timestamp: date(year: 2025, month: 7, day: 13, calendar: calendar),
                taskID: task.id,
                kind: .completed
            )
        ]

        let count = TaskDetailMacRoutineHeatmapPresentation.completedDayCount(
            logs: logs,
            task: task,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(count == 1)
    }
}

private let gregorianUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
    DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day
    ).date!
}
