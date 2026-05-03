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

        await store.send(.setData(tasks: [morningTask, eveningTask], logs: [morningLog, eveningLog])) {
            $0.tasks = [morningTask, eveningTask]
            $0.logs = [morningLog, eveningLog]
            $0.availableTags = ["Focus", "Home"]
            $0.groupedEntries = [
                TimelineFeature.TimelineSection(
                    date: calendar.startOfDay(for: now),
                    entries: [
                        TimelineEntry(
                            id: morningLog.id,
                            taskID: morningTask.id,
                            timestamp: makeDate("2026-03-20T08:00:00Z"),
                            taskName: "Read",
                            taskEmoji: "📚",
                            tags: ["Focus"],
                            isOneOff: false,
                            kind: .completed
                        ),
                        TimelineEntry(
                            id: eveningLog.id,
                            taskID: eveningTask.id,
                            timestamp: makeDate("2026-03-20T18:00:00Z"),
                            taskName: "Stretch",
                            taskEmoji: "🤸",
                            tags: ["Home"],
                            isOneOff: false,
                            kind: .completed
                        ),
                    ]
                )
            ]
        }

        #expect(store.state.availableTags == ["Focus", "Home"])
        #expect(store.state.groupedEntries.count == 1)
        #expect(store.state.groupedEntries.first?.date == calendar.startOfDay(for: now))
        #expect(store.state.groupedEntries.first?.entries.count == 2)
        #expect(!store.state.hasActiveFilters)
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

        await store.send(.setData(tasks: [olderTask, todayTask], logs: [olderLog, todayLog])) {
            $0.tasks = [olderTask, todayTask]
            $0.logs = [olderLog, todayLog]
            $0.availableTags = ["Deep", "Home"]
            $0.groupedEntries = [
                TimelineFeature.TimelineSection(
                    date: calendar.startOfDay(for: makeDate("2026-03-20T09:00:00Z")),
                    entries: [
                        TimelineEntry(
                            id: todayLog.id,
                            taskID: todayTask.id,
                            timestamp: makeDate("2026-03-20T09:00:00Z"),
                            taskName: "Water Plants",
                            taskEmoji: "🪴",
                            tags: ["Home"],
                            isOneOff: false,
                            kind: .completed
                        ),
                    ]
                ),
                TimelineFeature.TimelineSection(
                    date: calendar.startOfDay(for: makeDate("2026-03-10T08:00:00Z")),
                    entries: [
                        TimelineEntry(
                            id: olderLog.id,
                            taskID: olderTask.id,
                            timestamp: makeDate("2026-03-10T08:00:00Z"),
                            taskName: "Deep Work",
                            taskEmoji: "🧠",
                            tags: ["Deep"],
                            isOneOff: false,
                            kind: .completed
                        ),
                    ]
                ),
            ]
        }
        await store.send(.selectedTagChanged("Deep")) {
            $0.selectedTag = "Deep"
            $0.selectedTags = ["Deep"]
            $0.groupedEntries = [
                TimelineFeature.TimelineSection(
                    date: calendar.startOfDay(for: makeDate("2026-03-10T08:00:00Z")),
                    entries: [
                        TimelineEntry(
                            id: olderLog.id,
                            taskID: olderTask.id,
                            timestamp: makeDate("2026-03-10T08:00:00Z"),
                            taskName: "Deep Work",
                            taskEmoji: "🧠",
                            tags: ["Deep"],
                            isOneOff: false,
                            kind: .completed
                        ),
                    ]
                ),
            ]
        }

        #expect(store.state.selectedTag == "Deep")
        #expect(store.state.groupedEntries.count == 1)
        #expect(store.state.groupedEntries.first?.entries.count == 1)

        await store.send(.selectedRangeChanged(.today)) {
            $0.selectedRange = .today
            $0.selectedTag = nil
            $0.selectedTags = []
            $0.availableTags = ["Home"]
            $0.groupedEntries = [
                TimelineFeature.TimelineSection(
                    date: calendar.startOfDay(for: makeDate("2026-03-20T09:00:00Z")),
                    entries: [
                        TimelineEntry(
                            id: todayLog.id,
                            taskID: todayTask.id,
                            timestamp: makeDate("2026-03-20T09:00:00Z"),
                            taskName: "Water Plants",
                            taskEmoji: "🪴",
                            tags: ["Home"],
                            isOneOff: false,
                            kind: .completed
                        ),
                    ]
                ),
            ]
        }

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

        await store.send(.setData(tasks: [focusTask, homeTask], logs: [focusLog, homeLog])) {
            $0.tasks = [focusTask, homeTask]
            $0.logs = [focusLog, homeLog]
            $0.availableTags = ["Focus", "Home"]
            $0.groupedEntries = [
                TimelineFeature.TimelineSection(
                    date: calendar.startOfDay(for: now),
                    entries: [
                        TimelineEntry(
                            id: focusLog.id,
                            taskID: focusTask.id,
                            timestamp: makeDate("2026-03-20T08:00:00Z"),
                            taskName: "Read",
                            taskEmoji: "📚",
                            tags: ["Focus"],
                            isOneOff: false,
                            kind: .completed
                        ),
                        TimelineEntry(
                            id: homeLog.id,
                            taskID: homeTask.id,
                            timestamp: makeDate("2026-03-20T18:00:00Z"),
                            taskName: "Stretch",
                            taskEmoji: "🤸",
                            tags: ["Home"],
                            isOneOff: false,
                            kind: .completed
                        ),
                    ]
                )
            ]
        }

        await store.send(.excludedTagsChanged(["Focus"])) {
            $0.excludedTags = ["Focus"]
            $0.groupedEntries = [
                TimelineFeature.TimelineSection(
                    date: calendar.startOfDay(for: now),
                    entries: [
                        TimelineEntry(
                            id: homeLog.id,
                            taskID: homeTask.id,
                            timestamp: makeDate("2026-03-20T18:00:00Z"),
                            taskName: "Stretch",
                            taskEmoji: "🤸",
                            tags: ["Home"],
                            isOneOff: false,
                            kind: .completed
                        ),
                    ]
                )
            ]
        }

        #expect(store.state.hasActiveFilters)
        #expect(store.state.groupedEntries.first?.entries.count == 1)
        #expect(store.state.groupedEntries.first?.entries.first?.taskName == "Stretch")
    }
}

@MainActor
struct StatsFeatureTests {
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
        let expectedFocusChartPoints = FocusDurationStats.points(
            for: .week,
            sessions: [],
            referenceDate: now,
            calendar: calendar
        )

        let store = TestStore(initialState: StatsFeature.State()) {
            StatsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }
        store.exhaustivity = .off

        await store.send(.setData(tasks: [focusTask, healthTask], logs: [focusLog1, focusLog2, healthLog], focusSessions: [])) {
            $0.tasks = [focusTask, healthTask]
            $0.logs = [focusLog1, focusLog2, healthLog]
            $0.availableTags = ["Focus", "Health"]
            $0.filteredTaskCount = 2
            $0.metrics = StatsFeature.Metrics(
                chartPoints: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-19T08:00:00Z"),
                        makeDate("2026-03-20T08:00:00Z"),
                        makeDate("2026-03-20T09:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ),
                focusChartPoints: expectedFocusChartPoints,
                tagUsagePoints: [
                    TagUsageChartPoint(name: "Focus", completionCount: 2, linkedRoutineCount: 1, linkedTodoCount: 0, colorHex: nil),
                    TagUsageChartPoint(name: "Health", completionCount: 1, linkedRoutineCount: 1, linkedTodoCount: 0, colorHex: nil),
                ],
                totalDoneCount: 3,
                activeRoutineCount: 1,
                archivedRoutineCount: 1,
                totalCount: 3,
                averagePerDay: 3.0 / 7.0,
                highlightedBusiestDay: DoneChartPoint(date: makeDate("2026-03-20T00:00:00Z"), count: 2),
                activeDayCount: 2,
                chartUpperBound: 3,
                focusChartUpperBound: 10,
                sparklinePoints: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-19T08:00:00Z"),
                        makeDate("2026-03-20T08:00:00Z"),
                        makeDate("2026-03-20T09:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ),
                sparklineMaxCount: 2,
                xAxisDates: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-19T08:00:00Z"),
                        makeDate("2026-03-20T08:00:00Z"),
                        makeDate("2026-03-20T09:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ).map(\.date)
            )
        }
        await store.send(.selectedTagChanged("Focus")) {
            $0.selectedTag = "Focus"
            $0.selectedTags = ["Focus"]
            $0.filteredTaskCount = 1
            $0.metrics = StatsFeature.Metrics(
                chartPoints: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-19T08:00:00Z"),
                        makeDate("2026-03-20T08:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ),
                focusChartPoints: expectedFocusChartPoints,
                tagUsagePoints: [
                    TagUsageChartPoint(name: "Focus", completionCount: 2, linkedRoutineCount: 1, linkedTodoCount: 0, colorHex: nil),
                ],
                totalDoneCount: 2,
                activeRoutineCount: 1,
                archivedRoutineCount: 0,
                totalCount: 2,
                averagePerDay: 2.0 / 7.0,
                highlightedBusiestDay: DoneChartPoint(date: makeDate("2026-03-19T00:00:00Z"), count: 1),
                activeDayCount: 2,
                chartUpperBound: 2,
                focusChartUpperBound: 10,
                sparklinePoints: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-19T08:00:00Z"),
                        makeDate("2026-03-20T08:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ),
                sparklineMaxCount: 1,
                xAxisDates: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-19T08:00:00Z"),
                        makeDate("2026-03-20T08:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ).map(\.date)
            )
        }

        #expect(store.state.availableTags == ["Focus", "Health"])
        #expect(store.state.filteredTaskCount == 1)
        #expect(store.state.metrics.totalDoneCount == 2)
        #expect(store.state.metrics.activeRoutineCount == 1)
        #expect(store.state.metrics.archivedRoutineCount == 0)
        #expect(store.state.metrics.totalCount == 2)

        await store.send(.setData(tasks: [healthTask], logs: [healthLog], focusSessions: [])) {
            $0.tasks = [healthTask]
            $0.logs = [healthLog]
            $0.selectedTag = nil
            $0.selectedTags = []
            $0.availableTags = ["Health"]
            $0.filteredTaskCount = 1
            $0.metrics = StatsFeature.Metrics(
                chartPoints: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-20T09:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ),
                focusChartPoints: expectedFocusChartPoints,
                tagUsagePoints: [
                    TagUsageChartPoint(name: "Health", completionCount: 1, linkedRoutineCount: 1, linkedTodoCount: 0, colorHex: nil),
                ],
                totalDoneCount: 1,
                activeRoutineCount: 0,
                archivedRoutineCount: 1,
                totalCount: 1,
                averagePerDay: 1.0 / 7.0,
                highlightedBusiestDay: DoneChartPoint(date: makeDate("2026-03-20T00:00:00Z"), count: 1),
                activeDayCount: 1,
                chartUpperBound: 2,
                focusChartUpperBound: 10,
                sparklinePoints: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-20T09:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ),
                sparklineMaxCount: 1,
                xAxisDates: RoutineCompletionStats.points(
                    for: .week,
                    timestamps: [
                        makeDate("2026-03-20T09:00:00Z"),
                    ],
                    referenceDate: now,
                    calendar: calendar
                ).map(\.date)
            )
        }

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
