import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
    enum MoveDirection: String, Equatable {
        case up
        case down
    }

    enum TaskListMode: String, CaseIterable, Equatable, Identifiable {
        case all = "All"
        case routines = "Routines"
        case todos = "Todos"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .all: return "square.stack.3d.up"
            case .routines: return "repeat"
            case .todos: return "checklist"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .all: return "Show all tasks"
            case .routines: return "Show routines"
            case .todos: return "Show todos"
            }
        }
    }

    struct SelectedTaskReloadGuard: Equatable {
        var taskID: UUID
        var completedChecklistItemIDsStorage: String
        var lastDone: Date?
        var scheduleAnchor: Date?
    }

    struct DoneStats: Equatable {
        var totalCount: Int = 0
        var countsByTaskID: [UUID: Int] = [:]
        var canceledTotalCount: Int = 0
        var canceledCountsByTaskID: [UUID: Int] = [:]
    }

    struct RoutineDisplay: Equatable, Identifiable {
        let taskID: UUID
        var id: UUID { taskID }
        var name: String
        var emoji: String
        var notes: String?
        var hasImage: Bool
        var placeID: UUID?
        var placeName: String?
        var locationAvailability: RoutineLocationAvailability
        var tags: [String]
        var steps: [String]
        var interval: Int
        var recurrenceRule: RoutineRecurrenceRule
        var scheduleMode: RoutineScheduleMode
        var lastDone: Date?
        var canceledAt: Date?
        var dueDate: Date?
        var priority: RoutineTaskPriority
        var importance: RoutineTaskImportance
        var urgency: RoutineTaskUrgency
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var pinnedAt: Date?
        var daysUntilDue: Int
        var isOneOffTask: Bool
        var isCompletedOneOff: Bool
        var isCanceledOneOff: Bool
        var isDoneToday: Bool
        var isPaused: Bool
        var isSnoozed: Bool
        var isPinned: Bool
        var completedStepCount: Int
        var isInProgress: Bool
        var nextStepTitle: String?
        var checklistItemCount: Int
        var completedChecklistItemCount: Int
        var dueChecklistItemCount: Int
        var nextPendingChecklistItemTitle: String?
        var nextDueChecklistItemTitle: String?
        var doneCount: Int
        var manualSectionOrders: [String: Int] = [:]
        var color: RoutineTaskColor = .none
        var todoState: TodoState? = nil
    }

    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routinePlaces: [RoutinePlace] = []
        var timelineLogs: [RoutineLog] = []
        var routineDisplays: [RoutineDisplay] = []
        var awayRoutineDisplays: [RoutineDisplay] = []
        var archivedRoutineDisplays: [RoutineDisplay] = []
        var doneStats: DoneStats = DoneStats()
        var selectedTaskID: UUID?
        var isAddRoutineSheetPresented: Bool = false
        var locationSnapshot = LocationSnapshot(
            authorizationStatus: .notDetermined,
            coordinate: nil,
            horizontalAccuracy: nil,
            timestamp: nil
        )
        var hideUnavailableRoutines: Bool = false
        var addRoutineState: AddRoutineFeature.State?
        var taskDetailState: TaskDetailFeature.State?
        var selectedTaskReloadGuard: SelectedTaskReloadGuard?
        var pendingSelectedChecklistReloadGuardTaskID: UUID?
        var pendingDeleteTaskIDs: [UUID] = []
        var isDeleteConfirmationPresented: Bool = false
        var isMacFilterDetailPresented: Bool = false
        var taskListMode: TaskListMode = .todos

        // Filter state (moved from view @State)
        var selectedFilter: RoutineListFilter = .all
        var selectedTag: String? = nil
        var excludedTags: Set<String> = []
        var selectedManualPlaceFilterID: UUID? = nil
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var selectedTodoStateFilter: TodoState? = nil
        var tabFilterSnapshots: [String: TabFilterStateManager.Snapshot] = [:]
        var isFilterSheetPresented: Bool = false

        // Timeline filter state
        var selectedTimelineRange: TimelineRange = .all
        var selectedTimelineFilterType: TimelineFilterType = .all
        var selectedTimelineTag: String? = nil
        var selectedTimelineExcludedTags: Set<String> = []
        var selectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil

        // Stats filter state
        var statsSelectedRange: DoneChartRange = .week
        var statsSelectedTag: String? = nil

    }

    enum Action: Equatable {
        case onAppear
        case manualRefreshRequested
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], [RoutineLog], DoneStats)
        case tasksLoadFailed
        case locationSnapshotUpdated(LocationSnapshot)
        case hideUnavailableRoutinesChanged(Bool)
        case setSelectedTask(UUID?)

        case setAddRoutineSheet(Bool)
        case deleteTasksTapped([UUID])
        case setDeleteConfirmation(Bool)
        case setMacFilterDetailPresented(Bool)
        case taskListModeChanged(TaskListMode)
        case deleteTasksConfirmed
        case deleteTasks([UUID])
        case markTaskDone(UUID)
        case notTodayTask(UUID)
        case pauseTask(UUID)
        case resumeTask(UUID)
        case pinTask(UUID)
        case unpinTask(UUID)
        case moveTaskInSection(taskID: UUID, sectionKey: String, orderedTaskIDs: [UUID], direction: MoveDirection)

        // Filter actions
        case selectedFilterChanged(RoutineListFilter)
        case selectedTagChanged(String?)
        case excludedTagsChanged(Set<String>)
        case selectedManualPlaceFilterIDChanged(UUID?)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case selectedTodoStateFilterChanged(TodoState?)
        case isFilterSheetPresentedChanged(Bool)
        case clearOptionalFilters

        // Timeline filter actions
        case selectedTimelineRangeChanged(TimelineRange)
        case selectedTimelineFilterTypeChanged(TimelineFilterType)
        case selectedTimelineTagChanged(String?)
        case selectedTimelineExcludedTagsChanged(Set<String>)
        case selectedTimelineImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)

        // Stats filter actions
        case statsSelectedRangeChanged(DoneChartRange)
        case statsSelectedTagChanged(String?)

        case addRoutineSheet(AddRoutineFeature.Action)
        case taskDetail(TaskDetailFeature.Action)
        case routineSavedSuccessfully(RoutineTask)
        case routineSaveFailed
    }

    private enum CancelID {
        case loadTasks
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.modelContext) var modelContext
    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.locationClient) var locationClient
    @Dependency(\.cloudSyncClient) var cloudSyncClient
    @Dependency(\.continuousClock) var clock
    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                return .concatenate(
                    loadTasksEffect(),
                    .run { @MainActor send in
                        let snapshot = await self.locationClient.snapshot(false)
                        send(.locationSnapshotUpdated(snapshot))
                    }
                )

            case .manualRefreshRequested:
                return .run { @MainActor send in
                    let context = self.modelContext()
                    if context.hasChanges {
                        try? context.save()
                    }

                    try? await self.cloudSyncClient.pullLatestIntoLocalStore(context)
                    send(.onAppear)

                    // CloudKit imports are asynchronous; do a second pass shortly after manual refresh.
                    try? await self.clock.sleep(for: .seconds(2))
                    send(.onAppear)
                }

            case let .tasksLoadedSuccessfully(tasks, places, logs, doneStats):
                let detachedTasks = detachedTasks(from: tasks)
                let detachedPlaces = detachedPlaces(from: places)
                let reconciledTasks = reconcileSelectedDetailTask(detachedTasks, state: &state)
                state.routineTasks = reconciledTasks
                state.routinePlaces = detachedPlaces
                state.timelineLogs = logs.sorted {
                    let lhs = $0.timestamp ?? .distantPast
                    let rhs = $1.timestamp ?? .distantPast
                    return lhs > rhs
                }
                state.doneStats = doneStats
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                validateFilterState(&state)
                persistTemporaryViewState(state)
                let detailRefreshEffect = refreshSelectedTaskDetailEffect(for: state)
                guard state.addRoutineState != nil else { return detailRefreshEffect }
                return .merge(
                    detailRefreshEffect,
                    .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: reconciledTasks)))),
                    .send(.addRoutineSheet(.availableTagSummariesChanged(
                        RoutineTag.summaries(
                            from: reconciledTasks,
                            countsByTaskID: doneStats.countsByTaskID
                        )
                    ))),
                    .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: detachedPlaces, linkedTo: reconciledTasks)))),
                    .send(.addRoutineSheet(.availableRelationshipTasksChanged(RoutineTaskRelationshipCandidate.from(reconciledTasks))))
                )

            case .tasksLoadFailed:
                print("Failed to load tasks.")
                return .none

            case let .locationSnapshotUpdated(snapshot):
                state.locationSnapshot = snapshot
                refreshDisplays(&state)
                return .none

            case let .hideUnavailableRoutinesChanged(isHidden):
                state.hideUnavailableRoutines = isHidden
                appSettingsClient.setHideUnavailableRoutines(isHidden)
                persistTemporaryViewState(state)
                return .none

            case let .setSelectedTask(taskID):
                if let taskID,
                   state.selectedTaskID == taskID,
                   state.taskDetailState?.task.id == taskID {
                    state.isMacFilterDetailPresented = false
                    return .none
                }
                state.selectedTaskID = taskID
                if taskID != nil {
                    state.isMacFilterDetailPresented = false
                }
                guard let taskID,
                      let task = state.routineTasks.first(where: { $0.id == taskID }) else {
                    state.taskDetailState = nil
                    state.selectedTaskReloadGuard = nil
                    state.pendingSelectedChecklistReloadGuardTaskID = nil
                    return .none
                }
                state.taskDetailState = makeTaskDetailState(for: task)
                state.selectedTaskReloadGuard = nil
                state.pendingSelectedChecklistReloadGuardTaskID = nil
                return refreshSelectedTaskDetailEffect(for: state)

            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                if isPresented {
                    state.isMacFilterDetailPresented = false
                    state.addRoutineState = AddRoutineFeature.State(
                        organization: AddRoutineOrganizationState(
                            availableTags: availableTags(from: state.routineTasks),
                            availableTagSummaries: RoutineTag.summaries(
                                from: state.routineTasks,
                                countsByTaskID: state.doneStats.countsByTaskID
                            ),
                            tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode(),
                            availableRelationshipTasks: RoutineTaskRelationshipCandidate.from(state.routineTasks),
                            existingRoutineNames: existingRoutineNames(from: state.routineTasks),
                            availablePlaces: RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks)
                        )
                    )
                } else {
                    state.addRoutineState = nil
                }
                return .none

            case let .deleteTasksTapped(ids):
                let uniqueIDs = uniqueTaskIDs(ids)
                guard !uniqueIDs.isEmpty else { return .none }
                state.pendingDeleteTaskIDs = uniqueIDs
                state.isDeleteConfirmationPresented = true
                return .none

            case let .setDeleteConfirmation(isPresented):
                state.isDeleteConfirmationPresented = isPresented
                if !isPresented {
                    state.pendingDeleteTaskIDs = []
                }
                return .none

            case let .taskListModeChanged(mode):
                let oldMode = state.taskListMode
                // Save current filter state for the old mode
                state.tabFilterSnapshots[oldMode.rawValue] = TabFilterStateManager.Snapshot(
                    selectedTag: state.selectedTag,
                    excludedTags: state.excludedTags,
                    selectedFilter: state.selectedFilter,
                    selectedManualPlaceFilterID: state.selectedManualPlaceFilterID,
                    selectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter,
                    selectedTodoStateFilter: state.selectedTodoStateFilter
                )
                // Restore filter state for the new mode
                let savedSnapshot = state.tabFilterSnapshots[mode.rawValue]
                let snapshot = savedSnapshot ?? .default
                state.selectedTag = snapshot.selectedTag
                state.excludedTags = snapshot.excludedTags
                state.selectedFilter = snapshot.selectedFilter
                state.selectedManualPlaceFilterID = snapshot.selectedManualPlaceFilterID
                state.selectedImportanceUrgencyFilter = snapshot.selectedImportanceUrgencyFilter
                state.selectedTodoStateFilter = snapshot.selectedTodoStateFilter
                // First time on a mode: also clear hideUnavailableRoutines
                if savedSnapshot == nil && state.hideUnavailableRoutines {
                    state.hideUnavailableRoutines = false
                    appSettingsClient.setHideUnavailableRoutines(false)
                }
                state.taskListMode = mode
                state.isMacFilterDetailPresented = false
                // Clear task selection if the selected task doesn't match the new mode
                if let selectedTaskID = state.selectedTaskID,
                   let task = state.routineTasks.first(where: { $0.id == selectedTaskID }) {
                    let keepSelection: Bool
                    switch mode {
                    case .all:
                        keepSelection = true
                    case .todos:
                        keepSelection = task.isOneOffTask
                    case .routines:
                        keepSelection = !task.isOneOffTask
                    }
                    if !keepSelection {
                        state.selectedTaskID = nil
                        state.taskDetailState = nil
                    }
                }
                persistTemporaryViewState(state)
                return .none

            case let .setMacFilterDetailPresented(isPresented):
                state.isMacFilterDetailPresented = isPresented
                if isPresented {
                    state.isAddRoutineSheetPresented = false
                    state.addRoutineState = nil
                    // Clear list selection so re-clicking the same routine
                    // triggers a fresh selection change on macOS.
                    state.selectedTaskID = nil
                }
                return .none

            // MARK: - Filter actions

            case let .selectedFilterChanged(filter):
                state.selectedFilter = filter
                persistTemporaryViewState(state)
                return .none

            case let .selectedTagChanged(tag):
                state.selectedTag = tag
                persistTemporaryViewState(state)
                return .none

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                persistTemporaryViewState(state)
                return .none

            case let .selectedManualPlaceFilterIDChanged(id):
                state.selectedManualPlaceFilterID = id
                persistTemporaryViewState(state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = filter
                persistTemporaryViewState(state)
                return .none

            case let .selectedTodoStateFilterChanged(filter):
                state.selectedTodoStateFilter = filter
                persistTemporaryViewState(state)
                return .none

            case let .isFilterSheetPresentedChanged(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .clearOptionalFilters:
                state.selectedTag = nil
                state.excludedTags = []
                state.selectedManualPlaceFilterID = nil
                state.selectedImportanceUrgencyFilter = nil
                state.selectedTodoStateFilter = nil
                if state.hideUnavailableRoutines {
                    state.hideUnavailableRoutines = false
                    appSettingsClient.setHideUnavailableRoutines(false)
                }
                persistTemporaryViewState(state)
                return .none

            // MARK: - Timeline filter actions

            case let .selectedTimelineRangeChanged(range):
                state.selectedTimelineRange = range
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineFilterTypeChanged(filterType):
                state.selectedTimelineFilterType = filterType
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineTagChanged(tag):
                state.selectedTimelineTag = tag
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineExcludedTagsChanged(tags):
                state.selectedTimelineExcludedTags = tags
                persistTemporaryViewState(state)
                return .none

            case let .selectedTimelineImportanceUrgencyFilterChanged(filter):
                state.selectedTimelineImportanceUrgencyFilter = filter
                persistTemporaryViewState(state)
                return .none

            // MARK: - Stats filter actions

            case let .statsSelectedRangeChanged(range):
                state.statsSelectedRange = range
                persistTemporaryViewState(state)
                return .none

            case let .statsSelectedTagChanged(tag):
                state.statsSelectedTag = tag
                persistTemporaryViewState(state)
                return .none

            case .deleteTasksConfirmed:
                let ids = state.pendingDeleteTaskIDs
                state.pendingDeleteTaskIDs = []
                state.isDeleteConfirmationPresented = false
                return handleDeleteTasks(ids, state: &state)

            case let .deleteTasks(ids):
                return handleDeleteTasks(ids, state: &state)

            case let .markTaskDone(id):
                guard let index = state.routineTasks.firstIndex(where: {
                    $0.id == id && !$0.isArchived(referenceDate: now, calendar: calendar)
                }) else {
                    return .none
                }
                guard !state.routineTasks[index].isCompletedOneOff else {
                    return .none
                }
                guard !state.routineTasks[index].isCanceledOneOff else {
                    return .none
                }
                if state.routineTasks[index].isChecklistCompletionRoutine {
                    return .none
                }
                let completionDate = now
                let currentCalendar = calendar
                guard RoutineDateMath.canMarkDone(
                    for: state.routineTasks[index],
                    referenceDate: completionDate,
                    calendar: currentCalendar
                ) else {
                    return .none
                }

                if state.routineTasks[index].isChecklistDriven {
                    let hadCompletionToday = state.routineTasks[index].lastDone.map {
                        currentCalendar.isDate($0, inSameDayAs: completionDate)
                    } ?? false
                    let dueItemIDs = Set(
                        state.routineTasks[index]
                            .dueChecklistItems(referenceDate: completionDate, calendar: currentCalendar)
                            .map(\.id)
                    )
                    let updatedItemCount = state.routineTasks[index].markChecklistItemsPurchased(
                        dueItemIDs,
                        purchasedAt: completionDate
                    )
                    guard updatedItemCount > 0 else { return .none }
                    if !hadCompletionToday {
                        state.doneStats.totalCount += 1
                        state.doneStats.countsByTaskID[id, default: 0] += 1
                    }
                    refreshDisplays(&state)
                    syncSelectedTaskDetailState(&state)

                    return .run { @MainActor [id, completionDate, currentCalendar] _ in
                        do {
                            let context = ModelContext(self.modelContext().container)
                            guard let taskState = try RoutineLogHistory.markDueChecklistItemsPurchased(
                                taskID: id,
                                purchasedAt: completionDate,
                                context: context,
                                calendar: currentCalendar
                            ) else {
                                return
                            }
                            await self.notificationClient.schedule(
                                NotificationCoordinator.notificationPayload(
                                    for: taskState.task,
                                    referenceDate: completionDate,
                                    calendar: currentCalendar
                                )
                            )
                            NotificationCenter.default.postRoutineDidUpdate()
                        } catch {
                            print("Failed to update checklist routine from home list: \(error)")
                        }
                    }
                }

                let result = state.routineTasks[index].advance(completedAt: completionDate, calendar: calendar)
                if case .completedRoutine = result {
                    state.doneStats.totalCount += 1
                    state.doneStats.countsByTaskID[id, default: 0] += 1
                }
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return .run { @MainActor [id, completionDate, currentCalendar] _ in
                    do {
                        let context = ModelContext(self.modelContext().container)
                        guard let taskState = try RoutineLogHistory.advanceTask(
                            taskID: id,
                            completedAt: completionDate,
                            context: context,
                            calendar: currentCalendar
                        ) else {
                            return
                        }
                        if taskState.task.isOneOffTask {
                            await self.notificationClient.cancel(id.uuidString)
                        } else {
                            await self.notificationClient.schedule(
                                NotificationCoordinator.notificationPayload(
                                    for: taskState.task,
                                    referenceDate: completionDate,
                                    calendar: currentCalendar
                                )
                            )
                        }
                        NotificationCenter.default.postRoutineDidUpdate()
                    } catch {
                        print("Failed to mark routine as done from home list: \(error)")
                    }
                }

            case let .pauseTask(id):
                let pauseDate = now
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
                guard !state.routineTasks[index].isOneOffTask else { return .none }
                guard !state.routineTasks[index].isArchived(referenceDate: pauseDate, calendar: calendar) else { return .none }

                if state.routineTasks[index].scheduleAnchor == nil {
                    state.routineTasks[index].scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                        for: state.routineTasks[index],
                        referenceDate: pauseDate
                    )
                }
                state.routineTasks[index].pausedAt = pauseDate
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return .run { @MainActor [id, pauseDate] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                        if task.scheduleAnchor == nil {
                            task.scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(for: task, referenceDate: pauseDate)
                        }
                        task.pausedAt = pauseDate
                        try context.save()
                        await self.notificationClient.cancel(id.uuidString)
                        NotificationCenter.default.postRoutineDidUpdate()
                    } catch {
                        print("Failed to pause routine from home list: \(error)")
                    }
                }

            case let .resumeTask(id):
                let resumeDate = now
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
                guard !state.routineTasks[index].isOneOffTask else { return .none }
                guard state.routineTasks[index].isArchived(referenceDate: resumeDate, calendar: calendar) else { return .none }

                state.routineTasks[index].scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
                    for: state.routineTasks[index],
                    resumedAt: resumeDate
                )
                state.routineTasks[index].pausedAt = nil
                state.routineTasks[index].snoozedUntil = nil
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return .run { @MainActor [id, resumeDate, currentCalendar = self.calendar] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                        task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: task, resumedAt: resumeDate)
                        task.pausedAt = nil
                        task.snoozedUntil = nil
                        try context.save()
                        await self.notificationClient.schedule(
                            NotificationCoordinator.notificationPayload(
                                for: task,
                                referenceDate: resumeDate,
                                calendar: currentCalendar
                            )
                        )
                        NotificationCenter.default.postRoutineDidUpdate()
                    } catch {
                        print("Failed to resume routine from home list: \(error)")
                    }
                }

            case let .notTodayTask(id):
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
                guard !state.routineTasks[index].isOneOffTask else { return .none }
                guard !state.routineTasks[index].isArchived(referenceDate: now, calendar: calendar) else { return .none }

                let tomorrowStart = calendar.date(
                    byAdding: .day,
                    value: 1,
                    to: calendar.startOfDay(for: now)
                ) ?? now
                state.routineTasks[index].snoozedUntil = tomorrowStart
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return .run { @MainActor [id, tomorrowStart, currentCalendar = self.calendar] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                        task.snoozedUntil = tomorrowStart
                        try context.save()
                        await self.notificationClient.schedule(
                            NotificationCoordinator.notificationPayload(
                                for: task,
                                triggerDate: NotificationPreferences.reminderDate(on: tomorrowStart, calendar: currentCalendar),
                                isArchivedOverride: false,
                                referenceDate: tomorrowStart,
                                calendar: currentCalendar
                            )
                        )
                        NotificationCenter.default.postRoutineDidUpdate()
                    } catch {
                        print("Failed to archive routine for today from home list: \(error)")
                    }
                }

            case let .pinTask(id):
                let pinDate = now
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
                guard state.routineTasks[index].pinnedAt == nil else { return .none }

                state.routineTasks[index].pinnedAt = pinDate
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return .run { @MainActor [id, pinDate] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                        task.pinnedAt = pinDate
                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                    } catch {
                        print("Failed to pin routine from home list: \(error)")
                    }
                }

            case let .unpinTask(id):
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
                guard state.routineTasks[index].pinnedAt != nil else { return .none }

                state.routineTasks[index].pinnedAt = nil
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)

                return .run { @MainActor [id] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                        task.pinnedAt = nil
                        try context.save()
                        NotificationCenter.default.postRoutineDidUpdate()
                    } catch {
                        print("Failed to unpin routine from home list: \(error)")
                    }
                }

            case let .moveTaskInSection(taskID, sectionKey, orderedTaskIDs, direction):
                return moveTaskInSection(
                    taskID: taskID,
                    sectionKey: sectionKey,
                    orderedTaskIDs: orderedTaskIDs,
                    direction: direction,
                    state: &state
                )

            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                return .none

            case let .addRoutineSheet(.delegate(.didSave(name, freq, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color))):
                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        guard let trimmedName = RoutineTask.trimmedName(name), !trimmedName.isEmpty else {
                            send(.routineSaveFailed)
                            return
                        }

                        if try self.hasDuplicateRoutineName(trimmedName, in: context) {
                            send(.routineSaveFailed)
                            return
                        }

                        let newRoutine = RoutineTask(
                            name: trimmedName,
                            emoji: emoji,
                            notes: notes,
                            link: link,
                            deadline: deadline,
                            priority: priority,
                            importance: importance,
                            urgency: urgency,
                            imageData: imageData,
                            placeID: placeID,
                            tags: tags,
                            relationships: relationships,
                            steps: steps,
                            checklistItems: checklistItems,
                            scheduleMode: scheduleMode,
                            interval: Int16(freq),
                            recurrenceRule: recurrenceRule,
                            lastDone: nil,
                            scheduleAnchor: scheduleMode == .oneOff ? nil : self.now,
                            color: color
                        )
                        context.insert(newRoutine)
                        for item in attachments {
                            let att = RoutineAttachment(id: item.id, taskID: newRoutine.id, fileName: item.fileName, data: item.data)
                            context.insert(att)
                        }
                        try context.save()
                        send(.routineSavedSuccessfully(newRoutine))
                    } catch {
                        send(.routineSaveFailed)
                    }
                }

            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task.detachedCopy())
                refreshDisplays(&state)
                syncSelectedTaskDetailState(&state)
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                NotificationCenter.default.postRoutineDidUpdate()
                guard !task.isOneOffTask else { return .none }
                let payload = makeNotificationPayload(for: task, referenceDate: now)
                return .run { _ in
                    await self.notificationClient.schedule(payload)
                }

            case .routineSaveFailed:
                print("Failed to save routine.")
                return .none

            case .taskDetail(.routineDeleted):
                state.selectedTaskID = nil
                state.taskDetailState = nil
                state.selectedTaskReloadGuard = nil
                state.pendingSelectedChecklistReloadGuardTaskID = nil
                return .none

            case let .taskDetail(.toggleChecklistItemCompletion(itemID)):
                trackSelectedChecklistReloadGuardIfNeeded(for: itemID, in: &state)
                return .none

            case let .taskDetail(.markChecklistItemCompleted(itemID)):
                trackSelectedChecklistReloadGuardIfNeeded(for: itemID, in: &state)
                return .none

            case .taskDetail(.undoSelectedDateCompletion):
                trackSelectedChecklistUndoReloadGuardIfNeeded(in: &state)
                return .none

            case .taskDetail(.logsLoaded):
                syncSelectedTaskFromTaskDetail(&state)
                return .none

            case let .taskDetail(.openLinkedTask(taskID)):
                guard let task = state.routineTasks.first(where: { $0.id == taskID }) else { return .none }
                state.selectedTaskID = taskID
                state.taskDetailState = makeTaskDetailState(for: task)
                state.selectedTaskReloadGuard = nil
                state.pendingSelectedChecklistReloadGuardTaskID = nil
                return refreshSelectedTaskDetailEffect(for: state)

            case .taskDetail(.openAddLinkedTask):
                guard let currentTaskID = state.taskDetailState?.task.id,
                      let kind = state.taskDetailState?.addLinkedTaskRelationshipKind else { return .none }
                state.isAddRoutineSheetPresented = true
                state.isMacFilterDetailPresented = false
                state.addRoutineState = AddRoutineFeature.State(
                    organization: AddRoutineOrganizationState(
                        relationships: [RoutineTaskRelationship(targetTaskID: currentTaskID, kind: kind.inverse)],
                        availableTags: availableTags(from: state.routineTasks),
                        availableTagSummaries: RoutineTag.summaries(
                            from: state.routineTasks,
                            countsByTaskID: state.doneStats.countsByTaskID
                        ),
                        tagCounterDisplayMode: appSettingsClient.tagCounterDisplayMode(),
                        availableRelationshipTasks: RoutineTaskRelationshipCandidate.from(state.routineTasks, excluding: currentTaskID),
                        existingRoutineNames: existingRoutineNames(from: state.routineTasks),
                        availablePlaces: RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks)
                    )
                )
                return .none

            case .taskDetail:
                return .none

            case .addRoutineSheet:
                return .none
            }
        }
        .ifLet(\.addRoutineState, action: \.addRoutineSheet) {
            AddRoutineFeature(
                onSave: { name, freq, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color in
                    .send(.delegate(.didSave(name, freq, recurrenceRule, emoji, notes, link, deadline, priority, importance, urgency, imageData, placeID, tags, relationships, steps, scheduleMode, checklistItems, attachments, color)))
                },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }
        .ifLet(\.taskDetailState, action: \.taskDetail) {
            TaskDetailFeature()
        }
    }

    /// Prunes stale filter state after the task/place list is refreshed.
    private func validateFilterState(_ state: inout State) {
        // Validate selectedTag against all available tags
        let allDisplays = state.routineDisplays + state.awayRoutineDisplays + state.archivedRoutineDisplays
        let allAvailableTags = Self.availableTags(from: allDisplays)
        if let tag = state.selectedTag, !RoutineTag.contains(tag, in: allAvailableTags) {
            state.selectedTag = nil
        }
        // Prune excluded tags to those still present in the include-filtered pool
        let includeScopedDisplays = allDisplays.filter {
            Self.matchesSelectedTag(state.selectedTag, in: $0.tags)
        }
        let availableExcludeTags = Self.availableTags(from: includeScopedDisplays).filter { tag in
            state.selectedTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
        }
        state.excludedTags = state.excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }
        // Validate selectedManualPlaceFilterID
        if let placeID = state.selectedManualPlaceFilterID,
           !state.routinePlaces.contains(where: { $0.id == placeID }) {
            state.selectedManualPlaceFilterID = nil
        }
    }

    private func handleDeleteTasks(_ ids: [UUID], state: inout State) -> Effect<Action> {
        let uniqueIDs = uniqueTaskIDs(ids)
        guard !uniqueIDs.isEmpty else { return .none }

        let idSet = Set(uniqueIDs)
        RoutineTask.removeRelationships(targeting: idSet, from: state.routineTasks)
        state.routineTasks.removeAll { idSet.contains($0.id) }
        var removedDoneCount = 0
        var removedCanceledCount = 0
        for id in uniqueIDs {
            removedDoneCount += state.doneStats.countsByTaskID[id, default: 0]
            removedCanceledCount += state.doneStats.canceledCountsByTaskID[id, default: 0]
            state.doneStats.countsByTaskID.removeValue(forKey: id)
            state.doneStats.canceledCountsByTaskID.removeValue(forKey: id)
        }
        state.doneStats.totalCount = max(state.doneStats.totalCount - removedDoneCount, 0)
        state.doneStats.canceledTotalCount = max(state.doneStats.canceledTotalCount - removedCanceledCount, 0)
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        let deleteEffect: Effect<Action> = .run { @MainActor [uniqueIDs] _ in
            let context = self.modelContext()
            let allTasks = (try? context.fetch(FetchDescriptor<RoutineTask>())) ?? []
            RoutineTask.removeRelationships(targeting: idSet, from: allTasks)
            for id in uniqueIDs {
                let descriptor = FetchDescriptor<RoutineTask>(
                    predicate: #Predicate { task in
                        task.id == id
                    }
                )
                if let task = try context.fetch(descriptor).first {
                    context.delete(task)
                }
                let logs = try context.fetch(logsDescriptor(for: id))
                for log in logs {
                    context.delete(log)
                }
                await self.notificationClient.cancel(id.uuidString)
            }
            try? context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
        guard state.addRoutineState != nil else { return deleteEffect }
        return .merge(
            deleteEffect,
            .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: state.routineTasks)))),
            .send(.addRoutineSheet(.availableTagSummariesChanged(
                RoutineTag.summaries(
                    from: state.routineTasks,
                    countsByTaskID: state.doneStats.countsByTaskID
                )
            ))),
            .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks)))),
            .send(.addRoutineSheet(.availableRelationshipTasksChanged(RoutineTaskRelationshipCandidate.from(state.routineTasks))))
        )
    }

    private func moveTaskInSection(
        taskID: UUID,
        sectionKey: String,
        orderedTaskIDs: [UUID],
        direction: MoveDirection,
        state: inout State
    ) -> Effect<Action> {
        let existingTaskIDs = Set(state.routineTasks.map(\.id))
        var seen: Set<UUID> = []
        var normalizedIDs: [UUID] = []
        normalizedIDs.reserveCapacity(orderedTaskIDs.count)
        for id in orderedTaskIDs where existingTaskIDs.contains(id) {
            if seen.insert(id).inserted {
                normalizedIDs.append(id)
            }
        }

        guard normalizedIDs.count > 1,
              let currentIndex = normalizedIDs.firstIndex(of: taskID) else {
            return .none
        }

        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = currentIndex - 1
        case .down:
            targetIndex = currentIndex + 1
        }
        guard normalizedIDs.indices.contains(targetIndex) else { return .none }

        normalizedIDs.swapAt(currentIndex, targetIndex)

        for (order, id) in normalizedIDs.enumerated() {
            guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { continue }
            state.routineTasks[index].setManualSectionOrder(order, for: sectionKey)
        }
        refreshDisplays(&state)
        syncSelectedTaskDetailState(&state)

        return .run { @MainActor [normalizedIDs, sectionKey] _ in
            do {
                let context = self.modelContext()
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
                for (order, id) in normalizedIDs.enumerated() {
                    tasksByID[id]?.setManualSectionOrder(order, for: sectionKey)
                }
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                print("Failed to persist manual section order: \(error)")
            }
        }
    }

    private func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }

    func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }

    private func makeNotificationPayload(
        for task: RoutineTask,
        referenceDate: Date
    ) -> NotificationPayload {
        NotificationCoordinator.notificationPayload(for: task, referenceDate: referenceDate, calendar: calendar)
    }

    private func loadTasksEffect() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = ModelContext(self.modelContext().container)
                try self.enforceUniqueRoutineNames(in: context)
                try self.enforceUniquePlaceNames(in: context)
                _ = try RoutineLogHistory.backfillMissingLastDoneLogs(in: context)
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let places = try context.fetch(FetchDescriptor<RoutinePlace>())
                let logs = try context.fetch(FetchDescriptor<RoutineLog>())
                send(.tasksLoadedSuccessfully(tasks, places, logs, self.makeDoneStats(tasks: tasks, logs: logs)))
            } catch {
                send(.tasksLoadFailed)
            }
        }
        .cancellable(id: CancelID.loadTasks, cancelInFlight: true)
    }

    private func syncSelectedTaskDetailState(_ state: inout State) {
        guard let selectedTaskID = state.selectedTaskID else {
            state.taskDetailState = nil
            state.selectedTaskReloadGuard = nil
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        guard let task = state.routineTasks.first(where: { $0.id == selectedTaskID }) else {
            state.selectedTaskID = nil
            state.taskDetailState = nil
            state.selectedTaskReloadGuard = nil
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        if var detailState = state.taskDetailState {
            detailState.task = task.detachedCopy()
            detailState.taskRefreshID &+= 1
            detailState.daysSinceLastRoutine = RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailState.task.lastDone,
                referenceDate: now
            )
            detailState.overdueDays = detailState.task.isArchived(referenceDate: now, calendar: calendar)
                ? 0
                : RoutineDateMath.overdueDays(for: detailState.task, referenceDate: now, calendar: calendar)
            detailState.isDoneToday = detailState.task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
            state.taskDetailState = detailState
        } else {
            state.taskDetailState = makeTaskDetailState(for: task)
        }
    }

    private func refreshSelectedTaskDetailEffect(for state: State) -> Effect<Action> {
        guard state.taskDetailState != nil else { return .none }
        return .send(.taskDetail(.onAppear))
    }

    private func syncSelectedTaskFromTaskDetail(_ state: inout State) {
        guard let detailTask = state.taskDetailState?.task else { return }
        guard let index = state.routineTasks.firstIndex(where: { $0.id == detailTask.id }) else { return }
        let syncedTask = detailTask.detachedCopy()
        state.routineTasks[index] = syncedTask
        if state.pendingSelectedChecklistReloadGuardTaskID == syncedTask.id,
           syncedTask.isChecklistCompletionRoutine,
           state.selectedTaskID == detailTask.id {
            state.selectedTaskReloadGuard = makeSelectedTaskReloadGuard(for: syncedTask)
        }
        state.pendingSelectedChecklistReloadGuardTaskID = nil
        refreshDisplays(&state)
    }

    private func detachedTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.map { $0.detachedCopy() }
    }

    private func detachedPlaces(from places: [RoutinePlace]) -> [RoutinePlace] {
        places.map { $0.detachedCopy() }
    }

    private func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        let persistedState = persistedState ?? .default
        state.hideUnavailableRoutines = persistedState.hideUnavailableRoutines || appSettingsClient.hideUnavailableRoutines()
        state.selectedFilter = persistedState.homeSelectedFilter
        state.selectedTag = persistedState.homeSelectedTag
        state.excludedTags = persistedState.homeExcludedTags
        state.selectedManualPlaceFilterID = persistedState.homeSelectedManualPlaceFilterID
        state.selectedImportanceUrgencyFilter = persistedState.homeSelectedImportanceUrgencyFilter
        state.selectedTodoStateFilter = persistedState.homeSelectedTodoStateFilter
        state.tabFilterSnapshots = persistedState.homeTabFilterSnapshots
        state.selectedTimelineRange = persistedState.homeSelectedTimelineRange
        state.selectedTimelineFilterType = persistedState.homeSelectedTimelineFilterType
        state.selectedTimelineTag = persistedState.homeSelectedTimelineTag
        state.selectedTimelineExcludedTags = persistedState.homeSelectedTimelineExcludedTags
        state.selectedTimelineImportanceUrgencyFilter = persistedState.homeSelectedTimelineImportanceUrgencyFilter
        state.statsSelectedRange = persistedState.statsSelectedRange
        state.statsSelectedTag = persistedState.statsSelectedTag

        if let rawValue = persistedState.homeTaskListModeRawValue,
           let mode = TaskListMode(rawValue: rawValue) {
            state.taskListMode = mode
            if let snapshot = state.tabFilterSnapshots[rawValue] {
                state.selectedTag = snapshot.selectedTag
                state.excludedTags = snapshot.excludedTags
                state.selectedFilter = snapshot.selectedFilter
                state.selectedManualPlaceFilterID = snapshot.selectedManualPlaceFilterID
                state.selectedImportanceUrgencyFilter = snapshot.selectedImportanceUrgencyFilter
                state.selectedTodoStateFilter = snapshot.selectedTodoStateFilter
            }
        }
    }

    private func persistTemporaryViewState(_ state: State) {
        let existing = appSettingsClient.temporaryViewState() ?? .default
        var tabFilterSnapshots = state.tabFilterSnapshots
        tabFilterSnapshots[state.taskListMode.rawValue] = TabFilterStateManager.Snapshot(
            selectedTag: state.selectedTag,
            excludedTags: state.excludedTags,
            selectedFilter: state.selectedFilter,
            selectedManualPlaceFilterID: state.selectedManualPlaceFilterID,
            selectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter,
            selectedTodoStateFilter: state.selectedTodoStateFilter
        )
        appSettingsClient.setTemporaryViewState(
            TemporaryViewState(
                selectedAppTabRawValue: existing.selectedAppTabRawValue,
                homeTaskListModeRawValue: state.taskListMode.rawValue,
                homeSelectedFilter: state.selectedFilter,
                homeSelectedTag: state.selectedTag,
                homeExcludedTags: state.excludedTags,
                homeSelectedManualPlaceFilterID: state.selectedManualPlaceFilterID,
                homeSelectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter,
                homeSelectedTodoStateFilter: state.selectedTodoStateFilter,
                homeTabFilterSnapshots: tabFilterSnapshots,
                hideUnavailableRoutines: state.hideUnavailableRoutines,
                homeSelectedTimelineRange: state.selectedTimelineRange,
                homeSelectedTimelineFilterType: state.selectedTimelineFilterType,
                homeSelectedTimelineTag: state.selectedTimelineTag,
                homeSelectedTimelineExcludedTags: state.selectedTimelineExcludedTags,
                homeSelectedTimelineImportanceUrgencyFilter: state.selectedTimelineImportanceUrgencyFilter,
                macHomeSidebarModeRawValue: existing.macHomeSidebarModeRawValue,
                macSelectedSettingsSectionRawValue: existing.macSelectedSettingsSectionRawValue,
                timelineSelectedRange: existing.timelineSelectedRange,
                timelineFilterType: existing.timelineFilterType,
                timelineSelectedTag: existing.timelineSelectedTag,
                statsSelectedRange: existing.statsSelectedRange,
                statsSelectedTag: existing.statsSelectedTag,
                statsExcludedTags: existing.statsExcludedTags,
                statsTaskTypeFilterRawValue: existing.statsTaskTypeFilterRawValue
            )
        )
    }

}

extension HomeFeature {
    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        RoutineLogHistory.detailLogs(taskID: taskID, context: context)
    }

    static func availableTags(from routineDisplays: [RoutineDisplay]) -> [String] {
        tagSummaries(from: routineDisplays).map(\.name)
    }

    static func tagSummaries(from routineDisplays: [RoutineDisplay]) -> [RoutineTagSummary] {
        let tagCounts = routineDisplays.reduce(into: [String: Int]()) { partialResult, task in
            for tag in task.tags {
                guard let normalizedTag = RoutineTag.normalized(tag) else { continue }
                partialResult[normalizedTag, default: 0] += 1
            }
        }

        return RoutineTag.allTags(from: routineDisplays.map(\.tags))
            .map { tag in
                RoutineTagSummary(
                    name: tag,
                    linkedRoutineCount: tagCounts[RoutineTag.normalized(tag) ?? tag, default: 0]
                )
            }
            .sorted { lhs, rhs in
                if lhs.linkedRoutineCount != rhs.linkedRoutineCount {
                    return lhs.linkedRoutineCount > rhs.linkedRoutineCount
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    static func matchesSelectedTag(_ selectedTag: String?, in tags: [String]) -> Bool {
        guard let selectedTag else { return true }
        return RoutineTag.contains(selectedTag, in: tags)
    }

    static func matchesExcludedTags(_ excludedTags: Set<String>, in tags: [String]) -> Bool {
        guard !excludedTags.isEmpty else { return true }
        return !excludedTags.contains { RoutineTag.contains($0, in: tags) }
    }

    static func matchesImportanceUrgencyFilter(
        _ selectedFilter: ImportanceUrgencyFilterCell?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> Bool {
        guard let selectedFilter else { return true }
        return selectedFilter.matches(importance: importance, urgency: urgency)
    }

    static func matchesTodoStateFilter(_ filter: TodoState?, task: RoutineDisplay) -> Bool {
        guard let filter else { return true }
        guard task.isOneOffTask else { return true }
        return task.todoState == filter
    }
}
