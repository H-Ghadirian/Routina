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

    func testHomeRefreshUsesCentralCloudSyncFanIn() throws {
        let source = try Self.sourceFile("SharedCore/Screens/Home/HomeTCAView+Refresh.swift")

        XCTAssertTrue(
            source.contains("publisher(for: .routineDidUpdate)"),
            "Home should still refresh through the app-owned update notification."
        )
        XCTAssertFalse(
            source.contains("NSPersistentStoreRemoteChange"),
            "Home should not subscribe directly to Core Data remote-change notifications; CloudSyncedSurfaceRefreshCoordinator coalesces them first."
        )
        XCTAssertFalse(
            source.contains("NSPersistentCloudKitContainer.eventChangedNotification"),
            "Home should not subscribe directly to CloudKit event notifications; direct subscriptions duplicate refresh/fetch work during sync."
        )
    }

    func testCloudSyncFanInThrottlesSurfaceRefreshes() throws {
        let source = try Self.sourceFile("SharedCore/Sync/CloudSyncedSurfaceRefreshCoordinator.swift")

        XCTAssertTrue(source.contains("surfaceRefreshQuietWindowMilliseconds: Int64 = 1_500"))
        XCTAssertTrue(source.contains("widgetRefreshQuietWindowMilliseconds: Int64 = 30_000"))
        XCTAssertTrue(source.contains("minimumSurfaceRefreshSpacing: TimeInterval = 2.0"))
        XCTAssertTrue(source.contains("maximumSurfaceRefreshDeferral: TimeInterval = 5.0"))
        XCTAssertTrue(source.contains("firstPendingSurfaceRefreshAt"))
        XCTAssertTrue(source.contains("lastSurfaceRefreshAt"))
        XCTAssertTrue(
            source.contains("pendingRefreshTask?.cancel()"),
            "Cloud sync notification bursts should keep one pending surface refresh instead of posting repeated planner invalidations."
        )
        XCTAssertTrue(
            source.contains("postRoutineDidUpdate(\n            widgetRefreshDelayMilliseconds: widgetRefreshQuietWindowMilliseconds\n        )"),
            "Cloud sync should update app surfaces promptly while deferring nonessential widget refresh work out of active scroll windows."
        )
    }

    func testRoutineUpdateCoalescesWidgetRefreshWork() throws {
        let source = try Self.sourceFile("SharedCore/Services/NotificationCoordinator.swift")
        guard
            let methodStart = source.range(of: "func postRoutineDidUpdate(widgetRefreshDelayMilliseconds: Int64? = nil)"),
            let tagRenameStart = source.range(of: "func postRoutineTagDidRename")
        else {
            XCTFail("Expected routine update notification helpers to exist")
            return
        }
        let methodSource = String(source[methodStart.lowerBound..<tagRenameStart.lowerBound])

        XCTAssertTrue(methodSource.contains("RoutineWidgetRefreshScheduler.schedule(delayMilliseconds: widgetRefreshDelayMilliseconds)"))
        XCTAssertFalse(
            methodSource.contains("WidgetStatsService.refresh(using:"),
            "Routine updates should coalesce widget stats refreshes instead of fetching widget data on every posted app update."
        )
        XCTAssertTrue(source.contains("private enum RoutineWidgetRefreshScheduler"))
        XCTAssertTrue(source.contains("pendingTask?.cancel()"))
        XCTAssertTrue(source.contains("defaultWidgetRefreshQuietWindowMilliseconds: Int64 = 1_500"))
    }

    func testPlannerCachesProtectedSessionBlocksDuringScroll() throws {
        let source = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")

        XCTAssertTrue(source.contains("@StateObject private var sleepBlocksCache = DayPlanSleepBlocksCache()"))
        XCTAssertTrue(source.contains("@StateObject private var awayBlocksCache = DayPlanAwayBlocksCache()"))
        XCTAssertTrue(source.contains("let sleepBlocksByDayKey = sleepBlocksCache.blocksByDayKey("))
        XCTAssertTrue(source.contains("let awayBlocksByDayKey = awayBlocksCache.blocksByDayKey("))
        XCTAssertTrue(source.contains("referenceMinute = relevantSessions.contains { $0.endedAt == nil }"))
        XCTAssertTrue(source.contains("referenceMinute = relevantSessions.contains { $0.isActive && $0.plannedEndAt == nil }"))
    }

    func testPlannerTimelinePanelDoesNotBindSwiftDataQueriesIntoScrollRenderPath() throws {
        let source = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        guard
            let panelStart = source.range(of: "private struct DayPlanTimelinePanelView: View"),
            let contentStart = source.range(of: "private struct DayPlanTimelinePanelContentView: View")
        else {
            XCTFail("Expected DayPlan timeline panel structures to exist")
            return
        }
        let panelSource = String(source[panelStart.lowerBound..<contentStart.lowerBound])

        XCTAssertFalse(
            panelSource.contains("@Query"),
            "Planner timeline scrolling should read an explicit snapshot, not SwiftData @Query arrays that refetch during body updates."
        )
        XCTAssertTrue(panelSource.contains("@State private var dataSnapshot = DayPlanTimelineDataSnapshot()"))
        XCTAssertTrue(panelSource.contains("refreshTimelineDataSnapshot()"))
        XCTAssertFalse(
            panelSource.contains("ModelContext.didSave"),
            "Planner timeline data refreshes should stay behind the app-owned update fan-in instead of every raw SwiftData save."
        )
        XCTAssertTrue(source.contains("private struct DayPlanTimelineDataSnapshot"))
        XCTAssertTrue(source.contains("FetchDescriptor<RoutineTask>()"))
    }

    func testPlannerTimelineCachesRenderSnapshotDuringScroll() throws {
        let source = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")

        XCTAssertTrue(source.contains("@StateObject private var renderSnapshotCache = DayPlanTimelineRenderSnapshotCache()"))
        XCTAssertTrue(source.contains("let renderSnapshot = renderSnapshotCache.snapshot("))
        XCTAssertTrue(source.contains("private final class DayPlanTimelineRenderSnapshotCache"))
        XCTAssertTrue(source.contains("var dataSnapshotID: UUID"))
        XCTAssertTrue(source.contains("let refreshesEveryMinute = Self.hasVisibleOpenEndedTimelineBlock("))
        XCTAssertTrue(source.contains("var referenceMinute: ReferenceMinute?"))
        XCTAssertTrue(source.contains("referenceMinute = refreshesEveryMinute"))
        XCTAssertTrue(
            source.contains("if cachedKey == key, let cachedSnapshot"),
            "Planner scroll/layout passes should reuse the current render snapshot instead of rebuilding timeline dictionaries and SwiftData-derived task state."
        )
    }

    func testPlannerTimelineDataSnapshotDoesNotInvalidateForEquivalentRefreshes() throws {
        let source = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")

        XCTAssertTrue(source.contains("private struct DayPlanTimelineDataSnapshotSignature: Equatable"))
        XCTAssertTrue(source.contains("var signature = DayPlanTimelineDataSnapshotSignature()"))
        XCTAssertTrue(source.contains("if refreshedSnapshot.signature != dataSnapshot.signature"))
        XCTAssertTrue(
            source.contains("colorRawValue = task.colorRawValue"),
            "The planner snapshot signature should include fields that change visible block presentation, not just task IDs."
        )
        XCTAssertTrue(
            source.contains("accumulatedPausedSeconds = session.accumulatedPausedSeconds"),
            "Focus session timing changes should still invalidate the planner snapshot when they affect active focus blocks."
        )
    }

    func testHomeDoneStatsDoesNotRewalkLogsForEachOutcome() throws {
        let source = try Self.sourceFile("SharedCore/Features/Home/HomeTaskSupport.swift")

        XCTAssertFalse(
            source.contains("logs.reduce"),
            "Home refresh should scan logs once when building done stats; repeated reductions are noticeable with large Home histories."
        )
        XCTAssertTrue(source.contains("for log in logs"))
    }

    func testMacHomeBoardReusesColumnOrderedTaskIDs() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTodoBoardView.swift")

        XCTAssertFalse(
            source.contains("column.tasks.map(\\.id)"),
            "Board scroll and drag/drop rendering should reuse each column's ordered task IDs instead of rebuilding them for every card."
        )
        XCTAssertTrue(source.contains("let orderedTaskIDs: [UUID]"))
    }

    func testMacLaunchWidgetRefreshKeepsStatsWorkOutOfInitialScrollWindow() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")

        XCTAssertTrue(
            source.contains("scheduleLaunchRefresh()"),
            "Launch should use a dedicated schedule so broad stats work does not compete with the first task-detail scroll."
        )
        XCTAssertTrue(
            source.contains("scheduleStatsRefresh(delayNanoseconds: 2_000_000_000)"),
            "Stats widget refresh is intentionally delayed on launch because it may fetch many tasks/logs."
        )
        XCTAssertFalse(
            source.contains("WidgetCenter.shared.reloadAllTimelines()"),
            "Mac launch should reload only the Routina widgets whose data changed instead of invalidating every widget timeline."
        )
    }

    func testMacAppTargetsDoNotShipWidgetExtensions() throws {
        let project = try Self.sourceFile("RoutinaMacOS.xcodeproj/project.pbxproj")
        let prodTarget = try Self.projectBlock(
            named: "RoutinaMacOSProd",
            in: project,
            endingBefore: "RoutinaMacOSDev"
        )
        let devTarget = try Self.projectBlock(
            named: "RoutinaMacOSDev",
            in: project,
            endingBefore: "RoutinaMacOSTests"
        )

        for target in [prodTarget, devTarget] {
            XCTAssertFalse(target.contains("Embed Foundation Extensions"))
            XCTAssertFalse(target.contains("Register Widget Extension"))
            XCTAssertFalse(target.contains("RoutinaWidgetExtension.appex"))
            XCTAssertFalse(target.contains("RoutinaWidgetDevExtension.appex"))
            XCTAssertFalse(target.contains("RoutinaWidgetExtension */"))
            XCTAssertFalse(target.contains("RoutinaWidgetDevExtension */"))
        }

        XCTAssertTrue(project.contains("/* RoutinaWidgetExtension */ = {"))
        XCTAssertTrue(project.contains("/* RoutinaWidgetDevExtension */ = {"))
    }

    func testMacRawSwiftDataSavesDoNotDuplicateWidgetRefreshWork() throws {
        let rootSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")
        let statusStoreSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacFocusTimerStatusStore.swift")
        guard
            let saveReceiveStart = rootSource.range(of: "publisher(for: ModelContext.didSave)"),
            let routineReceiveStart = rootSource.range(
                of: "publisher(for: .routineDidUpdate)",
                range: saveReceiveStart.upperBound..<rootSource.endIndex
            )
        else {
            XCTFail("Expected mac root scene save/update notification handlers")
            return
        }
        let saveReceiveSource = String(rootSource[saveReceiveStart.lowerBound..<routineReceiveStart.lowerBound])

        XCTAssertFalse(
            saveReceiveSource.contains("widgetRefreshScheduler.schedule()"),
            "Raw SwiftData save notifications are noisy during CloudKit sync and should not duplicate coalesced routine-update widget refresh work."
        )
        XCTAssertTrue(saveReceiveSource.contains("focusTimerStatusStore.scheduleRefresh()"))
        XCTAssertFalse(
            rootSource.contains("func schedule(delayNanoseconds"),
            "The mac widget scheduler should be launch-only; routine updates use the shared coalesced widget scheduler."
        )
        XCTAssertTrue(statusStoreSource.contains("private var scheduledRefreshTask"))
        XCTAssertTrue(statusStoreSource.contains("func scheduleRefresh(delayNanoseconds: UInt64 = 500_000_000)"))
        XCTAssertTrue(statusStoreSource.contains("scheduledRefreshTask?.cancel()"))
    }

    func testWidgetStatsServiceDoesNotFetchCanceledLogsForStats() throws {
        let source = try Self.sourceFile("SharedCore/Services/WidgetStatsService.swift")

        XCTAssertFalse(
            source.contains("FetchDescriptor<RoutineLog>()"),
            "Widget stats should not fetch every routine log on launch; canceled logs are irrelevant for completion stats."
        )
        XCTAssertTrue(source.contains("log.kindRawValue == completedKindRawValue"))
    }

    func testMacFocusToolbarShowsTimerWithoutResizingEverySecond() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Shared/RoutinaMacFocusTimerToolbarBadge.swift")

        XCTAssertTrue(
            source.contains("RoutinaMacFocusTimerToolbarTimeText(status: status)"),
            "The active focus toolbar badge should show the live timer counter, not only a static focus label."
        )
        XCTAssertTrue(source.contains("status.menuBarTimeText(at: context.date)"))
        XCTAssertTrue(
            source.contains("Text(\"+00:00:00\")"),
            "Reserve a stable counter width so second-by-second timer updates do not resize the toolbar item."
        )
    }

    func testPlannerOnlyHidesUnassignedPlanFocusToolbarBadge() throws {
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let badgeSource = try Self.sourceFile("RoutinaMacApp/Screens/Shared/RoutinaMacFocusTimerToolbarBadge.swift")

        XCTAssertTrue(
            detailSource.contains("hiddenKinds: mainDetailMode == .planner ? [.unassigned] : []"),
            "Planner should hide only its own unassigned Plan Focus toolbar badge, while still showing active board or task timers."
        )
        XCTAssertFalse(
            detailSource.contains("if mainDetailMode != .planner"),
            "Do not hide the entire global focus timer toolbar item in Planner; board/sprint focus still needs to be visible there."
        )
        XCTAssertTrue(badgeSource.contains("return !hiddenKinds.contains(kind)"))
    }

    func testMacHomeFocusToolbarUsesSingleTimerSlot() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift")
        let rootSceneSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift")
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")

        XCTAssertTrue(
            source.contains("HomeMacToolbarSearchField("),
            "Home should keep the global task and timeline search field visible as the centered toolbar search affordance."
        )
        XCTAssertTrue(source.contains("ToolbarItem(placement: .principal)"))
        XCTAssertTrue(source.contains("static let width: CGFloat = 760"))
        XCTAssertTrue(source.contains("static let height: CGFloat = 44"))
        XCTAssertTrue(rootSceneSource.contains("window.toolbarStyle = .expanded"))
        XCTAssertTrue(rootSceneSource.contains("window.toolbar?.sizeMode = .regular"))
        XCTAssertTrue(source.contains("searchField.controlSize = .large"))
        XCTAssertTrue(source.contains("searchField.focusRingType = .none"))
        XCTAssertTrue(source.contains("nsView.focusRingType = .none"))
        XCTAssertFalse(source.contains("focusRingType = .default"))
        XCTAssertTrue(source.contains("Search tasks and timeline, or create a task"))
        XCTAssertTrue(source.contains("canCreateTaskFromQuery"))
        XCTAssertTrue(source.contains("Return"))
        XCTAssertTrue(source.contains("Create task"))
        XCTAssertTrue(source.contains("HomeMacToolbarSearchParserPreview"))
        XCTAssertTrue(source.contains("Detected details"))
        XCTAssertTrue(source.contains("RoutinaQuickAddDraft"))
        XCTAssertTrue(source.contains("enum HomeMacToolbarSearchLayout"))
        XCTAssertFalse(source.contains("parserPreviewDraft"))
        XCTAssertFalse(source.contains("parserPreviewPresentation"))
        XCTAssertFalse(source.contains(".popover("))
        XCTAssertTrue(source.contains("NSSearchField"))
        XCTAssertTrue(source.contains("routinaMacFocusSearchOrCreate"))
        XCTAssertTrue(source.contains("parent.onSubmit"))
        XCTAssertTrue(source.contains("restoreFocusAfterSearchUpdate()"))
        XCTAssertTrue(
            source.contains("shouldLeaveCurrentTextEditorFocused"),
            "Toolbar search may restore focus after filtering, but it must not steal focus from an intentionally focused comment, note, or other text editor."
        )
        XCTAssertTrue(source.contains("window.firstResponder as? NSTextView"))
        XCTAssertTrue(source.contains("activeEditor !== searchField.currentEditor()"))
        XCTAssertTrue(platformSource.contains("createTaskFromToolbarSearch"))
        XCTAssertTrue(platformSource.contains("canCreateTaskFromToolbarSearch"))
        XCTAssertTrue(platformSource.contains("toolbarSearchCreateDraft"))
        XCTAssertTrue(platformSource.contains("RoutinaQuickAddParser.parse"))
        XCTAssertTrue(platformSource.contains("draft.hasDetectedMetadata"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchParserPreview(draft: toolbarSearchCreateDraft)"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchLayout.width"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchLayout.parserPreviewTopPadding"))
        XCTAssertTrue(platformSource.contains("hasToolbarSearchResult"))
        XCTAssertTrue(platformSource.contains("!hasToolbarSearchResult(for: trimmedText)"))
        XCTAssertFalse(
            platformSource.contains("MacQuickAddSpotlightOverlay"),
            "The configurable quick-add shortcut should now be merged into the toolbar search field instead of opening a separate overlay."
        )
        XCTAssertTrue(platformSource.contains("plannerSearchText: searchTextBinding.wrappedValue"))
        XCTAssertTrue(detailSource.contains("calendarSearchText: plannerSearchText"))
        XCTAssertTrue(dayPlanSource.contains("filteredBlocksByDayKey("))
        XCTAssertTrue(dayPlanSource.contains("filteredTimelineBlocksByDayKey("))
        XCTAssertTrue(dayPlanSource.contains("tasksMatchingCalendarSearch(from: currentTasks)"))
        XCTAssertFalse(
            sidebarSource.contains("platformSearchField(searchText: searchTextBinding)"),
            "Task and timeline search should have one active text field. Duplicating the shared search binding in the sidebar steals first responder from the toolbar field."
        )
        XCTAssertTrue(
            source.contains("} else if isPlanFocusStartDisabled {\n            RoutinaMacFocusTimerToolbarItem(hiddenKinds: [.unassigned])\n        } else if focusStartTaskCount > 0 {"),
            "Home should swap Start Focus Timer for the active timer badge instead of showing a disabled starter beside the running timer."
        )
        XCTAssertEqual(
            source.components(separatedBy: "RoutinaMacFocusTimerToolbarItem(hiddenKinds: [.unassigned])").count - 1,
            1,
            "The active timer badge should live in the same toolbar branch as Start Focus Timer, not as an extra unconditional item."
        )
        XCTAssertFalse(
            source.contains("Assign Pending Focus"),
            "The toolbar focus menu should only start task-backed timers; pending unassigned focus assignment is no longer a toolbar action."
        )
    }

    func testMacHomeFiltersUseRightSideCompanionPane() throws {
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let filterContainerSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacFilterDetailContainerView.swift")
        let routineFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift")
        let timelineFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTimelineFiltersDetailView.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift")
        let boardSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Board.swift")
        let timelineSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift")

        XCTAssertTrue(detailSource.contains("static let filterDetailPaneWidth: CGFloat = 420"))
        XCTAssertTrue(detailSource.contains("private var filterDetailPane: some View"))
        XCTAssertTrue(detailSource.contains("private var fullscreenFilterDetailContent: some View"))
        XCTAssertTrue(detailSource.contains("onMinimizeFullscreenFilterDetail"))
        XCTAssertTrue(detailSource.contains("onCloseTaskDetails()\n                        onCloseFilterDetail()"))
        XCTAssertTrue(filterContainerSource.contains("GeometryReader"))
        XCTAssertTrue(filterContainerSource.contains(".frame(width: proxy.size.width, alignment: .topLeading)"))
        XCTAssertTrue(filterContainerSource.contains("compactHorizontalPadding"))
        XCTAssertTrue(sidebarSource.contains("minimumSegmentWidth: 96"))
        XCTAssertTrue(sidebarSource.contains("horizontalPadding: 10"))
        XCTAssertFalse(sidebarSource.contains("minimumSegmentWidth: 132"))
        XCTAssertFalse(sidebarSource.contains(".frame(maxWidth: 520)"))
        XCTAssertFalse(routineFilterSource.contains(".frame(width: 520)"))
        XCTAssertTrue(routineFilterSource.contains(".frame(maxWidth: .infinity)"))
        XCTAssertFalse(timelineFilterSource.contains(".frame(width: 420)"))
        XCTAssertTrue(timelineFilterSource.contains(".frame(maxWidth: .infinity)"))
        XCTAssertFalse(
            detailSource.contains("if store.isMacFilterDetailPresented {\n                filterView()"),
            "Home filters should no longer replace the full detail area when opened from the toolbar."
        )
        XCTAssertTrue(sidebarSource.contains("func expandMacFilterDetailPane()"))
        XCTAssertTrue(sidebarSource.contains("isMacFilterDetailFullscreen = true"))
        XCTAssertTrue(sidebarSource.contains("taskDetailPanePlacement = nil\n            store.send(.setMacFilterDetailPresented(true))"))
        XCTAssertTrue(platformSource.contains("isFilterDetailFullscreen: isMacFilterDetailFullscreen"))
        XCTAssertTrue(boardSource.contains("var macBoardCenterContent: some View {\n        macTodoBoardContent\n    }"))
        XCTAssertTrue(timelineSource.contains("isActive: isMacTimelineMode,\n                allowsFallbackSelection: !store.isMacFilterDetailPresented"))
    }

    func testMacToolbarStatusBadgeKeepsStableTextWidth() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Shared/MacToolbarComponents.swift")

        XCTAssertTrue(
            source.contains("greaterThanOrEqualToConstant: Self.measuredTitleWidth"),
            "Toolbar status badges should reserve their measured text width so labels like the Done counter do not truncate while AppKit relayouts."
        )
        XCTAssertTrue(source.contains("setContentCompressionResistancePriority(.required, for: .horizontal)"))
    }

    func testMacFocusTimerStatusFreezesPausedTaskTimer() {
        let status = RoutinaMacFocusTimerStatus(
            id: UUID(),
            targetID: UUID(),
            kind: .task,
            title: "Deep work",
            startedAt: Date(timeIntervalSince1970: 0),
            plannedDurationSeconds: 0,
            pausedAt: Date(timeIntervalSince1970: 10 * 60),
            accumulatedPausedSeconds: 0
        )

        XCTAssertEqual(status.menuBarTimeText(at: Date(timeIntervalSince1970: 30 * 60)), "10:00")
        XCTAssertEqual(status.menuBarModeText(at: Date(timeIntervalSince1970: 30 * 60)), "paused")
        XCTAssertEqual(status.systemImage, "pause.circle.fill")
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

    static func projectBlock(
        named targetName: String,
        in source: String,
        endingBefore nextTargetName: String
    ) throws -> String {
        guard
            let start = source.range(of: "/* \(targetName) */ = {"),
            let end = source.range(
                of: "/* \(nextTargetName) */ = {",
                range: start.upperBound..<source.endIndex
            )
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return String(source[start.lowerBound..<end.lowerBound])
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
