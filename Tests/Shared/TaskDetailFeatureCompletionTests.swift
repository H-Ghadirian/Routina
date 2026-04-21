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

@Suite(.serialized)
@MainActor
struct TaskDetailFeatureCompletionTests {
    @Test
    func markAsDone_forPastWeeklyExactTimeDate_usesScheduledTimestamp() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-21T10:00:00Z")
        let selectedDate = makeDate("2026-04-20T00:00:00Z")
        let expectedCompletion = makeDate("2026-04-20T17:00:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Workout",
            interval: 7,
            lastDone: nil,
            emoji: "💪",
            recurrenceRule: .weekly(on: 2, at: RoutineTimeOfDay(hour: 17, minute: 0)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                selectedDate: selectedDate
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.markAsDone) {
            $0.task.lastDone = expectedCompletion
            $0.taskRefreshID = 1
            $0.daysSinceLastRoutine = 1
        }

        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            return logs.contains { $0.kind == .completed && $0.timestamp == expectedCompletion }
        } assert: {
            $0.logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.daysSinceLastRoutine = 1
        }

        let persistedTaskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { persistedTask in
                        persistedTask.id == persistedTaskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(persistedTask.lastDone == expectedCompletion)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.timestamp == expectedCompletion)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }
}
