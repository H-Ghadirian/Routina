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
struct HomeTaskHelperTests {
    @Test
    func enforceUniqueRoutineNames_remapsRelationshipsFromDeletedDuplicates() throws {
        let context = makeInMemoryContext()
        let keeper = RoutineTask(
            name: "Make post and streams without products visible",
            relationships: []
        )
        let duplicate = RoutineTask(
            name: " Make post and streams without products visible ",
            relationships: [
                RoutineTaskRelationship(targetTaskID: keeper.id, kind: .related)
            ]
        )
        let blocker = RoutineTask(name: "Collect tracking bug context")
        let dependent = RoutineTask(
            name: "Release checklist",
            relationships: [
                RoutineTaskRelationship(targetTaskID: duplicate.id, kind: .blockedBy)
            ]
        )
        duplicate.replaceRelationships([
            RoutineTaskRelationship(targetTaskID: blocker.id, kind: .blockedBy)
        ])

        context.insert(keeper)
        context.insert(duplicate)
        context.insert(blocker)
        context.insert(dependent)
        try context.save()

        try HomeDeduplicationSupport.enforceUniqueRoutineNames(in: context)

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let keptTask = try #require(tasks.first { $0.id == keeper.id })
        let dependentTask = try #require(tasks.first { $0.id == dependent.id })

        #expect(tasks.filter { RoutineTask.normalizedName($0.name) == RoutineTask.normalizedName(keeper.name) }.count == 1)
        #expect(!tasks.contains { $0.id == duplicate.id })
        #expect(keptTask.relationships == [
            RoutineTaskRelationship(targetTaskID: blocker.id, kind: .blockedBy)
        ])
        #expect(dependentTask.relationships == [
            RoutineTaskRelationship(targetTaskID: keeper.id, kind: .blockedBy)
        ])
    }

    @Test
    func prepareDeleteTasks_removesTasksRelationshipsAndStats() {
        let keptID = UUID()
        let removedID = UUID()
        let otherRemovedID = UUID()
        let untouchedID = UUID()
        let keptTask = RoutineTask(
            id: keptID,
            name: "Ship report",
            relationships: [
                RoutineTaskRelationship(targetTaskID: removedID, kind: .blockedBy),
                RoutineTaskRelationship(targetTaskID: untouchedID, kind: .related)
            ]
        )
        let removedTask = RoutineTask(id: removedID, name: "Draft report")
        let otherRemovedTask = RoutineTask(id: otherRemovedID, name: "Archive notes")
        var tasks = [keptTask, removedTask, otherRemovedTask]
        var doneStats = HomeDoneStats(
            totalCount: 8,
            countsByTaskID: [
                keptID: 2,
                removedID: 4,
                otherRemovedID: 1
            ],
            canceledTotalCount: 3,
            canceledCountsByTaskID: [
                removedID: 2,
                otherRemovedID: 1
            ]
        )

        let update = HomeTaskDeletionSupport.prepareDeleteTasks(
            ids: [removedID, removedID, otherRemovedID],
            tasks: &tasks,
            doneStats: &doneStats
        )

        #expect(update?.uniqueIDs == [removedID, otherRemovedID])
        #expect(tasks.map(\.id) == [keptID])
        #expect(tasks[0].relationships == [RoutineTaskRelationship(targetTaskID: untouchedID, kind: .related)])
        #expect(doneStats.totalCount == 3)
        #expect(doneStats.canceledTotalCount == 0)
        #expect(doneStats.countsByTaskID == [keptID: 2])
        #expect(doneStats.canceledCountsByTaskID.isEmpty)
    }

    @Test
    func prepareDeleteTasks_returnsNilForEmptyOrUnknownInput() {
        let task = RoutineTask(name: "Read")
        var tasks = [task]
        var doneStats = HomeDoneStats(totalCount: 2, countsByTaskID: [task.id: 2])

        let update = HomeTaskDeletionSupport.prepareDeleteTasks(
            ids: [],
            tasks: &tasks,
            doneStats: &doneStats
        )

        #expect(update == nil)
        #expect(tasks.map(\.id) == [task.id])
        #expect(doneStats.totalCount == 2)
    }

    @Test
    func removeSprintAssignments_removesAssignmentsForDeletedTodosOnly() {
        let removedTodoID = UUID()
        let keptTodoID = UUID()
        let sprintID = UUID()
        var sprintBoardData = SprintBoardData(
            sprints: [BoardSprint(id: sprintID, title: "April")],
            assignments: [
                SprintAssignment(todoID: removedTodoID, sprintID: sprintID),
                SprintAssignment(todoID: keptTodoID, sprintID: sprintID)
            ]
        )

        HomeTaskDeletionSupport.removeSprintAssignments(
            targeting: [removedTodoID],
            from: &sprintBoardData
        )

        #expect(sprintBoardData.assignments == [
            SprintAssignment(todoID: keptTodoID, sprintID: sprintID)
        ])
    }

    @Test
    func moveTaskInSection_normalizesInputAndAppliesManualOrder() {
        let sectionKey = "home.ready"
        let first = RoutineTask(name: "First")
        let second = RoutineTask(name: "Second")
        let third = RoutineTask(name: "Third")
        first.setManualSectionOrder(0, for: sectionKey)
        second.setManualSectionOrder(1, for: sectionKey)
        third.setManualSectionOrder(2, for: sectionKey)
        var tasks = [first, second, third]

        let update = HomeTaskOrderingSupport.moveTaskInSection(
            taskID: second.id,
            sectionKey: sectionKey,
            orderedTaskIDs: [first.id, UUID(), second.id, second.id, third.id],
            direction: .down,
            tasks: &tasks
        )

        #expect(update == HomeTaskSectionOrderUpdate(
            sectionKey: sectionKey,
            orderedTaskIDs: [first.id, third.id, second.id]
        ))
        #expect(tasks.first(where: { $0.id == first.id })?.manualSectionOrder(for: sectionKey) == 0)
        #expect(tasks.first(where: { $0.id == third.id })?.manualSectionOrder(for: sectionKey) == 1)
        #expect(tasks.first(where: { $0.id == second.id })?.manualSectionOrder(for: sectionKey) == 2)
    }

    @Test
    func moveTaskInSection_returnsNilAtBoundary() {
        let sectionKey = "home.ready"
        let first = RoutineTask(name: "First")
        let second = RoutineTask(name: "Second")
        var tasks = [first, second]

        let update = HomeTaskOrderingSupport.moveTaskInSection(
            taskID: first.id,
            sectionKey: sectionKey,
            orderedTaskIDs: [first.id, second.id],
            direction: .up,
            tasks: &tasks
        )

        #expect(update == nil)
        #expect(first.manualSectionOrder(for: sectionKey) == nil)
        #expect(second.manualSectionOrder(for: sectionKey) == nil)
    }

    @Test
    func setTaskOrderInSection_deduplicatesAndIgnoresUnknownIDs() {
        let sectionKey = "home.blocked"
        let first = RoutineTask(name: "First")
        let second = RoutineTask(name: "Second")
        let third = RoutineTask(name: "Third")
        var tasks = [first, second, third]

        let update = HomeTaskOrderingSupport.setTaskOrderInSection(
            sectionKey: sectionKey,
            orderedTaskIDs: [third.id, UUID(), first.id, third.id],
            tasks: &tasks
        )

        #expect(update == HomeTaskSectionOrderUpdate(
            sectionKey: sectionKey,
            orderedTaskIDs: [third.id, first.id]
        ))
        #expect(tasks.first(where: { $0.id == third.id })?.manualSectionOrder(for: sectionKey) == 0)
        #expect(tasks.first(where: { $0.id == first.id })?.manualSectionOrder(for: sectionKey) == 1)
        #expect(tasks.first(where: { $0.id == second.id })?.manualSectionOrder(for: sectionKey) == nil)
    }

    @Test
    func makeSnapshot_detachesModelsSortsLogsAndHydratesRelatedTags() {
        let place = RoutinePlace(name: "Office", latitude: 52.52, longitude: 13.405)
        let selectedTask = RoutineTask(
            name: "Write",
            emoji: "W",
            tags: ["Focus", "Writing"]
        )
        let relatedTask = RoutineTask(
            name: "Stretch",
            emoji: "S",
            tags: ["Health", "Focus"]
        )
        let oldLog = RoutineLog(timestamp: makeDate("2026-04-10T08:00:00Z"), taskID: selectedTask.id)
        let newLog = RoutineLog(timestamp: makeDate("2026-04-12T08:00:00Z"), taskID: relatedTask.id)
        let nilTimestampLog = RoutineLog(timestamp: nil, taskID: selectedTask.id)
        let doneStats = HomeDoneStats(totalCount: 2, countsByTaskID: [selectedTask.id: 2])

        let snapshot = HomeTaskLoadSupport.makeSnapshot(
            tasks: [selectedTask, relatedTask],
            places: [place],
            goals: [],
            logs: [oldLog, nilTimestampLog, newLog],
            doneStats: doneStats,
            selectedTaskID: selectedTask.id,
            detailTask: selectedTask,
            selectedTaskReloadGuard: nil,
            persistedRelatedTagRules: [
                RoutineRelatedTagRule(tag: "Manual", relatedTags: ["Focus"])
            ]
        )

        selectedTask.name = "Changed after snapshot"
        place.name = "Changed place"

        #expect(snapshot.tasks.map { $0.name } == ["Write", "Stretch"])
        #expect(snapshot.places.map { $0.name } == ["Office"])
        #expect(snapshot.timelineLogs.map { $0.id } == [newLog.id, oldLog.id, nilTimestampLog.id])
        #expect(snapshot.doneStats == doneStats)
        #expect(snapshot.relatedTagRules.contains(
            RoutineRelatedTagRule(tag: "Manual", relatedTags: ["Focus"])
        ))
        #expect(snapshot.relatedTagRules.contains(
            RoutineRelatedTagRule(tag: "Focus", relatedTags: ["Health", "Writing"])
        ))
    }
}
