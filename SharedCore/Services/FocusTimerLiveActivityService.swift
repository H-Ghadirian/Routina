#if os(iOS) && canImport(ActivityKit)
import ActivityKit
import Foundation
import SwiftData

enum FocusTimerLiveActivityService {
    @MainActor
    static func sync(using container: ModelContainer) async {
        let context = ModelContext(container)
        await sync(using: context)
    }

    @MainActor
    static func sync(using context: ModelContext) async {
        do {
            let focus = try activeFocus(in: context)
            await sync(focus)
        } catch {
            NSLog("FocusTimerLiveActivityService: failed to compute focus timer — \(error)")
        }
    }

    private static func sync(_ focus: ActiveFocusTimerActivity?) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return
        }

        guard let focus else {
            await endAll()
            return
        }

        let attributes = FocusTimerActivityAttributes(
            sessionID: focus.sessionID,
            focusKind: focus.kind,
            targetID: focus.targetID,
            taskID: focus.taskID,
            taskName: focus.title,
            taskEmoji: focus.emoji
        )
        let state = FocusTimerActivityAttributes.ContentState(
            startedAt: focus.startedAt,
            plannedDurationSeconds: focus.plannedDurationSeconds,
            lastUpdated: focus.lastUpdated
        )
        let content = ActivityContent(state: state, staleDate: nil)

        let matchingActivities = Activity<FocusTimerActivityAttributes>.activities
            .filter {
                $0.attributes.sessionID == focus.sessionID
                    && ($0.attributes.focusKind ?? .task) == focus.kind
            }
        for activity in matchingActivities {
            await activity.update(content)
        }

        let staleActivities = Activity<FocusTimerActivityAttributes>.activities
            .filter {
                $0.attributes.sessionID != focus.sessionID
                    || ($0.attributes.focusKind ?? .task) != focus.kind
            }
        for activity in staleActivities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        guard matchingActivities.isEmpty else { return }

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            NSLog("FocusTimerLiveActivityService: failed to start focus activity — \(error)")
        }
    }

    private static func endAll() async {
        for activity in Activity<FocusTimerActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    @MainActor
    private static func activeFocus(in context: ModelContext) throws -> ActiveFocusTimerActivity? {
        let referenceDate = Date()
        let taskFocus = try activeTaskFocus(in: context, referenceDate: referenceDate)
        let sprintFocus = try activeSprintFocus(in: context, referenceDate: referenceDate)

        switch (taskFocus, sprintFocus) {
        case let (.some(task), .some(sprint)):
            return task.startedAt >= sprint.startedAt ? task : sprint
        case let (.some(task), nil):
            return task
        case let (nil, .some(sprint)):
            return sprint
        case (nil, nil):
            return nil
        }
    }

    @MainActor
    private static func activeTaskFocus(
        in context: ModelContext,
        referenceDate: Date
    ) throws -> ActiveFocusTimerActivity? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let sessions = try context.fetch(FetchDescriptor<FocusSession>())
        let focus = FocusTimerWidgetDataComputer.compute(
            tasks: tasks,
            sessions: sessions,
            referenceDate: referenceDate
        )

        guard let sessionID = focus.sessionID,
              let startedAt = focus.startedAt else {
            return nil
        }

        return ActiveFocusTimerActivity(
            sessionID: sessionID,
            kind: .task,
            targetID: focus.taskID,
            taskID: focus.taskID,
            title: focus.taskName,
            emoji: focus.taskEmoji,
            startedAt: startedAt,
            plannedDurationSeconds: focus.plannedDurationSeconds,
            lastUpdated: focus.lastUpdated
        )
    }

    @MainActor
    private static func activeSprintFocus(
        in context: ModelContext,
        referenceDate: Date
    ) throws -> ActiveFocusTimerActivity? {
        let sprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let sessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        guard let session = sessions
            .filter({ $0.stoppedAt == nil })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first
        else {
            return nil
        }

        let title = sprints
            .first { $0.id == session.sprintID }?
            .title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = title.map { $0.isEmpty ? "Sprint focus" : $0 } ?? "Sprint focus"

        return ActiveFocusTimerActivity(
            sessionID: session.id,
            kind: .sprint,
            targetID: session.sprintID,
            taskID: nil,
            title: displayTitle,
            emoji: "🏁",
            startedAt: session.startedAt,
            plannedDurationSeconds: 0,
            lastUpdated: referenceDate
        )
    }
}

private struct ActiveFocusTimerActivity {
    let sessionID: UUID
    let kind: FocusTimerActivityAttributes.FocusKind
    let targetID: UUID?
    let taskID: UUID?
    let title: String
    let emoji: String
    let startedAt: Date
    let plannedDurationSeconds: TimeInterval
    let lastUpdated: Date
}
#endif
