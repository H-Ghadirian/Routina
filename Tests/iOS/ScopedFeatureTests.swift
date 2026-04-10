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

        let store = TestStore(initialState: StatsFeature.State()) {
            StatsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
        }

        await store.send(.setData(tasks: [focusTask, healthTask], logs: [focusLog1, focusLog2, healthLog])) {
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
                totalDoneCount: 3,
                activeRoutineCount: 1,
                archivedRoutineCount: 1,
                totalCount: 3,
                averagePerDay: 3.0 / 7.0,
                highlightedBusiestDay: DoneChartPoint(date: makeDate("2026-03-20T00:00:00Z"), count: 2),
                activeDayCount: 2,
                chartUpperBound: 3,
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
                totalDoneCount: 2,
                activeRoutineCount: 1,
                archivedRoutineCount: 0,
                totalCount: 2,
                averagePerDay: 2.0 / 7.0,
                highlightedBusiestDay: DoneChartPoint(date: makeDate("2026-03-19T00:00:00Z"), count: 1),
                activeDayCount: 2,
                chartUpperBound: 2,
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

        await store.send(.setData(tasks: [healthTask], logs: [healthLog])) {
            $0.tasks = [healthTask]
            $0.logs = [healthLog]
            $0.selectedTag = nil
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
                totalDoneCount: 1,
                activeRoutineCount: 0,
                archivedRoutineCount: 1,
                totalCount: 1,
                averagePerDay: 1.0 / 7.0,
                highlightedBusiestDay: DoneChartPoint(date: makeDate("2026-03-20T00:00:00Z"), count: 1),
                activeDayCount: 1,
                chartUpperBound: 2,
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

        await store.send(.setData(tasks: [routineTask, todoTask], logs: [routineLog, todoLog])) {
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
        }

        await store.send(.taskTypeFilterChanged(.routines)) {
            $0.taskTypeFilter = .routines
            $0.selectedTag = nil
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

@MainActor
@Suite(.serialized)
struct SettingsFeatureDependencyTests {
    @Test
    func onAppear_hydratesStateFromDependenciesAndLoadsContextData() async throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Home")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            placeID: place.id,
            tags: ["Focus"]
        )
        _ = makeLog(in: context, task: task, timestamp: makeDate("2026-03-20T08:30:00Z"))
        try context.save()

        let reminderTime = makeDate("2026-03-20T06:45:00Z")
        let snapshot = LocationSnapshot(
            authorizationStatus: .authorizedAlways,
            coordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
            horizontalAccuracy: 20,
            timestamp: makeDate("2026-03-20T10:00:00Z")
        )
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "cloudKitSyncDiagnostics.summary")
        defaults.removeObject(forKey: "cloudKitSyncDiagnostics.timestamp")
        defaults.removeObject(forKey: "cloudKitSyncDiagnostics.pushStatus")

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appInfoClient = AppInfoClient(
                versionString: { "9.9.9" },
                dataModeDescription: { "Local + Cloud" },
                cloudContainerDescription: { "iCloud.com.routina" },
                isCloudSyncEnabled: { true }
            )
            $0.appSettingsClient = AppSettingsClient(
                notificationsEnabled: { true },
                setNotificationsEnabled: { _ in },
                hideUnavailableRoutines: { false },
                setHideUnavailableRoutines: { _ in },
                routineListSectioningMode: { .deadlineDate },
                setRoutineListSectioningMode: { _ in },
                notificationReminderTime: { reminderTime },
                setNotificationReminderTime: { _ in },
                selectedAppIcon: { .teal },
                temporaryViewState: { nil },
                setTemporaryViewState: { _ in },
                resetTemporaryViewState: { }
            )
            $0.notificationClient.systemNotificationsAuthorized = { true }
            $0.locationClient.snapshot = { _ in snapshot }
        }

        var loadedEstimate = CloudUsageEstimate.zero
        var loadedPlaces: [RoutinePlaceSummary] = []
        var loadedTags: [RoutineTagSummary] = []

        await store.send(.onAppear) {
            $0.appVersion = "9.9.9"
            $0.dataModeDescription = "Local + Cloud"
            $0.iCloudContainerDescription = "iCloud.com.routina"
            $0.cloudSyncAvailable = true
            $0.notificationsEnabled = true
            $0.notificationReminderTime = reminderTime
            $0.routineListSectioningMode = .deadlineDate
            $0.selectedAppIcon = .teal
            $0.appIconStatusMessage = ""
            $0.isDebugSectionVisible = false
        }

        await store.receive(.systemNotificationPermissionChecked(true))
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            loadedEstimate = estimate
            #expect(estimate.taskCount == 1)
            #expect(estimate.placeCount == 1)
            #expect(estimate.logCount == 1)
            return true
        } assert: {
            $0.cloudUsageEstimate = loadedEstimate
        }
        await store.receive { action in
            guard case let .placesLoaded(places) = action else { return false }
            loadedPlaces = places
            #expect(places.count == 1)
            #expect(places.first?.name == "Home")
            #expect(places.first?.linkedRoutineCount == 1)
            return true
        } assert: {
            $0.savedPlaces = loadedPlaces
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.count == 1)
            #expect(tags.first?.name == "Focus")
            #expect(tags.first?.linkedRoutineCount == 1)
            return true
        } assert: {
            $0.savedTags = loadedTags
        }
        await store.receive(.locationSnapshotUpdated(snapshot)) {
            $0.locationAuthorizationStatus = .authorizedAlways
            $0.lastKnownLocationCoordinate = snapshot.coordinate
        }
    }

    @Test
    func toggleNotifications_offPersistsPreferenceAndCancelsAllNotifications() async {
        let context = makeInMemoryContext()
        let capturedNotificationPreference = LockIsolated<Bool?>(nil)
        let cancelAllCallCount = LockIsolated(0)

        let store = TestStore(
            initialState: SettingsFeature.State(notificationsEnabled: true)
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.setNotificationsEnabled = { isEnabled in
                capturedNotificationPreference.setValue(isEnabled)
            }
            $0.notificationClient.cancelAll = {
                cancelAllCallCount.setValue(cancelAllCallCount.value + 1)
            }
        }

        await store.send(.toggleNotifications(false)) {
            $0.notificationsEnabled = false
        }

        #expect(capturedNotificationPreference.value == false)
        #expect(cancelAllCallCount.value == 1)
    }
}
