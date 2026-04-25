import CloudKit
import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct HomeFeatureTests {
    @Test
    func setAddRoutineSheet_togglesPresentationAndChildState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setAddRoutineSheet(true)) {
            $0.isAddRoutineSheetPresented = true
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    availableTagSummaries: [],
                    existingRoutineNames: []
                )
            )
        }

        await store.send(.setAddRoutineSheet(false)) {
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
        }
    }

    @Test
    func setAddRoutineSheet_seedsExistingNamesFromLoadedTasks() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚", tags: ["Learning"])

        let initialState = HomeFeature.State(
            routineTasks: [task],
            routineDisplays: [],
            doneStats: HomeFeature.DoneStats(totalCount: 4, countsByTaskID: [task.id: 4]),
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setAddRoutineSheet(true)) {
            $0.isAddRoutineSheetPresented = true
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    availableTags: ["Learning"],
                    availableTagSummaries: [
                        RoutineTagSummary(name: "Learning", linkedRoutineCount: 1, doneCount: 4)
                    ],
                    availableRelationshipTasks: [
                        RoutineTaskRelationshipCandidate(
                            id: task.id,
                            name: "Read",
                            emoji: "📚",
                            relationships: []
                        )
                    ],
                    existingRoutineNames: ["Read"]
                )
            )
        }
    }

    @Test
    func setAddRoutineSheet_hidesMacFilterDetail() async {
        let context = makeInMemoryContext()

        let store = TestStore(
            initialState: HomeFeature.State(isMacFilterDetailPresented: true)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setAddRoutineSheet(true)) {
            $0.isAddRoutineSheetPresented = true
            $0.isMacFilterDetailPresented = false
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    availableTagSummaries: [],
                    existingRoutineNames: []
                )
            )
        }
    }

    @Test
    func openAddLinkedTask_presentsAddRoutineSeededWithInverseRelationship() async throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Office")
        let currentTask = makeTask(
            in: context,
            name: "Draft report",
            interval: 2,
            lastDone: nil,
            emoji: "📝",
            placeID: place.id,
            tags: ["Focus"]
        )
        let relatedTask = makeTask(
            in: context,
            name: "Review draft",
            interval: 3,
            lastDone: nil,
            emoji: "🔍",
            placeID: place.id,
            tags: ["Writing"]
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [currentTask, relatedTask],
                routinePlaces: [place],
                selectedTaskID: currentTask.id,
                taskDetailState: TaskDetailFeature.State(
                    task: currentTask,
                    addLinkedTaskRelationshipKind: .blockedBy
                ),
                isMacFilterDetailPresented: true
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(HomeFeature.Action.taskDetail(.openAddLinkedTask)) {
            $0.isAddRoutineSheetPresented = true
            $0.isMacFilterDetailPresented = false
            $0.addRoutineState = AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(
                    relationships: [RoutineTaskRelationship(targetTaskID: currentTask.id, kind: .blocks)],
                    availableTags: ["Focus", "Writing"],
                    availableTagSummaries: [
                        RoutineTagSummary(name: "Focus", linkedRoutineCount: 1, doneCount: 0),
                        RoutineTagSummary(name: "Writing", linkedRoutineCount: 1, doneCount: 0)
                    ],
                    availableRelationshipTasks: [
                        RoutineTaskRelationshipCandidate(
                            id: relatedTask.id,
                            name: "Review draft",
                            emoji: "🔍",
                            relationships: [],
                            status: .onTrack
                        )
                    ],
                    existingRoutineNames: ["Draft report", "Review draft"],
                    availablePlaces: [
                        RoutinePlaceSummary(
                            id: place.id,
                            name: "Office",
                            radiusMeters: place.radiusMeters,
                            linkedRoutineCount: 2
                        )
                    ]
                )
            )
        }

        let addRoutineState = try #require(store.state.addRoutineState)
        #expect(addRoutineState.organization.relationships == [
            RoutineTaskRelationship(targetTaskID: currentTask.id, kind: .blocks)
        ])
        #expect(addRoutineState.organization.availableTags == ["Focus", "Writing"])
        #expect(addRoutineState.organization.existingRoutineNames == ["Draft report", "Review draft"])
        #expect(addRoutineState.organization.availablePlaces == [
            RoutinePlaceSummary(
                id: place.id,
                name: "Office",
                radiusMeters: place.radiusMeters,
                linkedRoutineCount: 2
            )
        ])
        #expect(addRoutineState.organization.availableRelationshipTasks == [
            RoutineTaskRelationshipCandidate(
                id: relatedTask.id,
                name: "Review draft",
                emoji: "🔍",
                relationships: [],
                status: .onTrack
            )
        ])
    }

    @Test
    func setDeleteConfirmation_falseClearsPendingDeleteIDs() async {
        let context = makeInMemoryContext()
        let pendingID = UUID()

        let store = TestStore(
            initialState: HomeFeature.State(
                pendingDeleteTaskIDs: [pendingID],
                isDeleteConfirmationPresented: true
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setDeleteConfirmation(false)) {
            $0.isDeleteConfirmationPresented = false
            $0.pendingDeleteTaskIDs = []
        }
    }

    @Test
    func clearOptionalFilters_resetsOptionalFiltersAndPersistsState() async {
        let context = makeInMemoryContext()
        let placeID = UUID()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)
        let hideUnavailableUpdates = LockIsolated<[Bool]>([])
        let matrixFilter = ImportanceUrgencyFilterCell(importance: .level3, urgency: .level2)

        let store = TestStore(
            initialState: HomeFeature.State(
                hideUnavailableRoutines: true,
                selectedTag: "Errands",
                excludedTags: ["Home"],
                selectedManualPlaceFilterID: placeID,
                selectedImportanceUrgencyFilter: matrixFilter
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setHideUnavailableRoutines = { value in
                hideUnavailableUpdates.withValue { $0.append(value) }
            }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.clearOptionalFilters) {
            $0.hideUnavailableRoutines = false
            $0.selectedTag = nil
            $0.excludedTags = []
            $0.selectedManualPlaceFilterID = nil
            $0.selectedImportanceUrgencyFilter = nil
        }

        #expect(hideUnavailableUpdates.value == [false])
        #expect(persistedState.value?.homeSelectedTag == nil)
        #expect(persistedState.value?.homeExcludedTags == [])
        #expect(persistedState.value?.homeSelectedManualPlaceFilterID == nil)
        #expect(persistedState.value?.homeSelectedImportanceUrgencyFilter == nil)
        #expect(persistedState.value?.hideUnavailableRoutines == false)
        #expect(
            persistedState.value?.homeTabFilterSnapshots[HomeFeature.TaskListMode.todos.rawValue]
            == TabFilterStateManager.Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil
            )
        )
    }

    @Test
    func selectedFilterChanged_overwritesPersistedSnapshotForCurrentMode() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)
        let stalePlaceID = UUID()

        let store = TestStore(
            initialState: HomeFeature.State(
                taskListMode: .routines,
                tabFilterSnapshots: [
                    HomeFeature.TaskListMode.routines.rawValue: TabFilterStateManager.Snapshot(
                        selectedTag: "Errands",
                        excludedTags: ["Home"],
                        selectedFilter: .due,
                        selectedManualPlaceFilterID: stalePlaceID
                    )
                ]
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { .default }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.selectedFilterChanged(.doneToday)) {
            $0.selectedFilter = .doneToday
        }

        #expect(
            persistedState.value?.homeTabFilterSnapshots[HomeFeature.TaskListMode.routines.rawValue]
            == TabFilterStateManager.Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .doneToday,
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil
            )
        )
    }

    @Test
    func setMacFilterDetailPresented_closesAddRoutine() async {
        let context = makeInMemoryContext()

        let store = TestStore(
            initialState: HomeFeature.State(
                selectedTaskID: UUID(),
                isAddRoutineSheetPresented: true,
                addRoutineState: AddRoutineFeature.State(
                    organization: AddRoutineOrganizationState(existingRoutineNames: [])
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setMacFilterDetailPresented(true)) {
            $0.isMacFilterDetailPresented = true
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
            $0.selectedTaskID = nil
        }
    }

    @Test
    func onAppear_restoresPersistedTemporaryViewState() async {
        let context = makeInMemoryContext()
        let persistedState = TemporaryViewState(
            selectedAppTabRawValue: Tab.home.rawValue,
            homeTaskListModeRawValue: HomeFeature.TaskListMode.routines.rawValue,
            homeSelectedFilter: .due,
            homeSelectedTag: "Home",
            homeExcludedTags: ["Work"],
            homeSelectedManualPlaceFilterID: UUID(),
            homeTabFilterSnapshots: [
                HomeFeature.TaskListMode.routines.rawValue: TabFilterStateManager.Snapshot(
                    selectedTag: "Home",
                    excludedTags: ["Work"],
                    selectedFilter: .due,
                    selectedManualPlaceFilterID: nil
                )
            ],
            hideUnavailableRoutines: true,
            homeSelectedTimelineRange: .month,
            homeSelectedTimelineFilterType: .todos,
            homeSelectedTimelineTag: "Errands",
            macHomeSidebarModeRawValue: HomeFeature.MacSidebarMode.stats.rawValue,
            macSelectedSettingsSectionRawValue: SettingsMacSection.notifications.rawValue,
            timelineSelectedRange: .all,
            timelineFilterType: .all,
            timelineSelectedTag: nil,
            statsSelectedRange: .year,
            statsSelectedTag: "Focus",
            statsExcludedTags: [],
            statsTaskTypeFilterRawValue: nil
        )
        let locationSnapshot = LocationSnapshot(
            authorizationStatus: .authorizedAlways,
            coordinate: nil,
            horizontalAccuracy: nil,
            timestamp: nil
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.locationClient.snapshot = { _ in locationSnapshot }
            $0.appSettingsClient.temporaryViewState = { persistedState }
            $0.appSettingsClient.hideUnavailableRoutines = { false }
        }

        await store.send(.onAppear) {
            $0.hideUnavailableRoutines = true
            $0.taskListMode = .routines
            $0.macSidebarMode = .stats
            $0.selectedFilter = .due
            $0.selectedTag = "Home"
            $0.excludedTags = ["Work"]
            $0.selectedSettingsSection = .notifications
            $0.tabFilterSnapshots = persistedState.homeTabFilterSnapshots
            $0.selectedTimelineRange = .month
            $0.selectedTimelineFilterType = .todos
            $0.selectedTimelineTag = "Errands"
            $0.statsSelectedRange = .year
            $0.statsSelectedTag = "Focus"
        }

        await store.receive(.tasksLoadedSuccessfully([], [], [], HomeFeature.DoneStats())) {
            $0.selectedTag = nil
            $0.excludedTags = []
        }
        await store.receive(.sprintBoardLoaded(SprintBoardData()))
        await store.receive(.locationSnapshotUpdated(locationSnapshot)) {
            $0.locationSnapshot = locationSnapshot
        }
    }

    @Test
    func selectedFilterChanged_persistsTemporaryViewState() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)
        let existingTemporaryViewState = TemporaryViewState(
            selectedAppTabRawValue: Tab.stats.rawValue,
            homeTaskListModeRawValue: HomeFeature.TaskListMode.routines.rawValue,
            homeSelectedFilter: .all,
            homeSelectedTag: nil,
            homeExcludedTags: [],
            homeSelectedManualPlaceFilterID: nil,
            homeTabFilterSnapshots: [:],
            hideUnavailableRoutines: false,
            homeSelectedTimelineRange: .month,
            homeSelectedTimelineFilterType: .todos,
            homeSelectedTimelineTag: "Errands",
            macHomeSidebarModeRawValue: HomeFeature.MacSidebarMode.stats.rawValue,
            macSelectedSettingsSectionRawValue: SettingsMacSection.notifications.rawValue,
            timelineSelectedRange: .month,
            timelineFilterType: .todos,
            timelineSelectedTag: "Deep",
            statsSelectedRange: .year,
            statsSelectedTag: "Focus",
            statsExcludedTags: [],
            statsTaskTypeFilterRawValue: StatsTaskTypeFilter.todos.rawValue
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                hideUnavailableRoutines: true,
                taskListMode: .todos,
                selectedTag: "Errands",
                excludedTags: ["Home"],
                selectedTimelineRange: .week,
                selectedTimelineFilterType: .routines,
                selectedTimelineTag: "Chores",
                statsSelectedRange: .month,
                statsSelectedTag: "Focus"
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { existingTemporaryViewState }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.selectedFilterChanged(.doneToday)) {
            $0.selectedFilter = .doneToday
        }

        #expect(persistedState.value?.homeTaskListModeRawValue == HomeFeature.TaskListMode.todos.rawValue)
        #expect(persistedState.value?.homeSelectedFilter == .doneToday)
        #expect(persistedState.value?.homeSelectedTag == "Errands")
        #expect(persistedState.value?.homeExcludedTags == ["Home"])
        #expect(persistedState.value?.hideUnavailableRoutines == true)
        #expect(persistedState.value?.homeSelectedTimelineRange == .week)
        #expect(persistedState.value?.homeSelectedTimelineFilterType == .routines)
        #expect(persistedState.value?.homeSelectedTimelineTag == "Chores")
        #expect(persistedState.value?.selectedAppTabRawValue == Tab.stats.rawValue)
        #expect(persistedState.value?.macHomeSidebarModeRawValue == HomeFeature.MacSidebarMode.routines.rawValue)
        #expect(persistedState.value?.timelineSelectedRange == .month)
        #expect(persistedState.value?.timelineFilterType == .todos)
        #expect(persistedState.value?.timelineSelectedTag == "Deep")
        #expect(persistedState.value?.statsSelectedRange == .year)
        #expect(persistedState.value?.statsSelectedTag == "Focus")
        #expect(persistedState.value?.statsTaskTypeFilterRawValue == StatsTaskTypeFilter.todos.rawValue)
    }

    @Test
    func selectedImportanceUrgencyFilterChanged_persistsTemporaryViewState() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)
        let existingTemporaryViewState = TemporaryViewState(
            selectedAppTabRawValue: Tab.stats.rawValue,
            homeTaskListModeRawValue: HomeFeature.TaskListMode.routines.rawValue,
            homeSelectedFilter: .all,
            homeSelectedTag: nil,
            homeExcludedTags: [],
            homeSelectedManualPlaceFilterID: nil,
            homeTabFilterSnapshots: [:],
            hideUnavailableRoutines: false,
            homeSelectedTimelineRange: .month,
            homeSelectedTimelineFilterType: .todos,
            homeSelectedTimelineTag: "Errands",
            macHomeSidebarModeRawValue: HomeFeature.MacSidebarMode.stats.rawValue,
            macSelectedSettingsSectionRawValue: SettingsMacSection.notifications.rawValue,
            timelineSelectedRange: .month,
            timelineFilterType: .todos,
            timelineSelectedTag: "Deep",
            statsSelectedRange: .year,
            statsSelectedTag: "Focus",
            statsExcludedTags: [],
            statsTaskTypeFilterRawValue: StatsTaskTypeFilter.todos.rawValue
        )
        let selectedCell = ImportanceUrgencyFilterCell(importance: .level3, urgency: .level2)

        let store = TestStore(
            initialState: HomeFeature.State()
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.temporaryViewState = { existingTemporaryViewState }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.selectedImportanceUrgencyFilterChanged(selectedCell)) {
            $0.selectedImportanceUrgencyFilter = selectedCell
        }

        #expect(persistedState.value?.homeSelectedImportanceUrgencyFilter == selectedCell)
        #expect(persistedState.value?.selectedAppTabRawValue == Tab.stats.rawValue)
    }

    @Test
    func importanceUrgencyFilter_matchesTasksAtOrAboveSelectedCell() {
        let selectedCell = ImportanceUrgencyFilterCell(importance: .level3, urgency: .level2)

        #expect(HomeFeature.matchesImportanceUrgencyFilter(selectedCell, importance: .level3, urgency: .level2))
        #expect(HomeFeature.matchesImportanceUrgencyFilter(selectedCell, importance: .level4, urgency: .level4))
        #expect(!HomeFeature.matchesImportanceUrgencyFilter(selectedCell, importance: .level2, urgency: .level4))
        #expect(!HomeFeature.matchesImportanceUrgencyFilter(selectedCell, importance: .level4, urgency: .level1))
    }

    @Test
    func macSidebarModeChanged_persistsDesktopSectionSelection() async {
        let context = makeInMemoryContext()
        let persistedState = LockIsolated<TemporaryViewState?>(nil)

        let store = TestStore(
            initialState: HomeFeature.State(
                macSidebarMode: .routines,
                selectedSettingsSection: .notifications
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.setTemporaryViewState = { persistedState.setValue($0) }
        }

        await store.send(.macSidebarModeChanged(.stats)) {
            $0.macSidebarMode = .stats
            $0.selectedTaskID = nil
            $0.taskDetailState = nil
            $0.selectedTaskReloadGuard = nil
            $0.pendingSelectedChecklistReloadGuardTaskID = nil
            $0.macSidebarSelection = nil
        }

        #expect(persistedState.value?.macHomeSidebarModeRawValue == HomeFeature.MacSidebarMode.stats.rawValue)
        #expect(persistedState.value?.macSelectedSettingsSectionRawValue == SettingsMacSection.notifications.rawValue)
    }

    @Test
    func setSelectedTask_populatesReducerOwnedDetailState() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-16T10:00:00Z")
        let lastDone = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Read",
            interval: 2,
            lastDone: lastDone,
            emoji: "📚",
            scheduleAnchor: lastDone
        )
        let log = makeLog(in: context, task: task, timestamp: lastDone)
        try context.save()

        let store = TestStore(
            initialState: HomeFeature.State(routineTasks: [task])
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setSelectedTask(task.id)) {
            $0.selectedTaskID = task.id
            $0.macSidebarSelection = .task(task.id)
            $0.taskDetailState = TaskDetailFeature.State(
                task: task,
                logs: [],
                selectedDate: calendar.startOfDay(for: now),
                daysSinceLastRoutine: 2,
                overdueDays: 0,
                isDoneToday: false
            )
        }

        let detailState = try #require(store.state.taskDetailState)
        #expect(store.state.selectedTaskID == task.id)
        #expect(detailState.task.id == task.id)
        #expect(detailState.selectedDate == calendar.startOfDay(for: now))
        #expect(detailState.daysSinceLastRoutine == 2)
        #expect(!detailState.isDoneToday)

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([log]))) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 2,
                    lastDone: lastDone,
                    scheduleAnchor: lastDone,
                    daysUntilDue: 0,
                    isDoneToday: false
                )
            ]
            $0.taskDetailState?.logs = [log]
            $0.taskDetailState?.daysSinceLastRoutine = 2
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = false
        }
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)
    }

    @Test
    func setSelectedTask_sameIDPreservesDetailStateAndReloadGuard() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = RoutineTask(
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(title: "Excel", intervalDays: 30, createdAt: now),
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        let detailTask = task.detachedCopy()
        let log = RoutineLog(timestamp: now, taskID: task.id)

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [task.detachedCopy()],
                selectedTaskID: task.id,
                taskDetailState: TaskDetailFeature.State(
                    task: detailTask,
                    logs: [log],
                    selectedDate: calendar.startOfDay(for: now),
                    daysSinceLastRoutine: 0,
                    overdueDays: 0,
                    isDoneToday: false
                ),
                selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard(
                    taskID: task.id,
                    completedChecklistItemIDsStorage: detailTask.completedChecklistItemIDsStorage,
                    lastDone: detailTask.lastDone,
                    scheduleAnchor: detailTask.scheduleAnchor
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.setSelectedTask(task.id))

        #expect(store.state.selectedTaskID == task.id)
        #expect(store.state.taskDetailState?.logs == [log])
        #expect(store.state.taskDetailState?.task.id == detailTask.id)
        #expect(store.state.selectedTaskReloadGuard?.taskID == task.id)
    }

    @Test
    func tasksLoadedSuccessfully_refreshesLogsForOpenTaskDetail() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-16T10:00:00Z")
        let lastDone = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Read",
            interval: 2,
            lastDone: lastDone,
            emoji: "📚",
            scheduleAnchor: lastDone
        )
        let log = makeLog(in: context, task: task, timestamp: lastDone)
        try context.save()

        let initialDetailState = TaskDetailFeature.State(
            task: task,
            logs: [],
            selectedDate: calendar.startOfDay(for: now),
            daysSinceLastRoutine: 2,
            overdueDays: 0,
            isDoneToday: false
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [task],
                selectedTaskID: task.id,
                taskDetailState: initialDetailState
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task], [], [], HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task.id: 1]))) {
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task.id: 1])
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 2,
                    lastDone: lastDone,
                    daysUntilDue: 0,
                    isDoneToday: false,
                    doneCount: 1
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([log]))) {
            $0.taskDetailState?.logs = [log]
            $0.taskDetailState?.daysSinceLastRoutine = 2
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = false
        }
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)
    }

    @Test
    func tasksLoadedSuccessfully_detachesReducerStateFromIncomingTaskModels() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let firstItemID = UUID()
        let secondItemID = UUID()
        let thirdItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let sourceTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: thirdItemID, title: "Payroll", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                selectedTaskID: taskID,
                taskDetailState: TaskDetailFeature.State(
                    task: sourceTask,
                    selectedDate: calendar.startOfDay(for: now)
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([sourceTask], [], [], HomeFeature.DoneStats())) {
            $0.routineTasks = [sourceTask]
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: nil,
                    scheduleAnchor: nil,
                    daysUntilDue: 30,
                    isDoneToday: false,
                    checklistItemCount: 3,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = false
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        _ = sourceTask.markChecklistItemCompleted(firstItemID, completedAt: now, calendar: calendar)
        _ = sourceTask.markChecklistItemCompleted(secondItemID, completedAt: now, calendar: calendar)

        #expect(store.state.routineTasks[0].completedChecklistItemCount == 0)
        #expect(store.state.routineTasks[0].lastDone == nil)
        #expect(store.state.taskDetailState?.task.completedChecklistItemCount == 0)
        #expect(store.state.taskDetailState?.task.lastDone == nil)
        #expect(store.state.taskDetailState?.isDoneToday == false)
    }

    @Test
    func taskDetailLogsLoaded_syncsSelectedTaskBackIntoHomeState() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let completedItemID = UUID()
        let pendingItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let sidebarTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: completedItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: pendingItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )

        let detailTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: completedItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: pendingItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        _ = detailTask.markChecklistItemCompleted(completedItemID, completedAt: now, calendar: calendar)

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [sidebarTask],
                selectedTaskID: taskID,
                taskDetailState: TaskDetailFeature.State(task: detailTask)
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.taskDetail(.logsLoaded([]))) {
            $0.routineTasks[0] = detailTask
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: nil,
                    daysUntilDue: 30,
                    isDoneToday: false,
                    checklistItemCount: 2,
                    completedChecklistItemCount: 1,
                    nextPendingChecklistItemTitle: "Excel"
                )
            ]
            $0.taskDetailState?.logs = []
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = false
        }
    }

    @Test
    func tasksLoadedSuccessfully_preservesSelectedChecklistProgressDuringReload() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let completedItemID = UUID()
        let pendingItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let staleReloadTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: completedItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: pendingItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )

        let selectedDetailTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: completedItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: pendingItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        _ = selectedDetailTask.markChecklistItemCompleted(completedItemID, completedAt: now, calendar: calendar)

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [selectedDetailTask],
                selectedTaskID: taskID,
                taskDetailState: TaskDetailFeature.State(task: selectedDetailTask),
                selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard(
                    taskID: taskID,
                    completedChecklistItemIDsStorage: selectedDetailTask.completedChecklistItemIDsStorage,
                    lastDone: selectedDetailTask.lastDone,
                    scheduleAnchor: selectedDetailTask.scheduleAnchor
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([staleReloadTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: nil,
                    daysUntilDue: 30,
                    isDoneToday: false,
                    checklistItemCount: 2,
                    completedChecklistItemCount: 1,
                    nextPendingChecklistItemTitle: "Excel"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
        }
        await store.receive(.taskDetail(.onAppear)) {
            $0.taskDetailState?.selectedDate = calendar.startOfDay(for: now)
        }
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        #expect(store.state.routineTasks[0].completedChecklistItemCount == 1)
        #expect(store.state.taskDetailState?.task.completedChecklistItemCount == 1)
        #expect(store.state.selectedTaskReloadGuard?.taskID == taskID)
    }

    @Test
    func taskDetailToggleChecklistItemCompletion_tracksReloadGuardForSharedSelectedTask() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let completedItemID = UUID()
        let pendingItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let sharedTask = makeTask(
            in: context,
            name: "Working hours",
            interval: 30,
            lastDone: nil,
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: completedItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: pendingItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        let taskID = sharedTask.id

        let initialState = HomeFeature.State(
            routineTasks: [sharedTask],
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(
                task: sharedTask,
                selectedDate: calendar.startOfDay(for: now)
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.taskDetail(.toggleChecklistItemCompletion(completedItemID))) {
            $0.pendingSelectedChecklistReloadGuardTaskID = taskID
            $0.taskDetailState?.taskRefreshID = 1
        }

        await store.receive(.taskDetail(.logsLoaded([]))) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: nil,
                    daysUntilDue: 30,
                    isDoneToday: false,
                    checklistItemCount: 2,
                    completedChecklistItemCount: 1,
                    nextPendingChecklistItemTitle: "Excel"
                )
            ]
            $0.taskDetailState?.logs = []
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = false
            $0.selectedTaskReloadGuard = HomeFeature.SelectedTaskReloadGuard(
                taskID: taskID,
                completedChecklistItemIDsStorage: sharedTask.completedChecklistItemIDsStorage,
                lastDone: nil,
                scheduleAnchor: nil
            )
            $0.pendingSelectedChecklistReloadGuardTaskID = nil
        }

        #expect(store.state.routineTasks[0].completedChecklistItemCount == 1)
        #expect(store.state.selectedTaskReloadGuard?.completedChecklistItemIDsStorage == sharedTask.completedChecklistItemIDsStorage)
    }

    @Test
    func tasksLoadedSuccessfully_preservesFreshlyCompletedChecklistRoutineDuringStaleReload() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let firstItemID = UUID()
        let secondItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let staleReloadTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )

        let selectedDetailTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        _ = selectedDetailTask.markChecklistItemCompleted(firstItemID, completedAt: now, calendar: calendar)
        _ = selectedDetailTask.markChecklistItemCompleted(secondItemID, completedAt: now, calendar: calendar)

        let initialState = HomeFeature.State(
            routineTasks: [selectedDetailTask],
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(
                task: selectedDetailTask,
                selectedDate: calendar.startOfDay(for: now),
                daysSinceLastRoutine: 0,
                overdueDays: 0,
                isDoneToday: true
            ),
            selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard(
                taskID: taskID,
                completedChecklistItemIDsStorage: selectedDetailTask.completedChecklistItemIDsStorage,
                lastDone: selectedDetailTask.lastDone,
                scheduleAnchor: selectedDetailTask.scheduleAnchor
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([staleReloadTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: now,
                    scheduleAnchor: now,
                    daysUntilDue: 30,
                    isDoneToday: true,
                    checklistItemCount: 2,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = true
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        #expect(store.state.routineTasks[0].lastDone == now)
        #expect(store.state.taskDetailState?.task.lastDone == now)
        #expect(store.state.taskDetailState?.isDoneToday == true)
        #expect(store.state.selectedTaskReloadGuard?.lastDone == now)
    }

    @Test
    func tasksLoadedSuccessfully_keepsChecklistCompletionGuardAfterMatchingRefresh() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let firstItemID = UUID()
        let secondItemID = UUID()
        let thirdItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let completedTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: thirdItemID, title: "Payroll", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30,
            lastDone: now,
            scheduleAnchor: now
        )

        let initialState = HomeFeature.State(
            routineTasks: [completedTask],
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(
                task: completedTask,
                selectedDate: calendar.startOfDay(for: now),
                daysSinceLastRoutine: 0,
                overdueDays: 0,
                isDoneToday: true
            ),
            selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard(
                taskID: taskID,
                completedChecklistItemIDsStorage: "",
                lastDone: now,
                scheduleAnchor: now
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([completedTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: now,
                    scheduleAnchor: now,
                    daysUntilDue: 30,
                    isDoneToday: true,
                    checklistItemCount: 3,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = true
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        #expect(store.state.selectedTaskReloadGuard?.lastDone == now)
    }

    @Test
    func tasksLoadedSuccessfully_preservesChecklistCompletionAfterMatchingThenStaleRefresh() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let firstItemID = UUID()
        let secondItemID = UUID()
        let thirdItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let completedTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: thirdItemID, title: "Payroll", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30,
            lastDone: now,
            scheduleAnchor: now
        )

        let stalePartialTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: thirdItemID, title: "Payroll", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        _ = stalePartialTask.markChecklistItemCompleted(firstItemID, completedAt: now, calendar: calendar)

        let initialState = HomeFeature.State(
            routineTasks: [completedTask],
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(
                task: completedTask,
                selectedDate: calendar.startOfDay(for: now),
                daysSinceLastRoutine: 0,
                overdueDays: 0,
                isDoneToday: true
            ),
            selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard(
                taskID: taskID,
                completedChecklistItemIDsStorage: "",
                lastDone: now,
                scheduleAnchor: now
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([completedTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: now,
                    scheduleAnchor: now,
                    daysUntilDue: 30,
                    isDoneToday: true,
                    checklistItemCount: 3,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = true
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        await store.send(.tasksLoadedSuccessfully([stalePartialTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: now,
                    scheduleAnchor: now,
                    daysUntilDue: 30,
                    isDoneToday: true,
                    checklistItemCount: 3,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 2
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = true
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        #expect(store.state.routineTasks[0].lastDone == now)
        #expect(store.state.routineTasks[0].completedChecklistItemCount == 0)
        #expect(store.state.taskDetailState?.task.lastDone == now)
        #expect(store.state.taskDetailState?.task.completedChecklistItemCount == 0)
        #expect(store.state.selectedTaskReloadGuard?.lastDone == now)
    }

    @Test
    func tasksLoadedSuccessfully_preservesChecklistCompletionDuringMultiplePartialReplays() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let firstItemID = UUID()
        let secondItemID = UUID()
        let thirdItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let completedTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: thirdItemID, title: "Payroll", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        _ = completedTask.markChecklistItemCompleted(firstItemID, completedAt: now, calendar: calendar)
        _ = completedTask.markChecklistItemCompleted(secondItemID, completedAt: now, calendar: calendar)
        _ = completedTask.markChecklistItemCompleted(thirdItemID, completedAt: now, calendar: calendar)

        let staleOneOfThreeTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: thirdItemID, title: "Payroll", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        _ = staleOneOfThreeTask.markChecklistItemCompleted(firstItemID, completedAt: now, calendar: calendar)

        let staleTwoOfThreeTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: thirdItemID, title: "Payroll", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )
        _ = staleTwoOfThreeTask.markChecklistItemCompleted(firstItemID, completedAt: now, calendar: calendar)
        _ = staleTwoOfThreeTask.markChecklistItemCompleted(secondItemID, completedAt: now, calendar: calendar)

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [completedTask],
                selectedTaskID: taskID,
                taskDetailState: TaskDetailFeature.State(
                    task: completedTask,
                    selectedDate: calendar.startOfDay(for: now),
                    daysSinceLastRoutine: 0,
                    overdueDays: 0,
                    isDoneToday: true
                ),
                selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard(
                    taskID: taskID,
                    completedChecklistItemIDsStorage: "",
                    lastDone: now,
                    scheduleAnchor: now
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([staleOneOfThreeTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: now,
                    scheduleAnchor: now,
                    daysUntilDue: 30,
                    isDoneToday: true,
                    checklistItemCount: 3,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = true
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        await store.send(.tasksLoadedSuccessfully([staleTwoOfThreeTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: now,
                    scheduleAnchor: now,
                    daysUntilDue: 30,
                    isDoneToday: true,
                    checklistItemCount: 3,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 2
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = true
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        #expect(store.state.routineTasks[0].lastDone == now)
        #expect(store.state.routineTasks[0].completedChecklistItemCount == 0)
        #expect(store.state.taskDetailState?.task.lastDone == now)
        #expect(store.state.taskDetailState?.task.completedChecklistItemCount == 0)
        #expect(store.state.taskDetailState?.isDoneToday == true)
        #expect(store.state.selectedTaskReloadGuard?.lastDone == now)
    }

    @Test
    func taskDetailUndoSelectedDateCompletion_tracksReloadGuardForChecklistRoutine() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let firstItemID = UUID()
        let secondItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let sharedTask = makeTask(
            in: context,
            name: "Working hours",
            interval: 30,
            lastDone: now,
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            scheduleAnchor: now
        )
        let taskID = sharedTask.id
        let todayLog = makeLog(in: context, task: sharedTask, timestamp: now)

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [sharedTask],
                selectedTaskID: taskID,
                taskDetailState: TaskDetailFeature.State(
                    task: sharedTask,
                    logs: [todayLog],
                    selectedDate: calendar.startOfDay(for: now),
                    daysSinceLastRoutine: 0,
                    overdueDays: 0,
                    isDoneToday: true
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.taskDetail(.undoSelectedDateCompletion)) {
            $0.pendingSelectedChecklistReloadGuardTaskID = taskID
            $0.taskDetailState?.taskRefreshID = 1
            $0.taskDetailState?.task.lastDone = nil
            $0.taskDetailState?.task.scheduleAnchor = nil
            $0.taskDetailState?.logs = []
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = false
        }

        await store.receive(.taskDetail(.logsLoaded([]))) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: nil,
                    scheduleAnchor: nil,
                    daysUntilDue: 30,
                    isDoneToday: false,
                    checklistItemCount: 2,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.selectedTaskReloadGuard = HomeFeature.SelectedTaskReloadGuard(
                taskID: taskID,
                completedChecklistItemIDsStorage: "",
                lastDone: nil,
                scheduleAnchor: nil
            )
            $0.pendingSelectedChecklistReloadGuardTaskID = nil
        }

        #expect(store.state.routineTasks[0].lastDone == nil)
        #expect(store.state.selectedTaskReloadGuard?.lastDone == nil)
    }

    @Test
    func tasksLoadedSuccessfully_preservesChecklistUndoStateDuringStaleReload() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-24T10:00:00Z")
        let taskID = UUID()
        let firstItemID = UUID()
        let secondItemID = UUID()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let staleReloadTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30,
            lastDone: now,
            scheduleAnchor: now
        )

        let selectedDetailTask = RoutineTask(
            id: taskID,
            name: "Working hours",
            emoji: "✨",
            checklistItems: [
                RoutineChecklistItem(id: firstItemID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: secondItemID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 30
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [selectedDetailTask],
                selectedTaskID: taskID,
                taskDetailState: TaskDetailFeature.State(
                    task: selectedDetailTask,
                    selectedDate: calendar.startOfDay(for: now),
                    daysSinceLastRoutine: 0,
                    overdueDays: 0,
                    isDoneToday: false
                ),
                selectedTaskReloadGuard: HomeFeature.SelectedTaskReloadGuard(
                    taskID: taskID,
                    completedChecklistItemIDsStorage: "",
                    lastDone: nil,
                    scheduleAnchor: nil
                )
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([staleReloadTask], [], [], HomeFeature.DoneStats())) {
            $0.routineDisplays = [
                makeDisplay(
                    taskID: taskID,
                    name: "Working hours",
                    emoji: "✨",
                    interval: 30,
                    scheduleMode: .fixedIntervalChecklist,
                    lastDone: nil,
                    scheduleAnchor: nil,
                    daysUntilDue: 30,
                    isDoneToday: false,
                    checklistItemCount: 2,
                    completedChecklistItemCount: 0,
                    nextPendingChecklistItemTitle: "Sciforma"
                )
            ]
            $0.taskDetailState?.taskRefreshID = 1
            $0.taskDetailState?.daysSinceLastRoutine = 0
            $0.taskDetailState?.overdueDays = 0
            $0.taskDetailState?.isDoneToday = false
        }

        await store.receive(.taskDetail(.onAppear))
        await store.receive(.taskDetail(.availablePlacesLoaded([])))
        await store.receive(.taskDetail(.availableTagsLoaded([])))
        await store.receive(.taskDetail(.relatedTagRulesLoaded([])))
        await store.receive(.taskDetail(.availableRelationshipTasksLoaded([])))
        await store.receive(.taskDetail(.logsLoaded([])))
        await store.receive(.taskDetail(.attachmentsLoaded([])))
        await receiveTaskDetailNotificationStatus(store)

        #expect(store.state.routineTasks[0].lastDone == nil)
        #expect(store.state.taskDetailState?.task.lastDone == nil)
        #expect(store.state.taskDetailState?.isDoneToday == false)
        #expect(store.state.selectedTaskReloadGuard?.lastDone == nil)
    }

    @Test
    func tasksLoadedSuccessfully_clearsSelectedDetailWhenTaskDisappears() async {
        let context = makeInMemoryContext()
        let removedTask = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        let survivingTask = makeTask(in: context, name: "Stretch", interval: 3, lastDone: nil, emoji: "🤸")

        let initialState = HomeFeature.State(
            routineTasks: [removedTask],
            selectedTaskID: removedTask.id,
            taskDetailState: TaskDetailFeature.State(task: removedTask)
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([survivingTask], [], [], HomeFeature.DoneStats())) {
            $0.routineTasks = [survivingTask]
            $0.routineDisplays = [
                makeDisplay(
                    taskID: survivingTask.id,
                    name: "Stretch",
                    emoji: "🤸",
                    interval: 3,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
            $0.selectedTaskID = nil
            $0.taskDetailState = nil
        }

        #expect(store.state.routineTasks == [survivingTask])
        #expect(store.state.selectedTaskID == nil)
        #expect(store.state.taskDetailState == nil)
    }

    @Test
    func tasksLoadedSuccessfully_mapsDisplayWithFallbacksAndDoneToday() async throws {
        let context = makeInMemoryContext()
        let today = makeDate("2026-03-18T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: nil,
            interval: 0,
            lastDone: today,
            emoji: "",
            tags: ["Focus"]
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.calendar = calendar
            $0.date.now = today
        }

        await store.send(.tasksLoadedSuccessfully([task], [], [], HomeFeature.DoneStats(totalCount: 3, countsByTaskID: [task.id: 3]))) {
            $0.routineTasks = [task]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 3, countsByTaskID: [task.id: 3])
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Unnamed task", emoji: "✨", tags: ["Focus"], interval: 1, lastDone: today, isDoneToday: true, doneCount: 3)
            ]
        }

        #expect(store.state.routineTasks.count == 1)
        #expect(store.state.routineDisplays.count == 1)
        #expect(store.state.doneStats.totalCount == 3)

        let display = try #require(store.state.routineDisplays.first)
        #expect(display.name == "Unnamed task")
        #expect(display.emoji == "✨")
        #expect(display.interval == 1)
        #expect(display.isDoneToday)
        #expect(display.doneCount == 3)
        #expect(display.tags == ["Focus"])
    }

    @Test
    func tasksLoadedSuccessfully_updatesOpenAddRoutineValidation() async {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")

        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(
                basics: AddRoutineBasicsState(routineName: "read"),
                organization: AddRoutineOrganizationState()
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task], [], [], HomeFeature.DoneStats())) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Read", emoji: "📚", interval: 1, lastDone: nil, isDoneToday: false)
            ]
        }
        await store.receive(.addRoutineSheet(.existingRoutineNamesChanged(["Read"]))) {
            $0.addRoutineState?.organization.existingRoutineNames = ["Read"]
            $0.addRoutineState?.organization.nameValidationMessage = "A task with this name already exists."
        }
        await store.receive(.addRoutineSheet(.availableTagSummariesChanged([])))
        await store.receive(.addRoutineSheet(.availablePlacesChanged([])))
        await store.receive(.addRoutineSheet(.availableRelationshipTasksChanged([
            RoutineTaskRelationshipCandidate(
                id: task.id,
                name: "Read",
                emoji: "📚",
                relationships: []
            )
        ]))) {
            $0.addRoutineState?.organization.availableRelationshipTasks = [
                RoutineTaskRelationshipCandidate(
                    id: task.id,
                    name: "Read",
                    emoji: "📚",
                    relationships: []
                )
            ]
        }
    }

    @Test
    func tasksLoadedSuccessfully_separatesArchivedRoutines() async {
        let context = makeInMemoryContext()
        let pauseDate = makeDate("2026-03-12T10:00:00Z")
        let anchorDate = makeDate("2026-03-10T10:00:00Z")
        let activeTask = makeTask(
            in: context,
            name: "Read",
            interval: 2,
            lastDone: nil,
            emoji: "📚",
            scheduleAnchor: anchorDate
        )
        let archivedTask = makeTask(
            in: context,
            name: "Stretch",
            interval: 3,
            lastDone: nil,
            emoji: "🤸",
            scheduleAnchor: anchorDate,
            pausedAt: pauseDate
        )

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([activeTask, archivedTask], [], [], HomeFeature.DoneStats())) {
            $0.routineTasks = [activeTask, archivedTask]
            $0.routineDisplays = [
                makeDisplay(
                    taskID: activeTask.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 2,
                    lastDone: nil,
                    scheduleAnchor: anchorDate,
                    daysUntilDue: -8,
                    isDoneToday: false
                )
            ]
            $0.archivedRoutineDisplays = [
                makeDisplay(
                    taskID: archivedTask.id,
                    name: "Stretch",
                    emoji: "🤸",
                    interval: 3,
                    lastDone: nil,
                    scheduleAnchor: anchorDate,
                    pausedAt: pauseDate,
                    isDoneToday: false,
                    isPaused: true
                )
            ]
        }
    }

    @Test
    func tasksLoadedSuccessfully_placesAwayRoutineIntoAwaySectionWhenOutsideSavedPlace() async {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home", latitude: 52.52, longitude: 13.405, radiusMeters: 100)
        let task = makeTask(
            in: context,
            name: "Wash Bedsheets",
            interval: 7,
            lastDone: nil,
            emoji: "🛏️",
            placeID: home.id
        )

        let initialState = HomeFeature.State(
            locationSnapshot: LocationSnapshot(
                authorizationStatus: .authorizedWhenInUse,
                coordinate: LocationCoordinate(latitude: 48.1374, longitude: 11.5755),
                horizontalAccuracy: 25,
                timestamp: Date()
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task], [home], [], HomeFeature.DoneStats())) {
            $0.routineTasks = [task]
            $0.routinePlaces = [home]
            $0.awayRoutineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Wash Bedsheets",
                    emoji: "🛏️",
                    placeID: home.id,
                    placeName: "Home",
                    locationAvailability: .away(placeName: "Home", distanceMeters: home.distance(to: LocationCoordinate(latitude: 48.1374, longitude: 11.5755))),
                    interval: 7,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }
    }

    @Test
    func tasksLoadedSuccessfully_keepsPlaceRoutineVisibleWhenLocationIsUnavailable() async {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home")
        let task = makeTask(
            in: context,
            name: "Laundry",
            interval: 7,
            lastDone: nil,
            emoji: "🧺",
            placeID: home.id
        )

        let initialState = HomeFeature.State(
            locationSnapshot: LocationSnapshot(
                authorizationStatus: .denied,
                coordinate: nil,
                horizontalAccuracy: nil,
                timestamp: nil
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task], [home], [], HomeFeature.DoneStats())) {
            $0.routineTasks = [task]
            $0.routinePlaces = [home]
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Laundry",
                    emoji: "🧺",
                    placeID: home.id,
                    placeName: "Home",
                    locationAvailability: .unknown(placeName: "Home"),
                    interval: 7,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }
    }

    @Test
    func tasksLoadedSuccessfully_marksPlaceRoutineAvailableWhenInsideSavedPlace() async {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home", latitude: 52.52, longitude: 13.405, radiusMeters: 150)
        let task = makeTask(
            in: context,
            name: "Wash Bedsheets",
            interval: 7,
            lastDone: nil,
            emoji: "🛏️",
            placeID: home.id
        )

        let initialState = HomeFeature.State(
            locationSnapshot: LocationSnapshot(
                authorizationStatus: .authorizedWhenInUse,
                coordinate: LocationCoordinate(latitude: 52.5203, longitude: 13.4049),
                horizontalAccuracy: 20,
                timestamp: Date()
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.tasksLoadedSuccessfully([task], [home], [], HomeFeature.DoneStats())) {
            $0.routineTasks = [task]
            $0.routinePlaces = [home]
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Wash Bedsheets",
                    emoji: "🛏️",
                    placeID: home.id,
                    placeName: "Home",
                    locationAvailability: .available(placeName: "Home"),
                    interval: 7,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }
    }

    @Test
    func availableTags_deduplicatesAndSortsAcrossRoutines() {
        let displays = [
            makeDisplay(taskID: UUID(), name: "Read", emoji: "📚", tags: ["Focus", "Learning"], interval: 1, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Run", emoji: "🏃", tags: ["health", "focus"], interval: 2, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Sleep", emoji: "😴", tags: [], interval: 1, lastDone: nil, isDoneToday: false)
        ]

        #expect(HomeFeature.availableTags(from: displays) == ["Focus", "health", "Learning"])
    }

    @Test
    func tagSummaries_countsAndSortsByLinkedRoutineCount() {
        let displays = [
            makeDisplay(taskID: UUID(), name: "Read", emoji: "📚", tags: ["Focus", "Learning"], interval: 1, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Run", emoji: "🏃", tags: ["health", "focus"], interval: 2, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Plan", emoji: "🗓️", tags: ["Learning"], interval: 3, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Shop", emoji: "🛒", tags: ["Errands"], interval: 1, lastDone: nil, isDoneToday: false)
        ]

        let summaries = HomeFeature.tagSummaries(from: displays)

        #expect(summaries.map(\.name) == ["Focus", "Learning", "Errands", "health"])
        #expect(summaries.map(\.linkedRoutineCount) == [2, 2, 1, 1])
        #expect(HomeFeature.availableTags(from: displays) == ["Focus", "Learning", "Errands", "health"])
    }

    @Test
    func placeLinkedCounts_respectsTaskListMode() {
        let homeID = UUID()
        let officeID = UUID()
        let displays = [
            makeDisplay(taskID: UUID(), name: "Laundry", emoji: "🧺", placeID: homeID, interval: 7, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Buy soap", emoji: "🧼", placeID: homeID, interval: 1, scheduleMode: .oneOff, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Plan sprint", emoji: "🗓️", placeID: officeID, interval: 1, scheduleMode: .oneOff, lastDone: nil, isDoneToday: false),
            makeDisplay(taskID: UUID(), name: "Read", emoji: "📚", interval: 1, lastDone: nil, isDoneToday: false)
        ]

        #expect(HomeFeature.placeLinkedCounts(from: displays, taskListMode: .all) == [homeID: 2, officeID: 1])
        #expect(HomeFeature.placeLinkedCounts(from: displays, taskListMode: .routines) == [homeID: 1])
        #expect(HomeFeature.placeLinkedCounts(from: displays, taskListMode: .todos) == [homeID: 1, officeID: 1])
    }

    @Test
    func addRoutineSheetCancel_closesSheet() async {
        let context = makeInMemoryContext()
        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(existingRoutineNames: [])
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.addRoutineSheet(.delegate(.didCancel))) {
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
        }
    }

    @Test
    func routineSavedSuccessfully_appendsTaskAndSchedulesNotification() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(in: context, name: "Walk", interval: 2, lastDone: nil, emoji: "🚶", tags: ["Outdoors", "Health"])
        let scheduledIDs = LockIsolated<[String]>([])

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.routineSavedSuccessfully(task)) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Walk", emoji: "🚶", tags: ["Outdoors", "Health"], interval: 2, lastDone: nil, isDoneToday: false)
            ]
        }

        #expect(store.state.routineTasks.count == 1)
        #expect(store.state.routineDisplays.count == 1)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func routineSavedSuccessfully_closesAddRoutineSheet() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(in: context, name: "Walk", interval: 2, lastDone: nil, emoji: "🚶")

        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(
                basics: AddRoutineBasicsState(routineName: "Walk"),
                organization: AddRoutineOrganizationState()
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.routineSavedSuccessfully(task)) {
            $0.routineTasks = [task]
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Walk", emoji: "🚶", interval: 2, lastDone: nil, isDoneToday: false)
            ]
            $0.isAddRoutineSheetPresented = false
            $0.addRoutineState = nil
        }
    }

    @Test
    func deleteTasks_removesMatchingIDsFromState() async {
        let context = makeInMemoryContext()
        let task1 = makeTask(in: context, name: "A", interval: 1, lastDone: nil, emoji: "🅰️")
        let task2 = makeTask(in: context, name: "B", interval: 2, lastDone: nil, emoji: "🅱️")

        let initialState = HomeFeature.State(
            routineTasks: [task1, task2],
            routineDisplays: [
                makeDisplay(taskID: task1.id, name: "A", emoji: "🅰️", interval: 1, lastDone: nil, isDoneToday: false, doneCount: 2),
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ],
            doneStats: HomeFeature.DoneStats(totalCount: 3, countsByTaskID: [task1.id: 2, task2.id: 1]),
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.deleteTasks([task1.id])) {
            $0.routineTasks = [task2]
            $0.routineDisplays = [
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task2.id: 1])
        }
    }

    @Test
    func deleteTasksTapped_presentsConfirmationAndStoresPendingIDs() async {
        let taskID = UUID()

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.deleteTasksTapped([taskID])) {
            $0.pendingDeleteTaskIDs = [taskID]
            $0.isDeleteConfirmationPresented = true
        }
    }

    @Test
    func setDeleteConfirmation_false_clearsPendingDeletion() async {
        let taskID = UUID()

        let store = TestStore(
            initialState: HomeFeature.State(
                pendingDeleteTaskIDs: [taskID],
                isDeleteConfirmationPresented: true
            )
        ) {
            HomeFeature()
        }

        await store.send(.setDeleteConfirmation(false)) {
            $0.pendingDeleteTaskIDs = []
            $0.isDeleteConfirmationPresented = false
        }
    }

    @Test
    func deleteTasksConfirmed_removesPendingIDsFromState() async {
        let context = makeInMemoryContext()
        let task1 = makeTask(in: context, name: "A", interval: 1, lastDone: nil, emoji: "🅰️")
        let task2 = makeTask(in: context, name: "B", interval: 2, lastDone: nil, emoji: "🅱️")

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [task1, task2],
                routineDisplays: [
                    makeDisplay(taskID: task1.id, name: "A", emoji: "🅰️", interval: 1, lastDone: nil, isDoneToday: false, doneCount: 2),
                    makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
                ],
                doneStats: HomeFeature.DoneStats(totalCount: 3, countsByTaskID: [task1.id: 2, task2.id: 1]),
                pendingDeleteTaskIDs: [task1.id],
                isDeleteConfirmationPresented: true
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.deleteTasksConfirmed) {
            $0.routineTasks = [task2]
            $0.routineDisplays = [
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task2.id: 1])
            $0.pendingDeleteTaskIDs = []
            $0.isDeleteConfirmationPresented = false
        }
    }

    @Test
    func deleteTasks_removesAssociatedLogsFromPersistence() async throws {
        let context = makeInMemoryContext()
        let task1 = makeTask(in: context, name: "A", interval: 1, lastDone: nil, emoji: "🅰️")
        let task2 = makeTask(in: context, name: "B", interval: 2, lastDone: nil, emoji: "🅱️")
        _ = makeLog(in: context, task: task1, timestamp: Date())
        _ = makeLog(in: context, task: task2, timestamp: Date())
        try context.save()

        let initialState = HomeFeature.State(
            routineTasks: [task1, task2],
            routineDisplays: [
                makeDisplay(taskID: task1.id, name: "A", emoji: "🅰️", interval: 1, lastDone: nil, isDoneToday: false, doneCount: 1),
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ],
            doneStats: HomeFeature.DoneStats(totalCount: 2, countsByTaskID: [task1.id: 1, task2.id: 1]),
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { _ in }
        }

        await store.send(.deleteTasks([task1.id])) {
            $0.routineTasks = [task2]
            $0.routineDisplays = [
                makeDisplay(taskID: task2.id, name: "B", emoji: "🅱️", interval: 2, lastDone: nil, isDoneToday: false, doneCount: 1)
            ]
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task2.id: 1])
        }

        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingLogs.count == 1)
        #expect(remainingLogs.first?.taskID == task2.id)
    }

    @Test
    func pauseTask_movesRoutineToArchivedAndCancelsNotification() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-14T10:00:00Z")
        let anchorDate = makeDate("2026-03-12T10:00:00Z")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 3,
            lastDone: nil,
            emoji: "📚",
            scheduleAnchor: anchorDate
        )
        try context.save()

        let canceledIDs = LockIsolated<[String]>([])
        let initialState = HomeFeature.State(
            routineTasks: [task],
            routineDisplays: [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 3,
                    lastDone: nil,
                    scheduleAnchor: anchorDate,
                    isDoneToday: false
                )
            ]
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now)
            $0.modelContext = { context }
            $0.date.now = now
            $0.notificationClient.schedule = { _ in }
            $0.notificationClient.cancel = { identifier in
                canceledIDs.withValue { $0.append(identifier) }
            }
        }

        await store.send(.pauseTask(task.id)) {
            $0.routineTasks[0].pausedAt = now
            $0.routineDisplays = []
            $0.archivedRoutineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 3,
                    lastDone: nil,
                    scheduleAnchor: anchorDate,
                    pausedAt: now,
                    isDoneToday: false,
                    isPaused: true
                )
            ]
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pausedAt == now)
        #expect(canceledIDs.value == [task.id.uuidString])
    }

    @Test
    func resumeTask_movesRoutineBackToActiveAndSchedulesNotification() async throws {
        let context = makeInMemoryContext()
        let pauseDate = makeDate("2026-03-10T10:00:00Z")
        let resumeDate = makeDate("2026-03-14T10:00:00Z")
        let anchorDate = makeDate("2026-03-05T10:00:00Z")
        let expectedAnchor = anchorDate.addingTimeInterval(resumeDate.timeIntervalSince(pauseDate))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(
            in: context,
            name: "Stretch",
            interval: 4,
            lastDone: nil,
            emoji: "🤸",
            scheduleAnchor: anchorDate,
            pausedAt: pauseDate
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let initialState = HomeFeature.State(
            routineTasks: [task],
            archivedRoutineDisplays: [
                makeDisplay(
                    taskID: task.id,
                    name: "Stretch",
                    emoji: "🤸",
                    interval: 4,
                    lastDone: nil,
                    scheduleAnchor: anchorDate,
                    pausedAt: pauseDate,
                    isDoneToday: false,
                    isPaused: true
                )
            ]
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: resumeDate, calendar: calendar)
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = resumeDate
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.resumeTask(task.id)) {
            $0.routineTasks[0].scheduleAnchor = expectedAnchor
            $0.routineTasks[0].pausedAt = nil
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Stretch",
                    emoji: "🤸",
                    interval: 4,
                    lastDone: nil,
                    scheduleAnchor: expectedAnchor,
                    daysUntilDue: -1,
                    isDoneToday: false
                )
            ]
            $0.archivedRoutineDisplays = []
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pausedAt == nil)
        #expect(savedTask.scheduleAnchor == expectedAnchor)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func notTodayTask_movesRoutineToArchivedForTodayAndSchedulesTomorrowReminder() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-14T10:00:00Z")
        let tomorrowStart = makeDate("2026-03-15T00:00:00Z")
        let anchorDate = makeDate("2026-03-12T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 3,
            lastDone: nil,
            emoji: "📚",
            scheduleAnchor: anchorDate
        )
        try context.save()

        let scheduledIDs = LockIsolated<[String]>([])
        let initialState = HomeFeature.State(
            routineTasks: [task],
            routineDisplays: [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 3,
                    lastDone: nil,
                    scheduleAnchor: anchorDate,
                    isDoneToday: false
                )
            ]
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
        }

        await store.send(.notTodayTask(task.id)) {
            $0.routineTasks[0].snoozedUntil = tomorrowStart
            $0.routineDisplays = []
            $0.archivedRoutineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 3,
                    lastDone: nil,
                    scheduleAnchor: anchorDate,
                    snoozedUntil: tomorrowStart,
                    isDoneToday: false,
                    isPaused: true
                )
            ]
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pausedAt == nil)
        #expect(savedTask.snoozedUntil == tomorrowStart)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func pinTask_marksRoutinePinnedAndPersists() async throws {
        let context = makeInMemoryContext()
        let pinDate = makeDate("2026-03-15T10:00:00Z")
        let task = makeTask(in: context, name: "Read", interval: 3, lastDone: nil, emoji: "📚")
        try context.save()

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [task]
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: pinDate)
            $0.modelContext = { context }
            $0.date.now = pinDate
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.pinTask(task.id)) {
            $0.routineTasks[0].pinnedAt = pinDate
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 3,
                    lastDone: nil,
                    pinnedAt: pinDate,
                    isDoneToday: false
                )
            ]
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pinnedAt == pinDate)
    }

    @Test
    func unpinTask_clearsPinnedStateAndPersists() async throws {
        let context = makeInMemoryContext()
        let pinDate = makeDate("2026-03-15T10:00:00Z")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 3,
            lastDone: nil,
            emoji: "📚",
            pinnedAt: pinDate
        )
        try context.save()

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [task],
                routineDisplays: [
                    makeDisplay(
                        taskID: task.id,
                        name: "Read",
                        emoji: "📚",
                        interval: 3,
                        lastDone: nil,
                        pinnedAt: pinDate,
                        isDoneToday: false
                    )
                ]
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: makeDate("2026-03-16T10:00:00Z"))
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.unpinTask(task.id)) {
            $0.routineTasks[0].pinnedAt = nil
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Read",
                    emoji: "📚",
                    interval: 3,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(savedTask.pinnedAt == nil)
    }

    @Test
    func markTaskDone_updatesStateAndPersistsLog() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 3, lastDone: nil, emoji: "📚")
        try context.save()

        let now = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let scheduledIDs = LockIsolated<[String]>([])

        let initialState = HomeFeature.State(
            routineTasks: [task],
            routineDisplays: [
                makeDisplay(taskID: task.id, name: "Read", emoji: "📚", interval: 3, lastDone: nil, isDoneToday: false)
            ],
            doneStats: HomeFeature.DoneStats(),
            isAddRoutineSheetPresented: false,
            addRoutineState: nil
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { payload in
                scheduledIDs.withValue { $0.append(payload.identifier) }
            }
            $0.calendar = calendar
            $0.date.now = now
        }

        await store.send(.markTaskDone(task.id)) {
            $0.routineTasks[0].lastDone = now
            $0.routineTasks[0].scheduleAnchor = now
            $0.routineDisplays[0].lastDone = now
            $0.routineDisplays[0].scheduleAnchor = now
            $0.routineDisplays[0].isDoneToday = true
            $0.routineDisplays[0].doneCount = 1
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task.id: 1])
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        #expect(savedTask.lastDone == now)
        #expect(savedTask.scheduleAnchor == now)
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(scheduledIDs.value == [task.id.uuidString])
    }

    @Test
    func markTaskDone_forOneOffTaskRemovesItFromListsAndCancelsNotification() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let task = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🥛",
            scheduleMode: .oneOff
        )
        try context.save()

        let canceledIDs = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [task],
                routineDisplays: [
                    makeDisplay(
                        taskID: task.id,
                        name: "Buy milk",
                        emoji: "🥛",
                        interval: 1,
                        scheduleMode: .oneOff,
                        lastDone: nil,
                        daysUntilDue: 0,
                        isOneOffTask: true,
                        isDoneToday: false
                    )
                ]
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now, calendar: calendar)
            $0.modelContext = { context }
            $0.calendar = calendar
            $0.date.now = now
            $0.notificationClient.cancel = { identifier in
                canceledIDs.withValue { $0.append(identifier) }
            }
        }

        await store.send(.markTaskDone(task.id)) {
            $0.routineTasks[0].lastDone = now
            $0.routineTasks[0].scheduleAnchor = now
            $0.routineDisplays = []
            $0.archivedRoutineDisplays = []
            $0.boardTodoDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Buy milk",
                    emoji: "🥛",
                    interval: 1,
                    scheduleMode: .oneOff,
                    lastDone: now,
                    daysUntilDue: .max,
                    isOneOffTask: true,
                    isCompletedOneOff: true,
                    isDoneToday: true,
                    doneCount: 1
                )
            ]
            $0.boardTodoDisplays[0].todoState = .done
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task.id: 1])
        }

        let savedTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(savedTask.lastDone == now)
        #expect(savedTask.scheduleMode == .oneOff)
        #expect(logs.count == 1)
        #expect(canceledIDs.value == [task.id.uuidString])
    }

    @Test
    func detailLogs_returnsPersistedLogsForSelectedTaskSortedNewestFirst() throws {
        let context = makeInMemoryContext()
        let selectedTask = makeTask(in: context, name: "Selected", interval: 1, lastDone: nil, emoji: "✅")
        let otherTask = makeTask(in: context, name: "Other", interval: 1, lastDone: nil, emoji: "❌")
        let older = makeDate("2026-02-27T08:00:00Z")
        let newer = makeDate("2026-02-28T08:00:00Z")

        let olderLog = makeLog(in: context, task: selectedTask, timestamp: older)
        let newerLog = makeLog(in: context, task: selectedTask, timestamp: newer)
        _ = makeLog(in: context, task: otherTask, timestamp: newer)
        try context.save()

        let logs = HomeFeature.detailLogs(taskID: selectedTask.id, context: context)

        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.taskID == selectedTask.id })
        #expect(logs.first?.id == newerLog.id)
        #expect(logs.last?.id == olderLog.id)
    }

    @Test
    func markTaskDone_advancesStepRoutineWithoutCreatingCompletionLog() async throws {
        let context = makeInMemoryContext()
        let task = makeTask(
            in: context,
            name: "Laundry",
            interval: 2,
            lastDone: nil,
            emoji: "🧺",
            steps: [
                RoutineStep(title: "Wash clothes"),
                RoutineStep(title: "Hang on the line"),
                RoutineStep(title: "Put away")
            ]
        )
        try context.save()

        let firstNow = makeDate("2026-03-14T10:00:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [task],
                routineDisplays: [
                    makeDisplay(
                        taskID: task.id,
                        name: "Laundry",
                        emoji: "🧺",
                        steps: ["Wash clothes", "Hang on the line", "Put away"],
                        interval: 2,
                        lastDone: nil,
                        isDoneToday: false,
                        completedStepCount: 0,
                        isInProgress: false,
                        nextStepTitle: "Wash clothes"
                    )
                ],
                doneStats: HomeFeature.DoneStats()
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.calendar = calendar
            $0.date.now = firstNow
        }

        await store.send(.markTaskDone(task.id)) {
            $0.routineTasks[0].completedStepCount = 1
            $0.routineTasks[0].sequenceStartedAt = firstNow
            $0.routineDisplays[0].completedStepCount = 1
            $0.routineDisplays[0].isInProgress = true
            $0.routineDisplays[0].nextStepTitle = "Hang on the line"
        }

        let afterFirstLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        let afterFirstTask = try #require(try context.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(afterFirstLogs.isEmpty)
        #expect(afterFirstTask.completedStepCount == 1)
        #expect(afterFirstTask.lastDone == nil)
    }

    @Test
    func addRoutine_rejectsDuplicateName_caseInsensitiveAndTrimmed() async throws {
        let context = makeInMemoryContext()
        _ = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        try context.save()

        let initialState = HomeFeature.State(
            routineTasks: [],
            routineDisplays: [],
            isAddRoutineSheetPresented: true,
            addRoutineState: AddRoutineFeature.State(
                organization: AddRoutineOrganizationState(existingRoutineNames: [])
            )
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }

        await store.send(.addRoutineSheet(.delegate(.didSave(AddRoutineSaveRequest(
            name: "  read  ",
            frequencyInDays: 7,
            recurrenceRule: .interval(days: 7),
            emoji: "🔥",
            priority: .medium,
            importance: .level2,
            urgency: .level2,
            tags: ["Evening"],
            scheduleMode: .fixedInterval,
            color: .none
        )))))
        await store.receive(.routineSaveFailed)

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.name == "Read")
        #expect(store.state.isAddRoutineSheetPresented)
    }

    @Test
    func onAppear_enforcesUniqueNamesByRemovingDuplicates() async throws {
        let context = makeInMemoryContext()
        let first = makeTask(in: context, name: "Routine A", interval: 1, lastDone: nil, emoji: "🅰️")
        let duplicate = makeTask(in: context, name: "  routine a  ", interval: 3, lastDone: nil, emoji: "♻️")
        _ = makeLog(in: context, task: duplicate, timestamp: Date())
        try context.save()

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.locationClient.snapshot = { _ in
                try? await Task.sleep(nanoseconds: 20_000_000)
                return LocationSnapshot(
                    authorizationStatus: .notDetermined,
                    coordinate: nil,
                    horizontalAccuracy: nil,
                    timestamp: nil
                )
            }
        }

        await store.send(.onAppear)
        await store.receive { action in
            guard case let .tasksLoadedSuccessfully(tasks, places, logs, doneStats) = action else { return false }
            #expect(tasks.count == 1)
            #expect(places.isEmpty)
            #expect(logs.isEmpty)
            #expect(tasks.first?.id == first.id)
            #expect(doneStats.totalCount == 0)
            return true
        } assert: {
            $0.routineTasks = [first]
            $0.routineDisplays = [
                makeDisplay(taskID: first.id, name: "Routine A", emoji: "🅰️", interval: 1, lastDone: nil, isDoneToday: false)
            ]
        }
        await store.receive(.sprintBoardLoaded(SprintBoardData()))
        await store.receive(.locationSnapshotUpdated(
            LocationSnapshot(
                authorizationStatus: .notDetermined,
                coordinate: nil,
                horizontalAccuracy: nil,
                timestamp: nil
            )
        ))

        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let remainingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(remainingTasks.count == 1)
        #expect(remainingTasks.first?.id == first.id)
        #expect(remainingLogs.isEmpty)
    }

    @Test
    func onAppear_enforcesUniquePlaceNamesByMergingDuplicates() async throws {
        let context = makeInMemoryContext()
        let unlinkedPlace = RoutinePlace(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: " Home ",
            latitude: 52.5200,
            longitude: 13.4050,
            radiusMeters: 150,
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        let linkedPlace = RoutinePlace(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Home",
            latitude: 52.5200,
            longitude: 13.4050,
            radiusMeters: 150,
            createdAt: makeDate("2026-03-02T08:00:00Z")
        )
        context.insert(unlinkedPlace)
        context.insert(linkedPlace)

        let task = makeTask(
            in: context,
            name: "Laundry",
            interval: 3,
            lastDone: nil,
            emoji: "🧺",
            placeID: linkedPlace.id
        )
        try context.save()

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.locationClient.snapshot = { _ in
                try? await Task.sleep(nanoseconds: 20_000_000)
                return LocationSnapshot(
                    authorizationStatus: .notDetermined,
                    coordinate: nil,
                    horizontalAccuracy: nil,
                    timestamp: nil
                )
            }
        }

        await store.send(.onAppear)
        await store.receive { action in
            guard case let .tasksLoadedSuccessfully(tasks, places, logs, doneStats) = action else { return false }
            #expect(tasks.count == 1)
            #expect(places.count == 1)
            #expect(logs.isEmpty)
            #expect(tasks.first?.id == task.id)
            #expect(tasks.first?.placeID == linkedPlace.id)
            #expect(places.first?.id == linkedPlace.id)
            #expect(doneStats.totalCount == 0)
            return true
        } assert: {
            $0.routineTasks = [task]
            $0.routinePlaces = [linkedPlace]
            $0.routineDisplays = [
                makeDisplay(
                    taskID: task.id,
                    name: "Laundry",
                    emoji: "🧺",
                    placeID: linkedPlace.id,
                    placeName: "Home",
                    locationAvailability: .unknown(placeName: "Home"),
                    interval: 3,
                    lastDone: nil,
                    isDoneToday: false
                )
            ]
        }
        await store.receive(.sprintBoardLoaded(SprintBoardData()))
        await store.receive(.locationSnapshotUpdated(
            LocationSnapshot(
                authorizationStatus: .notDetermined,
                coordinate: nil,
                horizontalAccuracy: nil,
                timestamp: nil
            )
        ))

        let remainingPlaces = try context.fetch(FetchDescriptor<RoutinePlace>())
        let remainingTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(remainingPlaces.count == 1)
        #expect(remainingPlaces.first?.id == linkedPlace.id)
        #expect(remainingTasks.first?.placeID == linkedPlace.id)
    }

    @Test
    func onAppear_backfillsMissingLogFromLastDone() async throws {
        let context = makeInMemoryContext()
        let lastDone = makeDate("2026-03-14T10:00:00Z")
        let now = makeDate("2026-03-14T12:00:00Z")
        let task = makeTask(in: context, name: "Shave Beard", interval: 4, lastDone: lastDone, emoji: "💪")
        try context.save()

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
            $0.calendar = calendar
            $0.date.now = now
            $0.locationClient.snapshot = { _ in
                try? await Task.sleep(nanoseconds: 20_000_000)
                return LocationSnapshot(
                    authorizationStatus: .notDetermined,
                    coordinate: nil,
                    horizontalAccuracy: nil,
                    timestamp: nil
                )
            }
        }

        await store.send(.onAppear)
        await store.receive { action in
            guard case let .tasksLoadedSuccessfully(tasks, places, logs, doneStats) = action else { return false }
            #expect(tasks.count == 1)
            #expect(places.isEmpty)
            #expect(tasks.first?.id == task.id)
            #expect(logs.count == 1)
            #expect(logs.first?.taskID == task.id)
            #expect(doneStats.totalCount == 1)
            #expect(doneStats.countsByTaskID[task.id] == 1)
            return true
        } assert: {
            $0.routineTasks = [task]
            $0.timelineLogs = try! context.fetch(FetchDescriptor<RoutineLog>()).sorted {
                let lhs = $0.timestamp ?? .distantPast
                let rhs = $1.timestamp ?? .distantPast
                return lhs > rhs
            }
            $0.doneStats = HomeFeature.DoneStats(totalCount: 1, countsByTaskID: [task.id: 1])
            $0.routineDisplays = [
                makeDisplay(taskID: task.id, name: "Shave Beard", emoji: "💪", interval: 4, lastDone: lastDone, isDoneToday: true, doneCount: 1)
            ]
        }
        await store.receive(.sprintBoardLoaded(SprintBoardData()))
        await store.receive(.locationSnapshotUpdated(
            LocationSnapshot(
                authorizationStatus: .notDetermined,
                coordinate: nil,
                horizontalAccuracy: nil,
                timestamp: nil
            )
        ))

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == lastDone)
    }

    @Test
    func cloudKitMerge_skipsLogicalDuplicateLogsFromRefresh() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        let timestamp = makeDate("2026-03-15T08:00:00Z")
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        try context.save()

        let cloudLog = CKRecord(
            recordType: "RoutineLog",
            recordID: CKRecord.ID(recordName: UUID().uuidString)
        )
        cloudLog["taskID"] = task.id.uuidString as CKRecordValue
        cloudLog["timestamp"] = timestamp as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [cloudLog], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_removesExistingDuplicateLogsDuringRefresh() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Walk", interval: 1, lastDone: nil, emoji: "🚶")
        let timestamp = makeDate("2026-03-15T09:30:00Z")
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        _ = makeLog(in: context, task: task, timestamp: timestamp)
        try context.save()

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == task.id)
        #expect(logs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_sameNamedTaskRemapsLogsToExistingLocalTask() throws {
        let context = makeInMemoryContext()
        let localTask = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: "📚")
        try context.save()

        let remoteTaskID = UUID()
        let timestamp = makeDate("2026-03-14T08:00:00Z")

        let remoteLog = CKRecord(
            recordType: "RoutineLog",
            recordID: CKRecord.ID(recordName: UUID().uuidString)
        )
        remoteLog["taskID"] = remoteTaskID.uuidString as CKRecordValue
        remoteLog["timestamp"] = timestamp as CKRecordValue

        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: remoteTaskID.uuidString)
        )
        remoteTask["name"] = "Read" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 1)
        remoteTask["lastDone"] = timestamp as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remoteLog, remoteTask], deletedRecordIDs: []),
            into: context
        )

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.taskID == localTask.id)

        let localTaskID = localTask.id
        let refreshedTask = try #require(
            try context.fetch(
                FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == localTaskID
                    }
                )
            ).first
        )
        #expect(refreshedTask.lastDone == timestamp)

        let detailLogs = HomeFeature.detailLogs(taskID: localTask.id, context: context)
        #expect(detailLogs.count == 1)
        #expect(detailLogs.first?.taskID == localTask.id)
        #expect(detailLogs.first?.timestamp == timestamp)
    }

    @Test
    func cloudKitMerge_sameNamedPlaceReusesExistingLocalPlace() throws {
        let context = makeInMemoryContext()
        let localPlace = RoutinePlace(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Home",
            latitude: 52.5200,
            longitude: 13.4050,
            radiusMeters: 150,
            createdAt: makeDate("2026-03-01T08:00:00Z")
        )
        context.insert(localPlace)
        try context.save()

        let remotePlaceID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let remoteTaskID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!

        let remotePlace = CKRecord(
            recordType: "RoutinePlace",
            recordID: CKRecord.ID(recordName: remotePlaceID.uuidString)
        )
        remotePlace["name"] = " home " as CKRecordValue
        remotePlace["latitude"] = NSNumber(value: 52.5300)
        remotePlace["longitude"] = NSNumber(value: 13.4100)
        remotePlace["radiusMeters"] = NSNumber(value: 200)
        remotePlace["createdAt"] = makeDate("2026-03-03T08:00:00Z") as CKRecordValue

        let remoteTask = CKRecord(
            recordType: "RoutineTask",
            recordID: CKRecord.ID(recordName: remoteTaskID.uuidString)
        )
        remoteTask["name"] = "Stretch" as CKRecordValue
        remoteTask["interval"] = NSNumber(value: 1)
        remoteTask["placeID"] = remotePlaceID.uuidString as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remotePlace, remoteTask], deletedRecordIDs: []),
            into: context
        )

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        #expect(places.count == 1)
        #expect(places.first?.id == localPlace.id)
        #expect(places.first?.displayName == "Home")
        #expect(places.first?.radiusMeters == 200)

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.id == remoteTaskID)
        #expect(tasks.first?.placeID == localPlace.id)
    }

    // MARK: - taskListMode

    @Test
    func taskListMode_defaultsToTodos() {
        let state = HomeFeature.State()
        #expect(state.taskListMode == .todos)
    }

    @Test
    func taskListModeChanged_updatesMode() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
        }

        await store.send(.taskListModeChanged(.all)) {
            $0.taskListMode = .all
        }

        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
        }
    }

    @Test
    func taskListModeChanged_toTodos_clearsRoutineSelection() async {
        let context = makeInMemoryContext()
        let routine = makeTask(in: context, name: "Meditate", interval: 1, lastDone: nil, emoji: "🧘")
        let routineID = routine.id

        let initialState = HomeFeature.State(
            routineTasks: [routine],
            routineDisplays: [makeDisplay(taskID: routineID, name: "Meditate", emoji: "🧘",
                                          interval: 1, lastDone: nil, isOneOffTask: false,
                                          isDoneToday: false)],
            selectedTaskID: routineID
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
            $0.selectedTaskID = nil
            $0.taskDetailState = nil
        }
    }

    @Test
    func taskListModeChanged_toRoutines_clearsTodoSelection() async {
        let context = makeInMemoryContext()
        let todo = makeTask(in: context, name: "Buy milk", interval: 1, lastDone: nil, emoji: "🛒",
                            scheduleMode: .oneOff)
        let todoID = todo.id

        let initialState = HomeFeature.State(
            routineTasks: [todo],
            routineDisplays: [makeDisplay(taskID: todoID, name: "Buy milk", emoji: "🛒",
                                          interval: 1, scheduleMode: .oneOff, lastDone: nil,
                                          isOneOffTask: true, isDoneToday: false)],
            selectedTaskID: todoID,
            taskListMode: .todos
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            $0.selectedTaskID = nil
            $0.taskDetailState = nil
        }
    }

    @Test
    func taskListModeChanged_toTodos_keepsTodoSelection() async {
        let context = makeInMemoryContext()
        let todo = makeTask(in: context, name: "Buy milk", interval: 1, lastDone: nil, emoji: "🛒",
                            scheduleMode: .oneOff)
        let todoID = todo.id

        let initialState = HomeFeature.State(
            routineTasks: [todo],
            routineDisplays: [makeDisplay(taskID: todoID, name: "Buy milk", emoji: "🛒",
                                          interval: 1, scheduleMode: .oneOff, lastDone: nil,
                                          isOneOffTask: true, isDoneToday: false)],
            selectedTaskID: todoID,
            taskListMode: .routines
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.todos)) {
            $0.taskListMode = .todos
            // selectedTaskID unchanged — todo stays selected
        }
        #expect(store.state.selectedTaskID == todoID)
    }

    @Test
    func taskListModeChanged_toRoutines_keepsRoutineSelection() async {
        let context = makeInMemoryContext()
        let routine = makeTask(in: context, name: "Meditate", interval: 1, lastDone: nil, emoji: "🧘")
        let routineID = routine.id

        let initialState = HomeFeature.State(
            routineTasks: [routine],
            routineDisplays: [makeDisplay(taskID: routineID, name: "Meditate", emoji: "🧘",
                                          interval: 1, lastDone: nil, isOneOffTask: false,
                                          isDoneToday: false)],
            selectedTaskID: routineID,
            taskListMode: .todos
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            // selectedTaskID unchanged — routine stays selected
        }
        #expect(store.state.selectedTaskID == routineID)
    }

    @Test
    func taskListModeChanged_withNoSelection_onlyUpdatesMode() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            // no selection to clear — everything else stays the same
        }
    }

    @Test
    func taskListModeChanged_toAll_keepsCurrentSelection() async {
        let context = makeInMemoryContext()
        let todo = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🛒",
            scheduleMode: .oneOff
        )
        let todoID = todo.id

        let initialState = HomeFeature.State(
            routineTasks: [todo],
            routineDisplays: [
                makeDisplay(
                    taskID: todoID,
                    name: "Buy milk",
                    emoji: "🛒",
                    interval: 1,
                    scheduleMode: .oneOff,
                    lastDone: nil,
                    isOneOffTask: true,
                    isDoneToday: false
                )
            ],
            selectedTaskID: todoID,
            taskListMode: .todos
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.all)) {
            $0.taskListMode = .all
        }

        #expect(store.state.selectedTaskID == todoID)
    }

    @Test
    func taskListModeChanged_toAll_restoresSavedSnapshot() async {
        let context = makeInMemoryContext()
        let todoPlaceID = UUID()
        let allPlaceID = UUID()

        let initialState = HomeFeature.State(
            taskListMode: .todos,
            selectedFilter: .due,
            selectedTag: "Errands",
            excludedTags: ["Home"],
            selectedManualPlaceFilterID: todoPlaceID,
            tabFilterSnapshots: [
                HomeFeature.TaskListMode.all.rawValue: TabFilterStateManager.Snapshot(
                    selectedTag: "Focus",
                    excludedTags: ["Work"],
                    selectedFilter: .doneToday,
                    selectedManualPlaceFilterID: allPlaceID
                )
            ]
        )

        let store = TestStore(initialState: initialState) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.all)) {
            $0.taskListMode = .all
            $0.selectedFilter = .doneToday
            $0.selectedTag = "Focus"
            $0.excludedTags = ["Work"]
            $0.selectedManualPlaceFilterID = allPlaceID
            $0.tabFilterSnapshots[HomeFeature.TaskListMode.todos.rawValue] = TabFilterStateManager.Snapshot(
                selectedTag: "Errands",
                excludedTags: ["Home"],
                selectedFilter: .due,
                selectedManualPlaceFilterID: todoPlaceID
            )
        }
    }

    @Test
    func macSidebarSelectionChanged_selectingTodoFromAllKeepsAllMode() async {
        let context = makeInMemoryContext()
        let todo = makeTask(
            in: context,
            name: "Buy milk",
            interval: 1,
            lastDone: nil,
            emoji: "🛒",
            scheduleMode: .oneOff
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [todo],
                taskListMode: .all,
                macSidebarMode: .routines
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.macSidebarSelectionChanged(.task(todo.id))) {
            $0.macSidebarSelection = .task(todo.id)
        }
        await store.receive(.setSelectedTask(todo.id))

        #expect(store.state.taskListMode == .all)
        #expect(store.state.selectedTaskID == todo.id)
    }

    @Test
    func macSidebarSelectionChanged_selectingRoutineFromAllKeepsAllMode() async {
        let context = makeInMemoryContext()
        let routine = makeTask(
            in: context,
            name: "Meditate",
            interval: 1,
            lastDone: nil,
            emoji: "🧘"
        )

        let store = TestStore(
            initialState: HomeFeature.State(
                routineTasks: [routine],
                taskListMode: .all,
                macSidebarMode: .routines
            )
        ) {
            HomeFeature()
        } withDependencies: {
            setTestDateDependencies(&$0)
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.macSidebarSelectionChanged(.task(routine.id))) {
            $0.macSidebarSelection = .task(routine.id)
        }
        await store.receive(.setSelectedTask(routine.id))

        #expect(store.state.taskListMode == .all)
        #expect(store.state.selectedTaskID == routine.id)
    }

    @Test
    func taskListModeChanged_hidesMacFilterDetail() async {
        let context = makeInMemoryContext()
        let store = TestStore(
            initialState: HomeFeature.State(isMacFilterDetailPresented: true)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.notificationClient.schedule = { _ in }
        }
        store.exhaustivity = .off

        await store.send(.taskListModeChanged(.routines)) {
            $0.taskListMode = .routines
            $0.isMacFilterDetailPresented = false
        }
    }
}

@MainActor
private func receiveTaskDetailNotificationStatus(
    _ store: TestStoreOf<HomeFeature>
) async {
    let isAlreadyLoaded = store.state.taskDetailState?.hasLoadedNotificationStatus == true
        && store.state.taskDetailState?.appNotificationsEnabled == false
        && store.state.taskDetailState?.systemNotificationsAuthorized == false
    if isAlreadyLoaded {
        await store.receive(.taskDetail(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false)))
    } else {
        await store.receive(.taskDetail(.notificationStatusLoaded(appEnabled: false, systemAuthorized: false))) {
            $0.taskDetailState?.hasLoadedNotificationStatus = true
            $0.taskDetailState?.appNotificationsEnabled = false
            $0.taskDetailState?.systemNotificationsAuthorized = false
        }
    }
}

private func makeDisplay(
    taskID: UUID,
    name: String,
    emoji: String,
    placeID: UUID? = nil,
    placeName: String? = nil,
    locationAvailability: RoutineLocationAvailability = .unrestricted,
    tags: [String] = [],
    steps: [String] = [],
    interval: Int,
    recurrenceRule: RoutineRecurrenceRule? = nil,
    scheduleMode: RoutineScheduleMode = .fixedInterval,
    lastDone: Date?,
    canceledAt: Date? = nil,
    dueDate: Date? = nil,
    priority: RoutineTaskPriority = .none,
    importance: RoutineTaskImportance = .level2,
    urgency: RoutineTaskUrgency = .level2,
    scheduleAnchor: Date? = nil,
    pausedAt: Date? = nil,
    snoozedUntil: Date? = nil,
    pinnedAt: Date? = nil,
    daysUntilDue: Int? = nil,
    isOneOffTask: Bool = false,
    isCompletedOneOff: Bool = false,
    isCanceledOneOff: Bool = false,
    isDoneToday: Bool,
    isPaused: Bool = false,
    completedStepCount: Int = 0,
    isInProgress: Bool = false,
    nextStepTitle: String? = nil,
    checklistItemCount: Int = 0,
    completedChecklistItemCount: Int = 0,
    dueChecklistItemCount: Int = 0,
    nextPendingChecklistItemTitle: String? = nil,
    nextDueChecklistItemTitle: String? = nil,
    doneCount: Int = 0,
    assignedSprintID: UUID? = nil,
    assignedSprintTitle: String? = nil
) -> HomeFeature.RoutineDisplay {
    let resolvedScheduleAnchor = scheduleAnchor ?? lastDone
    let resolvedIsPaused = isPaused || pausedAt != nil || snoozedUntil != nil
    let resolvedIsOneOffTask = isOneOffTask || scheduleMode == .oneOff
    let resolvedIsCompletedOneOff = isCompletedOneOff || (resolvedIsOneOffTask && lastDone != nil && !isInProgress)
    let resolvedDaysUntilDue = daysUntilDue ?? (resolvedIsPaused ? 0 : ((resolvedIsCompletedOneOff || isCanceledOneOff) ? Int.max : interval))
    let resolvedRecurrenceRule = recurrenceRule ?? .interval(days: interval)
    return HomeFeature.RoutineDisplay(
        taskID: taskID,
        name: name,
        emoji: emoji,
        notes: nil,
        hasImage: false,
        placeID: placeID,
        placeName: placeName,
        locationAvailability: locationAvailability,
        tags: tags,
        steps: steps,
        interval: interval,
        recurrenceRule: resolvedRecurrenceRule,
        scheduleMode: scheduleMode,
        isSoftIntervalRoutine: scheduleMode == .softInterval,
        lastDone: lastDone,
        canceledAt: canceledAt,
        dueDate: dueDate,
        priority: priority,
        importance: importance,
        urgency: urgency,
        scheduleAnchor: resolvedScheduleAnchor,
        pausedAt: pausedAt,
        snoozedUntil: snoozedUntil,
        pinnedAt: pinnedAt,
        daysUntilDue: resolvedDaysUntilDue,
        isOneOffTask: resolvedIsOneOffTask,
        isCompletedOneOff: resolvedIsCompletedOneOff,
        isCanceledOneOff: isCanceledOneOff,
        isDoneToday: isDoneToday,
        isPaused: resolvedIsPaused,
        isSnoozed: snoozedUntil != nil,
        isPinned: pinnedAt != nil,
        isOngoing: false,
        ongoingSince: nil,
        hasPassedSoftThreshold: false,
        completedStepCount: completedStepCount,
        isInProgress: isInProgress,
        nextStepTitle: nextStepTitle,
        checklistItemCount: checklistItemCount,
        completedChecklistItemCount: completedChecklistItemCount,
        dueChecklistItemCount: dueChecklistItemCount,
        nextPendingChecklistItemTitle: nextPendingChecklistItemTitle,
        nextDueChecklistItemTitle: nextDueChecklistItemTitle,
        doneCount: doneCount,
        assignedSprintID: assignedSprintID,
        assignedSprintTitle: assignedSprintTitle
    )
}
