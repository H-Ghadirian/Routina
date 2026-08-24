import SwiftUI

enum TaskDetailFocusSessionSectionVisibility {
    static func shouldShow(
        for task: RoutineTask,
        sessions: [FocusSession]
    ) -> Bool {
        task.focusModeEnabled || sessions.contains { session in
            session.taskID == task.id
                && (session.state == .active || session.state == .completed)
        }
    }
}

struct TaskDetailFocusSessionSectionView: View {
    let task: RoutineTask
    let sessions: [FocusSession]
    let allTasks: [RoutineTask]
    let blockingFocusTitle: String?

    init(
        task: RoutineTask,
        sessions: [FocusSession],
        allTasks: [RoutineTask],
        blockingFocusTitle: String? = nil
    ) {
        self.task = task
        self.sessions = sessions
        self.allTasks = allTasks
        self.blockingFocusTitle = blockingFocusTitle
    }

    var body: some View {
        FocusSessionCard(
            task: task,
            sessions: sessions,
            allTasks: allTasks,
            blockingFocusTitle: blockingFocusTitle
        )
    }
}
