import SwiftUI

struct HomeMacTodoBoardTaskMenuItems: View {
    let task: HomeFeature.RoutineDisplay
    let availableBacklogs: [BoardBacklog]
    let availableSprints: [BoardSprint]
    let activeSprints: [BoardSprint]
    let onMoveTask: (UUID, TodoState) -> Void
    let onAssignTaskToBacklog: (UUID, UUID?) -> Void
    let onAssignTaskToSprint: (UUID, UUID?) -> Void

    var body: some View {
        if task.todoState != .ready {
            Button("Move to Ready") {
                onMoveTask(task.id, .ready)
            }
        }
        if task.todoState != .paused {
            Button("Pause") {
                onMoveTask(task.id, .paused)
            }
        }
        if task.todoState != .inProgress {
            Button("Move to In Progress") {
                onMoveTask(task.id, .inProgress)
            }
        }
        if task.todoState != .blocked {
            Button("Move to Blocked") {
                onMoveTask(task.id, .blocked)
            }
        }
        if task.todoState != .done {
            Button("Mark Done") {
                onMoveTask(task.id, .done)
            }
        }

        Divider()

        backlogMenuItems
        activeSprintMenuItems

        if !availableSprints.isEmpty {
            Menu("Assign to Sprint") {
                ForEach(availableSprints) { sprint in
                    Button(sprint.title) {
                        onAssignTaskToSprint(task.id, sprint.id)
                    }
                    .disabled(task.assignedSprintID == sprint.id)
                }
            }
        }
    }

    @ViewBuilder
    private var backlogMenuItems: some View {
        if availableBacklogs.isEmpty {
            Button("Move to Backlog") {
                onAssignTaskToBacklog(task.id, nil)
            }
            .disabled(task.assignedSprintID == nil && task.assignedBacklogID == nil)
        } else {
            Menu("Move to Backlog") {
                Button("Backlog") {
                    onAssignTaskToBacklog(task.id, nil)
                }
                .disabled(task.assignedSprintID == nil && task.assignedBacklogID == nil)

                ForEach(availableBacklogs) { backlog in
                    Button(backlog.title) {
                        onAssignTaskToBacklog(task.id, backlog.id)
                    }
                    .disabled(task.assignedSprintID == nil && task.assignedBacklogID == backlog.id)
                }
            }
        }
    }

    @ViewBuilder
    private var activeSprintMenuItems: some View {
        if activeSprints.count == 1,
           let activeSprint = activeSprints.first,
           task.assignedSprintID != activeSprint.id {
            Button("Assign to \(activeSprint.title)") {
                onAssignTaskToSprint(task.id, activeSprint.id)
            }
        } else if activeSprints.count > 1 {
            Menu("Assign to Active Sprint") {
                ForEach(activeSprints) { sprint in
                    Button(sprint.title) {
                        onAssignTaskToSprint(task.id, sprint.id)
                    }
                    .disabled(task.assignedSprintID == sprint.id)
                }
            }
        }
    }
}
