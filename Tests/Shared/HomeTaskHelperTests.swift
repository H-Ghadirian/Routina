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
            completedDatesByTaskID: [
                keptID: [makeDate("2026-05-05T18:30:00Z")],
                removedID: [makeDate("2026-05-06T18:30:00Z")],
                otherRemovedID: [makeDate("2026-05-07T18:30:00Z")]
            ],
            canceledTotalCount: 3,
            canceledCountsByTaskID: [
                removedID: 2,
                otherRemovedID: 1
            ],
            canceledDatesByTaskID: [
                removedID: [makeDate("2026-05-07T18:30:00Z")],
                otherRemovedID: [makeDate("2026-05-08T18:30:00Z")]
            ],
            missedDatesByTaskID: [
                removedID: [makeDate("2026-05-01T18:30:00Z")]
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
        #expect(doneStats.completedDatesByTaskID == [keptID: [makeDate("2026-05-05T18:30:00Z")]])
        #expect(doneStats.canceledCountsByTaskID.isEmpty)
        #expect(doneStats.canceledDatesByTaskID.isEmpty)
        #expect(doneStats.missedDatesByTaskID.isEmpty)
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
    func makeDoneStats_countsOnlyLoadedTasksAcrossOutcomeKinds() {
        let primaryTask = RoutineTask(name: "Write")
        let secondaryTask = RoutineTask(name: "Review")
        let orphanedTaskID = UUID()
        let completedDate = makeDate("2026-05-20T08:00:00Z")
        let canceledDate = makeDate("2026-05-21T08:00:00Z")
        let missedDate = makeDate("2026-05-22T08:00:00Z")

        let stats = HomeTaskSupport.makeDoneStats(
            tasks: [primaryTask, secondaryTask],
            logs: [
                RoutineLog(timestamp: completedDate, taskID: primaryTask.id, kind: .completed),
                RoutineLog(timestamp: nil, taskID: primaryTask.id, kind: .completed),
                RoutineLog(timestamp: completedDate, taskID: secondaryTask.id, kind: .completed),
                RoutineLog(timestamp: canceledDate, taskID: primaryTask.id, kind: .canceled),
                RoutineLog(timestamp: nil, taskID: primaryTask.id, kind: .canceled),
                RoutineLog(timestamp: missedDate, taskID: primaryTask.id, kind: .missed),
                RoutineLog(timestamp: nil, taskID: primaryTask.id, kind: .missed),
                RoutineLog(timestamp: completedDate, taskID: orphanedTaskID, kind: .completed),
                RoutineLog(timestamp: canceledDate, taskID: orphanedTaskID, kind: .canceled),
                RoutineLog(timestamp: missedDate, taskID: orphanedTaskID, kind: .missed)
            ]
        )

        #expect(stats.totalCount == 3)
        #expect(stats.countsByTaskID == [
            primaryTask.id: 2,
            secondaryTask.id: 1
        ])
        #expect(stats.completedDatesByTaskID == [
            primaryTask.id: [completedDate],
            secondaryTask.id: [completedDate]
        ])
        #expect(stats.canceledTotalCount == 2)
        #expect(stats.canceledCountsByTaskID == [primaryTask.id: 2])
        #expect(stats.canceledDatesByTaskID == [primaryTask.id: [canceledDate]])
        #expect(stats.missedDatesByTaskID == [primaryTask.id: [missedDate]])
        #expect(stats.missedTotalCount == 1)
    }

    @Test
    func doneStatsReplaceLogsRefreshesSelectedTaskOutcomeCaches() {
        let taskID = UUID()
        let otherTaskID = UUID()
        let staleCompletedDate = makeDate("2026-06-15T08:00:00Z")
        let canceledDate = makeDate("2026-06-22T17:30:00Z")
        var stats = HomeDoneStats(
            totalCount: 2,
            countsByTaskID: [
                taskID: 1,
                otherTaskID: 1
            ],
            completedDatesByTaskID: [
                taskID: [staleCompletedDate],
                otherTaskID: [staleCompletedDate]
            ],
            canceledTotalCount: 0,
            canceledCountsByTaskID: [:],
            canceledDatesByTaskID: [:],
            missedDatesByTaskID: [:]
        )

        stats.replaceLogs(
            for: taskID,
            with: [
                RoutineLog(timestamp: canceledDate, taskID: taskID, kind: .canceled)
            ]
        )

        #expect(stats.totalCount == 1)
        #expect(stats.countsByTaskID == [otherTaskID: 1])
        #expect(stats.completedDatesByTaskID == [otherTaskID: [staleCompletedDate]])
        #expect(stats.canceledTotalCount == 1)
        #expect(stats.canceledCountsByTaskID == [taskID: 1])
        #expect(stats.canceledDatesByTaskID == [taskID: [canceledDate]])
    }

    @Test
    func replacingTimelineLogsRefreshesSelectedTaskLogsAndPreservesOtherTasks() {
        let taskID = UUID()
        let otherTaskID = UUID()
        let staleLog = RoutineLog(
            timestamp: makeDate("2026-06-15T08:00:00Z"),
            taskID: taskID,
            kind: .completed
        )
        let otherLog = RoutineLog(
            timestamp: makeDate("2026-06-18T08:00:00Z"),
            taskID: otherTaskID,
            kind: .completed
        )
        let refreshedLog = RoutineLog(
            timestamp: makeDate("2026-06-20T08:00:00Z"),
            taskID: taskID,
            kind: .completed
        )
        let nilTimestampLog = RoutineLog(
            timestamp: nil,
            taskID: taskID,
            kind: .missed
        )

        let logs = HomeTaskSupport.replacingTimelineLogs(
            for: taskID,
            in: [staleLog, otherLog],
            with: [nilTimestampLog, refreshedLog]
        )

        #expect(logs.map(\.id) == [refreshedLog.id, otherLog.id, nilTimestampLog.id])
        #expect(!logs.contains { $0.id == staleLog.id })
    }

    @Test
    func rowToneResolverUsesDisplayFieldsForScrollPathColor() {
        let referenceDate = makeDate("2026-05-25T08:00:00Z")

        #expect(HomeRoutineRowToneResolver.tone(
            for: makeHomeRoutineDisplay(
                interval: 4,
                lastDone: referenceDate.addingTimeInterval(-86_400)
            ),
            referenceDate: referenceDate
        ) == .green)
        #expect(HomeRoutineRowToneResolver.tone(
            for: makeHomeRoutineDisplay(
                interval: 4,
                scheduleAnchor: referenceDate.addingTimeInterval(-86_400 * 4)
            ),
            referenceDate: referenceDate
        ) == .red)
        #expect(HomeRoutineRowToneResolver.tone(
            for: makeHomeRoutineDisplay(
                recurrenceRule: .daily(at: .defaultValue),
                daysUntilDue: 1
            ),
            referenceDate: referenceDate
        ) == .orange)
        #expect(HomeRoutineRowToneResolver.tone(
            for: makeHomeRoutineDisplay(
                scheduleMode: .oneOff,
                isOneOffTask: true
            ),
            referenceDate: referenceDate
        ) == .blue)
    }

    @Test
    func rowIconColorPathDoesNotRebuildTaskListFiltering() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        let paths = [
            "iOS/Screens/Home/HomeTCAView+Filtering.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Filtering.swift"
        ]

        for path in paths {
            let source = try String(
                contentsOf: projectRoot.appendingPathComponent(path),
                encoding: .utf8
            )
            #expect(source.contains("HomeRoutineRowToneResolver.tone"))
            #expect(!source.contains("let urgency = urgencyLevel(for: task)"))
            #expect(!source.contains("Double(daysSinceScheduleAnchor(task))"))
        }
    }

    @Test
    func homeLoadingStateIncludesTextIconAndShimmerPlaceholder() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        let source = try String(
            contentsOf: projectRoot.appendingPathComponent("SharedCore/Screens/Home/HomeStatusAndEmptyViews.swift"),
            encoding: .utf8
        )

        #expect(source.contains("struct HomeLoadingStateView"))
        #expect(source.contains("Fetching routines, todos, and recent activity."))
        #expect(source.contains("Image(systemName: systemImage)"))
        #expect(source.contains("SwiftUI.TimelineView(.animation)"))
        #expect(source.contains("accessibilityReduceMotion"))
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

    @Test
    func makeSnapshotAddsLastDoneFallbackWhenTimelineLogIsMissing() {
        let calendar = makeTestCalendar()
        let completedAt = makeDate("2026-07-08T10:00:00Z")
        let completedTask = RoutineTask(
            name: "Dr appointment",
            emoji: "🩺",
            lastDone: completedAt,
            scheduleAnchor: completedAt
        )
        let otherTaskID = UUID()
        let existingLog = RoutineLog(
            timestamp: makeDate("2026-07-07T09:00:00Z"),
            taskID: otherTaskID,
            kind: .completed
        )

        let snapshot = HomeTaskLoadSupport.makeSnapshot(
            tasks: [completedTask],
            places: [],
            goals: [],
            logs: [existingLog],
            doneStats: HomeTaskSupport.makeDoneStats(tasks: [completedTask], logs: [existingLog]),
            selectedTaskID: nil,
            detailTask: nil,
            selectedTaskReloadGuard: nil,
            persistedRelatedTagRules: [],
            calendar: calendar
        )

        #expect(snapshot.timelineLogs.count == 2)
        #expect(snapshot.timelineLogs.first?.taskID == completedTask.id)
        #expect(snapshot.timelineLogs.first?.kind == .completed)
        #expect(snapshot.timelineLogs.first?.timestamp == completedAt)
        #expect(snapshot.timelineLogs.map(\.id).contains(existingLog.id))
        #expect(snapshot.doneStats.hasCompletedDate(taskID: completedTask.id, date: completedAt, calendar: calendar))
    }

    @Test
    func makeSnapshotDoesNotDuplicateLastDoneWhenSameDayLogExists() {
        let calendar = makeTestCalendar()
        let completedAt = makeDate("2026-07-08T10:00:00Z")
        let completedTask = RoutineTask(
            name: "Dr appointment",
            emoji: "🩺",
            lastDone: completedAt,
            scheduleAnchor: completedAt
        )
        let existingLog = RoutineLog(
            timestamp: makeDate("2026-07-08T09:00:00Z"),
            taskID: completedTask.id,
            kind: .completed
        )

        let snapshot = HomeTaskLoadSupport.makeSnapshot(
            tasks: [completedTask],
            places: [],
            goals: [],
            logs: [existingLog],
            doneStats: HomeTaskSupport.makeDoneStats(tasks: [completedTask], logs: [existingLog]),
            selectedTaskID: nil,
            detailTask: nil,
            selectedTaskReloadGuard: nil,
            persistedRelatedTagRules: [],
            calendar: calendar
        )

        #expect(snapshot.timelineLogs.map(\.id) == [existingLog.id])
    }

    @Test
    func timelineSourceUsesSelectedDetailLastDoneWhenParentTaskIsStale() {
        let calendar = makeTestCalendar()
        let taskID = UUID()
        let oldCompletion = makeDate("2026-07-07T09:00:00Z")
        let latestCompletion = makeDate("2026-07-09T10:00:00Z")
        let staleTask = RoutineTask(
            id: taskID,
            name: "Exercise",
            emoji: "🏃",
            lastDone: oldCompletion,
            scheduleAnchor: oldCompletion
        )
        let detailTask = staleTask.detachedCopy()
        detailTask.lastDone = latestCompletion
        detailTask.scheduleAnchor = latestCompletion
        let oldLog = RoutineLog(
            timestamp: oldCompletion,
            taskID: taskID,
            kind: .completed
        )
        let unrelatedLog = RoutineLog(
            timestamp: makeDate("2026-07-08T12:00:00Z"),
            taskID: UUID(),
            kind: .completed
        )

        let tasks = HomeTaskSupport.timelineTasksIncludingSelectedDetail(
            tasks: [staleTask],
            detailTask: detailTask
        )
        let logs = HomeTaskSupport.timelineLogsIncludingSelectedDetailFallback(
            timelineLogs: [oldLog, unrelatedLog],
            detailTask: detailTask,
            detailLogs: [oldLog],
            calendar: calendar
        )

        let fallbackLogID = TimelineSyntheticLogID.completion(
            taskID: taskID,
            completedAt: latestCompletion
        )
        #expect(tasks.first?.lastDone == latestCompletion)
        #expect(logs.first?.id == fallbackLogID)
        #expect(logs.first?.timestamp == latestCompletion)
        #expect(logs.map(\.id).contains(oldLog.id))
        #expect(logs.map(\.id).contains(unrelatedLog.id))
    }

    @Test
    func pendingChecklistReloadGuardPreservesCheckedDetailDuringStaleReload() {
        let now = makeDate("2026-06-17T10:00:00Z")
        let taskID = UUID()
        let sciformaID = UUID()
        let excelID = UUID()
        let staleTask = RoutineTask(
            id: taskID,
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: sciformaID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: excelID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        let checkedDetailTask = staleTask.detachedCopy()
        _ = checkedDetailTask.markChecklistItemCompleted(sciformaID, completedAt: now)
        var selection = HomeSelectionState(
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(task: checkedDetailTask, selectedDate: now)
        )

        HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
            for: sciformaID,
            selection: &selection,
            now: now,
            calendar: .current
        )

        let reconciliation = HomeReloadGuardSupport.reconcileSelectedDetailTask(
            [staleTask],
            selectedTaskID: taskID,
            detailTask: checkedDetailTask,
            selectedTaskReloadGuard: selection.selectedTaskReloadGuard
        )

        #expect(reconciliation.tasks.first?.isChecklistItemCompleted(sciformaID, referenceDate: now) == true)
        #expect(reconciliation.selectedTaskReloadGuard?.completedChecklistItemIDsStorage == checkedDetailTask.completedChecklistItemIDsStorage)
    }

    @Test
    func selectedDetailRefreshPreservesCheckedChecklistDuringStaleListRefresh() {
        let now = makeDate("2026-06-17T10:00:00Z")
        let taskID = UUID()
        let sciformaID = UUID()
        let excelID = UUID()
        let staleTask = RoutineTask(
            id: taskID,
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: sciformaID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: excelID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        let checkedDetailTask = staleTask.detachedCopy()
        _ = checkedDetailTask.markChecklistItemCompleted(sciformaID, completedAt: now)
        var selection = HomeSelectionState(
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(task: checkedDetailTask, selectedDate: now)
        )

        HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
            for: sciformaID,
            selection: &selection,
            now: now,
            calendar: .current
        )
        HomeDetailSelectionSupport.refreshSelectedTaskDetailState(
            selection: &selection,
            tasks: [staleTask],
            now: now,
            calendar: .current,
            makeTaskDetailState: { TaskDetailFeature.State(task: $0) }
        )

        #expect(selection.taskDetailState?.task.isChecklistItemCompleted(sciformaID, referenceDate: now) == true)
        #expect(selection.selectedTaskReloadGuard?.completedChecklistItemIDsStorage == checkedDetailTask.completedChecklistItemIDsStorage)
    }

    @Test
    func selectedDetailRefreshPreservesCompletedChecklistDuringStaleListRefresh() {
        let now = makeDate("2026-06-17T10:00:00Z")
        let taskID = UUID()
        let sciformaID = UUID()
        let excelID = UUID()
        let staleTask = RoutineTask(
            id: taskID,
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: sciformaID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: excelID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        let completedDetailTask = staleTask.detachedCopy()
        _ = completedDetailTask.markChecklistItemCompleted(sciformaID, completedAt: now)
        _ = completedDetailTask.markChecklistItemCompleted(excelID, completedAt: now)
        var selection = HomeSelectionState(
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(task: completedDetailTask, selectedDate: now)
        )

        HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
            for: excelID,
            selection: &selection,
            now: now,
            calendar: .current
        )
        HomeDetailSelectionSupport.refreshSelectedTaskDetailState(
            selection: &selection,
            tasks: [staleTask],
            now: now,
            calendar: .current,
            makeTaskDetailState: { TaskDetailFeature.State(task: $0) }
        )

        #expect(selection.taskDetailState?.task.lastDone == now)
        #expect(selection.taskDetailState?.task.completedChecklistItemIDsStorage.isEmpty == true)
        #expect(selection.taskDetailState?.isDoneToday == true)
        #expect(selection.selectedTaskReloadGuard?.lastDone == now)
    }

    @Test
    func selectedDetailRefreshPreservesChecklistUndoDuringStaleCompletedReload() {
        let now = makeDate("2026-06-17T10:00:00Z")
        let taskID = UUID()
        let sciformaID = UUID()
        let excelID = UUID()
        let completedReloadTask = RoutineTask(
            id: taskID,
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: sciformaID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: excelID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist,
            lastDone: now,
            scheduleAnchor: now
        )
        let uncheckedDetailTask = completedReloadTask.detachedCopy()
        uncheckedDetailTask.lastDone = nil
        uncheckedDetailTask.scheduleAnchor = nil
        uncheckedDetailTask.resetChecklistProgress()
        var selection = HomeSelectionState(
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(task: uncheckedDetailTask, selectedDate: now),
            selectedTaskReloadGuard: HomeReloadGuardSupport.makeSelectedTaskReloadGuard(for: completedReloadTask)
        )

        HomeDetailSelectionSupport.updatePendingChecklistUndoReloadGuard(selection: &selection)
        HomeDetailSelectionSupport.refreshSelectedTaskDetailState(
            selection: &selection,
            tasks: [completedReloadTask],
            now: now,
            calendar: .current,
            makeTaskDetailState: { TaskDetailFeature.State(task: $0) }
        )

        #expect(selection.taskDetailState?.task.lastDone == nil)
        #expect(selection.taskDetailState?.isDoneToday == false)
        #expect(selection.selectedTaskReloadGuard?.lastDone == nil)
    }

    @Test
    func selectedDetailRefreshPreservesRunoutItemDuringStaleListRefresh() {
        let now = makeDate("2026-06-17T10:00:00Z")
        let taskID = UUID()
        let breadID = UUID()
        let milkID = UUID()
        let staleTask = RoutineTask(
            id: taskID,
            name: "Groceries",
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: now),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 3, createdAt: now)
            ],
            scheduleMode: .derivedFromChecklist
        )
        let checkedDetailTask = staleTask.detachedCopy()
        _ = checkedDetailTask.markChecklistItemsDone([breadID], doneAt: now)
        var selection = HomeSelectionState(
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(task: checkedDetailTask, selectedDate: now)
        )

        HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
            for: breadID,
            selection: &selection,
            now: now,
            calendar: .current
        )
        HomeDetailSelectionSupport.refreshSelectedTaskDetailState(
            selection: &selection,
            tasks: [staleTask],
            now: now,
            calendar: .current,
            makeTaskDetailState: { TaskDetailFeature.State(task: $0) }
        )

        let item = selection.taskDetailState?.task.checklistItems.first { $0.id == breadID }
        #expect(item?.lastPurchasedAt == now)
        #expect(selection.selectedTaskReloadGuard?.checklistItems.first { $0.id == breadID }?.lastPurchasedAt == now)
    }

    @Test
    func selectedDetailRefreshPreservesPastRunoutItemDuringStaleListRefresh() {
        let calendar = makeTestCalendar()
        let now = makeDate("2026-06-18T10:00:00Z")
        let selectedDate = makeDate("2026-06-17T08:00:00Z")
        let doneAt = makeDate("2026-06-17T12:00:00Z")
        let taskID = UUID()
        let breadID = UUID()
        let milkID = UUID()
        let staleTask = RoutineTask(
            id: taskID,
            name: "Groceries",
            checklistItems: [
                RoutineChecklistItem(id: breadID, title: "Bread", intervalDays: 3, createdAt: makeDate("2026-06-10T10:00:00Z")),
                RoutineChecklistItem(id: milkID, title: "Milk", intervalDays: 3, createdAt: makeDate("2026-06-10T10:00:00Z"))
            ],
            scheduleMode: .derivedFromChecklist
        )
        let checkedDetailTask = staleTask.detachedCopy()
        _ = checkedDetailTask.markChecklistItemsDone([breadID], doneAt: doneAt, calendar: calendar)
        var selection = HomeSelectionState(
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(
                task: checkedDetailTask,
                selectedDate: calendar.startOfDay(for: selectedDate)
            )
        )

        HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
            for: breadID,
            selection: &selection,
            now: now,
            calendar: calendar
        )
        HomeDetailSelectionSupport.refreshSelectedTaskDetailState(
            selection: &selection,
            tasks: [staleTask],
            now: now,
            calendar: calendar,
            makeTaskDetailState: { TaskDetailFeature.State(task: $0) }
        )

        let item = selection.taskDetailState?.task.checklistItems.first { $0.id == breadID }
        #expect(item?.lastPurchasedAt == doneAt)
        #expect(selection.selectedTaskReloadGuard?.checklistItems.first { $0.id == breadID }?.lastPurchasedAt == doneAt)
    }

    @Test
    func pendingChecklistReloadGuardPreservesUncheckedDetailDuringStaleReload() {
        let now = makeDate("2026-06-17T10:00:00Z")
        let taskID = UUID()
        let sciformaID = UUID()
        let excelID = UUID()
        let staleCheckedTask = RoutineTask(
            id: taskID,
            name: "Working Hours",
            checklistItems: [
                RoutineChecklistItem(id: sciformaID, title: "Sciforma", intervalDays: 30, createdAt: now),
                RoutineChecklistItem(id: excelID, title: "Excel", intervalDays: 30, createdAt: now)
            ],
            scheduleMode: .fixedIntervalChecklist
        )
        _ = staleCheckedTask.markChecklistItemCompleted(sciformaID, completedAt: now)
        let uncheckedDetailTask = staleCheckedTask.detachedCopy()
        _ = uncheckedDetailTask.unmarkChecklistItemCompleted(sciformaID)
        var selection = HomeSelectionState(
            selectedTaskID: taskID,
            taskDetailState: TaskDetailFeature.State(task: uncheckedDetailTask, selectedDate: now),
            selectedTaskReloadGuard: HomeReloadGuardSupport.makeSelectedTaskReloadGuard(for: staleCheckedTask)
        )

        HomeDetailSelectionSupport.updatePendingChecklistReloadGuard(
            for: sciformaID,
            selection: &selection,
            now: now,
            calendar: .current
        )

        let reconciliation = HomeReloadGuardSupport.reconcileSelectedDetailTask(
            [staleCheckedTask],
            selectedTaskID: taskID,
            detailTask: uncheckedDetailTask,
            selectedTaskReloadGuard: selection.selectedTaskReloadGuard
        )

        #expect(reconciliation.tasks.first?.isChecklistItemCompleted(sciformaID, referenceDate: now) == false)
        #expect(reconciliation.selectedTaskReloadGuard?.completedChecklistItemIDsStorage == uncheckedDetailTask.completedChecklistItemIDsStorage)
    }
}

private func makeHomeRoutineDisplay(
    interval: Int = 1,
    recurrenceRule: RoutineRecurrenceRule = .interval(days: 1),
    scheduleMode: RoutineScheduleMode = .fixedInterval,
    lastDone: Date? = nil,
    scheduleAnchor: Date? = nil,
    daysUntilDue: Int = Int.max,
    hasMissedExactTimedOccurrence: Bool = false,
    isOneOffTask: Bool = false,
    isCompletedOneOff: Bool = false,
    isCanceledOneOff: Bool = false,
    isDoneToday: Bool = false,
    isPaused: Bool = false,
    locationAvailability: RoutineLocationAvailability = .unrestricted,
    isInProgress: Bool = false,
    completedChecklistItemCount: Int = 0
) -> HomeRoutineDisplay {
    HomeRoutineDisplay(
        taskID: UUID(),
        name: "Display",
        emoji: "sparkles",
        notes: nil,
        hasImage: false,
        placeID: nil,
        placeName: nil,
        locationAvailability: locationAvailability,
        tags: [],
        taskListTagSectionDescriptor: HomeTaskListTagGrouping.descriptor(for: []),
        steps: [],
        interval: interval,
        recurrenceRule: recurrenceRule,
        scheduleMode: scheduleMode,
        createdAt: nil,
        isSoftIntervalRoutine: false,
        lastDone: lastDone,
        canceledAt: nil,
        dueDate: nil,
        priority: .medium,
        importance: .level2,
        urgency: .level2,
        scheduleAnchor: scheduleAnchor,
        pausedAt: nil,
        snoozedUntil: nil,
        pinnedAt: nil,
        daysUntilDue: daysUntilDue,
        hasMissedExactTimedOccurrence: hasMissedExactTimedOccurrence,
        isOneOffTask: isOneOffTask,
        isCompletedOneOff: isCompletedOneOff,
        isCanceledOneOff: isCanceledOneOff,
        isDoneToday: isDoneToday,
        isPaused: isPaused,
        isSnoozed: false,
        isPinned: false,
        isOngoing: false,
        ongoingSince: nil,
        hasPassedSoftThreshold: false,
        completedStepCount: 0,
        isInProgress: isInProgress,
        nextStepTitle: nil,
        checklistItemCount: 0,
        completedChecklistItemCount: completedChecklistItemCount,
        dueChecklistItemCount: 0,
        nextPendingChecklistItemTitle: nil,
        nextDueChecklistItemTitle: nil,
        doneCount: 0
    )
}
