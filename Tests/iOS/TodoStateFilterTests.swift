import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

// MARK: - TodoState.filterableCases

@Suite("TodoState.filterableCases")
struct TodoStateFilterableCasesTests {
    @Test func filterableCases_excludesDone() {
        #expect(!TodoState.filterableCases.contains(.done))
    }

    @Test func filterableCases_includesExpectedStates() {
        #expect(TodoState.filterableCases.contains(.ready))
        #expect(TodoState.filterableCases.contains(.inProgress))
        #expect(TodoState.filterableCases.contains(.blocked))
        #expect(TodoState.filterableCases.contains(.paused))
    }

    @Test func filterableCases_hasFourElements() {
        #expect(TodoState.filterableCases.count == 4)
    }
}

// MARK: - HomeFeature reducer — selectedTodoStateFilterChanged

@Suite("HomeFeature — selectedTodoStateFilterChanged")
@MainActor
struct HomeFeatureTodoStateFilterActionTests {
    @Test
    func selectedTodoStateFilterChanged_updatesState() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.selectedTodoStateFilterChanged(.inProgress)) {
            $0.selectedTodoStateFilter = .inProgress
        }

        #expect(persistedState.value?.homeSelectedTodoStateFilter == .inProgress)
    }

    @Test
    func selectedTodoStateFilterChanged_nil_clearsFilter() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        let store = TestStore(
            initialState: HomeFeature.State(selectedTodoStateFilter: .blocked)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.selectedTodoStateFilterChanged(nil)) {
            $0.selectedTodoStateFilter = nil
        }

        #expect(persistedState.value?.homeSelectedTodoStateFilter == nil)
    }

    @Test
    func selectedTodoStateFilterChanged_persistsInTabSnapshot() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        let store = TestStore(
            initialState: HomeFeature.State(taskListMode: .todos)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.selectedTodoStateFilterChanged(.paused)) {
            $0.selectedTodoStateFilter = .paused
        }

        let snapshot = persistedState.value?.homeTabFilterSnapshots[HomeFeature.TaskListMode.todos.rawValue]
        #expect(snapshot?.selectedTodoStateFilter == .paused)
    }
}

// MARK: - HomeFeature reducer — clearOptionalFilters

@Suite("HomeFeature — clearOptionalFilters with todoStateFilter")
@MainActor
struct HomeFeatureClearTodoStateFilterTests {
    @Test
    func clearOptionalFilters_alsoClears_selectedTodoStateFilter() async {
        let context = makeInMemoryContext()

        let store = TestStore(
            initialState: HomeFeature.State(
                selectedTag: "Work",
                selectedTodoStateFilter: .inProgress
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { _ in }
        }

        await store.send(.clearOptionalFilters) {
            $0.selectedTag = nil
            $0.selectedTodoStateFilter = nil
        }
    }
}

// MARK: - HomeFeature reducer — taskListModeChanged snapshot

@Suite("HomeFeature — taskListModeChanged saves/restores todoStateFilter")
@MainActor
struct HomeFeatureTaskListModeTodoStateFilterTests {
    @Test
    func taskListModeChanged_savesTodoStateFilterInSnapshot() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        let store = TestStore(
            initialState: HomeFeature.State(
                taskListMode: .todos,
                selectedTodoStateFilter: .blocked
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            $0.selectedTodoStateFilter = nil
            $0.tabFilterSnapshots[HomeFeature.TaskListMode.todos.rawValue] = TabFilterStateManager.Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: .blocked
            )
        }

        let savedSnapshot = persistedState.value?.homeTabFilterSnapshots[HomeFeature.TaskListMode.todos.rawValue]
        #expect(savedSnapshot?.selectedTodoStateFilter == .blocked)
    }

    @Test
    func taskListModeChanged_restoresTodoStateFilterFromSnapshot() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        let existingTodosSnapshot = TabFilterStateManager.Snapshot(
            selectedTag: nil,
            excludedTags: [],
            selectedFilter: .all,
            selectedManualPlaceFilterID: nil,
            selectedImportanceUrgencyFilter: nil,
            selectedTodoStateFilter: .inProgress
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                taskListMode: .routines,
                tabFilterSnapshots: [HomeFeature.TaskListMode.todos.rawValue: existingTodosSnapshot]
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
            $0.selectedTodoStateFilter = .inProgress
            $0.tabFilterSnapshots[HomeFeature.TaskListMode.routines.rawValue] = TabFilterStateManager.Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil
            )
        }
    }

    @Test
    func taskListModeChanged_todoStateFilterIsIsolatedPerTab() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        // Start in Todos tab with inProgress filter
        let store = TestStore(
            initialState: HomeFeature.State(
                taskListMode: .todos,
                selectedTodoStateFilter: .inProgress
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        // Switch to routines — todos filter should be saved
        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            $0.selectedTodoStateFilter = nil
            $0.tabFilterSnapshots[HomeFeature.TaskListMode.todos.rawValue] = TabFilterStateManager.Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: .inProgress
            )
        }

        // Switch back to todos — filter should be restored
        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
            $0.selectedTodoStateFilter = .inProgress
            $0.tabFilterSnapshots[HomeFeature.TaskListMode.routines.rawValue] = TabFilterStateManager.Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil
            )
        }
    }
}

// MARK: - HomeFeature.matchesTodoStateFilter (logic tests via RoutineDisplay)

@Suite("HomeFeature — matchesTodoStateFilter logic")
struct MatchesTodoStateFilterLogicTests {
    private func makeTodoDisplay(todoState: TodoState?) -> HomeFeature.RoutineDisplay {
        HomeFeature.RoutineDisplay(
            taskID: UUID(),
            name: "Test Todo",
            emoji: "✅",
            notes: nil,
            hasImage: false,
            placeID: nil,
            placeName: nil,
            locationAvailability: .unrestricted,
            tags: [],
            steps: [],
            interval: 0,
            recurrenceRule: .interval(days: 0),
            scheduleMode: .oneOff,
            lastDone: nil,
            canceledAt: nil,
            dueDate: nil,
            priority: .none,
            importance: .level2,
            urgency: .level2,
            scheduleAnchor: nil,
            pausedAt: nil,
            snoozedUntil: nil,
            pinnedAt: nil,
            daysUntilDue: Int.max,
            isOneOffTask: true,
            isCompletedOneOff: false,
            isCanceledOneOff: false,
            isDoneToday: false,
            isPaused: false,
            isSnoozed: false,
            isPinned: false,
            completedStepCount: 0,
            isInProgress: false,
            nextStepTitle: nil,
            checklistItemCount: 0,
            completedChecklistItemCount: 0,
            dueChecklistItemCount: 0,
            nextPendingChecklistItemTitle: nil,
            nextDueChecklistItemTitle: nil,
            doneCount: 0,
            todoState: todoState
        )
    }

    private func makeRoutineDisplay() -> HomeFeature.RoutineDisplay {
        HomeFeature.RoutineDisplay(
            taskID: UUID(),
            name: "Test Routine",
            emoji: "🔁",
            notes: nil,
            hasImage: false,
            placeID: nil,
            placeName: nil,
            locationAvailability: .unrestricted,
            tags: [],
            steps: [],
            interval: 7,
            recurrenceRule: .interval(days: 7),
            scheduleMode: .fixedInterval,
            lastDone: nil,
            canceledAt: nil,
            dueDate: nil,
            priority: .none,
            importance: .level2,
            urgency: .level2,
            scheduleAnchor: nil,
            pausedAt: nil,
            snoozedUntil: nil,
            pinnedAt: nil,
            daysUntilDue: 7,
            isOneOffTask: false,
            isCompletedOneOff: false,
            isCanceledOneOff: false,
            isDoneToday: false,
            isPaused: false,
            isSnoozed: false,
            isPinned: false,
            completedStepCount: 0,
            isInProgress: false,
            nextStepTitle: nil,
            checklistItemCount: 0,
            completedChecklistItemCount: 0,
            dueChecklistItemCount: 0,
            nextPendingChecklistItemTitle: nil,
            nextDueChecklistItemTitle: nil,
            doneCount: 0,
            todoState: nil
        )
    }

    @Test func noFilter_matchesAllTodos() {
        let todo = makeTodoDisplay(todoState: .ready)
        #expect(HomeFeature.matchesTodoStateFilter(nil, task: todo))
    }

    @Test func noFilter_matchesRoutines() {
        let routine = makeRoutineDisplay()
        #expect(HomeFeature.matchesTodoStateFilter(nil, task: routine))
    }

    @Test func inProgressFilter_matchesInProgressTodo() {
        let todo = makeTodoDisplay(todoState: .inProgress)
        #expect(HomeFeature.matchesTodoStateFilter(.inProgress, task: todo))
    }

    @Test func inProgressFilter_rejectsReadyTodo() {
        let todo = makeTodoDisplay(todoState: .ready)
        #expect(!HomeFeature.matchesTodoStateFilter(.inProgress, task: todo))
    }

    @Test func blockedFilter_matchesBlockedTodo() {
        let todo = makeTodoDisplay(todoState: .blocked)
        #expect(HomeFeature.matchesTodoStateFilter(.blocked, task: todo))
    }

    @Test func blockedFilter_rejectsNonBlockedTodo() {
        let todo = makeTodoDisplay(todoState: .inProgress)
        #expect(!HomeFeature.matchesTodoStateFilter(.blocked, task: todo))
    }

    @Test func readyFilter_matchesReadyTodo() {
        let todo = makeTodoDisplay(todoState: .ready)
        #expect(HomeFeature.matchesTodoStateFilter(.ready, task: todo))
    }

    @Test func pausedFilter_matchesPausedTodo() {
        let todo = makeTodoDisplay(todoState: .paused)
        #expect(HomeFeature.matchesTodoStateFilter(.paused, task: todo))
    }

    @Test func anyFilter_matchesRoutineRegardlessOfState() {
        let routine = makeRoutineDisplay()
        for state in TodoState.filterableCases {
            #expect(HomeFeature.matchesTodoStateFilter(state, task: routine),
                    "Routine should pass todo state filter for state \(state)")
        }
    }
}

// MARK: - TabFilterStateManager — selectedTodoStateFilter round-trip

@Suite("TabFilterStateManager — selectedTodoStateFilter")
struct TabFilterTodoStateTests {
    @Test func saveAndRestore_preservesTodStateFilter() {
        var manager = TabFilterStateManager()
        let snapshot = TabFilterStateManager.Snapshot(
            selectedTag: nil,
            excludedTags: [],
            selectedFilter: .all,
            selectedManualPlaceFilterID: nil,
            selectedImportanceUrgencyFilter: nil,
            selectedTodoStateFilter: .blocked
        )
        manager.save(snapshot, for: "Todos")
        #expect(manager.snapshot(for: "Todos").selectedTodoStateFilter == .blocked)
    }

    @Test func defaultSnapshot_hasNilTodoStateFilter() {
        #expect(TabFilterStateManager.Snapshot.default.selectedTodoStateFilter == nil)
    }

    @Test func todoStateFilter_isIsolatedPerTab() {
        var manager = TabFilterStateManager()
        manager.save(
            TabFilterStateManager.Snapshot(selectedTag: nil, excludedTags: [], selectedFilter: .all, selectedManualPlaceFilterID: nil, selectedTodoStateFilter: .inProgress),
            for: "Todos"
        )
        manager.save(
            TabFilterStateManager.Snapshot(selectedTag: nil, excludedTags: [], selectedFilter: .all, selectedManualPlaceFilterID: nil, selectedTodoStateFilter: nil),
            for: "Routines"
        )
        #expect(manager.snapshot(for: "Todos").selectedTodoStateFilter == .inProgress)
        #expect(manager.snapshot(for: "Routines").selectedTodoStateFilter == nil)
    }
}
