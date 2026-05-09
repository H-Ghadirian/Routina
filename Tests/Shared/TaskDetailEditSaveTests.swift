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
struct TaskDetailEditSaveTests {
    @Test
    func editSaveTapped_preservesCreatedAtAndLogsOnMetadataEdit() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let createdAt = makeDate("2026-01-05T08:00:00Z")
        let logDate = makeDate("2026-01-12T12:00:00Z")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 7,
            lastDone: nil,
            emoji: "📚",
            createdAt: createdAt
        )
        _ = makeLog(in: context, task: task, timestamp: logDate)

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Read deeply",
                editRoutineEmoji: "📚",
                editScheduleMode: .fixedInterval,
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
            $0.task.scheduleAnchor = createdAt
            $0.overdueDays = RoutineDateMath.overdueDays(
                for: $0.task,
                referenceDate: now,
                calendar: calendar
            )
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        let persistedLogs = try context.fetch(
            FetchDescriptor<RoutineLog>(
                predicate: #Predicate<RoutineLog> { log in
                    log.taskID == taskID
                }
            )
        )
        #expect(persistedTask.name == "Read deeply")
        #expect(persistedTask.createdAt == createdAt)
        #expect(persistedTask.scheduleAnchor == createdAt)
        #expect(persistedLogs.count == 1)
        #expect(persistedLogs.first?.timestamp == logDate)
    }

    @Test
    func editSaveTapped_doesNotStampLegacyNilCreatedAtOnMetadataEdit() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Legacy",
            interval: 3,
            lastDone: nil,
            emoji: "🧭",
            createdAt: nil
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Legacy updated",
                editRoutineEmoji: "🧭",
                editScheduleMode: .fixedInterval,
                editFrequency: .day,
                editFrequencyValue: 3
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.name == "Legacy updated")
        #expect(persistedTask.createdAt == nil)
        #expect(persistedTask.scheduleAnchor == nil)
    }

    @Test
    func editSaveTapped_removingAllChecklistItemsConvertsToFixedRoutine() async throws {
        let context = makeInMemoryContext()
        let calendar = makeTestCalendar()
        let now = makeDate("2026-03-10T09:00:00Z")
        let task = makeTask(
            in: context,
            name: "Restock pantry",
            interval: 7,
            lastDone: nil,
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(title: "Beans", intervalDays: 14, createdAt: now),
                RoutineChecklistItem(title: "Rice", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )

        let store = TestStore(
            initialState: TaskDetailFeature.State(
                task: task,
                isEditSheetPresented: true,
                editRoutineName: "Restock pantry",
                editRoutineEmoji: "✨",
                editScheduleMode: .fixedIntervalChecklist,
                editRoutineChecklistItems: [],
                editFrequency: .week,
                editFrequencyValue: 1
            )
        ) {
            TaskDetailFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.editSaveTapped) {
            $0.isEditSheetPresented = false
        }
        await store.receive(.onAppear) {
            $0.selectedDate = calendar.startOfDay(for: now)
        }

        let taskID = task.id
        let persistedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate<RoutineTask> { task in
                        task.id == taskID
                    }
                )
            ).first
        )
        #expect(persistedTask.scheduleMode == .fixedInterval)
        #expect(persistedTask.checklistItems.isEmpty)
    }
}
