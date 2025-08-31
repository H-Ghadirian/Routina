import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
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
        var lastDone: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var isDoneToday: Bool
        var isPaused: Bool
        var completedStepCount: Int
        var isInProgress: Bool
        var nextStepTitle: String?
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
        var isAddRoutineSheetPresented: Bool = false
        var locationSnapshot = LocationSnapshot(
            authorizationStatus: .notDetermined,
            coordinate: nil,
            horizontalAccuracy: nil,
            timestamp: nil
        )
        var hideUnavailableRoutines: Bool = false
        var addRoutineState: AddRoutineFeature.State?
    }

    enum Action: Equatable {
        case onAppear
        case tasksLoadedSuccessfully([RoutineTask], [RoutinePlace], DoneStats)
        case tasksLoadFailed
        case locationSnapshotUpdated(LocationSnapshot)
        case hideUnavailableRoutinesChanged(Bool)

        case setAddRoutineSheet(Bool)
        case deleteTasks([UUID])
        case markTaskDone(UUID)
        case pauseTask(UUID)
        case resumeTask(UUID)

        case addRoutineSheet(AddRoutineFeature.Action)
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
                let loadTasksEffect = loadTasksEffect()
#if os(macOS)
                return loadTasksEffect
#else
                return .concatenate(
                    loadTasksEffect,
                    .run { @MainActor send in
                        let snapshot = await self.locationClient.snapshot(false)
                        send(.locationSnapshotUpdated(snapshot))
                    }
                )
#endif

            case let .tasksLoadedSuccessfully(tasks, places, doneStats):
                state.routineTasks = tasks
                state.routinePlaces = places
                state.doneStats = doneStats
                refreshDisplays(&state)
                guard state.addRoutineState != nil else { return .none }
                return .concatenate(
                    .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: tasks)))),
                    .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: places, linkedTo: tasks))))
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

            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                if isPresented {
                    state.addRoutineState = AddRoutineFeature.State(
                        existingRoutineNames: existingRoutineNames(from: state.routineTasks),
                        availablePlaces: RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks)
                    )
                } else {
                    state.addRoutineState = nil
                }
                return .none

            case let .deleteTasks(ids):
                let idSet = Set(ids)
                state.routineTasks.removeAll { idSet.contains($0.id) }
                var removedDoneCount = 0
                for id in ids {
                    removedDoneCount += state.doneStats.countsByTaskID[id, default: 0]
                    state.doneStats.countsByTaskID.removeValue(forKey: id)
                }
                state.doneStats.totalCount = max(state.doneStats.totalCount - removedDoneCount, 0)
                refreshDisplays(&state)

                let deleteEffect: Effect<Action> = .run { @MainActor [ids] _ in
                    let context = self.modelContext()
                    for id in ids {
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
                    .send(.addRoutineSheet(.availablePlacesChanged(RoutinePlace.summaries(from: state.routinePlaces, linkedTo: state.routineTasks))))
                )

            case let .markTaskDone(id):
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id && !$0.isPaused }) else {
                    return .none
                }
                let completionDate = now
                let result = state.routineTasks[index].advance(completedAt: completionDate, calendar: calendar)
                if case .completedRoutine = result {
                    state.doneStats.totalCount += 1
                    state.doneStats.countsByTaskID[id, default: 0] += 1
                }
                refreshDisplays(&state)

                let currentCalendar = calendar
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
                        await self.notificationClient.schedule(
                            NotificationCoordinator.notificationPayload(
                                for: taskState.task,
                                referenceDate: completionDate,
                                calendar: currentCalendar
                            )
                        )
                        NotificationCenter.default.postRoutineDidUpdate()
                    } catch {
                        print("Failed to mark routine as done from home list: \(error)")
                    }
                }

            case let .pauseTask(id):
                let pauseDate = now
                guard let index = state.routineTasks.firstIndex(where: { $0.id == id }) else { return .none }
                guard !state.routineTasks[index].isPaused else { return .none }

                if state.routineTasks[index].scheduleAnchor == nil {
                    state.routineTasks[index].scheduleAnchor = RoutineDateMath.effectiveScheduleAnchor(
                        for: state.routineTasks[index],
                        referenceDate: pauseDate
                    )
                }
                state.routineTasks[index].pausedAt = pauseDate
                refreshDisplays(&state)

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
                guard state.routineTasks[index].isPaused else { return .none }

                state.routineTasks[index].scheduleAnchor = RoutineDateMath.resumedScheduleAnchor(
                    for: state.routineTasks[index],
                    resumedAt: resumeDate
                )
                state.routineTasks[index].pausedAt = nil
                refreshDisplays(&state)

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

            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                return .none

            case let .addRoutineSheet(.delegate(.didSave(name, freq, emoji, placeID, tags, steps))):
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
                            interval: Int16(freq),
                            lastDone: nil,
                            scheduleAnchor: self.now
                        )
                        context.insert(newRoutine)
                        try context.save()
                        send(.routineSavedSuccessfully(newRoutine))
                    } catch {
                        send(.routineSaveFailed)
                    }
                }

            case let .routineSavedSuccessfully(task):
                state.routineTasks.append(task)
                refreshDisplays(&state)
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                NotificationCenter.default.postRoutineDidUpdate()
                let payload = makeNotificationPayload(for: task, referenceDate: now)
                return .run { _ in
                    await self.notificationClient.schedule(payload)
                }

            case .routineSaveFailed:
                print("Failed to save routine.")
                return .none

            case .addRoutineSheet:
                return .none
            }
        }
        .ifLet(\.addRoutineState, action: \.addRoutineSheet) {
            AddRoutineFeature(
                onSave: { name, freq, emoji, placeID, tags, steps in
                    .send(.delegate(.didSave(name, freq, emoji, placeID, tags, steps)))
                },
                onCancel: { .send(.delegate(.didCancel)) }
            )
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
            lastDone: task.lastDone,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            isDoneToday: doneTodayFromLastDone,
            isPaused: task.isPaused,
            completedStepCount: task.completedSteps,
            isInProgress: task.isInProgress,
            nextStepTitle: task.nextStepTitle,
            doneCount: doneStats.countsByTaskID[task.id, default: 0]
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

            if task.isPaused {
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
