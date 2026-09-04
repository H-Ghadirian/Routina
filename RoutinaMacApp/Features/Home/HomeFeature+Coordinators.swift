import ComposableArchitecture
import Foundation

extension HomeFeature {
    enum CancelID {
        case loadTasks
    }

    func taskLifecycleCoordinator() -> HomeTaskLifecycleCoordinator<Action> {
        HomeTaskLifecycleCoordinator(
            referenceDate: { self.now },
            calendar: calendar,
            modelContext: { self.modelContext() },
            cancelNotification: { identifier in
                await self.notificationClient.cancel(identifier)
            },
            scheduleNotification: { payload in
                await self.notificationClient.schedule(payload)
            }
        )
    }

    func taskDeletionCoordinator() -> HomeTaskDeletionCoordinator<Action> {
        HomeTaskDeletionCoordinator(
            modelContext: { self.modelContext() },
            saveSprintBoardData: { sprintBoardData in
                try? await self.sprintBoardClient.save(sprintBoardData)
            },
            cancelNotification: { identifier in
                await self.notificationClient.cancel(identifier)
            }
        )
    }

    func filterMutationHandler() -> HomeFeatureFilterMutationHandler<State, Action> {
        HomeFeatureFilterMutationHandler(
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            }
        )
    }

    func taskLoadHandler() -> HomeFeatureTaskLoadHandler<State, Action> {
        HomeFeatureTaskLoadHandler(
            relatedTagRules: { appSettingsClient.relatedTagRules() },
            flagRules: { appSettingsClient.flagRules() },
            definedFlags: { appSettingsClient.definedFlags() },
            tagColors: { appSettingsClient.tagColors() },
            calendar: { calendar },
            refreshDisplays: { state in refreshDisplays(&state) },
            syncSelectedTaskDetailState: { state in selectionRouter().refreshSelectedTaskDetailState(&state) },
            validateFilterState: { state in filterMutationHandler().validateFilterState(&state) },
            persistTemporaryViewState: { state in persistTemporaryViewState(state) },
            refreshSelectedTaskDetailEffect: { state in selectionRouter().refreshSelectedTaskDetailEffect(for: state) },
            addRoutineAction: { .addRoutineSheet($0) }
        )
    }

    func taskLoadEffectFactory() -> HomeFeatureTaskLoadEffectFactory<Action, CancelID> {
        HomeFeatureTaskLoadEffectFactory(
            calendar: calendar,
            cancelID: CancelID.loadTasks,
            modelContext: { self.modelContext() },
            loadedAction: { .tasksLoadedSuccessfully($0, $1, $2, $3, $4) },
            failedAction: { .tasksLoadFailed }
        )
    }

    func postMutationRefresher() -> HomeFeaturePostMutationRefresher<State, Action> {
        HomeFeaturePostMutationRefresher(
            refreshDisplays: { state in refreshDisplays(&state) },
            syncSelectedTaskDetailState: { state in selectionRouter().refreshSelectedTaskDetailState(&state) },
            definedFlags: { appSettingsClient.definedFlags() },
            addRoutineAction: { .addRoutineSheet($0) }
        )
    }

    func selectionRouter() -> HomeFeatureSelectionRouter<State, Action> {
        HomeFeatureSelectionRouter(
            now: now,
            calendar: calendar,
            makeTaskDetailState: makeTaskDetailState(for:),
            refreshDisplays: { state in refreshDisplays(&state) },
            refreshTaskDetailAction: { .taskDetail(.onAppear) },
            definedFlags: { appSettingsClient.definedFlags() },
            synchronizePlatformSelection: { state, taskID in
                if state.macSidebarMode == .routines || state.macSidebarMode == .board {
                    state.macSidebarSelection = taskID.map(MacSidebarSelection.task)
                }
            }
        )
    }

    func taskDetailActionRouter() -> HomeFeatureTaskDetailActionRouter<State, Action> {
        HomeFeatureTaskDetailActionRouter(
            clearTaskSelection: { state in
                selectionRouter().clearTaskSelection(&state)
            },
            updatePendingChecklistReloadGuard: { itemID, state in
                selectionRouter().updatePendingChecklistReloadGuard(for: itemID, state: &state)
            },
            updatePendingChecklistUndoReloadGuard: { state in
                selectionRouter().updatePendingChecklistUndoReloadGuard(&state)
            },
            syncSelectedTaskFromTaskDetail: { state in
                selectionRouter().syncSelectedTaskFromTaskDetail(&state)
            },
            syncSelectedTaskLogs: { logs, state in
                syncSelectedTaskLogs(logs, state: &state)
            },
            openLinkedTask: { taskID, state in
                selectionRouter().openLinkedTask(taskID, state: &state)
            },
            openLinkedTaskSheet: { state in
                addRoutinePresentationRouter().openLinkedTaskSheet(state: &state)
            }
        )
    }

    func addRoutinePresentationRouter() -> HomeFeatureAddRoutinePresentationRouter<State> {
        HomeFeatureAddRoutinePresentationRouter(
            tagCounterDisplayMode: { appSettingsClient.tagCounterDisplayMode() },
            relatedTagRules: { appSettingsClient.relatedTagRules() },
            definedFlags: { appSettingsClient.definedFlags() },
            flagRules: { appSettingsClient.flagRules() },
            addRoutineDraft: { AddRoutineDraftSnapshot.load(client: creationDraftClient) },
            referenceDate: { now },
            calendar: calendar
        )
    }

    func addRoutineActionHandler() -> HomeFeatureAddRoutineActionHandler<State, Action> {
        HomeFeatureAddRoutineActionHandler(
            referenceDate: now,
            calendar: calendar,
            dismissSheet: { state in
                addRoutinePresentationRouter().dismissSheet(state: &state)
                if state.macSidebarMode == .addTask {
                    state.navigation.leaveAddTask()
                    state.presentation.isMacFilterDetailPresented = false
                    persistTemporaryViewState(state)
                }
            },
            modelContext: { self.modelContext() },
            scheduleAnchor: { self.now },
            scheduleNotification: { payload in
                await self.notificationClient.schedule(payload)
            },
            savedAction: { .routineSavedSuccessfully($0) },
            updateTaskLadderGroup: { taskID, isEnabled in
                var organization = appSettingsClient.taskLadderOrganization()
                guard organization.setTaskGroupEnabled(isEnabled, taskID: taskID) else { return }
                appSettingsClient.setTaskLadderOrganization(organization)
            },
            failedAction: { .routineSaveFailed },
            finishMutation: { effect, state in
                postMutationRefresher().finishMutation(effect, state: &state)
            },
            loadTasksEffect: { loadTasksEffect() },
            clearDraft: { creationDraftClient.clear(.task) }
        )
    }

    func presentationRouter() -> HomeFeaturePresentationRouter<State> {
        HomeFeaturePresentationRouter()
    }

    func taskListModeRouter() -> HomeFeatureTaskListModeRouter<State> {
        HomeFeatureTaskListModeRouter(
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            },
            synchronizePlatformSelectionAfterModeChange: { state in
                state.macSidebarSelection = nil
            }
        )
    }

    func macNavigationRouter() -> HomeFeatureMacNavigationRouter {
        HomeFeatureMacNavigationRouter(
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            }
        )
    }

    func macBoardCommandRouter() -> HomeFeatureMacBoardCommandRouter {
        HomeFeatureMacBoardCommandRouter(
            moveTodoToState: { id, newState, state in
                handleMoveTodoToState(id, newState: newState, state: &state)
            },
            moveTodoOnBoard: { taskID, targetState, orderedTaskIDs, state in
                handleMoveTodoOnBoard(
                    taskID: taskID,
                    targetState: targetState,
                    orderedTaskIDs: orderedTaskIDs,
                    state: &state
                )
            },
            createBacklog: { title, state in
                handleCreateBacklogConfirmed(title: title, state: &state)
            },
            createSprint: { title, state in
                handleCreateSprintConfirmed(title: title, state: &state)
            },
            startSprint: { sprintID, state in
                handleStartSprint(sprintID, state: &state)
            },
            finishSprint: { sprintID, state in
                handleFinishSprint(sprintID, state: &state)
            },
            assignTodoToBacklog: { taskID, backlogID, state in
                handleAssignTodoToBacklog(taskID: taskID, backlogID: backlogID, state: &state)
            },
            assignTodosToBacklog: { taskIDs, backlogID, state in
                handleAssignTodosToBacklog(taskIDs: taskIDs, backlogID: backlogID, state: &state)
            },
            assignTodoToSprint: { taskID, sprintID, state in
                handleAssignTodoToSprint(taskID: taskID, sprintID: sprintID, state: &state)
            },
            assignTodosToSprint: { taskIDs, sprintID, state in
                handleAssignTodosToSprint(taskIDs: taskIDs, sprintID: sprintID, state: &state)
            },
            renameSprint: { id, title, state in
                handleRenameSprint(id: id, title: title, state: &state)
            },
            deleteSprint: { id, state in
                handleDeleteSprint(id: id, state: &state)
            }
        )
    }

    func taskLifecycleCommandRouter() -> HomeFeatureTaskLifecycleCommandRouter<State, Action> {
        HomeFeatureTaskLifecycleCommandRouter(
            markDone: { id, tasks, doneStats in
                taskLifecycleCoordinator().markTaskDone(
                    taskID: id,
                    tasks: &tasks,
                    doneStats: &doneStats
                )
            },
            markMissed: { id, tasks, doneStats in
                taskLifecycleCoordinator().markTaskMissed(
                    taskID: id,
                    tasks: tasks,
                    doneStats: &doneStats
                )
            },
            confirmAssumedDone: { id, tasks, doneStats in
                taskLifecycleCoordinator().confirmAssumedTaskDone(
                    taskID: id,
                    tasks: tasks,
                    doneStats: &doneStats
                )
            },
            markAssumedMissed: { id, tasks, doneStats in
                taskLifecycleCoordinator().markAssumedTaskMissed(
                    taskID: id,
                    tasks: tasks,
                    doneStats: &doneStats
                )
            },
            markCanceled: { id, tasks, doneStats in
                taskLifecycleCoordinator().markTaskCanceled(
                    taskID: id,
                    tasks: tasks,
                    doneStats: &doneStats
                )
            },
            pause: { id, tasks in
                taskLifecycleCoordinator().pauseTask(taskID: id, tasks: &tasks)
            },
            resume: { id, tasks in
                taskLifecycleCoordinator().resumeTask(taskID: id, tasks: &tasks)
            },
            notToday: { id, tasks in
                taskLifecycleCoordinator().notTodayTask(taskID: id, tasks: &tasks)
            },
            pin: { id, tasks in
                taskLifecycleCoordinator().pinTask(taskID: id, tasks: &tasks)
            },
            plan: { id, plannedDate, tasks in
                taskLifecycleCoordinator().planTask(
                    taskID: id,
                    plannedDate: plannedDate,
                    tasks: &tasks
                )
            },
            unpin: { id, tasks in
                taskLifecycleCoordinator().unpinTask(taskID: id, tasks: &tasks)
            },
            finishMutation: { effect, state in
                postMutationRefresher().finishMutation(effect, state: &state)
            }
        )
    }

    func lifecycleActionHandler() -> HomeFeatureLifecycleActionHandler<State, Action> {
        HomeFeatureLifecycleActionHandler(
            temporaryViewState: { appSettingsClient.temporaryViewState() },
            applyTemporaryViewState: { persistedState, state in
                applyTemporaryViewState(persistedState, to: &state)
            },
            tagColors: { appSettingsClient.tagColors() },
            refreshDisplays: { state in
                refreshDisplays(&state)
            },
            setHideUnavailableRoutines: { isHidden in
                appSettingsClient.setHideUnavailableRoutines(isHidden)
            },
            persistTemporaryViewState: { state in
                persistTemporaryViewState(state)
            },
            loadOnAppearEffect: { state in
                .concatenate(
                    loadTasksEffect(),
                    loadSprintBoardEffect(revision: state.board.sprintBoardRevision),
                    .run { @MainActor send in
                        let snapshot = await self.locationClient.snapshot(false)
                        send(.locationSnapshotUpdated(snapshot))
                    }
                )
            },
            manualRefreshEffect: {
                HomeFeatureLifecycleEffectSupport.manualRefreshEffect(
                    modelContext: { self.modelContext() },
                    pullLatestIntoLocalStore: { try await self.cloudSyncClient.pullLatestIntoLocalStore($0) },
                    sleepBeforeSecondRefresh: { try await self.clock.sleep(for: .seconds(2)) },
                    onAppearAction: { .onAppear },
                    refreshFailedAction: { .manualRefreshFailed($0) }
                )
            }
        )
    }

    func automaticPlaceCheckInEffect(for snapshot: LocationSnapshot) -> Effect<Action> {
        guard appSettingsClient.placesEnabled(),
            appSettingsClient.automaticPlaceCheckInEnabled()
        else {
            return .run { @MainActor _ in
                do {
                    _ = try PlaceCheckInSupport.endActiveAutomaticSession(in: self.modelContext())
                } catch {
                    NSLog("Ending automatic place check-in failed: \(error.localizedDescription)")
                }
            }
        }

        guard snapshot.canDeterminePresence, let coordinate = snapshot.coordinate else {
            return .none
        }

        let horizontalAccuracyMeters = snapshot.horizontalAccuracy
        return .run { @MainActor _ in
            do {
                _ = try PlaceCheckInSupport.reconcileAutomaticCheckIn(
                    coordinate: coordinate,
                    horizontalAccuracyMeters: horizontalAccuracyMeters,
                    in: self.modelContext()
                )
            } catch {
                NSLog("Automatic place check-in failed: \(error.localizedDescription)")
            }
        }
    }
}
