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
        #expect(task.placeID == nil)
        #expect(task.scheduleAnchor == nil)
        #expect(task.pausedAt == nil)
        #expect(task.tags.isEmpty)
        #expect(task.steps.isEmpty)
        #expect(task.checklistItems.isEmpty)
        #expect(task.scheduleMode == .fixedInterval)
        #expect(task.completedStepCount == 0)
        #expect(task.sequenceStartedAt == nil)
    }

    @Test
    func routineTask_tagsAreSanitizedAndDeduplicated() {
        let task = RoutineTask(tags: [" Health ", "health", "deep work", ""])
        #expect(task.tags == ["Health", "deep work"])
    }

    @Test
    func routinePlace_normalizesNameAndClampsRadius() {
        let place = RoutinePlace(name: "  Home  ", latitude: 52.52, longitude: 13.405, radiusMeters: 5)
        #expect(place.name == "Home")
        #expect(place.displayName == "Home")
        #expect(place.radiusMeters == 25)
    }

    @Test
    func routineLog_defaultsAreInitialized() {
        let taskID = UUID()
        let log = RoutineLog(taskID: taskID)
        #expect(log.taskID == taskID)
        #expect(!log.id.uuidString.isEmpty)
        #expect(log.timestamp == nil)
    }

    @Test
    func routineTask_stepsSerializeAndAdvanceSequentially() {
        let firstStepID = UUID()
        let secondStepID = UUID()
        let task = RoutineTask(
            steps: [
                RoutineStep(id: firstStepID, title: "Wash clothes"),
                RoutineStep(id: secondStepID, title: "Hang on the line")
            ]
        )

        #expect(task.steps.map(\.title) == ["Wash clothes", "Hang on the line"])
        #expect(task.nextStepTitle == "Wash clothes")

        let firstAdvance = task.advance(completedAt: makeDate("2026-03-17T10:00:00Z"))
        #expect(firstAdvance == .advancedStep(completedSteps: 1, totalSteps: 2))
        #expect(task.isInProgress)
        #expect(task.nextStepTitle == "Hang on the line")

        let secondAdvance = task.advance(completedAt: makeDate("2026-03-17T11:00:00Z"))
        #expect(secondAdvance == .completedRoutine)
        #expect(task.completedStepCount == 0)
        #expect(task.sequenceStartedAt == nil)
        #expect(task.lastDone == makeDate("2026-03-17T11:00:00Z"))
    }

    @Test
    func routineTask_checklistItemsSerializeAndUpdateIndividually() {
        let breadID = UUID()
        let milkID = UUID()
        let createdAt = makeDate("2026-03-17T10:00:00Z")
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: createdAt),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5, createdAt: createdAt)
            ]
        )

        #expect(task.scheduleMode == .derivedFromChecklist)
        #expect(task.checklistItems.map(\.title) == ["Bread", "Milk"])

        let updatedCount = task.markChecklistItemsPurchased([breadID], purchasedAt: makeDate("2026-03-18T12:00:00Z"))
        #expect(updatedCount == 1)
        #expect(task.checklistItems.first(where: { $0.id == breadID })?.lastPurchasedAt == makeDate("2026-03-18T12:00:00Z"))
        #expect(task.checklistItems.first(where: { $0.id == milkID })?.lastPurchasedAt == nil)
        #expect(task.lastDone == makeDate("2026-03-18T12:00:00Z"))
    }

    @Test
    func routineTask_fixedIntervalChecklist_completesOnlyAfterAllItemsAreDone() {
        let breadID = UUID()
        let milkID = UUID()
        let task = RoutineTask(
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 5)
            ],
            scheduleMode: .fixedIntervalChecklist,
            interval: 7
        )

        let firstCompletion = task.markChecklistItemCompleted(
            breadID,
            completedAt: makeDate("2026-03-18T12:00:00Z")
        )
        #expect(firstCompletion == .advancedChecklist(completedItems: 1, totalItems: 2))
        #expect(task.completedChecklistItemCount == 1)
        #expect(task.isChecklistInProgress)
        #expect(task.lastDone == nil)

        let finalCompletion = task.markChecklistItemCompleted(
            milkID,
            completedAt: makeDate("2026-03-18T12:05:00Z")
        )
        #expect(finalCompletion == .completedRoutine)
        #expect(task.completedChecklistItemCount == 0)
        #expect(!task.isChecklistInProgress)
        #expect(task.lastDone == makeDate("2026-03-18T12:05:00Z"))
    }
}
