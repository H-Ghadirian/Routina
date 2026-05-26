import SwiftUI

struct StatsDataRefreshModifier: ViewModifier {
    let tasks: [RoutineTask]
    let logs: [RoutineLog]
    let focusSessions: [FocusSession]
    let emotionLogs: [EmotionLog]
    let notes: [RoutineNote]
    let noteAttachmentNoteIDs: Set<UUID>
    let goals: [RoutineGoal]
    let onAppear: () -> Void
    let onDataChanged: ([RoutineTask], [RoutineLog], [FocusSession], [EmotionLog], [RoutineNote], Set<UUID>, [RoutineGoal]) -> Void

    func body(content: Content) -> some View {
        content
            .task {
                onAppear()
                sendCurrentData()
            }
            .onChange(of: tasks) { _, newValue in
                onDataChanged(newValue, logs, focusSessions, emotionLogs, notes, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: logs) { _, newValue in
                onDataChanged(tasks, newValue, focusSessions, emotionLogs, notes, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: focusSessions) { _, newValue in
                onDataChanged(tasks, logs, newValue, emotionLogs, notes, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: emotionLogs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, newValue, notes, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: notes) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, emotionLogs, newValue, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: noteAttachmentNoteIDs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, emotionLogs, notes, newValue, goals)
            }
            .onChange(of: goals) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, emotionLogs, notes, noteAttachmentNoteIDs, newValue)
            }
    }

    private func sendCurrentData() {
        onDataChanged(tasks, logs, focusSessions, emotionLogs, notes, noteAttachmentNoteIDs, goals)
    }
}

extension View {
    func statsDataRefresh(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        emotionLogs: [EmotionLog],
        notes: [RoutineNote],
        noteAttachmentNoteIDs: Set<UUID>,
        goals: [RoutineGoal],
        onAppear: @escaping () -> Void,
        onDataChanged: @escaping ([RoutineTask], [RoutineLog], [FocusSession], [EmotionLog], [RoutineNote], Set<UUID>, [RoutineGoal]) -> Void
    ) -> some View {
        modifier(
            StatsDataRefreshModifier(
                tasks: tasks,
                logs: logs,
                focusSessions: focusSessions,
                emotionLogs: emotionLogs,
                notes: notes,
                noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                goals: goals,
                onAppear: onAppear,
                onDataChanged: onDataChanged
            )
        )
    }
}
