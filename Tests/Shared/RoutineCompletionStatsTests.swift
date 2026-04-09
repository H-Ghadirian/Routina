import Foundation
import Testing
@testable @preconcurrency import RoutinaAppSupport

struct RoutineCompletionStatsTests {
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
}
