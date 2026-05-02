import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct HomeFeatureTaskLoadEffectFactoryTests {
    @Test
    func loadTasksFetchesRecordsAndBuildsDoneStats() throws {
        let context = makeInMemoryContext()
        let taskID = UUID()
        let placeID = UUID()
        let goalID = UUID()
        let task = RoutineTask(
            id: taskID,
            name: "Focus",
            emoji: "🎯",
            placeID: placeID,
            goalIDs: [goalID]
        )
        let place = RoutinePlace(
            id: placeID,
            name: "Office",
            latitude: 52.52,
            longitude: 13.405
        )
        let goal = RoutineGoal(id: goalID, title: "Deep work")
        let completedLog = RoutineLog(
            timestamp: makeDate("2026-03-20T08:00:00Z"),
            taskID: taskID
        )
        let canceledLog = RoutineLog(
            timestamp: makeDate("2026-03-21T08:00:00Z"),
            taskID: taskID,
            kind: .canceled
        )
        context.insert(task)
        context.insert(place)
        context.insert(goal)
        context.insert(completedLog)
        context.insert(canceledLog)
        try context.save()

        let factory = HomeFeatureTaskLoadEffectFactory<TestTaskLoadEffectAction, TestTaskLoadCancelID>(
            calendar: makeTestCalendar(),
            cancelID: .loadTasks,
            modelContext: { context },
            loadedAction: { .loaded($0, $1, $2, $3, $4) },
            failedAction: { .failed }
        )

        let result = try factory.loadTasks()

        #expect(result.tasks.map(\.id) == [taskID])
        #expect(result.places.map(\.id) == [placeID])
        #expect(result.goals.map(\.id) == [goalID])
        #expect(Set(result.logs.map(\.id)) == [completedLog.id, canceledLog.id])
        #expect(result.doneStats.totalCount == 1)
        #expect(result.doneStats.countsByTaskID[taskID] == 1)
        #expect(result.doneStats.canceledTotalCount == 1)
        #expect(result.doneStats.canceledCountsByTaskID[taskID] == 1)
    }
}

private enum TestTaskLoadEffectAction: Equatable {
    case loaded([RoutineTask], [RoutinePlace], [RoutineGoal], [RoutineLog], HomeDoneStats)
    case failed
}

private enum TestTaskLoadCancelID: Hashable {
    case loadTasks
}
