import SwiftUI

struct TaskDetailFocusSessionSectionView: View {
    let task: RoutineTask
    let sessions: [FocusSession]
    let allTasks: [RoutineTask]
    let onCompletedDuration: ((TimeInterval) -> Void)?

    init(
        task: RoutineTask,
        sessions: [FocusSession],
        allTasks: [RoutineTask],
        onCompletedDuration: ((TimeInterval) -> Void)? = nil
    ) {
        self.task = task
        self.sessions = sessions
        self.allTasks = allTasks
        self.onCompletedDuration = onCompletedDuration
    }

    var body: some View {
        FocusSessionCard(
            task: task,
            sessions: sessions,
            allTasks: allTasks,
            onCompletedDuration: onCompletedDuration
        )
    }
}
