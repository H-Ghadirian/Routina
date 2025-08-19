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
            let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
            let sessions = try context.fetch(FetchDescriptor<FocusSession>())
            let focus = FocusTimerWidgetDataComputer.compute(tasks: tasks, sessions: sessions)
            await sync(focus)
        } catch {
            NSLog("FocusTimerLiveActivityService: failed to compute focus timer — \(error)")
        }
    }

    static func sync(_ focus: FocusTimerWidgetData) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return
        }

        guard
            focus.isActive,
            let sessionID = focus.sessionID,
            let startedAt = focus.startedAt
        else {
            await endAll()
            return
        }

        let attributes = FocusTimerActivityAttributes(
            sessionID: sessionID,
            taskID: focus.taskID,
            taskName: focus.taskName,
            taskEmoji: focus.taskEmoji
        )
        let state = FocusTimerActivityAttributes.ContentState(
            startedAt: startedAt,
            plannedDurationSeconds: focus.plannedDurationSeconds,
            lastUpdated: focus.lastUpdated
        )
        let content = ActivityContent(state: state, staleDate: nil)

        let matchingActivities = Activity<FocusTimerActivityAttributes>.activities
            .filter { $0.attributes.sessionID == sessionID }
        for activity in matchingActivities {
            await activity.update(content)
        }

        let staleActivities = Activity<FocusTimerActivityAttributes>.activities
            .filter { $0.attributes.sessionID != sessionID }
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
}
#endif
