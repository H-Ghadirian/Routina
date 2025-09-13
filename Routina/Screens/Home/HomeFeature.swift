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
        var tags: [String]
        var interval: Int
        var lastDone: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var isDoneToday: Bool
        var isPaused: Bool
        var doneCount: Int
    }

    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routineDisplays: [RoutineDisplay] = []
        var archivedRoutineDisplays: [RoutineDisplay] = []
        var doneStats: DoneStats = DoneStats()
        var isAddRoutineSheetPresented: Bool = false
        var addRoutineState: AddRoutineFeature.State?
    }

    enum Action: Equatable {
        case onAppear
        case tasksLoadedSuccessfully([RoutineTask], DoneStats)
        case tasksLoadFailed

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

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { @MainActor send in
                    do {
                        let context = ModelContext(self.modelContext().container)
                        try self.enforceUniqueRoutineNames(in: context)
                        _ = try RoutineLogHistory.backfillMissingLastDoneLogs(in: context)
                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
                        send(.tasksLoadedSuccessfully(tasks, self.makeDoneStats(tasks: tasks, logs: logs)))
                    } catch {
                        send(.tasksLoadFailed)
                    }
                }
                .cancellable(id: CancelID.loadTasks, cancelInFlight: true)

            case let .tasksLoadedSuccessfully(tasks, doneStats):
                state.routineTasks = tasks
                state.doneStats = doneStats
                refreshDisplays(&state)
                guard state.addRoutineState != nil else { return .none }
                return .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: tasks))))

            case .tasksLoadFailed:
                print("Failed to load tasks.")
                return .none

            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                if isPresented {
                    state.addRoutineState = AddRoutineFeature.State(
                        existingRoutineNames: existingRoutineNames(from: state.routineTasks)
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
                    NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                }
                guard state.addRoutineState != nil else { return deleteEffect }
                return .merge(
                    deleteEffect,
                    .send(.addRoutineSheet(.existingRoutineNamesChanged(existingRoutineNames(from: state.routineTasks))))
                )

            case let .markTaskDone(id):
                guard state.routineTasks.contains(where: { $0.id == id && !$0.isPaused }) else {
                    return .none
                }
                let completionDate = now
                let shouldCountNewDone = state.routineTasks.first(where: { $0.id == id }).flatMap(\.lastDone).map {
                    !calendar.isDate($0, inSameDayAs: completionDate)
                } ?? true

                if let index = state.routineTasks.firstIndex(where: { $0.id == id }) {
                    state.routineTasks[index].lastDone = completionDate
                    state.routineTasks[index].scheduleAnchor = completionDate
                }

                if let index = state.routineDisplays.firstIndex(where: { $0.taskID == id }) {
                    state.routineDisplays[index].lastDone = completionDate
                    state.routineDisplays[index].scheduleAnchor = completionDate
                    state.routineDisplays[index].isDoneToday = true
                    if shouldCountNewDone {
                        state.routineDisplays[index].doneCount += 1
                    }
                }

                if shouldCountNewDone {
                    state.doneStats.totalCount += 1
                    state.doneStats.countsByTaskID[id, default: 0] += 1
                }

                let currentCalendar = calendar
                return .run { @MainActor [id, completionDate, currentCalendar, shouldCountNewDone] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }

                        if !shouldCountNewDone {
                            await self.notificationClient.schedule(
                                NotificationCoordinator.notificationPayload(
                                    for: task,
                                    referenceDate: completionDate,
                                    calendar: currentCalendar
                                )
                            )
                            return
                        }

                        task.lastDone = completionDate
                        task.scheduleAnchor = completionDate
                        context.insert(RoutineLog(timestamp: completionDate, taskID: id))
                        try context.save()
                        await self.notificationClient.schedule(
                            NotificationCoordinator.notificationPayload(
                                for: task,
                                referenceDate: completionDate,
                                calendar: currentCalendar
                            )
                        )
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
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
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
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
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                    } catch {
                        print("Failed to resume routine from home list: \(error)")
                    }
                }

            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                return .none

            case let .addRoutineSheet(.delegate(.didSave(name, freq, emoji, tags))):
                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else {
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
                            tags: tags,
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
                NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
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
                onSave: { name, freq, emoji, tags in .send(.delegate(.didSave(name, freq, emoji, tags))) },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }
    }

    private func makeRoutineDisplay(_ task: RoutineTask, doneStats: DoneStats) -> RoutineDisplay {
        let doneTodayFromLastDone = task.lastDone.map { Calendar.current.isDateInToday($0) } ?? false

        return RoutineDisplay(
            taskID: task.id,
            name: task.name ?? "Unnamed task",
            emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
            tags: task.tags,
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone,
            scheduleAnchor: task.scheduleAnchor,
            pausedAt: task.pausedAt,
            isDoneToday: doneTodayFromLastDone,
            isPaused: task.isPaused,
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

    private func existingRoutineNames(from tasks: [RoutineTask]) -> [String] {
        tasks.compactMap(\.name)
    }

    private func refreshDisplays(_ state: inout State) {
        state.routineDisplays = state.routineTasks
            .filter { !$0.isPaused }
            .map { makeRoutineDisplay($0, doneStats: state.doneStats) }
        state.archivedRoutineDisplays = state.routineTasks
            .filter(\.isPaused)
            .map { makeRoutineDisplay($0, doneStats: state.doneStats) }
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
        guard let normalized = normalizedRoutineName(name) else { return false }
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.contains { task in
            if let excludingID, task.id == excludingID {
                return false
            }
            return normalizedRoutineName(task.name) == normalized
        }
    }

    private func enforceUniqueRoutineNames(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        var tasksByNormalizedName: [String: [RoutineTask]] = [:]
        var removedAny = false

        for task in tasks {
            guard let normalized = normalizedRoutineName(task.name) else { continue }
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
            NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
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

    private func normalizedRoutineName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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
