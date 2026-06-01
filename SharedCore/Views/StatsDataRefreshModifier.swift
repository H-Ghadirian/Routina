import SwiftUI

struct StatsDataRefreshModifier: ViewModifier {
    let tasks: [RoutineTask]
    let logs: [RoutineLog]
    let focusSessions: [FocusSession]
    let awaySessions: [AwaySession]
    let emotionLogs: [EmotionLog]
    let notes: [RoutineNote]
    let events: [RoutineEvent]
    let noteAttachmentNoteIDs: Set<UUID>
    let goals: [RoutineGoal]
    let onAppear: () -> Void
    let onDataChanged: ([RoutineTask], [RoutineLog], [FocusSession], [AwaySession], [EmotionLog], [RoutineNote], [RoutineEvent], Set<UUID>, [RoutineGoal]) -> Void

    func body(content: Content) -> some View {
        content
            .task {
                onAppear()
                sendCurrentData()
            }
            .onChange(of: tasks) { _, newValue in
                onDataChanged(newValue, logs, focusSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: logs) { _, newValue in
                onDataChanged(tasks, newValue, focusSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: focusSessions) { _, newValue in
                onDataChanged(tasks, logs, newValue, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: awaySessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, newValue, emotionLogs, notes, events, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: emotionLogs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, awaySessions, newValue, notes, events, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: notes) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, awaySessions, emotionLogs, newValue, events, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: events) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, awaySessions, emotionLogs, notes, newValue, noteAttachmentNoteIDs, goals)
            }
            .onChange(of: noteAttachmentNoteIDs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, awaySessions, emotionLogs, notes, events, newValue, goals)
            }
            .onChange(of: goals) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, newValue)
            }
    }

    private func sendCurrentData() {
        onDataChanged(tasks, logs, focusSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals)
    }
}

extension View {
    func statsDataRefresh(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        awaySessions: [AwaySession],
        emotionLogs: [EmotionLog],
        notes: [RoutineNote],
        events: [RoutineEvent],
        noteAttachmentNoteIDs: Set<UUID>,
        goals: [RoutineGoal],
        onAppear: @escaping () -> Void,
        onDataChanged: @escaping ([RoutineTask], [RoutineLog], [FocusSession], [AwaySession], [EmotionLog], [RoutineNote], [RoutineEvent], Set<UUID>, [RoutineGoal]) -> Void
    ) -> some View {
        modifier(
            StatsDataRefreshModifier(
                tasks: tasks,
                logs: logs,
                focusSessions: focusSessions,
                awaySessions: awaySessions,
                emotionLogs: emotionLogs,
                notes: notes,
                events: events,
                noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                goals: goals,
                onAppear: onAppear,
                onDataChanged: onDataChanged
            )
        )
    }
}
