import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct HomeMacToolbarQuickAddSubmissionTests {
    @Test
    func submissionKeepsTheEditedLinkTitleVisibleAtReturn() throws {
        let draft = try #require(RoutinaQuickAddParser.parse(
            "https://www.youtube.com/watch?v=abc123"
        ))

        let submission = HomeMacToolbarQuickAddSubmission(
            draft: draft,
            taskTitle: "Watch my edited mobility title",
            reminderChoice: .none,
            customReminderAt: Date(timeIntervalSince1970: 2_000_000),
            calendar: makeCalendar()
        )

        #expect(submission.taskTitle == "Watch my edited mobility title")
        #expect(submission.reminderAt == nil)
    }

    @Test
    func submissionKeepsTheSelectedReminderVisibleAtReturn() throws {
        let calendar = makeCalendar()
        let draft = try #require(RoutinaQuickAddParser.parse(
            "Physiotherapist Tuesday, 25 August 15:00",
            referenceDate: makeDate("2026-08-20T10:00:00Z"),
            calendar: calendar
        ))
        let eventDate = try #require(draft.exactAvailabilityDate(calendar: calendar))

        let submission = HomeMacToolbarQuickAddSubmission(
            draft: draft,
            taskTitle: "Physiotherapist",
            reminderChoice: .twoHours,
            customReminderAt: Date(timeIntervalSince1970: 2_000_000),
            calendar: calendar
        )

        #expect(submission.taskTitle == "Physiotherapist")
        #expect(submission.reminderAt == eventDate.addingTimeInterval(-2 * 60 * 60))
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func makeDate(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
    }
}
