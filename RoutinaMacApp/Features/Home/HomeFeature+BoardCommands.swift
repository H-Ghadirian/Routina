import ComposableArchitecture
import Foundation
import SwiftData

extension HomeFeature {
    func handleDeleteTasks(_ ids: [UUID], state: inout State) -> Effect<Action> {
        var routineTasks = state.routineTasks
        var doneStats = state.doneStats
        var sprintBoardData: SprintBoardData? = state.sprintBoardData
        guard
            let deleteEffect = taskDeletionCoordinator().deleteTasks(
                ids: ids,
                tasks: &routineTasks,
                doneStats: &doneStats,
                sprintBoardData: &sprintBoardData
            )
        else { return .none }
        state.routineTasks = routineTasks
        state.doneStats = doneStats
        if let sprintBoardData {
            state.sprintBoardData = sprintBoardData
        }
        return postMutationRefresher().finishMutation(
            deleteEffect,
            state: &state,
            refreshAddRoutineAvailability: true
        )
    }

    func moveTaskInSection(
        taskID: UUID,
        sectionKey: String,
        orderedTaskIDs: [UUID],
        direction: MoveDirection,
        state: inout State
    ) -> Effect<Action> {
        guard
            let update = HomeTaskOrderingSupport.moveTaskInSection(
                taskID: taskID,
                sectionKey: sectionKey,
                orderedTaskIDs: orderedTaskIDs,
                direction: direction,
                tasks: &state.routineTasks
            )
        else { return .none }
        return postMutationRefresher().finishMutation(
            HomeTaskOrderingSupport.persistTaskOrder(
                update,
                failureMessage: "Failed to persist manual section order",
                modelContext: { self.modelContext() }
            ),
            state: &state
        )
    }

    func applySprintBoardLoaded(
        _ sprintBoardData: SprintBoardData,
        state: inout State
    ) -> Effect<Action> {
        state.sprintBoardData = sprintBoardData
        state.selectedBoardScope = HomeBoardMutationSupport.validatedScope(
            state.selectedBoardScope,
            in: sprintBoardData
        )
        refreshDisplays(&state)
        return .none
    }

    func setTaskOrderInSection(
        sectionKey: String,
        orderedTaskIDs: [UUID],
        state: inout State
    ) -> Effect<Action> {
        guard
            let update = HomeTaskOrderingSupport.setTaskOrderInSection(
                sectionKey: sectionKey,
                orderedTaskIDs: orderedTaskIDs,
                tasks: &state.routineTasks
            )
        else { return .none }
        return postMutationRefresher().finishMutation(
            HomeTaskOrderingSupport.persistTaskOrder(
                update,
                failureMessage: "Failed to persist board section order",
                modelContext: { self.modelContext() }
            ),
            state: &state
        )
    }

    func deleteCustomTaskSection(
        sectionID: UUID,
        state: inout State
    ) -> Effect<Action> {
        guard
            let update = HomeTaskLifecycleSupport.deleteCustomTaskSection(
                sectionID: sectionID,
                tasks: &state.routineTasks
            )
        else {
            return .none
        }

        return postMutationRefresher().finishMutation(
            persistDeletedCustomTaskSection(update),
            state: &state
        )
    }

    func pauseCustomTaskSectionTasks(
        _ taskIDs: [UUID],
        state: inout State
    ) -> Effect<Action> {
        guard
            let effect = taskLifecycleCoordinator().pauseTasks(
                taskIDs: taskIDs,
                tasks: &state.routineTasks
            )
        else {
            return .none
        }
        return postMutationRefresher().finishMutation(effect, state: &state)
    }

    func resumeCustomTaskSectionTasks(
        _ taskIDs: [UUID],
        state: inout State
    ) -> Effect<Action> {
        guard
            let effect = taskLifecycleCoordinator().resumeTasks(
                taskIDs: taskIDs,
                tasks: &state.routineTasks
            )
        else {
            return .none
        }
        return postMutationRefresher().finishMutation(effect, state: &state)
    }

    private func persistDeletedCustomTaskSection(
        _ update: HomeDeleteCustomTaskSectionUpdate
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                let changedTaskIDs = Set(update.taskIDs)
                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                    .filter { changedTaskIDs.contains($0.id) }

                for task in tasks {
                    if task.customTaskSectionID == update.sectionID {
                        task.customTaskSectionID = nil
                    }
                    var manualSectionOrders = task.manualSectionOrders
                    manualSectionOrders.removeValue(forKey: update.sectionKey)
                    task.manualSectionOrders = manualSectionOrders
                    DeviceActivityRecorder.recordAction(
                        .updated,
                        entity: .task,
                        entityID: task.id,
                        entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                        details: "Removed task from deleted custom section",
                        in: context
                    )
                }

                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to delete custom task section: \(error)")
            }
        }
    }

    func moveTaskToCustomSection(
        taskID: UUID,
        sectionID: UUID?,
        state: inout State
    ) -> Effect<Action> {
        guard let index = state.routineTasks.firstIndex(where: { $0.id == taskID }) else {
            return .none
        }

        let task = state.routineTasks[index]
        let plannedDate = task.plannedDate
        var manualSectionOrders = task.manualSectionOrders
        if let sectionID {
            let sectionKey = HomeCustomTaskSectionStorage.manualOrderSectionKey(for: sectionID)
            if manualSectionOrders[sectionKey] == nil {
                manualSectionOrders[sectionKey] = nextManualOrder(in: sectionKey, tasks: state.routineTasks)
            }
        }

        guard
            task.customTaskSectionID != sectionID
                || task.plannedDate != plannedDate
                || task.manualSectionOrders != manualSectionOrders
        else {
            return .none
        }

        task.customTaskSectionID = sectionID
        task.plannedDate = plannedDate
        task.manualSectionOrders = manualSectionOrders
        state.routineTasks[index] = task

        return postMutationRefresher().finishMutation(
            persistCustomTaskSectionAssignment(
                taskID: taskID,
                sectionID: sectionID,
                plannedDate: plannedDate,
                manualSectionOrders: manualSectionOrders
            ),
            state: &state
        )
    }

    private func persistCustomTaskSectionAssignment(
        taskID: UUID,
        sectionID: UUID?,
        plannedDate: Date?,
        manualSectionOrders: [String: Int]
    ) -> Effect<Action> {
        .run { @MainActor _ in
            do {
                let context = modelContext()
                guard let task = try context.fetch(HomeTaskSupport.taskDescriptor(for: taskID)).first else {
                    return
                }
                task.customTaskSectionID = sectionID
                task.plannedDate = plannedDate
                task.manualSectionOrders = manualSectionOrders
                DeviceActivityRecorder.recordAction(
                    .updated,
                    entity: .task,
                    entityID: taskID,
                    entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                    details: sectionID == nil ? "Cleared custom task section" : "Moved task to custom section",
                    in: context
                )
                try context.save()
                NotificationCenter.default.postRoutineDidUpdate()
            } catch {
                RoutinaLog.error("Failed to move task to custom section: \(error)")
            }
        }
    }

    static func boardSectionKey(for state: TodoState) -> String {
        switch state {
        case .ready, .paused:
            return "todoBoard.ready"
        case .inProgress:
            return "todoBoard.inProgress"
        case .blocked:
            return "todoBoard.blocked"
        case .done:
            return "todoBoard.done"
        }
    }

    func nextManualOrder(in sectionKey: String, tasks: [RoutineTask]) -> Int {
        let maxOrder = tasks.compactMap { $0.manualSectionOrders[sectionKey] }.max() ?? -1
        return maxOrder + 1
    }

    func loadSprintBoardEffect(revision: Int) -> Effect<Action> {
        .run { send in
            do {
                let sprintBoardData = try await sprintBoardClient.load()
                await send(.sprintBoardLoadedFromStorage(sprintBoardData, revision: revision))
            } catch {
                RoutinaLog.error("Failed to load sprint board data: \(error)")
                await send(.sprintBoardLoadedFromStorage(SprintBoardData(), revision: revision))
            }
        }
    }

    func saveSprintBoardEffect(_ sprintBoardData: SprintBoardData) -> Effect<Action> {
        .run { _ in
            do {
                try await sprintBoardClient.save(sprintBoardData)
                await MainActor.run {
                    NotificationCenter.default.postRoutineDidUpdate()
                }
            } catch {
                RoutinaLog.error("Failed to save sprint board data: \(error)")
            }
        }
    }
}
