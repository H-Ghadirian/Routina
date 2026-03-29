import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
    struct SelectedTaskReloadGuard: Equatable {
        var taskID: UUID
        var completedChecklistItemIDsStorage: String
        var lastDone: Date?
        var scheduleAnchor: Date?
    }

    struct DoneStats: Equatable {
        var totalCount: Int = 0
        var countsByTaskID: [UUID: Int] = [:]
    }

    struct RoutineDisplay: Equatable, Identifiable {
        let taskID: UUID
        var id: UUID { taskID }
        var name: String
        var emoji: String
        var placeID: UUID?
        var placeName: String?
        var locationAvailability: RoutineLocationAvailability
        var tags: [String]
        var steps: [String]
        var interval: Int
        var recurrenceRule: RoutineRecurrenceRule
        var scheduleMode: RoutineScheduleMode
        var lastDone: Date?
        var dueDate: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var pinnedAt: Date?
        var daysUntilDue: Int
        var isOneOffTask: Bool
        var isCompletedOneOff: Bool
        var isDoneToday: Bool
        var isPaused: Bool
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
    }

    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routinePlaces: [RoutinePlace] = []
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
        var routineDetailState: RoutineDetailFeature.State?
        var selectedTaskReloadGuard: SelectedTaskReloadGuard?
        var pendingSelectedChecklistReloadGuardTaskID: UUID?
        var pendingDeleteTaskIDs: [UUID] = []
        var isDeleteConfirmationPresented: Bool = false
    }

    enum Action: Equatable {
        case onAppear
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], DoneStats)
        case tasksLoadFailed
        case locationSnapshotUpdated(LocationSnapshot)
        case hideUnavailableRoutinesChanged(Bool)
        case setSelectedTask(UUID?)

        case setAddRoutineSheet(Bool)
        case deleteTasksTapped([UUID])
        case setDeleteConfirmation(Bool)
        case deleteTasksConfirmed
        case deleteTasks([UUID])
        case markTaskDone(UUID)
        case pauseTask(UUID)
        case resumeTask(UUID)
        case pinTask(UUID)
        case unpinTask(UUID)

        case addRoutineSheet(AddRoutineFeature.Action)
        case routineDetail(RoutineDetailFeature.Action)
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

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.hideUnavailableRoutines = SharedDefaults.app[.appSettingHideUnavailableRoutines]
                return .concatenate(
                    loadTasksEffect(),
                    .run { @MainActor send in
                        let snapshot = await self.locationClient.snapshot(false)
                        send(.locationSnapshotUpdated(snapshot))
                    }
                )

            case let .tasksLoadedSuccessfully(tasks, places, doneStats):
                let detachedTasks = detachedTasks(from: tasks)
                let detachedPlaces = detachedPlaces(from: places)
                let reconciledTasks = reconcileSelectedDetailTask(detachedTasks, state: &state)
                state.routineTasks = reconciledTasks
                state.routinePlaces = detachedPlaces
                state.doneStats = doneStats
                refreshDisplays(&state)
                syncSelectedRoutineDetailState(&state)
                let detailRefreshEffect = refreshSelectedRoutineDetailEffect(for: state)
                guard state.addRoutineState != nil else { return detailRefreshEffect }
                return .merge(
                    detailRefreshEffect,
                    .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: reconciledTasks)))),
                    .send(.addRoutineSheet(.availableTagsChanged(availableTags(from: reconciledTasks)))),
                    .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: detachedPlaces, linkedTo: reconciledTasks))))
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
                SharedDefaults.app[.appSettingHideUnavailableRoutines] = isHidden
                return .none

            case let .setSelectedTask(taskID):
                if let taskID,
                   state.selectedTaskID == taskID,
                   state.routineDetailState?.task.id == taskID {
                    return .none
                }
                state.selectedTaskID = taskID
                guard let taskID,
                      let task = state.routineTasks.first(where: { $0.id == taskID }) else {
                    state.routineDetailState = nil
                    state.selectedTaskReloadGuard = nil
                    state.pendingSelectedChecklistReloadGuardTaskID = nil
                    return .none
                }
                state.routineDetailState = makeRoutineDetailState(for: task)
                state.selectedTaskReloadGuard = nil
                state.pendingSelectedChecklistReloadGuardTaskID = nil
                return refreshSelectedRoutineDetailEffect(for: state)

            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                if isPresented {
                    state.addRoutineState = AddRoutineFeature.State(
                        availableTags: availableTags(from: state.routineTasks),
                        existingRoutineNames: existingRoutineNames(from: state.routineTasks),
                        availablePlaces: RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks)
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

            case .deleteTasksConfirmed:
                let ids = state.pendingDeleteTaskIDs
                state.pendingDeleteTaskIDs = []
                state.isDeleteConfirmationPresented = false
                return handleDeleteTasks(ids, state: &state)

            case let .deleteTasks(ids):
                return handleDeleteTasks(ids, state: &state)

            case let .markTaskDone(id):
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id && !$0.isPaused }) else {
                    return .none
                }
                guard !state.routineTasks[index].isCompletedOneOff else {
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
                    syncSelectedRoutineDetailState(&state)

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
                syncSelectedRoutineDetailState(&state)

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
                guard !state.routineTasks[index].isPaused else { return .none }

                if state.routineTasks[index].scheduleAnchor == nil {
                    state.routineTasks[index].scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                        for: state.routineTasks[index],
                        referenceDate: pauseDate
                    )
                }
                state.routineTasks[index].pausedAt = pauseDate
                refreshDisplays(&state)
                syncSelectedRoutineDetailState(&state)

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
                guard state.routineTasks[index].isPaused else { return .none }

                state.routineTasks[index].scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
                    for: state.routineTasks[index],
                    resumedAt: resumeDate
                )
                state.routineTasks[index].pausedAt = nil
                refreshDisplays(&state)
                syncSelectedRoutineDetailState(&state)

                return .run { @MainActor [id, resumeDate, currentCalendar = self.calendar] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }
                        task.scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(for: task, resumedAt: resumeDate)
                        task.pausedAt = nil
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

            case let .pinTask(id):
                let pinDate = now
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
                guard state.routineTasks[index].pinnedAt == nil else { return .none }

                state.routineTasks[index].pinnedAt = pinDate
                refreshDisplays(&state)
                syncSelectedRoutineDetailState(&state)

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
                syncSelectedRoutineDetailState(&state)

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

            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                return .none

            case let .addRoutineSheet(.delegate(.didSave(name, freq, recurrenceRule, emoji, placeID, tags, steps, scheduleMode, checklistItems))):
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
                            placeID: placeID,
                            tags: tags,
                            steps: steps,
                            checklistItems: checklistItems,
                            scheduleMode: scheduleMode,
                            interval: Int16(freq),
                            recurrenceRule: recurrenceRule,
                            lastDone: nil,
                            scheduleAnchor: scheduleMode == .oneOff ? nil : self.now
                        )
                        context.insert(newRoutine)
                        try context.save()
                        send(.routineSavedSuccessfully(newRoutine))
                    } catch {
                        send(.routineSaveFailed)
                    }
                }

            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task.detachedCopy())
                refreshDisplays(&state)
                syncSelectedRoutineDetailState(&state)
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

            case .routineDetail(.routineDeleted):
                state.selectedTaskID = nil
                state.routineDetailState = nil
                state.selectedTaskReloadGuard = nil
                state.pendingSelectedChecklistReloadGuardTaskID = nil
                return .none

            case let .routineDetail(.toggleChecklistItemCompletion(itemID)):
                trackSelectedChecklistReloadGuardIfNeeded(for: itemID, in: &state)
                return .none

            case let .routineDetail(.markChecklistItemCompleted(itemID)):
                trackSelectedChecklistReloadGuardIfNeeded(for: itemID, in: &state)
                return .none

            case .routineDetail(.undoSelectedDateCompletion):
                trackSelectedChecklistUndoReloadGuardIfNeeded(in: &state)
                return .none

            case .routineDetail(.logsLoaded):
                syncSelectedTaskFromRoutineDetail(&state)
                return .none

            case .routineDetail:
                return .none

            case .addRoutineSheet:
                return .none
            }
        }
        .ifLet(\.addRoutineState, action: \.addRoutineSheet) {
            AddRoutineFeature(
                onSave: { name, freq, recurrenceRule, emoji, placeID, tags, steps, scheduleMode, checklistItems in
                    .send(.delegate(.didSave(name, freq, recurrenceRule, emoji, placeID, tags, steps, scheduleMode, checklistItems)))
                },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }
        .ifLet(\.routineDetailState, action: \.routineDetail) {
            RoutineDetailFeature()
        }
    }

    private func makeRoutineDisplay(
        _ task: RoutineTask,
        placesByID: [UUID: RoutinePlace],
        locationSnapshot: LocationSnapshot,
        doneStats: DoneStats
    ) -> RoutineDisplay {
        let doneTodayFromLastDone = task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        let linkedPlace = task.placeID.flatMap { placesByID[$0] }
        let locationAvailability: RoutineLocationAvailability

        if let linkedPlace {
            if locationSnapshot.canDeterminePresence, let coordinate = locationSnapshot.coordinate {
                let distance = linkedPlace.distance(to: coordinate)
                if linkedPlace.contains(coordinate) {
                    locationAvailability = .available(placeName: linkedPlace.displayName)
                } else {
                    locationAvailability = .away(
                        placeName: linkedPlace.displayName,
                        distanceMeters: distance
                    )
                }
            } else {
                locationAvailability = .unknown(placeName: linkedPlace.displayName)
            }
        } else {
            locationAvailability = .unrestricted
        }

        let nextDueChecklistItem = task.nextDueChecklistItem(referenceDate: now, calendar: calendar)
        let dueChecklistItems = task.dueChecklistItems(referenceDate: now, calendar: calendar)
        let dueDate: Date? = !task.isPaused && !task.isOneOffTask && !task.isChecklistDriven && task.recurrenceRule.isFixedCalendar
            ? RoutineDateMath.dueDate(for: task, referenceDate: now, calendar: calendar)
            : nil
        let daysUntilDue = task.isPaused
            ? 0
            : task.isCompletedOneOff
                ? Int.max
                : RoutineDateMath.daysUntilDue(for: task, referenceDate: now, calendar: calendar)

        return RoutineDisplay(
            taskID: task.id,
            name: task.name ?? "Unnamed task",
            emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
            placeID: task.placeID,
            placeName: linkedPlace?.displayName,
            locationAvailability: locationAvailability,
            tags: task.tags,
            steps: task.steps.map(\.title),
            interval: max(Int(task.interval), 1),
            recurrenceRule: task.recurrenceRule,
            scheduleMode: task.scheduleMode,
            lastDone: task.lastDone,
            dueDate: dueDate,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            pinnedAt: task.pinnedAt,
            daysUntilDue: daysUntilDue,
            isOneOffTask: task.isOneOffTask,
            isCompletedOneOff: task.isCompletedOneOff,
            isDoneToday: doneTodayFromLastDone,
            isPaused: task.isPaused,
            isPinned: task.isPinned,
            completedStepCount: task.completedSteps,
            isInProgress: task.isInProgress,
            nextStepTitle: task.nextStepTitle,
            checklistItemCount: task.checklistItems.count,
            completedChecklistItemCount: task.completedChecklistItemCount,
            dueChecklistItemCount: dueChecklistItems.count,
            nextPendingChecklistItemTitle: task.nextPendingChecklistItemTitle,
            nextDueChecklistItemTitle: nextDueChecklistItem?.title,
            doneCount: doneStats.countsByTaskID[task.id, default: 0]
        )
    }

    private func uniqueTaskIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }

    private func handleDeleteTasks(_ ids: [UUID], state: inout State) -> Effect<Action> {
        let uniqueIDs = uniqueTaskIDs(ids)
        guard !uniqueIDs.isEmpty else { return .none }

        let idSet = Set(uniqueIDs)
        state.routineTasks.removeAll { idSet.contains($0.id) }
        var removedDoneCount = 0
        for id in uniqueIDs {
            removedDoneCount += state.doneStats.countsByTaskID[id, default: 0]
            state.doneStats.countsByTaskID.removeValue(forKey: id)
        }
        state.doneStats.totalCount = max(state.doneStats.totalCount - removedDoneCount, 0)
        refreshDisplays(&state)
        syncSelectedRoutineDetailState(&state)

        let deleteEffect: Effect<Action> = .run { @MainActor [uniqueIDs] _ in
            let context = self.modelContext()
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
            .send(.addRoutineSheet(.availableTagsChanged(availableTags(from: state.routineTasks)))),
            .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks))))
        )
    }

    private func taskDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineTask> {
        FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
    }

    private func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
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
                send(.tasksLoadedSuccessfully(tasks, places, self.makeDoneStats(tasks: tasks, logs: logs)))
            } catch {
                send(.tasksLoadFailed)
            }
        }
        .cancellable(id: CancelID.loadTasks, cancelInFlight: true)
    }

    private func existingRoutineNames(from tasks: [RoutineTask]) -> [String] {
        tasks.compactMap(\.name)
    }

    private func availableTags(from tasks: [RoutineTask]) -> [String] {
        RoutineTag.allTags(from: tasks.map(\.tags))
    }

    private func refreshDisplays(_ state: inout State) {
        let placesByID = Dictionary(uniqueKeysWithValues: state.routinePlaces.map { ($0.id, $0) })
        var active: [RoutineDisplay] = []
        var away: [RoutineDisplay] = []
        var archived: [RoutineDisplay] = []

        for task in state.routineTasks {
            let display = makeRoutineDisplay(
                task,
                placesByID: placesByID,
                locationSnapshot: state.locationSnapshot,
                doneStats: state.doneStats
            )

            if task.isPaused || task.isCompletedOneOff {
                archived.append(display)
            } else if case .away = display.locationAvailability {
                away.append(display)
            } else {
                active.append(display)
            }
        }

        state.routineDisplays = active
        state.awayRoutineDisplays = away
        state.archivedRoutineDisplays = archived
    }

    private func makeRoutineDetailState(for task: RoutineTask) -> RoutineDetailFeature.State {
        let detailTask = task.detachedCopy()
        let defaultSelectedDate = detailTask.isCompletedOneOff
            ? calendar.startOfDay(for: detailTask.lastDone ?? now)
            : calendar.startOfDay(for: now)
        return RoutineDetailFeature.State(
            task: detailTask,
            logs: [],
            selectedDate: defaultSelectedDate,
            daysSinceLastRoutine: RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailTask.lastDone,
                referenceDate: now
            ),
            overdueDays: detailTask.isPaused
                ? 0
                : RoutineDateMath.overdueDays(for: detailTask, referenceDate: now, calendar: calendar),
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        )
    }

    private func syncSelectedRoutineDetailState(_ state: inout State) {
        guard let selectedTaskID = state.selectedTaskID else {
            state.routineDetailState = nil
            state.selectedTaskReloadGuard = nil
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        guard let task = state.routineTasks.first(where: { $0.id == selectedTaskID }) else {
            state.selectedTaskID = nil
            state.routineDetailState = nil
            state.selectedTaskReloadGuard = nil
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        if var detailState = state.routineDetailState {
            detailState.task = task.detachedCopy()
            detailState.taskRefreshID &+= 1
            detailState.daysSinceLastRoutine = RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailState.task.lastDone,
                referenceDate: now
            )
            detailState.overdueDays = detailState.task.isPaused
                ? 0
                : RoutineDateMath.overdueDays(for: detailState.task, referenceDate: now, calendar: calendar)
            detailState.isDoneToday = detailState.task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
            state.routineDetailState = detailState
        } else {
            state.routineDetailState = makeRoutineDetailState(for: task)
        }
    }

    private func refreshSelectedRoutineDetailEffect(for state: State) -> Effect<Action> {
        guard state.routineDetailState != nil else { return .none }
        return .send(.routineDetail(.onAppear))
    }

    private func makeDoneStats(tasks: [RoutineTask], logs: [RoutineLog]) -> DoneStats {
        let taskIDs = Set(tasks.map(\.id))
        let countsByTaskID = logs.reduce(into: [UUID: Int]()) { partialResult, log in
            guard taskIDs.contains(log.taskID) else { return }
            partialResult[log.taskID, default: 0] += 1
        }
        return DoneStats(
            totalCount: countsByTaskID.values.reduce(0, +),
            countsByTaskID: countsByTaskID
        )
    }

    private func syncSelectedTaskFromRoutineDetail(_ state: inout State) {
        guard let detailTask = state.routineDetailState?.task else { return }
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

    private func reconcileSelectedDetailTask(_ incomingTasks: [RoutineTask], state: inout State) -> [RoutineTask] {
        guard let selectedTaskID = state.selectedTaskID,
              let detailTask = state.routineDetailState?.task,
              detailTask.id == selectedTaskID else {
            state.selectedTaskReloadGuard = nil
            return incomingTasks
        }

        guard let incomingIndex = incomingTasks.firstIndex(where: { $0.id == selectedTaskID }) else {
            state.selectedTaskReloadGuard = nil
            return incomingTasks
        }

        guard let reloadGuard = state.selectedTaskReloadGuard,
              reloadGuard.taskID == selectedTaskID else {
            return incomingTasks
        }

        let incomingTask = incomingTasks[incomingIndex]
        if matchesSelectedTaskReloadGuard(incomingTask, guard: reloadGuard) {
            return incomingTasks
        }

        guard shouldPreserveSelectedDetailTask(detailTask, over: incomingTask, guardedBy: reloadGuard) else {
            state.selectedTaskReloadGuard = nil
            return incomingTasks
        }

        var reconciledTasks = incomingTasks
        reconciledTasks[incomingIndex] = detailTask.detachedCopy()
        return reconciledTasks
    }

    private func detachedTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.map { $0.detachedCopy() }
    }

    private func detachedPlaces(from places: [RoutinePlace]) -> [RoutinePlace] {
        places.map { $0.detachedCopy() }
    }

    private func makeSelectedTaskReloadGuard(for task: RoutineTask) -> SelectedTaskReloadGuard {
        SelectedTaskReloadGuard(
            taskID: task.id,
            completedChecklistItemIDsStorage: task.completedChecklistItemIDsStorage,
            lastDone: task.lastDone,
            scheduleAnchor: task.scheduleAnchor
        )
    }

    private func matchesSelectedTaskReloadGuard(
        _ task: RoutineTask,
        guard reloadGuard: SelectedTaskReloadGuard
    ) -> Bool {
        task.id == reloadGuard.taskID
            && task.completedChecklistItemIDsStorage == reloadGuard.completedChecklistItemIDsStorage
            && task.lastDone == reloadGuard.lastDone
            && task.scheduleAnchor == reloadGuard.scheduleAnchor
    }

    private func shouldPreserveSelectedDetailTask(
        _ current: RoutineTask,
        over incoming: RoutineTask,
        guardedBy reloadGuard: SelectedTaskReloadGuard
    ) -> Bool {
        guard current.id == incoming.id,
              current.id == reloadGuard.taskID,
              current.isChecklistCompletionRoutine,
              incoming.isChecklistCompletionRoutine else {
            return false
        }

        return current.name == incoming.name
            && current.emoji == incoming.emoji
            && current.placeID == incoming.placeID
            && current.tags == incoming.tags
            && current.steps == incoming.steps
            && current.checklistItems == incoming.checklistItems
            && current.scheduleMode == incoming.scheduleMode
            && current.recurrenceRule == incoming.recurrenceRule
            && current.interval == incoming.interval
            && current.pausedAt == incoming.pausedAt
            && current.completedStepCount == incoming.completedStepCount
            && current.sequenceStartedAt == incoming.sequenceStartedAt
    }

    private func trackSelectedChecklistReloadGuardIfNeeded(
        for itemID: UUID,
        in state: inout State
    ) {
        guard let selectedTaskID = state.selectedTaskID,
              let detailState = state.routineDetailState,
              detailState.task.id == selectedTaskID,
              detailState.task.isChecklistCompletionRoutine,
              !detailState.task.isPaused,
              detailState.task.checklistItems.contains(where: { $0.id == itemID }),
              calendar.isDate(detailState.selectedDate ?? now, inSameDayAs: now) else {
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        let task = detailState.task
        if task.isChecklistItemCompleted(itemID) {
            state.pendingSelectedChecklistReloadGuardTaskID = task.isChecklistInProgress ? task.id : nil
            return
        }

        let alreadyCompletedToday = task.completedChecklistItemIDs.isEmpty
            && task.lastDone.map { calendar.isDate($0, inSameDayAs: now) } == true
        state.pendingSelectedChecklistReloadGuardTaskID = alreadyCompletedToday ? nil : task.id
    }

    private func trackSelectedChecklistUndoReloadGuardIfNeeded(in state: inout State) {
        guard let selectedTaskID = state.selectedTaskID,
              let detailState = state.routineDetailState,
              detailState.task.id == selectedTaskID,
              detailState.task.isChecklistCompletionRoutine else {
            state.pendingSelectedChecklistReloadGuardTaskID = nil
            return
        }

        state.pendingSelectedChecklistReloadGuardTaskID = detailState.task.id
    }

    private func hasDuplicateRoutineName(
        _ name: String,
        in context: ModelContext,
        excludingID: UUID? = nil
    ) throws -> Bool {
        guard let normalized = RoutineTask.normalizedName(name) else { return false }
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.contains { task in
            if let excludingID, task.id == excludingID {
                return false
            }
            return RoutineTask.normalizedName(task.name) == normalized
        }
    }

    private func enforceUniqueRoutineNames(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        var tasksByNormalizedName: [String: [RoutineTask]] = [:]
        var removedAny = false

        for task in tasks {
            guard let normalized = RoutineTask.normalizedName(task.name) else { continue }
            tasksByNormalizedName[normalized, default: []].append(task)
        }

        for sameNamedTasks in tasksByNormalizedName.values {
            guard sameNamedTasks.count > 1 else { continue }

            let keeper = preferredTaskToKeep(from: sameNamedTasks)
            for task in sameNamedTasks where task.id != keeper.id {
                let logs = try context.fetch(logsDescriptor(for: task.id))
                for log in logs {
                    context.delete(log)
                }
                context.delete(task)
                removedAny = true
            }
        }

        if removedAny {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    private func enforceUniquePlaceNames(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, task in
            guard let placeID = task.placeID else { return }
            partialResult[placeID, default: 0] += 1
        }

        var placesByNormalizedName: [String: [RoutinePlace]] = [:]
        var removedAny = false

        for place in places {
            guard let normalized = RoutinePlace.normalizedName(place.name) else { continue }
            placesByNormalizedName[normalized, default: []].append(place)
        }

        for sameNamedPlaces in placesByNormalizedName.values {
            guard sameNamedPlaces.count > 1 else { continue }

            let keeper = preferredPlaceToKeep(from: sameNamedPlaces, linkedCounts: linkedCounts)
            for place in sameNamedPlaces where place.id != keeper.id {
                for task in tasks where task.placeID == place.id {
                    task.placeID = keeper.id
                }
                context.delete(place)
                removedAny = true
            }
        }

        if removedAny {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    private func preferredTaskToKeep(from tasks: [RoutineTask]) -> RoutineTask {
        tasks.min { taskSelectionKey($0) < taskSelectionKey($1) } ?? tasks[0]
    }

    private func taskSelectionKey(_ task: RoutineTask) -> (Int, String, String) {
        let rawName = task.name ?? ""
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let whitespacePenalty = rawName == trimmedName ? 0 : 1
        let foldedName = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return (whitespacePenalty, foldedName, task.id.uuidString.lowercased())
    }

    private func preferredPlaceToKeep(
        from places: [RoutinePlace],
        linkedCounts: [UUID: Int]
    ) -> RoutinePlace {
        places.min { lhs, rhs in
            placeSelectionKey(lhs, linkedCounts: linkedCounts) < placeSelectionKey(rhs, linkedCounts: linkedCounts)
        } ?? places[0]
    }

    private func placeSelectionKey(
        _ place: RoutinePlace,
        linkedCounts: [UUID: Int]
    ) -> (Int, Int, Date, String, String) {
        let rawName = place.name
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedCountPenalty = -linkedCounts[place.id, default: 0]
        let whitespacePenalty = rawName == trimmedName ? 0 : 1
        let foldedName = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return (
            linkedCountPenalty,
            whitespacePenalty,
            place.createdAt,
            foldedName,
            place.id.uuidString.lowercased()
        )
    }

}

extension HomeFeature {
    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        RoutineLogHistory.detailLogs(taskID: taskID, context: context)
    }

    static func availableTags(from routineDisplays: [RoutineDisplay]) -> [String] {
        RoutineTag.allTags(from: routineDisplays.map(\.tags))
    }

    static func matchesSelectedTag(_ selectedTag: String?, in tags: [String]) -> Bool {
        guard let selectedTag else { return true }
        return RoutineTag.contains(selectedTag, in: tags)
    }
}
