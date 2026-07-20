import SwiftUI

extension HomeTCAView {
    var homeTaskRowCommandHandler: HomeTaskRowCommandHandler {
        HomeTaskRowCommandHandler(
            open: { openTask($0) },
            resume: { store.send(.resumeTask($0)) },
            markDone: { store.send(.markTaskDone($0)) },
            markMissed: { store.send(.markTaskMissed($0)) },
            markCanceled: { store.send(.markTaskCanceled($0)) },
            notToday: { store.send(.notTodayTask($0)) },
            pause: { store.send(.pauseTask($0)) },
            moveTaskInSection: { taskID, sectionKey, orderedTaskIDs, direction in
                store.send(
                    .moveTaskInSection(
                        taskID: taskID,
                        sectionKey: sectionKey,
                        orderedTaskIDs: orderedTaskIDs,
                        direction: direction
                    )
                )
            },
            pin: { store.send(.pinTask($0)) },
            unpin: { store.send(.unpinTask($0)) },
            delete: { deleteTask($0) }
        )
    }

    func routineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool = true,
        moveContext: HomeTaskListMoveContext? = nil
    ) -> some View {
        platformRoutineNavigationRow(
            for: task,
            rowNumber: rowNumber,
            includeMarkDone: includeMarkDone,
            moveContext: moveContext
        )
    }

    @ViewBuilder
    func routineContextMenu(
        for task: HomeFeature.RoutineDisplay,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext? = nil
    ) -> some View {
        let presentation = HomeTaskRowActionPresentation.make(
            for: task,
            includeMarkDone: includeMarkDone,
            moveContext: moveContext,
            allowsPinning: true
        )

        Button {
            homeTaskRowCommandHandler.handle(presentation.openCommand)
        } label: {
            Label("Open", systemImage: "arrow.right.circle")
        }

        ForEach(presentation.lifecycleActions) { action in
            Button {
                homeTaskRowCommandHandler.handle(action.command(taskID: task.taskID))
            } label: {
                Label(action.title, systemImage: action.systemImage)
            }
            .disabled(action.isDisabled)
        }

        if !presentation.moveActions.isEmpty {
            Divider()

            ForEach(presentation.moveActions) { action in
                Button {
                    homeTaskRowCommandHandler.handle(action.command(taskID: task.taskID))
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .disabled(action.isDisabled)
            }
        }

        let supportsPlanning = RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: task.scheduleMode,
            trackingCadenceEnabled: task.trackingCadenceEnabled,
            isDailyRoutine: task.isDailyRoutine
        )

        if supportsPlanning || presentation.notTodayCommand != nil {
            Divider()

            Menu {
                if supportsPlanning {
                    Button {
                        store.send(.planTask(task.taskID, Date()))
                    } label: {
                        Label("Today", systemImage: "calendar")
                    }

                    Button {
                        presentPlanningDatePicker(for: task)
                    } label: {
                        Label("Choose Date...", systemImage: "calendar.badge.plus")
                    }

                    if task.plannedDate != nil {
                        Button {
                            store.send(.planTask(task.taskID, nil))
                        } label: {
                            Label("Clear Plan", systemImage: "xmark.circle")
                        }
                    }
                }

                if supportsPlanning, presentation.notTodayCommand != nil {
                    Divider()
                }

                if let notTodayCommand = presentation.notTodayCommand {
                    Button {
                        homeTaskRowCommandHandler.handle(notTodayCommand)
                    } label: {
                        Label("Not today", systemImage: "moon.zzz")
                    }
                }
            } label: {
                Label("Plan to do", systemImage: "calendar.badge.clock")
            }
        }

        if let pinAction = presentation.pinAction {
            Button {
                homeTaskRowCommandHandler.handle(pinAction.command)
            } label: {
                Label(pinAction.title, systemImage: pinAction.systemImage)
            }
        }

        Button(role: .destructive) {
            homeTaskRowCommandHandler.handle(presentation.deleteCommand)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    var planningDatePickerPresentedBinding: Binding<Bool> {
        Binding(
            get: { planningDateTaskID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissPlanningDatePicker()
                }
            }
        )
    }

    func presentPlanningDatePicker(for task: HomeFeature.RoutineDisplay) {
        planningDateTaskID = task.taskID
        planningDateDraft = task.plannedDate ?? Date()
    }

    func savePlanningDatePicker() {
        guard let taskID = planningDateTaskID else { return }
        store.send(.planTask(taskID, planningDateDraft))
        dismissPlanningDatePicker()
    }

    func dismissPlanningDatePicker() {
        planningDateTaskID = nil
    }
}
