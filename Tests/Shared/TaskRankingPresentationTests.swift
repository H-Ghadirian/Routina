import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskRankingPresentationTests {
    private let referenceDate = Date(timeIntervalSince1970: 10_000)
    private let calendar = Calendar(identifier: .gregorian)

    @Test
    func categoricalMetricUsesSeparateValueAndMissingSectionsAndExcludesIneligibleTasks() {
        let high = RoutineTask(
            name: "High",
            pressure: .high,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let medium = RoutineTask(
            name: "Medium",
            pressure: .medium,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let unknown = RoutineTask(name: "Unknown", createdAt: Date(timeIntervalSince1970: 300))
        let paused = RoutineTask(
            name: "Paused",
            pressure: .high,
            pausedAt: Date(timeIntervalSince1970: 500)
        )
        let completed = RoutineTask(
            name: "Completed",
            pressure: .high,
            scheduleMode: .oneOff,
            lastDone: Date(timeIntervalSince1970: 500)
        )
        let canceled = RoutineTask(
            name: "Canceled",
            pressure: .high,
            scheduleMode: .oneOff,
            canceledAt: Date(timeIntervalSince1970: 500)
        )
        let blocked = RoutineTask(
            name: "Blocked",
            pressure: .high,
            scheduleMode: .oneOff,
            todoStateRawValue: TodoState.blocked.rawValue
        )

        let presentation = TaskRankingPresentation.make(
            tasks: [high, medium, unknown, paused, completed, canceled, blocked],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(presentation.sections.map(\.title) == ["High pressure", "Medium pressure", "No pressure"])
        #expect(presentation.sections.map(\.tasks.count) == [1, 1, 1])
        #expect(presentation.sections.last?.tasks.map(\.id) == [unknown.id])
        #expect(presentation.taskCount == 3)
        #expect(presentation.eligibleTaskIDs == Set([high.id, medium.id, unknown.id]))
        #expect(!presentation.sections.contains { section in
            section.tasks.contains(where: { $0.id == blocked.id })
        })
    }

    @Test
    func relationshipBlockedTasksStayOutOfTheLadderEvenWhenStoredStateIsActionable() {
        let blocker = RoutineTask(
            name: "Finish prerequisite",
            scheduleMode: .oneOff,
            todoStateRawValue: TodoState.ready.rawValue
        )
        let blocked = RoutineTask(
            name: "Dependent task",
            pressure: .high,
            relationships: [
                RoutineTaskRelationship(targetTaskID: blocker.id, kind: .blockedBy)
            ],
            scheduleMode: .oneOff,
            todoStateRawValue: TodoState.inProgress.rawValue
        )

        let presentation = TaskRankingPresentation.make(
            tasks: [blocker, blocked],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(presentation.taskCount == 1)
        #expect(presentation.eligibleTaskIDs == Set([blocker.id]))
        #expect(!presentation.sections.flatMap { $0.tasks }.contains(where: { $0.id == blocked.id }))
    }

    @Test
    func repeatingRelationshipBlockersUseCompletionHistoryHandoffs() {
        let olderBlockerCompletion = Date(timeIntervalSince1970: 200)
        let dependentCompletion = Date(timeIntervalSince1970: 300)
        let newerBlockerCompletion = Date(timeIntervalSince1970: 400)
        let blocker = RoutineTask(
            name: "Repeating prerequisite",
            pressure: .medium
        )
        let dependent = RoutineTask(
            name: "Repeating dependent",
            pressure: .high,
            relationships: [
                RoutineTaskRelationship(targetTaskID: blocker.id, kind: .blockedBy)
            ]
        )

        let stillBlocked = TaskRankingPresentation.make(
            tasks: [blocker, dependent],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            completionDatesByTaskID: [
                blocker.id: [olderBlockerCompletion],
                dependent.id: [dependentCompletion]
            ]
        )
        let unlocked = TaskRankingPresentation.make(
            tasks: [blocker, dependent],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            completionDatesByTaskID: [
                blocker.id: [newerBlockerCompletion],
                dependent.id: [dependentCompletion]
            ]
        )

        #expect(!stillBlocked.eligibleTaskIDs.contains(dependent.id))
        #expect(unlocked.eligibleTaskIDs.contains(dependent.id))
    }

    @Test
    func taskLadderFlagRuleExcludesOnlyTasksWithTheMatchingFlag() {
        let excluded = RoutineTask(name: "Excluded", pressure: .high, flags: ["Someday"])
        let included = RoutineTask(name: "Included", pressure: .high, flags: ["Current"])
        let hiddenFromHomeOnly = RoutineTask(
            name: "Hidden from Home only",
            pressure: .high,
            flags: ["Off radar"]
        )

        let presentation = TaskRankingPresentation.make(
            tasks: [excluded, included, hiddenFromHomeOnly],
            flagRules: [
                RoutineFlagRule(flag: "someday", kind: .hideFromTaskLadder),
                RoutineFlagRule(flag: "Off radar", kind: .hideFromTaskLists)
            ],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(Set(presentation.sections.flatMap(\.tasks).map(\.id)) == Set([
            included.id,
            hiddenFromHomeOnly.id
        ]))
        #expect(presentation.taskCount == 2)
    }

    @Test
    func rootLadderUsesPlacementIndependentlyFromCompletionRelationships() {
        let walk = RoutineTask(name: "Walk", pressure: .medium)
        let gym = RoutineTask(name: "Gym", pressure: .medium)
        let run = RoutineTask(name: "Run", pressure: .medium)
        let blockedSwim = RoutineTask(
            name: "Swim",
            pressure: .medium,
            scheduleMode: .oneOff,
            todoStateRawValue: TodoState.blocked.rawValue
        )
        let exercise = RoutineTask(name: "Exercise", pressure: .low)
        let legacyTarget = RoutineTask(name: "Movement", pressure: .low)
        let cycle = RoutineTask(
            name: "Cycle",
            pressure: .medium,
            relationships: [
                RoutineTaskRelationship(targetTaskID: legacyTarget.id, kind: .canComplete)
            ]
        )
        let callMom = RoutineTask(name: "Call Mom", pressure: .low)
        let tasks = [exercise, walk, gym, run, blockedSwim, legacyTarget, cycle, callMom]
        let organization = TaskLadderOrganization(placements: [
            TaskLadderPlacement(taskID: walk.id, parent: .task(exercise.id)),
            TaskLadderPlacement(taskID: gym.id, parent: .task(exercise.id)),
            TaskLadderPlacement(taskID: run.id, parent: .task(exercise.id)),
            TaskLadderPlacement(taskID: blockedSwim.id, parent: .task(exercise.id))
        ])

        let root = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let rootTaskIDs = Set(root.sections.flatMap(\.tasks).map(\.id))

        #expect(rootTaskIDs.contains(exercise.id))
        #expect(rootTaskIDs.contains(callMom.id))
        #expect(rootTaskIDs.contains(cycle.id))
        #expect(rootTaskIDs.contains(legacyTarget.id))
        #expect(!rootTaskIDs.contains(walk.id))
        #expect(!rootTaskIDs.contains(gym.id))
        #expect(!rootTaskIDs.contains(run.id))
        #expect(!rootTaskIDs.contains(blockedSwim.id))
        #expect(root.rowMetadataByTaskID[exercise.id]?.childCount == 3)

        let nested = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [exercise.id]
        )

        #expect(Set(nested.sections.flatMap(\.tasks).map(\.id)) == Set([walk.id, gym.id, run.id]))
        #expect(nested.scopeParentTaskID == exercise.id)
        #expect(nested.taskCount == 3)
    }

    @Test
    func explicitlyEnabledRepeatingTaskGroupIsOpenableBeforeItHasChildren() {
        let routine = RoutineTask(name: "Exercise", pressure: .medium)
        let organization = TaskLadderOrganization(taskGroupIDs: [routine.id])

        let presentation = TaskRankingPresentation.make(
            tasks: [routine],
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(presentation.rowMetadataByTaskID[routine.id]?.isTaskGroup == true)
        #expect(presentation.rowMetadataByTaskID[routine.id]?.childCount == 0)
    }

    @Test
    func taskGroupSuggestsEligibleBidirectionallyLinkedTasksThatCanBecomeChildren() throws {
        let exercise = RoutineTask(name: "Exercise", pressure: .low)
        let gym = RoutineTask(name: "Gym", pressure: .medium)
        let walk = RoutineTask(name: "Walk", pressure: .medium)
        let placed = RoutineTask(name: "Already placed", pressure: .medium)
        let rejected = RoutineTask(name: "Rejected", pressure: .medium)
        let hidden = RoutineTask(name: "Hidden", pressure: .medium, flags: ["Someday"])
        let cycle = RoutineTask(name: "Cycle", pressure: .medium)
        let moveMe = RoutineTask(
            name: "Move me",
            pressure: .medium,
            lastDone: referenceDate
        )
        exercise.replaceRelationships([
            RoutineTaskRelationship(targetTaskID: gym.id, kind: .related),
            RoutineTaskRelationship(targetTaskID: placed.id, kind: .blocks),
            RoutineTaskRelationship(targetTaskID: rejected.id, kind: .related),
            RoutineTaskRelationship(targetTaskID: hidden.id, kind: .related),
            RoutineTaskRelationship(targetTaskID: cycle.id, kind: .related),
            RoutineTaskRelationship(targetTaskID: moveMe.id, kind: .blockedBy)
        ])
        walk.replaceRelationships([
            RoutineTaskRelationship(targetTaskID: exercise.id, kind: .canComplete)
        ])
        let company = TaskLadderGroup(name: "Company")
        let organization = TaskLadderOrganization(
            groups: [company],
            placements: [
                TaskLadderPlacement(taskID: placed.id, parent: .task(exercise.id)),
                TaskLadderPlacement(taskID: exercise.id, parent: .task(cycle.id)),
                TaskLadderPlacement(taskID: moveMe.id, parent: .group(company.id))
            ],
            taskGroupIDs: [exercise.id],
            rejectedLinkedTaskChildSuggestions: [
                TaskLadderLinkedTaskSuggestionRejection(
                    parentTaskID: exercise.id,
                    linkedTaskID: rejected.id
                )
            ]
        )

        let presentation = TaskRankingPresentation.make(
            tasks: [exercise, gym, walk, placed, rejected, hidden, cycle, moveMe],
            organization: organization,
            flagRules: [RoutineFlagRule(flag: "Someday", kind: .hideFromTaskLadder)],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [exercise.id]
        )

        #expect(presentation.linkedTaskChildSuggestions.map(\.taskName) == ["Gym", "Move me", "Walk"])
        #expect(presentation.linkedTaskChildSuggestions.map(\.relationshipKind) == [
            .related,
            .blockedBy,
            .canBeCompletedBy
        ])
        #expect(presentation.linkedTaskChildSuggestions.first {
            $0.taskID == moveMe.id
        }?.willMoveFromAnotherPlacement == true)
        #expect(!presentation.linkedTaskChildSuggestions.contains { $0.taskID == placed.id })
        #expect(!presentation.linkedTaskChildSuggestions.contains { $0.taskID == rejected.id })
        #expect(!presentation.linkedTaskChildSuggestions.contains { $0.taskID == hidden.id })
        #expect(!presentation.linkedTaskChildSuggestions.contains { $0.taskID == cycle.id })
    }

    @Test
    func linkedTaskSuggestionsOnlyAppearInsideTaskBackedGroups() {
        let exercise = RoutineTask(name: "Exercise", pressure: .low)
        let walk = RoutineTask(
            name: "Walk",
            pressure: .medium,
            relationships: [
                RoutineTaskRelationship(targetTaskID: exercise.id, kind: .canComplete)
            ]
        )

        let root = TaskRankingPresentation.make(
            tasks: [exercise, walk],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let inactiveNested = TaskRankingPresentation.make(
            tasks: [exercise, walk],
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [exercise.id]
        )
        let activeNested = TaskRankingPresentation.make(
            tasks: [exercise, walk],
            organization: TaskLadderOrganization(taskGroupIDs: [exercise.id]),
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [exercise.id]
        )

        #expect(root.linkedTaskChildSuggestions.isEmpty)
        #expect(inactiveNested.linkedTaskChildSuggestions.isEmpty)
        #expect(activeNested.taskCount == 0)
        #expect(activeNested.linkedTaskChildSuggestions.map(\.taskID) == [walk.id])
        #expect(!activeNested.isEmpty)
    }

    @Test
    func linkedTaskSuggestionIdentityIsDistinctFromItsAcceptedTaskRowIdentity() throws {
        let exercise = RoutineTask(name: "Exercise", pressure: .low)
        let walk = RoutineTask(
            name: "Walk",
            pressure: .medium,
            relationships: [
                RoutineTaskRelationship(targetTaskID: exercise.id, kind: .canComplete)
            ]
        )
        let presentation = TaskRankingPresentation.make(
            tasks: [exercise, walk],
            organization: TaskLadderOrganization(taskGroupIDs: [exercise.id]),
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [exercise.id]
        )

        let suggestion = try #require(presentation.linkedTaskChildSuggestions.first)

        #expect(AnyHashable(suggestion.id) != AnyHashable(walk.id))
    }

    @Test
    func groupInheritsHighestCategoricalValuesFromItsActionableDirectTasks() throws {
        let company = TaskLadderGroup(
            name: "Company",
            inheritedMetrics: [.pressure, .urgency, .importance, .thinkingNeeded]
        )
        let lower = RoutineTask(
            name: "Lower",
            importance: .level1,
            urgency: .level1,
            pressure: .low,
            thinkingNeeded: .low,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
        let highestActionable = RoutineTask(
            name: "Highest actionable",
            importance: .level3,
            urgency: .level3,
            pressure: .medium,
            thinkingNeeded: .medium,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
        let blockedHigher = RoutineTask(
            name: "Blocked higher",
            importance: .level4,
            urgency: .level4,
            pressure: .high,
            thinkingNeeded: .high,
            scheduleMode: .oneOff,
            todoStateRawValue: TodoState.blocked.rawValue,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
        let organization = TaskLadderOrganization(
            groups: [company],
            placements: [lower, highestActionable, blockedHigher].map {
                TaskLadderPlacement(taskID: $0.id, parent: .group(company.id))
            }
        )
        let expectedValues: [TaskRankingMetric: TaskRankingMetricValue] = [
            .pressure: .pressure(.medium),
            .urgency: .urgency(.level3),
            .importance: .importance(.level3),
            .thinkingNeeded: .thinkingNeeded(.medium)
        ]

        for (metric, expectedValue) in expectedValues {
            let presentation = TaskRankingPresentation.make(
                tasks: [lower, highestActionable, blockedHigher],
                organization: organization,
                flagRules: [],
                metric: metric,
                isReversed: false,
                referenceDate: referenceDate,
                calendar: calendar
            )
            let groupSection = try #require(
                presentation.sections.first(where: { section in
                    section.tasks.contains(where: { $0.id == company.id })
                })
            )

            #expect(groupSection.value == expectedValue)
            #expect(presentation.rowMetadataByTaskID[company.id]?.inheritsMetricValue == true)
            #expect(presentation.rowMetadataByTaskID[company.id]?.childCount == 2)
        }
    }

    @Test
    func inheritedGroupStaysMissingWhenNoActionableChildHasAnExplicitValue() throws {
        let company = TaskLadderGroup(
            name: "Company",
            inheritedMetrics: [.pressure, .urgency, .importance, .thinkingNeeded]
        )
        let missing = RoutineTask(name: "Missing")
        let organization = TaskLadderOrganization(
            groups: [company],
            placements: [
                TaskLadderPlacement(taskID: missing.id, parent: .group(company.id))
            ]
        )

        for metric in [
            TaskRankingMetric.pressure,
            .urgency,
            .importance,
            .thinkingNeeded
        ] {
            let presentation = TaskRankingPresentation.make(
                tasks: [missing],
                organization: organization,
                flagRules: [],
                metric: metric,
                isReversed: false,
                referenceDate: referenceDate,
                calendar: calendar
            )
            let groupSection = try #require(
                presentation.sections.first(where: { section in
                    section.tasks.contains(where: { $0.id == company.id })
                })
            )

            #expect(groupSection.isMissingValue)
            #expect(groupSection.value == nil)
        }
    }

    @Test
    func nestedLadderTieBreakRanksAreScopedToTheParent() throws {
        let walk = RoutineTask(name: "Walk", pressure: .medium)
        let gym = RoutineTask(name: "Gym", pressure: .medium)
        let exercise = RoutineTask(name: "Exercise", pressure: .low)
        let organization = TaskLadderOrganization(placements: [
            TaskLadderPlacement(taskID: walk.id, parent: .task(exercise.id)),
            TaskLadderPlacement(taskID: gym.id, parent: .task(exercise.id))
        ])
        walk.setTaskRankingOrder(0, for: .pressure, value: .pressure(.medium))
        gym.setTaskRankingOrder(1_000_000, for: .pressure, value: .pressure(.medium))
        walk.setTaskRankingOrder(
            1_000_000,
            for: .pressure,
            value: .pressure(.medium),
            scopeTaskID: exercise.id
        )
        gym.setTaskRankingOrder(
            0,
            for: .pressure,
            value: .pressure(.medium),
            scopeTaskID: exercise.id
        )
        var tasks = [exercise, walk, gym]

        let nested = TaskRankingPresentation.make(
            tasks: tasks,
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [exercise.id]
        )
        #expect(nested.sections.first?.tasks.map(\.id) == [gym.id, walk.id])

        let update = try #require(
            TaskRankingOrderingSupport.moveTask(taskID: walk.id, direction: .up, in: nested)
        )
        TaskRankingOrderingSupport.apply(update, to: &tasks)

        let movedWalk = try #require(tasks.first(where: { $0.id == walk.id }))
        #expect(update.scopeTaskID == exercise.id)
        #expect(movedWalk.taskRankingOrder(
            for: .pressure,
            value: .pressure(.medium)
        ) == 0)
        #expect(movedWalk.taskRankingOrder(
            for: .pressure,
            value: .pressure(.medium),
            scopeTaskID: exercise.id
        ) != 1_000_000)
    }

    @Test
    func movingAcrossPressureSectionsThenUpPreservesNeighboursAndUsesOnlyLocalRanks() throws {
        let d = RoutineTask(name: "D", pressure: .medium, createdAt: Date(timeIntervalSince1970: 100))
        let c = RoutineTask(name: "C", pressure: .medium, createdAt: Date(timeIntervalSince1970: 90))
        let a = RoutineTask(name: "A", pressure: .low, createdAt: Date(timeIntervalSince1970: 80))
        let b = RoutineTask(name: "B", pressure: .low, createdAt: Date(timeIntervalSince1970: 70))
        d.setTaskRankingOrder(0, for: .pressure, value: .pressure(.medium))
        c.setTaskRankingOrder(2_000_000, for: .pressure, value: .pressure(.medium))
        a.setTaskRankingOrder(0, for: .pressure, value: .pressure(.low))
        b.setTaskRankingOrder(1_000_000, for: .pressure, value: .pressure(.low))
        var tasks = [d, c, a, b]

        var presentation = TaskRankingPresentation.make(
            tasks: tasks,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let moveToMedium = try #require(
            TaskRankingOrderingSupport.moveTask(taskID: a.id, direction: .up, in: presentation)
        )
        TaskRankingOrderingSupport.apply(moveToMedium, to: &tasks)

        presentation = TaskRankingPresentation.make(
            tasks: tasks,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(presentation.sections.first?.tasks.map(\.id) == [d.id, c.id, a.id])
        let moveAboveC = try #require(
            TaskRankingOrderingSupport.moveTask(taskID: a.id, direction: .up, in: presentation)
        )
        TaskRankingOrderingSupport.apply(moveAboveC, to: &tasks)

        let finalPresentation = TaskRankingPresentation.make(
            tasks: tasks,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(finalPresentation.sections.first?.tasks.map(\.id) == [d.id, a.id, c.id])
        #expect(tasks.first(where: { $0.id == a.id })?.pressure == .medium)
        #expect(tasks.first(where: { $0.id == d.id })?.taskRankingOrder(
            for: .pressure,
            value: .pressure(.medium)
        ) == 0)
        #expect(tasks.first(where: { $0.id == a.id })?.taskRankingOrder(
            for: .pressure,
            value: .pressure(.medium)
        ) == 1_000_000)
    }

    @Test
    func estimatedTimeSortIsReadOnlyAndKeepsMissingEstimatesSeparate() {
        let fifteen = RoutineTask(name: "15", estimatedDurationMinutes: 15)
        let sixteen = RoutineTask(name: "16", estimatedDurationMinutes: 16)
        let unknown = RoutineTask(name: "Unknown")

        let shortestFirst = TaskRankingPresentation.make(
            tasks: [sixteen, unknown, fifteen],
            flagRules: [],
            metric: .estimatedTime,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let longestFirst = TaskRankingPresentation.make(
            tasks: [sixteen, unknown, fifteen],
            flagRules: [],
            metric: .estimatedTime,
            isReversed: true,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(shortestFirst.sections.first?.tasks.map(\.id) == [fifteen.id, sixteen.id])
        #expect(longestFirst.sections.first?.tasks.map(\.id) == [sixteen.id, fifteen.id])
        #expect(shortestFirst.sections.first?.title == "Has estimate")
        #expect(shortestFirst.sections.allSatisfy { !$0.supportsManualOrdering })
        #expect(shortestFirst.sections.last?.title == "No estimate")
        #expect(
            TaskRankingOrderingSupport.moveTask(
                taskID: fifteen.id,
                direction: .down,
                in: shortestFirst
            ) == nil
        )
    }

    @Test
    func reorderingWithinPressureDoesNotRefreshItsValueTimestamp() throws {
        let first = RoutineTask(name: "First", pressure: .medium)
        let second = RoutineTask(name: "Second", pressure: .medium)
        let originalTimestamp = Date(timeIntervalSince1970: 7_000)
        first.pressureUpdatedAt = originalTimestamp
        second.pressureUpdatedAt = originalTimestamp
        first.setTaskRankingOrder(0, for: .pressure, value: .pressure(.medium))
        second.setTaskRankingOrder(1_000_000, for: .pressure, value: .pressure(.medium))
        var tasks = [first, second]

        let presentation = TaskRankingPresentation.make(
            tasks: tasks,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let update = try #require(
            TaskRankingOrderingSupport.moveTask(taskID: second.id, direction: .up, in: presentation)
        )
        TaskRankingOrderingSupport.apply(update, to: &tasks)

        #expect(tasks.first(where: { $0.id == second.id })?.pressureUpdatedAt == originalTimestamp)
    }

    @Test
    func directionPreferencesRoundTripIndependentlyForEachMetric() {
        let rawValue = TaskRankingDirectionStorage.encode([.pressure, .thinkingNeeded])

        #expect(TaskRankingDirectionStorage.decode(rawValue) == [.pressure, .thinkingNeeded])
        #expect(TaskRankingDirectionStorage.decode("pressure,unknown") == [.pressure])
    }

    @Test
    func rowMetadataShowsTagsAndRepeatingStateAcrossMetrics() throws {
        let repeating = RoutineTask(
            name: "Repeating",
            pressure: .medium,
            tags: ["Work", "Writing"],
            estimatedDurationMinutes: 30
        )
        let oneOff = RoutineTask(
            name: "One-off",
            pressure: .medium,
            tags: ["Admin"],
            scheduleMode: .oneOff,
            estimatedDurationMinutes: 15
        )

        for metric in TaskRankingMetric.allCases {
            let presentation = TaskRankingPresentation.make(
                tasks: [repeating, oneOff],
                flagRules: [],
                metric: metric,
                isReversed: false,
                referenceDate: referenceDate,
                calendar: calendar
            )

            #expect(presentation.rowMetadataByTaskID[repeating.id]?.tagLabels == ["#Work", "#Writing"])
            #expect(presentation.rowMetadataByTaskID[repeating.id]?.isRepeating == true)
            #expect(presentation.rowMetadataByTaskID[oneOff.id]?.tagLabels == ["#Admin"])
            #expect(presentation.rowMetadataByTaskID[oneOff.id]?.isRepeating == false)
        }
    }

    @Test
    func taskLadderRowsRenderRepeatingLabelWithoutMetricFallbacks() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )

        #expect(source.contains("metadata.tagLabels.joined(separator: \" • \")"))
        #expect(source.contains("Label(\"Repeating\", systemImage: \"repeat\")"))
        #expect(source.contains("Open Inner Task Ladder"))
        #expect(source.contains("metadata.childCount"))
        #expect(source.contains("metadata.inheritsMetricValue"))
        #expect(source.contains("Label(\"Inherited\", systemImage: \"arrow.triangle.branch\")"))
        #expect(!source.contains("private func metadataLabels"))
        #expect(!source.contains("No pressure value"))
    }

    @Test
    func taskLadderSearchFindsNestedTasksWithoutFlatteningTheirLocation() throws {
        let referenceDate = Date(timeIntervalSince1970: 1_000)
        let calendar = Calendar(identifier: .gregorian)
        let parent = RoutineTask(name: "Mail project", pressure: .high)
        let child = RoutineTask(name: "Read message", pressure: .medium)
        let hidden = RoutineTask(
            name: "Read private mail",
            pressure: .low,
            flags: ["No ladder"]
        )
        let organization = TaskLadderOrganization(
            placements: [TaskLadderPlacement(taskID: child.id, parent: .task(parent.id))],
            taskGroupIDs: [parent.id]
        )
        let flagRules = [RoutineFlagRule(flag: "No ladder", kind: .hideFromTaskLadder)]
        let ranking = TaskRankingPresentation.make(
            tasks: [parent, child, hidden],
            organization: organization,
            flagRules: flagRules,
            metric: .pressure,
            isReversed: false,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let search = TaskRankingSearchPresentation.make(
            tasks: [parent, child, hidden],
            organization: organization,
            eligibleTaskIDs: ranking.eligibleTaskIDs,
            flagRules: flagRules,
            metric: .pressure,
            valueMode: .base,
            searchText: "read",
            referenceDate: referenceDate,
            calendar: calendar
        )

        let match = try #require(search.matches.first)
        #expect(match.task.id == child.id)
        #expect(match.scopePath == [parent.id])
        #expect(match.locationTitle == "Task Ladder › Mail project › Medium pressure")
        let outsideMatch = try #require(search.outsideMatches.first)
        #expect(outsideMatch.task.id == hidden.id)
        #expect(outsideMatch.reason == "Hidden from Task Ladder by Flag")
    }

    @Test
    func taskLadderOffersBaseNowAndTemporalRuleEditing() throws {
        let viewSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )
        let featureSource = try Self.sourceFile(
            "SharedCore/Features/Home/TaskRankingFeature.swift"
        )
        let sharedEditorSource = try Self.sourceFile(
            "SharedCore/Screens/Shared/TaskTemporalWeightRuleEditor.swift"
        )

        #expect(viewSource.contains("ForEach(TaskRankingValueMode.allCases)"))
        #expect(viewSource.contains("Button(\"Changes over Time…\")"))
        #expect(viewSource.contains("TaskTemporalWeightRuleSheet("))
        #expect(sharedEditorSource.contains("Define the value after completion and the independent due-date behavior"))
        #expect(sharedEditorSource.contains("TaskTemporalWeightSummaryCard"))
        #expect(sharedEditorSource.contains("RoutineTaskTemporalWeightTiming.allCases"))
        #expect(sharedEditorSource.contains("case .gradualBeforeDue:"))
        #expect(sharedEditorSource.contains("case .gradualWhileOverdue:"))
        #expect(!sharedEditorSource.contains(".pickerStyle(.segmented)"))
        #expect(featureSource.contains("case temporalBoundaryReached"))
        #expect(featureSource.contains("scheduleTemporalRefresh(for: state)"))
        #expect(featureSource.contains("persistTemporalWeightRule("))
        #expect(featureSource.contains("importance: importance"))
    }

    @Test
    func taskLadderGroupEditorOffersInheritedValues() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskLadderOrganizationMacViews.swift"
        )

        #expect(source.contains("Inherit (highest task value)"))
        #expect(source.contains("group.setInheritsValue(true, for: metric)"))
        #expect(source.contains("group's actionable tasks"))
    }

    @Test
    func taskLadderGroupEditorSnapshotsExistingGroupBeforePresentation() throws {
        let rankingSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )
        let editorSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskLadderOrganizationMacViews.swift"
        )

        #expect(rankingSource.contains("struct TaskLadderGroupEditorPresentation: Identifiable"))
        #expect(rankingSource.contains("let group: TaskLadderGroup?"))
        #expect(rankingSource.contains(".sheet(item: $groupEditorPresentation)"))
        #expect(rankingSource.contains("group: presentation.group"))
        #expect(rankingSource.contains("TaskLadderGroupEditorPresentation(group: group)"))
        #expect(!rankingSource.contains("isGroupEditorPresented"))
        #expect(!rankingSource.contains("editingGroupID"))
        #expect(editorSource.contains("_group = State(initialValue: group ?? TaskLadderGroup(name: \"\"))"))
        #expect(editorSource.contains(".disabled(group.name.trimmingCharacters"))
    }

    @Test
    func taskLadderOffersDirectRepeatingTaskGroupFlow() throws {
        let rankingSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )
        let organizationSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskLadderOrganizationMacViews.swift"
        )

        #expect(rankingSource.contains("Use Repeating Task as Group…"))
        #expect(rankingSource.contains("Add Task to This Group…"))
        #expect(rankingSource.contains("if !task.isOneOffTask"))
        #expect(rankingSource.contains(".taskPlacementSaved("))
        #expect(rankingSource.contains(".task(parentTaskID)"))
        #expect(rankingSource.contains(".childLadderOpened(parentTaskID)"))
        #expect(organizationSource.contains("The repeating task keeps its schedule, completion action, and history."))
        #expect(organizationSource.contains("organization.validParents("))
        #expect(organizationSource.contains("TaskLadderPlacementEditorSheet.completionBehavior("))
    }

    @Test
    func taskLadderLetsPeopleAcceptOrRejectLinkedTaskChildSuggestions() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )

        #expect(source.contains("Linked task suggestions"))
        #expect(source.contains("Label(\"Reject\", systemImage: \"xmark\")"))
        #expect(source.contains("Label(\"Accept\", systemImage: \"checkmark\")"))
        #expect(source.contains(".linkedTaskChildSuggestionRejected("))
        #expect(source.contains(".linkedTaskChildSuggestionAccepted("))
        #expect(source.contains("keeps the task link and its completion behavior unchanged"))
        #expect(source.contains("ForEach(store.presentation.linkedTaskChildSuggestions)"))
    }

    @Test
    func taskLadderGroupRowsShowDetailsOnClickAndOpenTheirInnerLadderOnDoubleClick() throws {
        let viewSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )
        let featureSource = try Self.sourceFile(
            "SharedCore/Features/Home/TaskRankingFeature.swift"
        )

        #expect(viewSource.contains("store.send(.groupSelected(task.id))"))
        #expect(viewSource.contains(".onMacDoubleClick(enabled: canOpenInnerLadder)"))
        #expect(viewSource.contains("store.send(.childLadderOpened(task.id))"))
        #expect(viewSource.contains("Click to show details; double-click to open the inner Task Ladder"))
        #expect(viewSource.contains("Button(\"Show Group Details\")"))
        #expect(viewSource.contains("Button(\"Open Inner Task Ladder\")"))
        #expect(viewSource.contains("store.detailGroup"))
        #expect(featureSource.contains("var selectedGroupID: UUID?"))
        #expect(featureSource.contains("case groupSelected(UUID)"))
        #expect(featureSource.contains("var detailGroup: TaskLadderGroup?"))
        #expect(featureSource.contains("var detailGroupChildCount: Int"))
    }

    @Test
    func taskLadderObservesSelectionAtBodyAndRefreshesOnlyChangedRowChrome() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )

        let bodyStart = try #require(source.range(of: "var body: some View"))
        let bodyEnd = try #require(
            source.range(
                of: "private var workspaceControls",
                range: bodyStart.upperBound..<source.endIndex
            )
        )
        let body = source[bodyStart.lowerBound..<bodyEnd.lowerBound]
        let selectedTaskRead = try #require(body.range(of: "let selectedTaskID = store.selectedTaskID"))
        let splitView = try #require(body.range(of: "HSplitView {"))
        #expect(selectedTaskRead.lowerBound < splitView.lowerBound)
        #expect(source.contains("let selectedTaskID = store.selectedTaskID"))
        #expect(source.contains("let selectedGroupID = store.selectedGroupID"))
        #expect(source.contains("let selectedNodeID: TaskLadderNodeID?"))
        #expect(source.contains("rankingList(selectedNodeID: selectedNodeID)"))
        #expect(source.contains("TaskLadderRowSelectionIdentity("))
        #expect(source.contains(".id(selectionIdentity)"))
        #expect(source.contains(".accessibilityAddTraits(isSelected ? .isSelected : [])"))
        #expect(!source.contains("? store.selectedGroupID == task.id"))
    }

    @Test
    func taskLadderRowSelectionIdentityChangesOnlyForOldAndNewSelection() {
        let firstID = UUID()
        let secondID = UUID()
        let unrelatedID = UUID()
        let firstNode = TaskLadderNodeID.task(firstID)
        let secondNode = TaskLadderNodeID.task(secondID)
        let unrelatedNode = TaskLadderNodeID.task(unrelatedID)

        let before = [firstNode, secondNode, unrelatedNode].map {
            TaskLadderRowSelectionIdentity(nodeID: $0, selectedNodeID: firstNode)
        }
        let after = [firstNode, secondNode, unrelatedNode].map {
            TaskLadderRowSelectionIdentity(nodeID: $0, selectedNodeID: secondNode)
        }

        #expect(before[0] != after[0])
        #expect(before[1] != after[1])
        #expect(before[2] == after[2])
        #expect(before.map(\.isSelected) == [true, false, false])
        #expect(after.map(\.isSelected) == [false, true, false])
    }

    @Test
    func macTaskLadderChromeStatesEachConceptOnce() throws {
        let rankingSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )
        let groupDetailSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskLadderOrganizationMacViews.swift"
        )

        #expect(rankingSource.contains("Label(\"Add Group\", systemImage: \"folder.badge.plus\")"))
        #expect(rankingSource.contains("Text(taskCountLabel)"))
        #expect(rankingSource.contains("if !store.scopePath.isEmpty"))
        #expect(rankingSource.contains("Text(store.scopeParentName ?? \"Nested tasks\")"))
        #expect(!rankingSource.contains("Text(store.scopeParentName ?? \"Task Ladder\")"))
        #expect(!rankingSource.contains("private var listSubtitle"))
        #expect(!rankingSource.contains("section.isMissingValue ? \"Separate\" : \"Read only\""))
        #expect(rankingSource.contains("read only"))
        #expect(groupDetailSource.contains("Tasks inside this group are completed independently."))
        #expect(!groupDetailSource.contains("This is an organizational container."))
        #expect(!groupDetailSource.contains("Task Ladder group ·"))
    }

    @Test
    func taskLadderValueSectionsHaveIndependentCollapsibleHeaders() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )

        #expect(source.contains("@State private var collapsedSectionIDs = Set<String>()"))
        #expect(source.contains("let isCollapsed = collapsedSectionIDs.contains(section.id)"))
        #expect(source.contains("toggleRankingSection(section)"))
        #expect(source.contains("collapsedSectionIDs.insert(section.id)"))
        #expect(source.contains("collapsedSectionIDs.remove(section.id)"))
        #expect(source.contains("section.supportsManualOrdering"))
        #expect(source.contains("read only"))
    }

    @Test
    func taskLadderKeepsRowsAsDirectLazySectionContent() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )

        #expect(source.contains("LazyVStack(alignment: .leading, spacing: 0)"))
        #expect(source.contains("Section {"))
        #expect(source.contains("ForEach(section.tasks)"))
        #expect(source.contains("rankingSectionHeader(section, isCollapsed: isCollapsed)"))
        #expect(!source.contains("private func rankingSection(_ section"))
    }

    @Test
    func onDueDateRuleKeepsBaseBeforeDueAndJumpsOnDueDate() throws {
        let interval = 10
        let dueTodayAnchor = try #require(
            calendar.date(byAdding: .day, value: -interval, to: referenceDate)
        )
        let dueTomorrowAnchor = try #require(
            calendar.date(byAdding: .day, value: -(interval - 1), to: referenceDate)
        )
        let task = RoutineTask(
            name: "Due-weighted",
            pressure: .low,
            scheduleMode: .fixedInterval,
            interval: Int16(interval),
            recurrenceRule: .interval(days: interval),
            lastDone: dueTomorrowAnchor,
            scheduleAnchor: dueTomorrowAnchor
        )
        task.temporalWeightRule = RoutineTaskTemporalWeightRule(
            curve: .onDueDate,
            pressureAtDue: .high
        )

        #expect(
            RoutineTaskTemporalWeightResolver.effectiveWeights(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ).pressure == .low
        )

        task.lastDone = dueTodayAnchor
        task.scheduleAnchor = dueTodayAnchor

        #expect(
            RoutineTaskTemporalWeightResolver.effectiveWeights(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ).pressure == .high
        )
    }

    @Test
    func gradualRuleStepsTowardDueTargetsInsideLeadWindow() throws {
        let interval = 10
        let twoDaysBeforeDueAnchor = try #require(
            calendar.date(byAdding: .day, value: -(interval - 2), to: referenceDate)
        )
        let task = RoutineTask(
            name: "Gradual",
            importance: .level1,
            urgency: .level1,
            pressure: .none,
            scheduleMode: .fixedInterval,
            interval: Int16(interval),
            recurrenceRule: .interval(days: interval),
            lastDone: twoDaysBeforeDueAnchor,
            scheduleAnchor: twoDaysBeforeDueAnchor,
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
        task.temporalWeightRule = RoutineTaskTemporalWeightRule(
            curve: .gradual,
            leadDays: 6,
            importanceAtDue: .level4,
            urgencyAtDue: .level4,
            pressureAtDue: .high
        )

        let weights = RoutineTaskTemporalWeightResolver.effectiveWeights(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(weights.importance == .level3)
        #expect(weights.urgency == .level3)
        #expect(weights.pressure == .medium)
        #expect(weights.progress > 0 && weights.progress < 1)
    }

    @Test
    func eachTemporalMetricUsesItsOwnDueDatePolicy() throws {
        let interval = 10
        let task = RoutineTask(
            name: "Independent changes",
            importance: .level1,
            urgency: .level1,
            pressure: .none,
            scheduleMode: .fixedInterval,
            interval: Int16(interval),
            recurrenceRule: .interval(days: interval),
            hasExplicitImportance: true,
            hasExplicitUrgency: true
        )
        task.temporalWeightRule = RoutineTaskTemporalWeightRule(
            importance: RoutineTaskTemporalWeightPolicy(
                target: .level4,
                timing: .onDueDate
            ),
            urgency: RoutineTaskTemporalWeightPolicy(
                target: .level4,
                timing: .gradualBeforeDue,
                days: 5
            ),
            pressure: RoutineTaskTemporalWeightPolicy(
                target: .high,
                timing: .gradualWhileOverdue,
                days: 1
            )
        )

        let twoDaysBeforeDueAnchor = try #require(
            calendar.date(byAdding: .day, value: -(interval - 2), to: referenceDate)
        )
        task.lastDone = twoDaysBeforeDueAnchor
        task.scheduleAnchor = twoDaysBeforeDueAnchor
        let beforeDue = RoutineTaskTemporalWeightResolver.effectiveWeights(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(beforeDue.importance == .level1)
        #expect(beforeDue.urgency == .level3)
        #expect(beforeDue.pressure == .none)

        let dueTodayAnchor = try #require(
            calendar.date(byAdding: .day, value: -interval, to: referenceDate)
        )
        task.lastDone = dueTodayAnchor
        task.scheduleAnchor = dueTodayAnchor
        let dueToday = RoutineTaskTemporalWeightResolver.effectiveWeights(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(dueToday.importance == .level4)
        #expect(dueToday.urgency == .level4)
        #expect(dueToday.pressure == .none)

        let twoDaysOverdueAnchor = try #require(
            calendar.date(byAdding: .day, value: -(interval + 2), to: referenceDate)
        )
        task.lastDone = twoDaysOverdueAnchor
        task.scheduleAnchor = twoDaysOverdueAnchor
        let overdue = RoutineTaskTemporalWeightResolver.effectiveWeights(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        #expect(overdue.importance == .level4)
        #expect(overdue.urgency == .level4)
        #expect(overdue.pressure == .medium)
    }

    @Test
    func afterDoneCadenceCapsBeforeDueWindowToItsRepeatInterval() {
        let task = RoutineTask(
            name: "Every two days",
            importance: .level1,
            scheduleMode: .fixedInterval,
            interval: 2,
            recurrenceRule: .interval(days: 2)
        )
        task.temporalWeightRule = RoutineTaskTemporalWeightRule(
            importance: RoutineTaskTemporalWeightPolicy(
                target: .level4,
                timing: .gradualBeforeDue,
                days: 7
            )
        )

        let sanitized = RoutineTaskTemporalWeightResolver.sanitizedRule(
            task.temporalWeightRule,
            for: task
        )

        #expect(sanitized?.importance?.days == 2)
    }

    @Test
    func legacySharedCurveStorageMigratesToIndependentMetricPolicies() throws {
        let legacyStorage =
            #"{"curve":"gradual","leadDays":7,"importanceAtDue":"Critical","pressureAtDue":"High"}"#
        let migrated = try #require(
            RoutineTaskTemporalWeightStorage.deserialize(legacyStorage)
        )

        #expect(migrated.importance?.target == .level4)
        #expect(migrated.importance?.timing == .gradualBeforeDue)
        #expect(migrated.importance?.days == 7)
        #expect(migrated.urgency == nil)
        #expect(migrated.pressure?.target == .high)
        #expect(migrated.pressure?.timing == .gradualBeforeDue)
        #expect(migrated.pressure?.days == 7)
        #expect(!RoutineTaskTemporalWeightStorage.serialize(migrated).contains("leadDays"))
    }

    @Test
    func advancingCompletedOccurrenceReturnsNowValuesToBase() throws {
        let interval = 7
        let dueTodayAnchor = try #require(
            calendar.date(byAdding: .day, value: -interval, to: referenceDate)
        )
        let task = RoutineTask(
            name: "Reset after done",
            pressure: .low,
            scheduleMode: .fixedInterval,
            interval: Int16(interval),
            recurrenceRule: .interval(days: interval),
            lastDone: dueTodayAnchor,
            scheduleAnchor: dueTodayAnchor
        )
        task.temporalWeightRule = RoutineTaskTemporalWeightRule(
            curve: .gradual,
            leadDays: 3,
            pressureAtDue: .high
        )

        #expect(
            RoutineTaskTemporalWeightResolver.effectiveWeights(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ).pressure == .high
        )

        task.lastDone = referenceDate
        task.scheduleAnchor = referenceDate

        #expect(
            RoutineTaskTemporalWeightResolver.effectiveWeights(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ).pressure == .low
        )
    }

    @Test
    func nowPresentationIsReadOnlyAndInheritedGroupsUseEffectiveChildValue() throws {
        let interval = 7
        let dueTodayAnchor = try #require(
            calendar.date(byAdding: .day, value: -interval, to: referenceDate)
        )
        let child = RoutineTask(
            name: "Dynamic child",
            pressure: .low,
            scheduleMode: .fixedInterval,
            interval: Int16(interval),
            recurrenceRule: .interval(days: interval),
            lastDone: dueTodayAnchor,
            scheduleAnchor: dueTodayAnchor
        )
        child.temporalWeightRule = RoutineTaskTemporalWeightRule(
            curve: .onDueDate,
            pressureAtDue: .high
        )
        let group = TaskLadderGroup(name: "Inherited", inheritedMetrics: [.pressure])
        let organization = TaskLadderOrganization(
            groups: [group],
            placements: [TaskLadderPlacement(taskID: child.id, parent: .group(group.id))]
        )

        let base = TaskRankingPresentation.make(
            tasks: [child],
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            valueMode: .base,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let now = TaskRankingPresentation.make(
            tasks: [child],
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            valueMode: .now,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let nestedNow = TaskRankingPresentation.make(
            tasks: [child],
            organization: organization,
            flagRules: [],
            metric: .pressure,
            isReversed: false,
            valueMode: .now,
            referenceDate: referenceDate,
            calendar: calendar,
            scopePath: [group.id]
        )

        #expect(base.sections.first { $0.tasks.contains(where: { $0.id == group.id }) }?.value == .pressure(.low))
        #expect(now.sections.first { $0.tasks.contains(where: { $0.id == group.id }) }?.value == .pressure(.high))
        #expect(now.sections.allSatisfy { !$0.supportsManualOrdering })
        #expect(nestedNow.rowMetadataByTaskID[child.id]?.temporalTimingLabel == "Due today")
        #expect(TaskRankingOrderingSupport.moveTask(taskID: group.id, direction: .down, in: now) == nil)
    }

    @Test
    func temporalRuleRoundTripsAndSoftRoutinesIgnoreIt() {
        let task = RoutineTask(name: "Gentle", pressure: .low, scheduleMode: .softInterval)
        let rule = RoutineTaskTemporalWeightRule(
            curve: .gradual,
            leadDays: 14,
            importanceAtDue: .level4,
            urgencyAtDue: .level3,
            pressureAtDue: .high
        )

        task.temporalWeightRule = rule

        #expect(task.temporalWeightRule == rule)
        #expect(!RoutineTaskTemporalWeightResolver.supportsTemporalWeight(task))
        #expect(
            RoutineTaskTemporalWeightResolver.effectiveWeights(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            ).pressure == .low
        )
    }

    @Test
    func temporalValuesRejectLegacyRecordRowsWithoutACompatibilitySetupPath() {
        let task = RoutineTask(name: "Legacy", scheduleMode: .softInterval)

        #expect(!RoutineTaskTemporalWeightResolver.supportsTemporalWeight(task))
        #expect(task.scheduleMode.taskType.userFacingTitle == "Repeating task")
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
