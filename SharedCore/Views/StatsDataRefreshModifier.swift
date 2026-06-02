import SwiftUI

struct StatsDataRefreshModifier: ViewModifier {
    let tasks: [RoutineTask]
    let logs: [RoutineLog]
    let focusSessions: [FocusSession]
    let sprintFocusSessions: [SprintFocusSessionRecord]
    let boardSprints: [BoardSprintRecord]
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
    let onDataChanged: ([RoutineTask], [RoutineLog], [FocusSession], [SprintFocusSessionRecord], [BoardSprintRecord], [SleepSession], [AwaySession], [EmotionLog], [RoutineNote], [RoutineEvent], Set<UUID>, [RoutineGoal], [RoutinePlace], [PlaceCheckInSession]) -> Void

    func body(content: Content) -> some View {
        content
            .task {
                onAppear()
                sendCurrentData()
            }
            .task(id: activeFocusRefreshID) {
                guard !activeFocusRefreshID.isEmpty else { return }

                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    guard !Task.isCancelled else { return }
                    sendCurrentData()
                }
            }
            .onChange(of: tasks) { _, newValue in
                onDataChanged(newValue, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: logs) { _, newValue in
                onDataChanged(tasks, newValue, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: focusSessions) { _, newValue in
                onDataChanged(tasks, logs, newValue, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: sprintFocusSessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, newValue, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: boardSprints) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, newValue, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: sleepSessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, newValue, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: awaySessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, newValue, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: emotionLogs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, newValue, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: notes) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, newValue, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: events) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, newValue, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
            }
            .onChange(of: noteAttachmentNoteIDs) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, newValue, goals, places, placeCheckInSessions)
            }
            .onChange(of: goals) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, newValue, places, placeCheckInSessions)
            }
            .onChange(of: places) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, newValue, placeCheckInSessions)
            }
            .onChange(of: placeCheckInSessions) { _, newValue in
                onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, newValue)
            }
    }

    private func sendCurrentData() {
        onDataChanged(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions)
    }

    private var activeFocusRefreshID: String {
        let taskSessionIDs = focusSessions
            .filter { $0.state == .active && !$0.isPaused }
            .map { "task-\($0.id.uuidString)" }
        let sprintSessionIDs = sprintFocusSessions
            .filter { $0.isActive && !$0.isPaused }
            .map { "sprint-\($0.id.uuidString)" }
        return (taskSessionIDs + sprintSessionIDs)
            .sorted()
            .joined(separator: "|")
    }
}

extension View {
    func statsDataRefresh(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        focusSessions: [FocusSession],
        sprintFocusSessions: [SprintFocusSessionRecord],
        boardSprints: [BoardSprintRecord],
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
        onDataChanged: @escaping ([RoutineTask], [RoutineLog], [FocusSession], [SprintFocusSessionRecord], [BoardSprintRecord], [SleepSession], [AwaySession], [EmotionLog], [RoutineNote], [RoutineEvent], Set<UUID>, [RoutineGoal], [RoutinePlace], [PlaceCheckInSession]) -> Void
    ) -> some View {
        modifier(
            StatsDataRefreshModifier(
                tasks: tasks,
                logs: logs,
                focusSessions: focusSessions,
                sprintFocusSessions: sprintFocusSessions,
                boardSprints: boardSprints,
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
