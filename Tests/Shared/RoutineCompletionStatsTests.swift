import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutineCompletionStatsTests {
    @Test
    func todayPoints_countOnlyReferenceDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let referenceDate = makeDate("2026-03-14T10:00:00Z")
        let timestamps = [
            makeDate("2026-03-13T23:59:59Z"),
            makeDate("2026-03-14T08:00:00Z"),
            makeDate("2026-03-14T18:00:00Z"),
            makeDate("2026-03-15T00:00:00Z")
        ]

        let points = RoutineCompletionStats.points(
            for: .today,
            timestamps: timestamps,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(points.count == 1)
        #expect(points.first?.date == makeDate("2026-03-14T00:00:00Z"))
        #expect(points.first?.count == 2)
    }

    @Test
    func weekPoints_countTrailingSevenDaysAndZeroFillMissingDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let referenceDate = makeDate("2026-03-14T10:00:00Z")
        let timestamps = [
            makeDate("2026-03-08T08:00:00Z"),
            makeDate("2026-03-10T08:00:00Z"),
            makeDate("2026-03-10T18:00:00Z"),
            makeDate("2026-03-13T08:00:00Z"),
            makeDate("2026-03-14T09:00:00Z"),
            makeDate("2026-03-15T09:00:00Z")
        ]

        let points = RoutineCompletionStats.points(
            for: .week,
            timestamps: timestamps,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(points.count == 7)
        #expect(points.first?.date == makeDate("2026-03-08T00:00:00Z"))
        #expect(points.last?.date == makeDate("2026-03-14T00:00:00Z"))
        #expect(points.map(\.count) == [1, 0, 2, 0, 0, 1, 1])
    }

    @Test
    func monthPoints_coverTrailingThirtyDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let referenceDate = makeDate("2026-03-14T10:00:00Z")
        let timestamps = [
            makeDate("2026-02-12T23:59:59Z"),
            makeDate("2026-02-13T08:00:00Z"),
            makeDate("2026-02-28T08:00:00Z"),
            makeDate("2026-03-14T08:00:00Z")
        ]

        let points = RoutineCompletionStats.points(
            for: .month,
            timestamps: timestamps,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(points.count == 30)
        #expect(points.first?.date == makeDate("2026-02-13T00:00:00Z"))
        #expect(points.last?.date == makeDate("2026-03-14T00:00:00Z"))
        #expect(points.first?.count == 1)
        #expect(points.last?.count == 1)
        #expect(RoutineCompletionStats.totalCount(in: points) == 3)
    }

    @Test
    func yearPoints_coverTrailingThreeHundredSixtyFiveDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let referenceDate = makeDate("2026-03-14T10:00:00Z")
        let timestamps = [
            makeDate("2025-03-14T23:59:59Z"),
            makeDate("2025-03-15T08:00:00Z"),
            makeDate("2025-12-31T08:00:00Z"),
            makeDate("2026-03-14T08:00:00Z")
        ]

        let points = RoutineCompletionStats.points(
            for: .year,
            timestamps: timestamps,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(points.count == 365)
        #expect(points.first?.date == makeDate("2025-03-15T00:00:00Z"))
        #expect(points.last?.date == makeDate("2026-03-14T00:00:00Z"))
        #expect(points.first?.count == 1)
        #expect(points.last?.count == 1)
        #expect(RoutineCompletionStats.totalCount(in: points) == 3)
        #expect(RoutineCompletionStats.busiestDay(in: points)?.count == 1)
    }

    @Test
    func weekPoints_ignoreDatesOutsideSelectedRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let referenceDate = makeDate("2026-03-14T10:00:00Z")
        let timestamps = [
            makeDate("2026-03-07T12:00:00Z"),
            makeDate("2026-03-08T08:00:00Z"),
            makeDate("2026-03-14T18:00:00Z"),
            makeDate("2026-03-15T08:00:00Z")
        ]

        let points = RoutineCompletionStats.points(
            for: .week,
            timestamps: timestamps,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(points.map(\.count) == [1, 0, 0, 0, 0, 0, 1])
        #expect(RoutineCompletionStats.totalCount(in: points) == 2)
    }

    @Test
    func outcomePoints_bucketDoneMissedAndCanceledByDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let taskID = UUID()
        let referenceDate = makeDate("2026-03-14T10:00:00Z")
        let logs = [
            RoutineLog(timestamp: makeDate("2026-03-10T08:00:00Z"), taskID: taskID, kind: .completed),
            RoutineLog(timestamp: makeDate("2026-03-10T18:00:00Z"), taskID: taskID, kind: .missed),
            RoutineLog(timestamp: makeDate("2026-03-11T08:00:00Z"), taskID: taskID, kind: .canceled),
            RoutineLog(timestamp: makeDate("2026-03-15T08:00:00Z"), taskID: taskID, kind: .completed)
        ]

        let points = RoutineCompletionStats.outcomePoints(
            for: .week,
            logs: logs,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(points.count == 7)
        #expect(points[2].date == makeDate("2026-03-10T00:00:00Z"))
        #expect(points[2].doneCount == 1)
        #expect(points[2].missedCount == 1)
        #expect(points[2].canceledCount == 0)
        #expect(points[2].totalCount == 2)
        #expect(points[3].doneCount == 0)
        #expect(points[3].missedCount == 0)
        #expect(points[3].canceledCount == 1)
        #expect(points.last?.totalCount == 0)
    }

    @Test
    func points_bucketByProvidedCalendarTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))

        let referenceDate = makeDate("2026-03-14T12:00:00Z")
        let timestamps = [
            makeDate("2026-03-13T22:30:00Z"),
            makeDate("2026-03-13T23:30:00Z"),
            makeDate("2026-03-14T00:30:00Z")
        ]

        let points = RoutineCompletionStats.points(
            for: .week,
            timestamps: timestamps,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(points.last?.date == calendar.startOfDay(for: referenceDate))
        #expect(points[5].count == 1)
        #expect(points[6].count == 2)
    }

    @Test
    func averageAndBusiestDay_computeSummaryValues() {
        let points = [
            DoneChartPoint(date: makeDate("2026-03-10T00:00:00Z"), count: 2),
            DoneChartPoint(date: makeDate("2026-03-11T00:00:00Z"), count: 5),
            DoneChartPoint(date: makeDate("2026-03-12T00:00:00Z"), count: 2)
        ]

        #expect(RoutineCompletionStats.totalCount(in: points) == 9)
        #expect(RoutineCompletionStats.averageCount(in: points) == 3)
        #expect(RoutineCompletionStats.busiestDay(in: points)?.date == makeDate("2026-03-11T00:00:00Z"))
    }

    @Test
    func busiestDay_prefersEarlierDateWhenCountsTie() {
        let points = [
            DoneChartPoint(date: makeDate("2026-03-10T00:00:00Z"), count: 4),
            DoneChartPoint(date: makeDate("2026-03-11T00:00:00Z"), count: 4),
            DoneChartPoint(date: makeDate("2026-03-12T00:00:00Z"), count: 1)
        ]

        #expect(RoutineCompletionStats.busiestDay(in: points)?.date == makeDate("2026-03-10T00:00:00Z"))
    }

    @Test
    func summaryHelpers_handleEmptyPointCollections() {
        let points: [DoneChartPoint] = []

        #expect(RoutineCompletionStats.totalCount(in: points) == 0)
        #expect(RoutineCompletionStats.averageCount(in: points) == 0)
        #expect(RoutineCompletionStats.busiestDay(in: points) == nil)
    }

    @Test
    func focusWeekdayAveragePoints_averageDailyFocusByWeekdayInCalendarOrder() {
        var calendar = makeTestCalendar()
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let startDate = makeDate("2026-03-02T00:00:00Z")
        let secondsByDayOffset: [Int: TimeInterval] = [
            0: 60 * 60,
            7: 120 * 60,
            8: 30 * 60
        ]
        let points = (0..<14).compactMap { offset -> FocusDurationChartPoint? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return nil
            }

            return FocusDurationChartPoint(
                date: date,
                seconds: secondsByDayOffset[offset, default: 0]
            )
        }

        let weekdayPoints = FocusDurationStats.weekdayAveragePoints(
            from: points,
            calendar: calendar
        )

        #expect(weekdayPoints.map(\.shortSymbol) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        #expect(weekdayPoints.map(\.contributingDayCount) == Array(repeating: 2, count: 7))
        #expect(weekdayPoints[0].seconds == TimeInterval(90 * 60))
        #expect(weekdayPoints[1].seconds == TimeInterval(15 * 60))
        #expect(weekdayPoints[2].seconds == 0)
        #expect(FocusDurationStats.strongestWeekdayAverage(in: weekdayPoints)?.weekday == 2)
    }
}
