import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

@MainActor
struct TimelineFeatureTests {
    @Test
    func setData_groupsEntriesAndCollectsAvailableTags() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()

        let morningTask = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            tags: ["Focus"]
        )
        let eveningTask = makeTask(
            in: context,
            name: "Stretch",
            interval: 1,
            lastDone: nil,
            emoji: "🤸",
            tags: ["Home"]
        )
        let morningLog = makeLog(in: context, task: morningTask, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let eveningLog = makeLog(in: context, task: eveningTask, timestamp: makeDate("2026-03-20T18:00:00Z"))

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.setData(tasks: [morningTask, eveningTask], logs: [morningLog, eveningLog]))

        #expect(store.state.availableTags == ["Focus", "Home"])
        #expect(store.state.groupedEntries.count == 1)
        #expect(store.state.groupedEntries.first?.date == calendar.startOfDay(for: now))
        #expect(store.state.groupedEntries.first?.entries.count == 2)
        #expect(store.state.groupedEntries.first?.entries.map(\.taskName) == ["Stretch", "Read"])
        #expect(!store.state.hasActiveFilters)
    }

    @Test
    func setData_usesLastDoneFallbackWhenCompletionLogIsMissing() async {
        let context = makeInMemoryContext()
        let doneAt = makeDate("2026-07-09T08:15:00Z")
        let calendar = makeTestCalendar()
        let task = makeTask(
            in: context,
            name: "Dr appointment",
            interval: 1,
            lastDone: doneAt,
            emoji: "🩺",
            tags: ["Health"]
        )
        let fallbackLogID = TimelineSyntheticLogID.completion(taskID: task.id, completedAt: doneAt)

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: doneAt, calendar: calendar)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.setData(tasks: [task], logs: []))

        #expect(store.state.groupedEntries.first?.entries.first?.id == fallbackLogID)
        #expect(store.state.groupedEntries.first?.entries.first?.taskID == task.id)
        #expect(store.state.groupedEntries.first?.entries.first?.timestamp == doneAt)
    }

    @Test
    func selectedRangeChanged_clearsSelectedTagWhenItFallsOutOfScope() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()

        let olderTask = makeTask(
            in: context,
            name: "Deep Work",
            interval: 1,
            lastDone: nil,
            emoji: "🧠",
            tags: ["Deep"]
        )
        let todayTask = makeTask(
            in: context,
            name: "Water Plants",
            interval: 1,
            lastDone: nil,
            emoji: "🪴",
            tags: ["Home"]
        )
        let olderLog = makeLog(in: context, task: olderTask, timestamp: makeDate("2026-03-10T08:00:00Z"))
        let todayLog = makeLog(in: context, task: todayTask, timestamp: makeDate("2026-03-20T09:00:00Z"))

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.setData(tasks: [olderTask, todayTask], logs: [olderLog, todayLog]))
        await store.send(.selectedTagChanged("Deep"))

        #expect(store.state.selectedTag == "Deep")
        #expect(store.state.groupedEntries.count == 1)
        #expect(store.state.groupedEntries.first?.entries.count == 1)

        await store.send(.selectedRangeChanged(.today))

        #expect(store.state.selectedTag == nil)
        #expect(store.state.availableTags == ["Home"])
        #expect(store.state.groupedEntries.count == 1)
        #expect(store.state.groupedEntries.first?.entries.count == 1)
        #expect(store.state.groupedEntries.first?.entries.first?.taskName == "Water Plants")
    }

    @Test
    func excludedTags_hideMatchingEntries() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()

        let focusTask = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            tags: ["Focus"]
        )
        let homeTask = makeTask(
            in: context,
            name: "Stretch",
            interval: 1,
            lastDone: nil,
            emoji: "🤸",
            tags: ["Home"]
        )
        let focusLog = makeLog(in: context, task: focusTask, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let homeLog = makeLog(in: context, task: homeTask, timestamp: makeDate("2026-03-20T18:00:00Z"))

        let store = TestStore(initialState: TimelineFeature.State()) {
            TimelineFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.setData(tasks: [focusTask, homeTask], logs: [focusLog, homeLog]))
        await store.send(.excludedTagsChanged(["Focus"]))

        #expect(store.state.hasActiveFilters)
        #expect(store.state.groupedEntries.first?.entries.count == 1)
        #expect(store.state.groupedEntries.first?.entries.first?.taskName == "Stretch")
    }
}

@MainActor
struct StatsFeatureTests {
    @Test
    func dataRefreshDebounceCompleted_loadsPersistedDataThroughReducerDependency() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()
        let task = makeTask(
            in: context,
            name: "Reducer-owned stats",
            interval: 1,
            lastDone: nil,
            emoji: "📊",
            tags: ["Architecture"]
        )
        try context.save()

        let store = TestStore(initialState: StatsFeature.State()) {
            StatsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.appSettingsClient = .noop
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.dataRefreshDebounceCompleted)
        await store.receive(\.setData)

        #expect(store.state.tasks.map(\.id) == [task.id])
        #expect(store.state.availableTags == ["Architecture"])
        #expect(store.state.filteredTaskCount == 1)
    }

    @Test
    func setData_recomputesMetricsAndClearsUnavailableSelectedTag() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()

        let focusTask = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            tags: ["Focus"]
        )
        let healthTask = makeTask(
            in: context,
            name: "Run",
            interval: 1,
            lastDone: nil,
            emoji: "🏃",
            tags: ["Health"],
            pausedAt: makeDate("2026-03-19T10:00:00Z")
        )
        let focusLog1 = makeLog(in: context, task: focusTask, timestamp: makeDate("2026-03-19T08:00:00Z"))
        let focusLog2 = makeLog(in: context, task: focusTask, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let healthLog = makeLog(in: context, task: healthTask, timestamp: makeDate("2026-03-20T09:00:00Z"))
        let store = TestStore(initialState: StatsFeature.State()) {
            StatsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }
        store.exhaustivity = .off

        await store.send(.setData(tasks: [focusTask, healthTask], logs: [focusLog1, focusLog2, healthLog], focusSessions: []))
        await store.send(.selectedTagChanged("Focus"))

        #expect(store.state.availableTags == ["Focus", "Health"])
        #expect(store.state.filteredTaskCount == 1)
        #expect(store.state.metrics.totalDoneCount == 2)
        #expect(store.state.metrics.activeRoutineCount == 1)
        #expect(store.state.metrics.archivedRoutineCount == 0)
        #expect(store.state.metrics.totalCount == 2)

        await store.send(.setData(tasks: [healthTask], logs: [healthLog], focusSessions: []))

        #expect(store.state.selectedTag == nil)
        #expect(store.state.availableTags == ["Health"])
        #expect(store.state.filteredTaskCount == 1)
        #expect(store.state.metrics.totalDoneCount == 1)
        #expect(store.state.metrics.activeRoutineCount == 0)
        #expect(store.state.metrics.archivedRoutineCount == 1)
        #expect(store.state.metrics.totalCount == 1)
    }

    @Test
    func taskTypeFilter_limitsTasksLogsAndAvailableTags() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-20T10:00:00Z")
        let calendar = makeTestCalendar()

        let routineTask = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            tags: ["Focus"]
        )
        let todoTask = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🥛",
            tags: ["Errands"],
            scheduleMode: .oneOff
        )
        let routineLog = makeLog(in: context, task: routineTask, timestamp: makeDate("2026-03-20T08:00:00Z"))
        let todoLog = makeLog(in: context, task: todoTask, timestamp: makeDate("2026-03-20T09:00:00Z"))

        let store = TestStore(initialState: StatsFeature.State()) {
            StatsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }
        store.exhaustivity = .off

        await store.send(.setData(tasks: [routineTask, todoTask], logs: [routineLog, todoLog], focusSessions: [])) {
            $0.tasks = [routineTask, todoTask]
            $0.logs = [routineLog, todoLog]
            $0.availableTags = ["Errands", "Focus"]
            $0.filteredTaskCount = 2
            $0.metrics.totalDoneCount = 2
            $0.metrics.activeRoutineCount = 2
            $0.metrics.totalCount = 2
        }

        await store.send(.taskTypeFilterChanged(.todos)) {
            $0.taskTypeFilter = .todos
            $0.availableTags = ["Errands"]
            $0.filteredTaskCount = 1
            $0.metrics.totalDoneCount = 1
            $0.metrics.activeRoutineCount = 1
            $0.metrics.totalCount = 1
        }

        await store.send(.selectedTagChanged("Errands")) {
            $0.selectedTag = "Errands"
            $0.selectedTags = ["Errands"]
        }

        await store.send(.taskTypeFilterChanged(.routines)) {
            $0.taskTypeFilter = .routines
            $0.selectedTag = nil
            $0.selectedTags = []
            $0.availableTags = ["Focus"]
            $0.filteredTaskCount = 1
            $0.metrics.totalDoneCount = 1
            $0.metrics.activeRoutineCount = 1
            $0.metrics.totalCount = 1
        }

        await store.send(.excludedTagsChanged(["Focus"])) {
            $0.excludedTags = ["Focus"]
            $0.filteredTaskCount = 0
            $0.metrics.totalDoneCount = 0
            $0.metrics.activeRoutineCount = 0
            $0.metrics.totalCount = 0
        }

        await store.send(.clearFilters) {
            $0.selectedRange = .week
            $0.taskTypeFilter = .all
            $0.selectedTag = nil
            $0.excludedTags = []
            $0.availableTags = ["Errands", "Focus"]
            $0.filteredTaskCount = 2
            $0.metrics.totalDoneCount = 2
            $0.metrics.activeRoutineCount = 2
            $0.metrics.totalCount = 2
        }
    }
}
