import SwiftUI

struct StatsDataRefreshModifier: ViewModifier {
    let tasks: [RoutineTask]
    let logs: [RoutineLog]
    let focusSessions: [FocusSession]
    let sleepSessions: [SleepSession]
    let awaySessions: [AwaySession]
    let emotionLogs: [EmotionLog]
    let notes: [RoutineNote]
    let events: [RoutineEvent]
    let noteAttachmentNoteIDs: Set<UUID>
    let goals: [RoutineGoal]
    let places: [RoutinePlace]
    let placeCheckInSessions: [PlaceCheckInSession]
    let onAppear: () -> Void
    let onDataChanged: ([RoutineTask], [RoutineLog], [FocusSession], [SleepSession], [AwaySession], [EmotionLog], [RoutineNote], [RoutineEvent], Set<UUID>, [RoutineGoal], [RoutinePlace], [PlaceCheckInSession]) -> Void

    func body(content: Content) -> some View {
        content
            .task {
                onAppear()
                sendCurrentData()
            }
            .onChange(of: tasks) { _, newValue in
                onDataChanged(newValue, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: logs) { _, newValue in
                onDataChanged(tasks, newValue, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: focusSessions) { _, newValue in
                onDataChanged(tasks, logs, newValue, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: sleepSessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, newValue, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: awaySessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, newValue, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: emotionLogs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, newValue, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: notes) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, newValue, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: events) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, newValue, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: noteAttachmentNoteIDs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, events, newValue, goals, places, placeCheckInSessions)
            }
            .onChange(of: goals) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, newValue, places, placeCheckInSessions)
            }
            .onChange(of: places) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, newValue, placeCheckInSessions)
            }
            .onChange(of: placeCheckInSessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, newValue)
            }
    }

    private func sendCurrentData() {
        onDataChanged(tasks, logs, focusSessions, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
    }
}

extension View {
    func statsDataRefresh(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        emotionLogs: [EmotionLog],
        notes: [RoutineNote],
        events: [RoutineEvent],
        noteAttachmentNoteIDs: Set<UUID>,
        goals: [RoutineGoal],
        places: [RoutinePlace],
        placeCheckInSessions: [PlaceCheckInSession],
        onAppear: @escaping () -> Void,
        onDataChanged: @escaping ([RoutineTask], [RoutineLog], [FocusSession], [SleepSession], [AwaySession], [EmotionLog], [RoutineNote], [RoutineEvent], Set<UUID>, [RoutineGoal], [RoutinePlace], [PlaceCheckInSession]) -> Void
    ) -> some View {
        modifier(
            StatsDataRefreshModifier(
                tasks: tasks,
                logs: logs,
                focusSessions: focusSessions,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                emotionLogs: emotionLogs,
                notes: notes,
                events: events,
                noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                goals: goals,
                places: places,
                placeCheckInSessions: placeCheckInSessions,
                onAppear: onAppear,
                onDataChanged: onDataChanged
            )
        )
    }
}
