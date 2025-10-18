import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

@MainActor
struct SwiftDataModelTests {
    @Test
    func routineTask_defaultsAreInitialized() {
        let task = RoutineTask()
        #expect(task.interval == 1)
        #expect(!task.id.uuidString.isEmpty)
        #expect(task.lastDone == nil)
        #expect(task.tags.isEmpty)
    }

    @Test
    func routineTask_tagsAreSanitizedAndDeduplicated() {
        let task = RoutineTask(tags: [" Health ", "health", "deep work", ""])
        #expect(task.tags == ["Health", "deep work"])
    }

    @Test
    func routineLog_defaultsAreInitialized() {
        let taskID = UUID()
        let log = RoutineLog(taskID: taskID)
        #expect(log.taskID == taskID)
        #expect(!log.id.uuidString.isEmpty)
        #expect(log.timestamp == nil)
    }
}
