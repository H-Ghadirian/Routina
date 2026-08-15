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
        #expect(!presentation.sections.contains { section in
            section.tasks.contains(where: { $0.id == blocked.id })
        })
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
        #expect(source.contains("Show Nested Tasks"))
        #expect(source.contains("metadata.childCount"))
        #expect(source.contains("metadata.inheritsMetricValue"))
        #expect(source.contains("Label(\"Inherited\", systemImage: \"arrow.triangle.branch\")"))
        #expect(!source.contains("private func metadataLabels"))
        #expect(!source.contains("No pressure value"))
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
    func taskLadderValueSectionsHaveIndependentCollapsibleHeaders() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )

        #expect(source.contains("@State private var collapsedSectionIDs = Set<String>()"))
        #expect(source.contains("let isCollapsed = collapsedSectionIDs.contains(section.id)"))
        #expect(source.contains("toggleRankingSection(section)"))
        #expect(source.contains("collapsedSectionIDs.insert(section.id)"))
        #expect(source.contains("collapsedSectionIDs.remove(section.id)"))
        #expect(source.contains("accessibilityValue(isCollapsed ? \"Collapsed\" : \"Expanded\")"))
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
