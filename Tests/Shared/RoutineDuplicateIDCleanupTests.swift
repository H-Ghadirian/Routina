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
struct RoutineDuplicateIDCleanupTests {
    @Test
    func leavesUniqueRowsUntouched() throws {
        let context = makeInMemoryContext()
        let a = RoutineTask(id: UUID(), name: "A")
        let b = RoutineTask(id: UUID(), name: "B")
        context.insert(a)
        context.insert(b)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remaining.count == 2)
        #expect(Set(remaining.map(\.id)) == Set([a.id, b.id]))
    }

    @Test
    func keepsRoutineTaskWithLatestLastDone() throws {
        let context = makeInMemoryContext()
        let sharedID = UUID()
        let stale = RoutineTask(id: sharedID, name: "Stale", lastDone: makeDate("2026-01-01T10:00:00Z"))
        let fresh = RoutineTask(id: sharedID, name: "Fresh", lastDone: makeDate("2026-04-01T10:00:00Z"))
        context.insert(stale)
        context.insert(fresh)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Fresh")
    }

    @Test
    func fallsBackToCreatedAtWhenLastDoneIsNil() throws {
        let context = makeInMemoryContext()
        let sharedID = UUID()
        let older = RoutineTask(
            id: sharedID,
            name: "Older",
            createdAt: makeDate("2026-01-01T10:00:00Z")
        )
        let newer = RoutineTask(
            id: sharedID,
            name: "Newer",
            createdAt: makeDate("2026-03-01T10:00:00Z")
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Newer")
    }

    @Test
    func removesDuplicatePlacesKeepingNewest() throws {
        let context = makeInMemoryContext()
        let sharedID = UUID()
        let older = RoutinePlace(
            id: sharedID,
            name: "Old Office",
            latitude: 52.52,
            longitude: 13.40,
            createdAt: makeDate("2026-01-01T10:00:00Z")
        )
        let newer = RoutinePlace(
            id: sharedID,
            name: "New Office",
            latitude: 52.52,
            longitude: 13.40,
            createdAt: makeDate("2026-03-01T10:00:00Z")
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutinePlace>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "New Office")
    }

    @Test
    func removesDuplicateLogsKeepingLatestTimestamp() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let sharedLogID = UUID()
        let earlier = RoutineLog(
            id: sharedLogID,
            timestamp: makeDate("2026-03-10T08:00:00Z"),
            taskID: taskID
        )
        let later = RoutineLog(
            id: sharedLogID,
            timestamp: makeDate("2026-03-15T08:00:00Z"),
            taskID: taskID
        )
        context.insert(earlier)
        context.insert(later)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.timestamp == makeDate("2026-03-15T08:00:00Z"))
    }

    @Test
    func removesDuplicateFocusSessionsKeepingLatestActivity() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let sharedID = UUID()
        let abandoned = FocusSession(
            id: sharedID,
            taskID: taskID,
            startedAt: makeDate("2026-03-01T08:00:00Z"),
            abandonedAt: makeDate("2026-03-01T08:05:00Z")
        )
        let completed = FocusSession(
            id: sharedID,
            taskID: taskID,
            startedAt: makeDate("2026-03-05T08:00:00Z"),
            completedAt: makeDate("2026-03-05T08:25:00Z")
        )
        context.insert(abandoned)
        context.insert(completed)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<FocusSession>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.completedAt == makeDate("2026-03-05T08:25:00Z"))
    }

    @Test
    func isIdempotent() throws {
        let context = makeInMemoryContext()
        let sharedID = UUID()
        context.insert(RoutineTask(id: sharedID, name: "A", lastDone: makeDate("2026-01-01T10:00:00Z")))
        context.insert(RoutineTask(id: sharedID, name: "B", lastDone: makeDate("2026-04-01T10:00:00Z")))
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)
        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "B")
    }

    @Test
    func onlyTouchesGroupsWithDuplicates() throws {
        let context = makeInMemoryContext()
        let dupID = UUID()
        let unique1 = RoutineTask(id: UUID(), name: "Unique 1")
        let unique2 = RoutineTask(id: UUID(), name: "Unique 2")
        let dupOld = RoutineTask(id: dupID, name: "Dup old", lastDone: makeDate("2026-01-01T10:00:00Z"))
        let dupNew = RoutineTask(id: dupID, name: "Dup new", lastDone: makeDate("2026-04-01T10:00:00Z"))
        context.insert(unique1)
        context.insert(unique2)
        context.insert(dupOld)
        context.insert(dupNew)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remaining = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remaining.count == 3)
        let names = Set(remaining.compactMap(\.name))
        #expect(names == ["Unique 1", "Unique 2", "Dup new"])
    }

    @Test
    func canonicalReturnsNilWhenNoMatches() throws {
        let context = makeInMemoryContext()
        let missingID = UUID()
        let descriptor = FetchDescriptor<RoutineTask>(predicate: #Predicate { $0.id == missingID })

        let result = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.lastDone ?? .distantPast }
        )

        #expect(result == nil)
    }

    @Test
    func canonicalReturnsLoneRowWithoutDeleting() throws {
        let context = makeInMemoryContext()
        let id = UUID()
        let lone = RoutineTask(id: id, name: "Lonely")
        context.insert(lone)
        try context.save()

        let descriptor = FetchDescriptor<RoutineTask>(predicate: #Predicate { $0.id == id })
        let result = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.lastDone ?? .distantPast }
        )

        #expect(result?.id == id)
        let remaining = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remaining.count == 1)
    }

    @Test
    func canonicalCollapsesDuplicatesInPlace() throws {
        let context = makeInMemoryContext()
        let id = UUID()
        context.insert(RoutineTask(id: id, name: "Stale", lastDone: makeDate("2026-01-01T10:00:00Z")))
        context.insert(RoutineTask(id: id, name: "Fresh", lastDone: makeDate("2026-04-01T10:00:00Z")))
        try context.save()

        let descriptor = FetchDescriptor<RoutineTask>(predicate: #Predicate { $0.id == id })
        let result = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.lastDone ?? .distantPast }
        )
        try context.save()

        #expect(result?.name == "Fresh")
        let remaining = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.name == "Fresh")
    }

    @Test
    func logsReferencingDeduplicatedTaskRemainResolvable() throws {
        let context = makeInMemoryContext()
        let sharedID = UUID()
        let stale = RoutineTask(id: sharedID, name: "Stale", lastDone: makeDate("2026-01-01T10:00:00Z"))
        let fresh = RoutineTask(id: sharedID, name: "Fresh", lastDone: makeDate("2026-04-01T10:00:00Z"))
        context.insert(stale)
        context.insert(fresh)
        let log = RoutineLog(timestamp: makeDate("2026-04-02T08:00:00Z"), taskID: sharedID)
        context.insert(log)
        try context.save()

        RoutineDuplicateIDCleanup.run(in: context)

        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingTasks.count == 1)
        #expect(remainingLogs.count == 1)
        #expect(remainingLogs.first?.taskID == remainingTasks.first?.id)
    }
}
