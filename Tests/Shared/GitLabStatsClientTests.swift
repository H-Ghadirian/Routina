import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct GitLabStatsClientTests {
    // MARK: - Event weighting

    @Test
    func gitLabEventWeight_nonPushEventCountsAsOne() {
        #expect(gitLabEventWeight(pushCommitCount: nil) == 1)
    }

    @Test
    func gitLabEventWeight_pushEventCountsCommits() {
        #expect(gitLabEventWeight(pushCommitCount: 7) == 7)
    }

    @Test
    func gitLabEventWeight_zeroCommitPushFallsBackToOne() {
        // GitLab occasionally returns push events with commit_count=0
        // (e.g., branch creation). Treat those as a single contribution.
        #expect(gitLabEventWeight(pushCommitCount: 0) == 1)
    }

    // MARK: - Date parsing

    @Test
    func parseGitLabDate_parsesIsoWithFractionalSeconds() {
        let date = parseGitLabDate("2025-04-20T12:34:56.789Z")
        #expect(date != nil)
    }

    @Test
    func parseGitLabDate_parsesIsoWithoutFractionalSeconds() {
        let date = parseGitLabDate("2025-04-20T12:34:56Z")
        #expect(date != nil)
    }

    @Test
    func parseGitLabDate_rejectsGarbage() {
        #expect(parseGitLabDate("not a date") == nil)
    }

    // MARK: - Widget data aggregation

    @Test
    func makeGitLabWidgetData_emptyCountsProducesZeroTotal() {
        let calendar = makeUTCCalendar()
        let now = makeUTCDate("2025-04-23T10:00:00Z")
        let fetchFloor = calendar.date(byAdding: .day, value: -364, to: calendar.startOfDay(for: now))!

        let data = makeGitLabWidgetData(
            dailyCounts: [:],
            username: "ghadirian",
            now: now,
            calendar: calendar,
            fetchFloor: fetchFloor
        )

        #expect(data.username == "ghadirian")
        #expect(data.totalContributions == 0)
    }

    @Test
    func makeGitLabWidgetData_totalSumsAllCounts() {
        let calendar = makeUTCCalendar()
        let now = makeUTCDate("2025-04-23T10:00:00Z")
        let fetchFloor = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now))!

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: today)!

        let data = makeGitLabWidgetData(
            dailyCounts: [
                today: 5,
                yesterday: 3,
                lastWeek: 2
            ],
            username: "ghadirian",
            now: now,
            calendar: calendar,
            fetchFloor: fetchFloor
        )

        #expect(data.totalContributions == 10)
    }

    @Test
    func makeGitLabWidgetData_shrinksGridToEarliestEvent() {
        // Fetch floor is 364 days back; earliest event is only 30 days back.
        // Grid should start at the earliest-event week boundary, not at the
        // fetch floor, so the widget isn't padded with empty months.
        let calendar = makeUTCCalendar()
        let now = makeUTCDate("2025-04-23T10:00:00Z")
        let today = calendar.startOfDay(for: now)
        let fetchFloor = calendar.date(byAdding: .day, value: -364, to: today)!
        let earliestEventDay = calendar.date(byAdding: .day, value: -30, to: today)!

        let data = makeGitLabWidgetData(
            dailyCounts: [earliestEventDay: 1, today: 1],
            username: "ghadirian",
            now: now,
            calendar: calendar,
            fetchFloor: fetchFloor
        )

        // 30-day span should fit in ≤6 weeks, far fewer than 52.
        #expect(data.weeks.count <= 6)
        #expect(data.weeks.count >= 4)
    }

    @Test
    func makeGitLabWidgetData_clampsEarliestEventAtFetchFloor() {
        // If some event somehow pre-dates fetchFloor, we still clamp the grid
        // to fetchFloor — we don't want the grid growing beyond the client's
        // requested window.
        let calendar = makeUTCCalendar()
        let now = makeUTCDate("2025-04-23T10:00:00Z")
        let today = calendar.startOfDay(for: now)
        let fetchFloor = calendar.date(byAdding: .day, value: -30, to: today)!
        let preFloorDay = calendar.date(byAdding: .day, value: -60, to: today)!

        let data = makeGitLabWidgetData(
            dailyCounts: [preFloorDay: 1],
            username: "ghadirian",
            now: now,
            calendar: calendar,
            fetchFloor: fetchFloor
        )

        // Grid spans fetchFloor..today — roughly 30 days, ≤6 weeks.
        #expect(data.weeks.count <= 6)
    }

    @Test
    func makeGitLabWidgetData_gridEndsOnToday() {
        let calendar = makeUTCCalendar()
        let now = makeUTCDate("2025-04-23T10:00:00Z")
        let today = calendar.startOfDay(for: now)
        let fetchFloor = calendar.date(byAdding: .day, value: -30, to: today)!

        let data = makeGitLabWidgetData(
            dailyCounts: [today: 4],
            username: "ghadirian",
            now: now,
            calendar: calendar,
            fetchFloor: fetchFloor
        )

        // Last cell in the last week whose date string matches today.
        let todayString = gitLabDayString(today, calendar: calendar)
        let lastWeek = try! #require(data.weeks.last)
        let cellForToday = lastWeek.days.first(where: { $0.date == todayString })
        #expect(cellForToday != nil)
        #expect(cellForToday?.count == 4)
    }

    // MARK: - buildWeeks grid layout

    @Test
    func buildWeeks_usesSundayStartedWeeks() {
        // Pick a known Wednesday as startDay; the grid must pad Sun/Mon/Tue
        // as leading blanks and produce a Sunday-first week.
        let calendar = makeUTCCalendar()
        let startDay = makeUTCDate("2025-04-23T00:00:00Z") // Wednesday
        let endOfToday = startDay

        let weeks = buildWeeks(
            counts: [:],
            startDay: startDay,
            endOfToday: endOfToday,
            calendar: calendar
        )

        let firstWeek = try! #require(weeks.first)
        #expect(firstWeek.days.count == 7)

        // Leading Sun/Mon/Tue must be before startDay (outside the window)
        // and therefore have count 0.
        let startString = gitLabDayString(startDay, calendar: calendar)
        let startIndex = try! #require(firstWeek.days.firstIndex(where: { $0.date == startString }))
        #expect(startIndex == 3) // Wednesday = index 3 in a Sunday-first week
        for leadingDay in firstWeek.days.prefix(startIndex) {
            #expect(leadingDay.count == 0)
        }
    }

    @Test
    func buildWeeks_countsAreZeroOutsideWindow() {
        // A day with a count outside [startDay, endOfToday] must not appear
        // as a lit cell in the rendered grid.
        let calendar = makeUTCCalendar()
        let startDay = makeUTCDate("2025-04-20T00:00:00Z") // Sunday
        let endOfToday = makeUTCDate("2025-04-23T00:00:00Z") // Wednesday
        let outsideDay = calendar.date(byAdding: .day, value: -5, to: startDay)!

        let weeks = buildWeeks(
            counts: [outsideDay: 99],
            startDay: startDay,
            endOfToday: endOfToday,
            calendar: calendar
        )

        let outsideString = gitLabDayString(outsideDay, calendar: calendar)
        let outsideCell = weeks.flatMap(\.days).first(where: { $0.date == outsideString })
        // Either the cell isn't rendered at all, or it's rendered with 0.
        if let cell = outsideCell {
            #expect(cell.count == 0)
        }
    }
}

// MARK: - Helpers

private func makeUTCCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
}

private func makeUTCDate(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: iso) ?? Date()
}

private func gitLabDayString(_ day: Date, calendar: Calendar) -> String {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: day)
}
