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
struct TodoStateFeatureTests {

    // MARK: - Model: todoState computed property

    @Test
    func todoState_returnsNilForRoutines() {
        let routine = RoutineTask(name: "Exercise", scheduleMode: .fixedInterval)
        #expect(routine.todoState == nil)
    }

    @Test
    func todoState_returnsReadyByDefaultForNewTodo() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff)
        #expect(todo.todoState == .ready)
    }

    @Test
    func todoState_returnsDoneWhenLastDoneIsSet() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, lastDone: makeDate("2026-03-18T10:00:00Z"))
        #expect(todo.todoState == .done)
    }

    @Test
    func todoState_returnsDoneWhenCanceledAtIsSet() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, canceledAt: makeDate("2026-03-18T10:00:00Z"))
        #expect(todo.todoState == .done)
    }

    @Test
    func todoState_returnsPausedWhenPausedAtIsSet() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, pausedAt: makeDate("2026-03-18T10:00:00Z"))
        #expect(todo.todoState == .paused)
    }

    @Test
    func todoState_pausedTakesPrecedenceOverRawValue() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, pausedAt: makeDate("2026-03-18T10:00:00Z"), todoStateRawValue: "inProgress")
        #expect(todo.todoState == .paused)
    }

    @Test
    func todoState_doneTakesPrecedenceOverRawValue() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, lastDone: makeDate("2026-03-18T10:00:00Z"), todoStateRawValue: "inProgress")
        #expect(todo.todoState == .done)
    }

    @Test
    func todoState_returnsStoredRawValueWhenActiveAndUnarchived() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, todoStateRawValue: "inProgress")
        #expect(todo.todoState == .inProgress)

        let todo2 = RoutineTask(name: "Fix bug", scheduleMode: .oneOff, todoStateRawValue: "blocked")
        #expect(todo2.todoState == .blocked)
    }

    @Test
    func todoState_returnsReadyForUnknownRawValue() {
        let todo = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, todoStateRawValue: "unknownFutureValue")
        #expect(todo.todoState == .ready)
    }

    // MARK: - Reducer: todoStateChanged

    @Test
    func pressureChanged_updatesPressureAndPersists() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let task = RoutineTask(name: "Prepare budget", scheduleMode: .fixedInterval)
        context.insert(task)
        try context.save()

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.pressureChanged(.high))

        #expect(store.state.task.pressure == .high)
        #expect(store.state.editPressure == .high)
        #expect(store.state.taskRefreshID == 1)
        let saved = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(saved.pressure == .high)
        #expect(saved.pressureUpdatedAt != nil)
    }

    @Test
    func todoStateChanged_toInProgress_updatesRawValueAndPersists() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let task = RoutineTask(name: "Write report", scheduleMode: .oneOff)
        context.insert(task)
        try context.save()

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.todoStateChanged(.inProgress)) {
            $0.task.todoStateRawValue = "inProgress"
            $0.task.pausedAt = nil
            $0.taskRefreshID = 1
        }

        let saved = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(saved.todoStateRawValue == "inProgress")
        #expect(saved.pausedAt == nil)
    }

    @Test
    func todoStateChanged_toBlocked_updatesRawValueAndPersists() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let task = RoutineTask(name: "Fix bug", scheduleMode: .oneOff, todoStateRawValue: "inProgress")
        context.insert(task)
        try context.save()

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.todoStateChanged(.blocked)) {
            $0.task.todoStateRawValue = "blocked"
            $0.taskRefreshID = 1
        }

        let saved = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(saved.todoStateRawValue == "blocked")
    }

    @Test
    func todoStateChanged_toPaused_setsPausedAtAndClearsRawValue() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let task = RoutineTask(name: "Research", scheduleMode: .oneOff, todoStateRawValue: "inProgress")
        context.insert(task)
        try context.save()

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.todoStateChanged(.paused)) {
            $0.task.pausedAt = now
            $0.task.todoStateRawValue = nil
            $0.taskRefreshID = 1
        }

        let saved = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(saved.pausedAt == now)
        #expect(saved.todoStateRawValue == nil)
    }

    @Test
    func todoStateChanged_toReady_clearsPausedAtAndSnoozedUntil() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let pauseDate = makeDate("2026-03-15T10:00:00Z")
        let snoozedUntil = makeDate("2026-03-19T00:00:00Z")
        let task = RoutineTask(name: "Research", scheduleMode: .oneOff, pausedAt: pauseDate)
        task.snoozedUntil = snoozedUntil
        context.insert(task)
        try context.save()

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.todoStateChanged(.ready)) {
            $0.task.pausedAt = nil
            $0.task.snoozedUntil = nil
            $0.task.todoStateRawValue = "ready"
            $0.taskRefreshID = 1
        }

        let saved = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(saved.pausedAt == nil)
        #expect(saved.snoozedUntil == nil)
        #expect(saved.todoStateRawValue == "ready")
    }

    @Test
    func todoStateChanged_ignoredForRoutines() async {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Exercise", scheduleMode: .fixedInterval)
        context.insert(task)

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.todoStateChanged(.inProgress))
        // State unchanged — no mutation expected
        #expect(store.state.task.todoStateRawValue == nil)
        #expect(store.state.taskRefreshID == 0)
    }

    @Test
    func todoStateChanged_ignoredForCompletedOneOff() async {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Buy milk", scheduleMode: .oneOff, lastDone: makeDate("2026-03-18T10:00:00Z"))
        context.insert(task)

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.todoStateChanged(.inProgress))
        #expect(store.state.taskRefreshID == 0)
    }

    @Test
    func todoStateChanged_toDone_completesTheTodo() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let task = RoutineTask(name: "Write report", scheduleMode: .oneOff)
        context.insert(task)
        try context.save()

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.todoStateChanged(.done))
        #expect(store.state.task.lastDone == now)
        #expect(store.state.task.isCompletedOneOff)
    }

    // MARK: - Reducer: setBlockedStateConfirmation / confirmBlockedStateCompletion

    @Test
    func setBlockedStateConfirmation_togglesFlag() async {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Deploy", scheduleMode: .oneOff)
        context.insert(task)

        let store = TestStore(initialState: TaskDetailFeature.State(task: task)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.setBlockedStateConfirmation(true)) {
            $0.isBlockedStateConfirmationPresented = true
        }
        await store.send(.setBlockedStateConfirmation(false)) {
            $0.isBlockedStateConfirmationPresented = false
        }
    }

    @Test
    func confirmBlockedStateCompletion_dismissesAlertAndCompletesTodo() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-18T10:00:00Z")
        let task = RoutineTask(name: "Deploy", scheduleMode: .oneOff)
        context.insert(task)
        try context.save()

        let store = TestStore(initialState: TaskDetailFeature.State(
            task: task,
            isBlockedStateConfirmationPresented: true
        )) {
            TaskDetailFeature()
        } withDependencies: {
            $0.modelContext = { context }
            setTestDateDependencies(&$0, now: now)
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.confirmBlockedStateCompletion) {
            $0.isBlockedStateConfirmationPresented = false
        }

        #expect(store.state.task.lastDone == now)
        #expect(store.state.task.isCompletedOneOff)
    }

    // MARK: - Presentation: hasActiveRelationshipBlocker

    @Test
    func hasActiveRelationshipBlocker_falseWhenNoBlockingRelationships() {
        let task = RoutineTask(name: "Deploy", scheduleMode: .oneOff)
        let state = TaskDetailFeature.State(task: task)
        #expect(!state.hasActiveRelationshipBlocker)
    }

    @Test
    func hasActiveRelationshipBlocker_trueWhenBlockerIsNotDone() {
        let blockerID = UUID()
        let task = RoutineTask(
            name: "Deploy",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)],
            scheduleMode: .oneOff
        )
        let candidates = [
            RoutineTaskRelationshipCandidate(
                id: blockerID,
                name: "Write tests",
                emoji: "🧪",
                relationships: [],
                status: .pendingTodo
            )
        ]
        var state = TaskDetailFeature.State(task: task)
        state.availableRelationshipTasks = candidates
        #expect(state.hasActiveRelationshipBlocker)
    }

    @Test
    func hasActiveRelationshipBlocker_falseWhenBlockerIsCompleted() {
        let blockerID = UUID()
        let task = RoutineTask(
            name: "Deploy",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)],
            scheduleMode: .oneOff
        )
        let candidates = [
            RoutineTaskRelationshipCandidate(
                id: blockerID,
                name: "Write tests",
                emoji: "🧪",
                relationships: [],
                status: .completedOneOff
            )
        ]
        var state = TaskDetailFeature.State(task: task)
        state.availableRelationshipTasks = candidates
        #expect(!state.hasActiveRelationshipBlocker)
    }

    @Test
    func isCompletionButtonDisabled_trueWhenHasActiveRelationshipBlocker() {
        let blockerID = UUID()
        let task = RoutineTask(
            name: "Deploy",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)],
            scheduleMode: .oneOff
        )
        let candidates = [
            RoutineTaskRelationshipCandidate(
                id: blockerID,
                name: "Write tests",
                emoji: "🧪",
                relationships: [],
                status: .pendingTodo
            )
        ]
        var state = TaskDetailFeature.State(task: task)
        state.availableRelationshipTasks = candidates
        #expect(state.isCompletionButtonDisabled)
    }

    @Test
    func isCompletionButtonDisabled_falseWhenBlockerIsDone() {
        let blockerID = UUID()
        let task = RoutineTask(
            name: "Deploy",
            relationships: [RoutineTaskRelationship(targetTaskID: blockerID, kind: .blockedBy)],
            scheduleMode: .oneOff
        )
        let candidates = [
            RoutineTaskRelationshipCandidate(
                id: blockerID,
                name: "Write tests",
                emoji: "🧪",
                relationships: [],
                status: .completedOneOff
            )
        ]
        var state = TaskDetailFeature.State(task: task)
        state.availableRelationshipTasks = candidates
        #expect(!state.isCompletionButtonDisabled)
    }

    // MARK: - Backup / Restore round-trip

    @Test
    func backupAndRestore_preservesTodoStateRawValue() async throws {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Draft email", scheduleMode: .oneOff, todoStateRawValue: "inProgress")
        context.insert(task)
        try context.save()

        let json = try SettingsRoutineDataPersistence.buildBackupJSON(from: context)
        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(with: json, in: restoreContext)

        #expect(summary.tasks == 1)
        let restored = try #require(restoreContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(restored.todoStateRawValue == "inProgress")
        #expect(restored.todoState == .inProgress)
    }

    @Test
    func backupAndRestore_preservesNilTodoStateRawValue() async throws {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Buy groceries", scheduleMode: .oneOff)
        context.insert(task)
        try context.save()

        let json = try SettingsRoutineDataPersistence.buildBackupJSON(from: context)
        let restoreContext = makeInMemoryContext()
        _ = try SettingsRoutineDataPersistence.replaceAllRoutineData(with: json, in: restoreContext)

        let restored = try #require(restoreContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(restored.todoStateRawValue == nil)
        #expect(restored.todoState == .ready)
    }

    @Test
    func backupPackageAndRestore_preservesTaskImagesAndAttachments() async throws {
        let context = makeInMemoryContext()
        let imageData = Data([0x01, 0x02, 0x03])
        let attachmentData = Data([0x04, 0x05, 0x06])
        let task = RoutineTask(name: "File insurance", imageData: imageData)
        context.insert(task)
        context.insert(
            RoutineAttachment(
                taskID: task.id,
                fileName: "receipt.jpg",
                data: attachmentData
            )
        )
        try context.save()

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(from: context)
        let restoreContext = makeInMemoryContext()
        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        let attachmentsURL = packageURL.appendingPathComponent(SettingsRoutineDataPersistence.attachmentsDirectoryName)
        try FileManager.default.createDirectory(at: attachmentsURL, withIntermediateDirectories: true)
        try package.manifestData.write(to: packageURL.appendingPathComponent(SettingsRoutineDataPersistence.manifestFileName))
        for (fileName, data) in package.attachmentFiles {
            try data.write(to: attachmentsURL.appendingPathComponent(fileName))
        }
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        #expect(summary.tasks == 1)
        #expect(summary.attachments == 1)
        let restoredTask = try #require(restoreContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(restoredTask.imageData == imageData)
        let restoredAttachment = try #require(restoreContext.fetch(FetchDescriptor<RoutineAttachment>()).first)
        #expect(restoredAttachment.taskID == restoredTask.id)
        #expect(restoredAttachment.fileName == "receipt.jpg")
        #expect(restoredAttachment.data == attachmentData)
    }
}

@Suite(.serialized)
@MainActor
struct TaskDetailCreatedAtPresentationTests {
    @Test
    func createdAtBadgeValue_returnsNilWhenCreatedAtIsNil() {
        let task = RoutineTask(name: "Old task", createdAt: nil)
        let state = TaskDetailFeature.State(task: task)
        #expect(state.createdAtBadgeValue == nil)
    }

    @Test
    func createdAtBadgeValue_showsTodayLabelWhenCreatedToday() {
        let task = RoutineTask(name: "New task", createdAt: Date())
        let state = TaskDetailFeature.State(task: task)
        let value = state.createdAtBadgeValue
        #expect(value != nil)
        #expect(value?.hasSuffix("· Today") == true)
    }

    @Test
    func createdAtBadgeValue_showsDaysAgoAndDateForPastDate() throws {
        let calendar = Calendar.current
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: calendar.startOfDay(for: Date()))!
        let task = RoutineTask(name: "Run", createdAt: tenDaysAgo)
        let state = TaskDetailFeature.State(task: task)
        let value = try #require(state.createdAtBadgeValue)
        #expect(value.contains("10 days ago"))
        #expect(value.contains("·"))
    }

    @Test
    func createdAtBadgeValue_usesSingularDayWordForOneDay() throws {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let task = RoutineTask(name: "Walk", createdAt: yesterday)
        let state = TaskDetailFeature.State(task: task)
        let value = try #require(state.createdAtBadgeValue)
        #expect(value.contains("1 day ago"))
    }
}
