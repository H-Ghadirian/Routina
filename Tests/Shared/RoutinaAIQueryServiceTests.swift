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
struct RoutinaAIQueryServiceTests {
    @Test
    func snapshotFiltersBySearchTextAndCountsMatchingTasks() throws {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home")
        _ = makeTask(
            in: context,
            name: "Workout",
            interval: 1,
            lastDone: makeDate("2026-04-20T08:00:00Z"),
            emoji: "💪",
            placeID: home.id,
            tags: ["Health"],
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 7, minute: 0))
        )
        _ = makeTask(
            in: context,
            name: "Review budget",
            interval: 30,
            lastDone: makeDate("2026-04-01T08:00:00Z"),
            emoji: "💸",
            tags: ["Admin"],
            recurrenceRule: .monthly(on: 1)
        )

        let snapshot = try RoutinaAIQueryService.snapshot(
            in: context,
            query: RoutinaAITaskQuery(searchText: "health home", includeArchived: true, includeCompleted: true, limit: nil),
            now: makeDate("2026-04-23T09:00:00Z"),
            calendar: makeTestCalendar()
        )

        #expect(snapshot.counts.totalTasks == 2)
        #expect(snapshot.counts.matchingTasks == 1)
        #expect(snapshot.tasks.count == 1)
        #expect(snapshot.tasks.first?.name == "Workout")
        #expect(snapshot.tasks.first?.placeName == "Home")
    }

    @Test
    func snapshotExcludesArchivedAndCompletedWhenRequested() throws {
        let context = makeInMemoryContext()
        let pausedTask = makeTask(
            in: context,
            name: "Read novel",
            interval: 7,
            lastDone: makeDate("2026-04-10T08:00:00Z"),
            emoji: "📚",
            pausedAt: makeDate("2026-04-20T08:00:00Z")
        )
        let completedTodo = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: makeDate("2026-04-22T08:00:00Z"),
            emoji: "🥛",
            scheduleMode: .oneOff
        )
        let activeTask = makeTask(
            in: context,
            name: "Morning stretch",
            interval: 1,
            lastDone: makeDate("2026-04-22T08:00:00Z"),
            emoji: "🧘",
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 7, minute: 30))
        )

        let snapshot = try RoutinaAIQueryService.snapshot(
            in: context,
            query: RoutinaAITaskQuery(
                searchText: nil,
                includeArchived: false,
                includeCompleted: false,
                limit: nil
            ),
            now: makeDate("2026-04-23T09:00:00Z"),
            calendar: makeTestCalendar()
        )

        #expect(snapshot.counts.totalTasks == 3)
        #expect(snapshot.counts.matchingTasks == 1)
        #expect(snapshot.tasks.map(\.id) == [activeTask.id])
        #expect(!snapshot.tasks.contains(where: { $0.id == pausedTask.id }))
        #expect(!snapshot.tasks.contains(where: { $0.id == completedTodo.id }))
    }

    @Test
    func snapshotMarksOverdueTasksBeforeReadyTasks() throws {
        let context = makeInMemoryContext()
        let overdueTask = makeTask(
            in: context,
            name: "Water plants",
            interval: 2,
            lastDone: makeDate("2026-04-18T08:00:00Z"),
            emoji: "🪴",
            recurrenceRule: .interval(days: 2)
        )
        _ = makeTask(
            in: context,
            name: "Inbox zero",
            interval: 1,
            lastDone: makeDate("2026-04-23T07:00:00Z"),
            emoji: "📥",
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 19, minute: 0))
        )

        let snapshot = try RoutinaAIQueryService.snapshot(
            in: context,
            now: makeDate("2026-04-23T09:00:00Z"),
            calendar: makeTestCalendar()
        )

        #expect(snapshot.tasks.first?.id == overdueTask.id)
        #expect(snapshot.tasks.first?.primaryStatus == .overdue)
        #expect(snapshot.tasks.first?.overdueDays == 3)
    }

    @Test
    func snapshotToleratesDuplicatePlaceIDs() throws {
        let context = makeInMemoryContext()
        let sharedID = UUID()
        let firstPlace = RoutinePlace(id: sharedID, name: "Office A", latitude: 52.52, longitude: 13.40)
        let secondPlace = RoutinePlace(id: sharedID, name: "Office B", latitude: 52.52, longitude: 13.40)
        context.insert(firstPlace)
        context.insert(secondPlace)
        _ = makeTask(
            in: context,
            name: "Standup",
            interval: 1,
            lastDone: makeDate("2026-04-20T08:00:00Z"),
            emoji: "🗣️",
            placeID: sharedID,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 9, minute: 0))
        )
        try context.save()

        let snapshot = try RoutinaAIQueryService.snapshot(
            in: context,
            now: makeDate("2026-04-23T09:00:00Z"),
            calendar: makeTestCalendar()
        )

        #expect(snapshot.tasks.count == 1)
        #expect(snapshot.tasks.first?.placeName != nil)
    }
}
