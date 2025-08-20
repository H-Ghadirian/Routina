import SwiftUI

struct TaskDetailFocusSessionSectionView: View {
    let task: RoutineTask
    let sessions: [FocusSession]
    let allTasks: [RoutineTask]
    let blockingFocusTitle: String?
    let onCompletedDuration: ((TimeInterval) -> Void)?

    init(
        task: RoutineTask,
        sessions: [FocusSession],
        allTasks: [RoutineTask],
        blockingFocusTitle: String? = nil,
        onCompletedDuration: ((TimeInterval) -> Void)? = nil
    ) {
        self.task = task
        self.sessions = sessions
        self.allTasks = allTasks
        self.blockingFocusTitle = blockingFocusTitle
        self.onCompletedDuration = onCompletedDuration
    }

    var body: some View {
        FocusSessionCard(
            task: task,
            sessions: sessions,
            allTasks: allTasks,
            blockingFocusTitle: blockingFocusTitle,
            onCompletedDuration: onCompletedDuration
        )
    }
}
