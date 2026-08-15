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
        #expect(!source.contains("private func metadataLabels"))
        #expect(!source.contains("No pressure value"))
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
