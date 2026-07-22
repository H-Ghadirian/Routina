import ComposableArchitecture
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
struct CalendarTaskImportFeatureTests {
    @Test
    func addTaskRequested_persistsCalendarTaskThroughReducer() async throws {
        let context = makeInMemoryContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let formatter = ISO8601DateFormatter()
        let startDate = try #require(formatter.date(from: "2026-07-25T09:00:00Z"))
        let endDate = try #require(formatter.date(from: "2026-07-25T10:00:00Z"))
        let suggestion = CalendarTaskSuggestion(
            id: "calendar-event",
            eventIdentifier: "event-id",
            calendarIdentifier: "calendar-id",
            calendarTitle: "Work",
            eventTitle: "Architecture review",
            eventStartDate: startDate,
            eventEndDate: endDate,
            isAllDay: false,
            taskTitle: "  Prepare architecture review  ",
            deadline: startDate,
            reviewState: .pending
        )

        let store = TestStore(initialState: CalendarTaskImportFeature.State()) {
            CalendarTaskImportFeature()
        } withDependencies: {
            $0.calendar = calendar
            $0.modelContext = { context }
        }

        await store.send(.addTaskRequested(suggestion))
        await store.receive(\.addTaskSucceeded) {
            $0.addedSuggestionIDs = [suggestion.id]
        }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let task = try #require(tasks.first)
        #expect(tasks.count == 1)
        #expect(task.name == "Prepare architecture review")
        #expect(task.tags == ["Calendar"])
        #expect(task.deadline == startDate)
        #expect(task.todoState == .ready)
        #expect(CalendarTaskImportSupport.sourceMarker(in: task.notes ?? "") == "Calendar event: event-id")
    }

    @Test
    func addTaskRequested_ignoresNonPendingSuggestion() async {
        let suggestion = CalendarTaskSuggestion(
            id: "duplicate",
            eventIdentifier: "event-id",
            calendarIdentifier: "calendar-id",
            calendarTitle: "Work",
            eventTitle: "Already imported",
            eventStartDate: .distantPast,
            eventEndDate: .distantPast,
            isAllDay: false,
            taskTitle: "Already imported",
            deadline: nil,
            reviewState: .duplicate
        )
        let store = TestStore(initialState: CalendarTaskImportFeature.State()) {
            CalendarTaskImportFeature()
        }

        await store.send(.addTaskRequested(suggestion))
    }
}
