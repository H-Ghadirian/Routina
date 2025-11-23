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

        case addRoutineSheet(AddRoutineFeature.Action)
        case routineSavedSuccessfully(RoutineTask)
        case routineSaveFailed
    }

    private enum CancelID {
        case loadTasks
    }

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.modelContext) var modelContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
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
                return .none

            case .tasksLoadFailed:
                print("Failed to load tasks.")
                return .none

            case let .setAddRoutineSheet(isPresented):
                state.isAddRoutineSheetPresented = isPresented
                if isPresented {
                    state.addRoutineState = AddRoutineFeature.State()
                }
                return .none

            case let .deleteTasks(ids):
                let idSet = Set(ids)
                state.routineTasks.removeAll { idSet.contains($0.id) }
                state.routineDisplays.removeAll { idSet.contains($0.taskID) }

                return .run { @MainActor [ids] _ in
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
                    }
                    try? context.save()
                }

            case .addRoutineSheet(.delegate(.didCancel)):
                state.isAddRoutineSheetPresented = false
                return .none

            case let .addRoutineSheet(.delegate(.didSave(name, freq, emoji))):
                state.isAddRoutineSheetPresented = false

                return .run { @MainActor send in
                    do {
                        let context = self.modelContext()
                        let newRoutine = RoutineTask(
                            name: name,
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

    private func logsDescriptor(for taskID: UUID) -> FetchDescriptor<RoutineLog> {
        FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )
    }

    private func makeNotificationPayload(for task: RoutineTask) -> NotificationPayload {
        NotificationPayload(
            identifier: task.id.uuidString,
            name: task.name,
            interval: max(Int(task.interval), 1),
            lastDone: task.lastDone
        )
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
