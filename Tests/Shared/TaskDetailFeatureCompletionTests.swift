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
    func confirmAssumedPastDays_includesTodayWhenTodayIsAssumedDone() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-02-25T21:30:00Z")
        let task = RoutineTask(
            name: "Brush teeth",
            emoji: "🪥",
            scheduleMode: .fixedInterval,
            recurrenceRule: .daily(at: RoutineTimeOfDay(hour: 21, minute: 0)),
            createdAt: makeDate("2026-02-24T00:00:00Z"),
            autoAssumeDailyDone: true
        )
        context.insert(task)
        try context.save()

        let calendar = makeTestCalendar()
        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [],
                selectedDate: calendar.startOfDay(for: now)
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

        _ = await store.withExhaustivity(.off) {
            await store.send(.confirmAssumedPastDays) {
                $0.task.lastDone = now
                $0.taskRefreshID = 1
                $0.isDoneToday = true
            }
        }

        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            return logs.count == 2
        } assert: {
            let logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.logs = logs
            #expect(logs.compactMap(\.timestamp) == [
                now,
                makeDate("2026-02-24T12:00:00Z"),
            ])
            $0.isDoneToday = true
        }

        let persistedTask = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        let persistedLogs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(persistedTask.lastDone == now)
        #expect(persistedLogs.count == 2)
        #expect(persistedLogs.compactMap(\.timestamp).sorted(by: >) == [
            now,
            makeDate("2026-02-24T12:00:00Z"),
        ])
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func completionButton_usesBulkConfirmWhenTodayAndPastDaysAreAssumed() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let task = RoutineTask(
            name: "Walk",
            emoji: "🚶",
            scheduleMode: .fixedInterval,
            recurrenceRule: .interval(days: 1),
            createdAt: yesterday,
            autoAssumeDailyDone: true
        )
        let state = TaskDetailFeature.State(
            task: task,
            logs: [],
            selectedDate: today
        )

        #expect(state.shouldUseBulkConfirmAsPrimaryAction)
        #expect(state.completionButtonAction == .confirmAssumedPastDays)
        #expect(state.completionButtonTitle == "Confirm 2 assumed days")
        #expect(!state.shouldShowBulkConfirmAssumedDays)
    }

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

    @Test
    func selectedDateDone_forExactTimedWeeklyRoutine_ignoresNonOccurrenceDays() {
        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let thursdayCompletion = makeDate("2026-04-23T18:30:00Z")
        let friday = makeDate("2026-04-24T00:00:00Z")

        let task = RoutineTask(
            name: "Group session",
            scheduleMode: .fixedInterval,
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            lastDone: thursdayCompletion,
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z"),
            createdAt: makeDate("2026-04-19T10:00:00Z")
        )

        let state = TaskDetailFeature.State(
            task: task,
            logs: [RoutineLog(timestamp: thursdayCompletion, taskID: task.id)],
            selectedDate: calendar.startOfDay(for: friday)
        )

        #expect(state.selectedScheduledOccurrenceDate == nil)
        #expect(!state.isSelectedDateDone)
        #expect(!state.isSelectedDateTerminal)
    }

    @Test
    func markAsDone_forTodayOnOverdueWeeklyExactTimeRoutine_usesOutstandingOccurrenceTimestamp() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-24T10:00:00Z")
        let expectedCompletion = makeDate("2026-04-23T18:30:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Group session",
            interval: 7,
            lastDone: nil,
            emoji: "✨",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                selectedDate: calendar.startOfDay(for: now)
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
            $0.overdueDays = 0
            $0.isDoneToday = false
        }

        await store.receive { action in
            guard case let .logsLoaded(logs) = action else { return false }
            return logs.contains { $0.kind == .completed && $0.timestamp == expectedCompletion }
        } assert: {
            $0.logs = RoutineLogHistory.detailLogs(taskID: task.id, context: context)
            $0.daysSinceLastRoutine = 1
            $0.overdueDays = 0
            $0.isDoneToday = false
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

    @Test
    func logsLoaded_forInvalidNonOccurrenceTimedLog_doesNotMarkDoneToday() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-24T10:36:00Z")
        let invalidFridayCompletion = makeDate("2026-04-24T10:36:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Group session",
            interval: 7,
            lastDone: invalidFridayCompletion,
            emoji: "✨",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        let fridayLog = makeLog(in: context, task: task, timestamp: invalidFridayCompletion)

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.logsLoaded([fridayLog])) {
            $0.logs = [fridayLog]
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 0
            $0.isDoneToday = false
        }
    }

    @Test
    func removeLogEntry_removesInvalidTimedCompletion() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-04-24T10:36:00Z")
        let invalidFridayCompletion = makeDate("2026-04-24T10:36:00Z")

        var calendar = makeTestCalendar()
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Group session",
            interval: 7,
            lastDone: invalidFridayCompletion,
            emoji: "✨",
            recurrenceRule: .weekly(on: 5, at: RoutineTimeOfDay(hour: 18, minute: 30)),
            scheduleAnchor: makeDate("2026-04-19T10:00:00Z")
        )
        let fridayLog = makeLog(in: context, task: task, timestamp: invalidFridayCompletion)
        try context.save()

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                logs: [fridayLog],
                selectedDate: calendar.startOfDay(for: now)
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.removeLogEntry(invalidFridayCompletion)) {
            $0.task.lastDone = nil
            $0.task.scheduleAnchor = makeDate("2026-04-19T10:00:00Z")
            $0.taskRefreshID = 1
            $0.logs = []
            $0.daysSinceLastRoutine = 0
            $0.overdueDays = 1
            $0.isDoneToday = false
        }

        await store.receive(.logsLoaded([]))

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

        #expect(persistedTask.lastDone == nil)
        #expect(persistedTask.scheduleAnchor == makeDate("2026-04-19T10:00:00Z"))
        #expect(persistedLogs.isEmpty)
    }
}
