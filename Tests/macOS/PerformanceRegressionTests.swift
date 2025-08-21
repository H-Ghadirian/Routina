import XCTest
@testable @preconcurrency import RoutinaMacOSDev

final class PerformanceRegressionTests: XCTestCase {
    func testMacStatsViewDoesNotBindSwiftDataQueriesIntoRenderPath() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/StatsView.swift")

        XCTAssertFalse(
            source.contains("@Query"),
            "Mac Stats scrolling should not bind SwiftData @Query arrays into the visible render path. Fetch on data-change notifications instead."
        )
        XCTAssertTrue(
            source.contains("FetchDescriptor<RoutineTask>()"),
            "Stats data should still be refreshed explicitly from SwiftData when the underlying data changes."
        )
    }

    func testMacHomeToolbarDoesNotScanRoutineTaskModelsForStatsModeBadges() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift")

        XCTAssertFalse(
            source.contains("store.routineTasks.filter"),
            "The mac toolbar is rebuilt while Stats scrolls; it should use display snapshots instead of scanning SwiftData-backed RoutineTask models."
        )
        XCTAssertTrue(source.contains("homeToolbarRoutineCount"))
        XCTAssertTrue(source.contains("homeToolbarTodoCount"))
    }

    func testStatsChartsOnlyUseNestedScrollingWhenChartNeedsOverflow() {
        XCTAssertFalse(
            StatsChartPresentation(selectedRange: .today, isCompact: false).usesHorizontalChartScroll
        )
        XCTAssertFalse(
            StatsChartPresentation(selectedRange: .week, isCompact: false).usesHorizontalChartScroll
        )
        XCTAssertFalse(
            StatsChartPresentation(selectedRange: .month, isCompact: false).usesHorizontalChartScroll
        )
        XCTAssertTrue(
            StatsChartPresentation(selectedRange: .month, isCompact: true).usesHorizontalChartScroll
        )
        XCTAssertTrue(
            StatsChartPresentation(selectedRange: .year, isCompact: false).usesHorizontalChartScroll
        )
    }

    func testStatsDerivedStateLargeDatasetPerformance() {
        let referenceDate = Self.referenceDate
        let calendar = Self.calendar
        let fixture = Self.makeStatsFixture(
            taskCount: 2_400,
            logCount: 18_000,
            focusSessionCount: 2_400,
            referenceDate: referenceDate
        )

        let baseline = Self.makeStatsDerivedState(
            fixture: fixture,
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertGreaterThan(baseline.filteredTaskCount, 0)
        XCTAssertGreaterThan(baseline.metrics.chartPoints.count, 100)
        XCTAssertLessThanOrEqual(baseline.metrics.chartPoints.count, DoneChartRange.year.trailingDayCount)
        XCTAssertEqual(baseline.metrics.createdChartPoints.count, baseline.metrics.chartPoints.count)
        XCTAssertFalse(baseline.metrics.tagUsagePoints.isEmpty)
        XCTAssertFalse(baseline.tagSummaries.isEmpty)
        XCTAssertFalse(baseline.availableExcludeTags.contains("Focus"))
        XCTAssertGreaterThan(baseline.taskCountForSelectedTypeFilter, baseline.filteredTaskCount)

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(),
                XCTMemoryMetric()
            ],
            options: options
        ) {
            _ = Self.makeStatsDerivedState(
                fixture: fixture,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    func testStatsDerivedStatePrecomputesSidebarTagData() {
        let referenceDate = Self.referenceDate
        let calendar = Self.calendar
        let focusRoutine = RoutineTask(
            name: "Focus Routine",
            tags: ["Focus", "Deep"],
            scheduleMode: .fixedInterval,
            lastDone: referenceDate.addingTimeInterval(-86_400),
            createdAt: referenceDate.addingTimeInterval(-172_800)
        )
        let blockedTodo = RoutineTask(
            name: "Blocked Todo",
            tags: ["Focus", "Blocked"],
            scheduleMode: .oneOff,
            lastDone: nil,
            createdAt: referenceDate.addingTimeInterval(-86_400),
            todoStateRawValue: TodoState.blocked.rawValue
        )
        let healthRoutine = RoutineTask(
            name: "Health Routine",
            tags: ["Health"],
            scheduleMode: .fixedInterval,
            lastDone: nil,
            createdAt: referenceDate.addingTimeInterval(-43_200)
        )
        let state = StatsFeatureDerivedStateBuilder.build(
            tasks: [focusRoutine, blockedTodo, healthRoutine],
            logs: [
                RoutineLog(timestamp: referenceDate, taskID: focusRoutine.id, kind: .completed),
                RoutineLog(timestamp: referenceDate, taskID: blockedTodo.id, kind: .completed)
            ],
            focusSessions: [],
            selectedRange: .week,
            taskTypeFilter: .all,
            createdChartTaskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Focus"],
            includeTagMatchMode: .all,
            excludedTags: ["Blocked"],
            excludeTagMatchMode: .any,
            tagColors: ["focus": "#112233"],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(state.taskCountForSelectedTypeFilter, 3)
        XCTAssertEqual(state.filteredTaskCount, 1)
        XCTAssertEqual(state.availableExcludeTags, ["Blocked", "Deep"])
        XCTAssertEqual(
            state.tagSummaries.map(\.name),
            ["Blocked", "Deep", "Focus", "Health"]
        )
        XCTAssertEqual(
            state.tagSummaries.first { $0.name == "Focus" }?.colorHex,
            "#112233"
        )
    }

    func testTimelineGroupingLargeDatasetPerformance() {
        let referenceDate = Self.referenceDate
        let calendar = Self.calendar
        let fixture = Self.makeTimelineFixture(
            taskCount: 1_800,
            logCount: 16_000,
            referenceDate: referenceDate
        )

        let baseline = Self.makeTimelineSections(
            fixture: fixture,
            referenceDate: referenceDate,
            calendar: calendar
        )
        XCTAssertGreaterThanOrEqual(baseline.count, 28)
        XCTAssertFalse(baseline.first?.entries.isEmpty ?? true)

        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(
            metrics: [
                XCTClockMetric(),
                XCTCPUMetric(),
                XCTMemoryMetric()
            ],
            options: options
        ) {
            _ = Self.makeTimelineSections(
                fixture: fixture,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }
}

private extension PerformanceRegressionTests {
    struct StatsFixture {
        var tasks: [RoutineTask]
        var logs: [RoutineLog]
        var focusSessions: [FocusSession]
    }

    struct TimelineFixture {
        var tasks: [RoutineTask]
        var logs: [RoutineLog]
    }

    static var referenceDate: Date {
        Date(timeIntervalSince1970: 1_774_007_200)
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = testsDirectory
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    static func makeStatsDerivedState(
        fixture: StatsFixture,
        referenceDate: Date,
        calendar: Calendar
    ) -> StatsFeatureDerivedState {
        StatsFeatureDerivedStateBuilder.build(
            tasks: fixture.tasks,
            logs: fixture.logs,
            focusSessions: fixture.focusSessions,
            selectedRange: .year,
            taskTypeFilter: .all,
            createdChartTaskTypeFilter: .all,
            selectedImportanceUrgencyFilter: nil,
            advancedQuery: "",
            selectedTags: ["Focus"],
            includeTagMatchMode: .all,
            excludedTags: ["Blocked"],
            excludeTagMatchMode: .any,
            tagColors: [:],
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func makeTimelineSections(
        fixture: TimelineFixture,
        referenceDate: Date,
        calendar: Calendar
    ) -> [(date: Date, entries: [TimelineEntry])] {
        let entries = TimelineLogic.filteredEntries(
            logs: fixture.logs,
            tasks: fixture.tasks,
            range: .month,
            filterType: .all,
            now: referenceDate,
            calendar: calendar
        )
        return TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
    }

    static func makeStatsFixture(
        taskCount: Int,
        logCount: Int,
        focusSessionCount: Int,
        referenceDate: Date
    ) -> StatsFixture {
        let tasks = makeTasks(count: taskCount, referenceDate: referenceDate)
        let logs = makeLogs(count: logCount, tasks: tasks, referenceDate: referenceDate)
        let focusSessions = makeFocusSessions(
            count: focusSessionCount,
            tasks: tasks,
            referenceDate: referenceDate
        )
        return StatsFixture(tasks: tasks, logs: logs, focusSessions: focusSessions)
    }

    static func makeTimelineFixture(
        taskCount: Int,
        logCount: Int,
        referenceDate: Date
    ) -> TimelineFixture {
        let tasks = makeTasks(count: taskCount, referenceDate: referenceDate)
        let logs = makeLogs(count: logCount, tasks: tasks, referenceDate: referenceDate)
        return TimelineFixture(tasks: tasks, logs: logs)
    }

    static func makeTasks(count: Int, referenceDate: Date) -> [RoutineTask] {
        (0..<count).map { index in
            let isTodo = index.isMultiple(of: 4)
            return RoutineTask(
                name: "Perf Task \(index)",
                emoji: isTodo ? "square.and.pencil" : "checklist",
                notes: "Synthetic performance fixture task \(index)",
                priority: priority(for: index),
                importance: importance(for: index),
                urgency: urgency(for: index),
                tags: tags(for: index),
                scheduleMode: isTodo ? .oneOff : .fixedInterval,
                interval: Int16((index % 14) + 1),
                lastDone: referenceDate.addingTimeInterval(TimeInterval(-86_400 * (index % 60))),
                pausedAt: index.isMultiple(of: 11) ? referenceDate : nil,
                pinnedAt: index.isMultiple(of: 9) ? referenceDate.addingTimeInterval(TimeInterval(-index)) : nil,
                createdAt: referenceDate.addingTimeInterval(TimeInterval(-43_200 * (index % 365))),
                todoStateRawValue: isTodo ? todoState(for: index).rawValue : nil,
                estimatedDurationMinutes: 15 + (index % 8) * 5,
                storyPoints: (index % 13) + 1
            )
        }
    }

    static func makeLogs(count: Int, tasks: [RoutineTask], referenceDate: Date) -> [RoutineLog] {
        (0..<count).map { index in
            let task = tasks[index % tasks.count]
            let secondsAgo = TimeInterval(900 * index)
            return RoutineLog(
                timestamp: referenceDate.addingTimeInterval(-secondsAgo),
                taskID: task.id,
                kind: index.isMultiple(of: 9) ? .canceled : .completed,
                actualDurationMinutes: 10 + (index % 8) * 5
            )
        }
    }

    static func makeFocusSessions(
        count: Int,
        tasks: [RoutineTask],
        referenceDate: Date
    ) -> [FocusSession] {
        (0..<count).map { index in
            let task = tasks[index % tasks.count]
            let startedAt = referenceDate.addingTimeInterval(TimeInterval(-1_800 * index))
            return FocusSession(
                taskID: task.id,
                startedAt: startedAt,
                plannedDurationSeconds: 25 * 60,
                completedAt: startedAt.addingTimeInterval(TimeInterval(600 + (index % 6) * 300))
            )
        }
    }

    static func tags(for index: Int) -> [String] {
        let primary = ["Focus", "Health", "Admin", "Learning", "Planning", "Writing"]
        let secondary = ["Morning", "Evening", "Review", "Deep Work", "Quick"]
        var tags = [
            primary[index % primary.count],
            secondary[(index / 3) % secondary.count]
        ]
        if index.isMultiple(of: 10) {
            tags.append("Blocked")
        }
        return tags
    }

    static func priority(for index: Int) -> RoutineTaskPriority {
        RoutineTaskPriority.allCases[index % RoutineTaskPriority.allCases.count]
    }

    static func importance(for index: Int) -> RoutineTaskImportance {
        RoutineTaskImportance.allCases[index % RoutineTaskImportance.allCases.count]
    }

    static func urgency(for index: Int) -> RoutineTaskUrgency {
        RoutineTaskUrgency.allCases[index % RoutineTaskUrgency.allCases.count]
    }

    static func todoState(for index: Int) -> TodoState {
        switch index % 4 {
        case 0:
            return .ready
        case 1:
            return .inProgress
        case 2:
            return .blocked
        default:
            return .paused
        }
    }
}
