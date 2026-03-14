import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct HomeFeature {
    struct RoutineDisplay: Equatable, Identifiable {
        let taskID: UUID
        var id: UUID { taskID }
        var name: String
        var emoji: String
        var interval: Int
        var lastDone: Date?
        var isDoneToday: Bool
    }

    @ObservableState
    struct State: Equatable {
        var routineTasks: [RoutineTask] = []
        var routineDisplays: [RoutineDisplay] = []
        var isAddRoutineSheetPresented: Bool = false
        var addRoutineState: AddRoutineFeature.State?
    }

    enum Action: Equatable {
        case onAppear
        case tasksLoadedSuccessfully([RoutineTask])
        case tasksLoadFailed

        case setAddRoutineSheet(Bool)
        case deleteTasks([UUID])
        case markTaskDone(UUID)

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
                        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                        send(.tasksLoadedSuccessfully(tasks))
                    } catch {
                        send(.tasksLoadFailed)
                    }
                }
                .cancellable(id: CancelID.loadTasks, cancelInFlight: true)

            case let .tasksLoadedSuccessfully(tasks):
                state.routineTasks = tasks
                state.routineDisplays = tasks.map(makeRoutineDisplay)
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
                state.routineDisplays.removeAll { idSet.contains($0.taskID) }

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
                let completionDate = now

                if let index = state.routineTasks.firstIndex(where: { $0.id == id }) {
                    state.routineTasks[index].lastDone = completionDate
                }

                if let index = state.routineDisplays.firstIndex(where: { $0.taskID == id }) {
                    state.routineDisplays[index].lastDone = completionDate
                    state.routineDisplays[index].isDoneToday = true
                }

                let currentCalendar = calendar
                return .run { @MainActor [id, completionDate, currentCalendar] _ in
                    do {
                        let context = self.modelContext()
                        guard let task = try context.fetch(taskDescriptor(for: id)).first else { return }

                        if let lastDone = task.lastDone,
                           currentCalendar.isDate(lastDone, inSameDayAs: completionDate) {
                            await self.notificationClient.schedule(NotificationCoordinator.notificationPayload(for: task))
                            return
                        }

                        task.lastDone = completionDate
                        context.insert(RoutineLog(timestamp: completionDate, taskID: id))
                        try context.save()
                        await self.notificationClient.schedule(NotificationCoordinator.notificationPayload(for: task))
                        NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                    } catch {
                        print("Failed to mark routine as done from home list: \(error)")
                    }
                }

            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                return .none

            case let .addRoutineSheet(.delegate(.didSave(name, freq, emoji))):
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
                            interval: Int16(freq),
                            lastDone: nil
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
                state.routineDisplays.append(makeRoutineDisplay(task))
                state.isAddRoutineSheetPresented = false
                state.addRoutineState = nil
                NotificationCenter.default.post(name: Notification.Name("routineDidUpdate"), object: nil)
                let payload = makeNotificationPayload(for: task)
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
                onSave: { name, freq, emoji in .send(.delegate(.didSave(name, freq, emoji))) },
                onCancel: { .send(.delegate(.didCancel)) }
            )
        }
    }

    private func makeRoutineDisplay(_ task: RoutineTask) -> RoutineDisplay {
        let doneTodayFromLastDone = task.lastDone.map { Calendar.current.isDateInToday($0) } ?? false

        return RoutineDisplay(
            taskID: task.id,
            name: task.name ?? "Unnamed task",
            emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone,
            isDoneToday: doneTodayFromLastDone
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

    private func makeNotificationPayload(for task: RoutineTask) -> NotificationPayload {
        NotificationCoordinator.notificationPayload(for: task)
    }

    private func existingRoutineNames(from tasks: [RoutineTask]) -> [String] {
        tasks.compactMap(\.name)
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
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }
}
