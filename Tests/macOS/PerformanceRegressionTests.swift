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

    func testMacStatsDashboardToolbarControlsAreBetaGated() throws {
        let statsSource = try Self.sourceFile("RoutinaMacApp/Screens/StatsView.swift")
        let settingsSource = try Self.sourceFile("RoutinaMacApp/Screens/Settings/SettingsMacDataSupportDetailViews.swift")

        XCTAssertTrue(statsSource.contains("appSettingMacStatsDashboardControlsEnabled"))
        XCTAssertTrue(statsSource.contains("if areMacStatsDashboardControlsEnabled {\n                    ToolbarItemGroup(placement: .primaryAction)"))
        XCTAssertTrue(statsSource.contains("summaryDisplayModeMenu\n                        dashboardEditButton"))
        XCTAssertTrue(settingsSource.contains("Toggle(\"Show Stats dashboard controls\""))
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

    func testMacFutureSectionContextMenuBulkTogglesInnerGroups() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift")

        XCTAssertTrue(source.contains("Label(\"Expand All\""))
        XCTAssertTrue(source.contains("Label(\"Collapse All Subsections\""))
        XCTAssertTrue(source.contains("section.kind == .future && section.taskGroups.contains { $0.isCollapsible }"))
        XCTAssertTrue(source.contains("isMacFutureTasksSectionCollapsed = false"))
        XCTAssertTrue(source.contains("ids.formUnion(subsectionIDs)"))
        XCTAssertTrue(source.contains("ids.subtract(subsectionIDs)"))
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
        XCTAssertTrue(source.contains("@State private var hasDeferredTimelineDataSnapshotRefresh = false"))
        XCTAssertTrue(source.contains("requestTimelineDataSnapshotRefresh()"))
        XCTAssertTrue(source.contains("guard !isExternalInspectorPresented else"))
        XCTAssertTrue(source.contains("RoutinaMacScrollInteractionGate.isScrollActive"))
        XCTAssertTrue(source.contains("scheduleDeferredTimelineDataSnapshotRefreshRetry()"))
        XCTAssertTrue(
            source.contains("colorRawValue = task.colorRawValue"),
            "The planner snapshot signature should include fields that change visible block presentation, not just task IDs."
        )
        XCTAssertTrue(
            source.contains("accumulatedPausedSeconds = session.accumulatedPausedSeconds"),
            "Focus session timing changes should still invalidate the planner snapshot when they affect active focus blocks."
        )
    }

    func testMacPlannerCompanionLayoutKeepsHeaderInsidePlannerColumn() throws {
        XCTAssertEqual(
            MacDetailContainerSizing.plannerInspectorContentMinWidth,
            DayPlanWeekCalendarSizing.minimumDetailWidth(isExternalInspectorPresented: true)
        )
        XCTAssertEqual(
            MacDetailContainerSizing.plannerTaskDetailMinWidth,
            MacDetailContainerSizing.plannerInspectorContentMinWidth + MacDetailContainerSizing.taskDetailPaneWidth
        )
        XCTAssertEqual(RoutinaMacWindowSizing.minWidth, 1440)
        XCTAssertGreaterThanOrEqual(RoutinaMacWindowSizing.defaultWidth, RoutinaMacWindowSizing.minWidth)
        XCTAssertGreaterThanOrEqual(
            RoutinaMacWindowSizing.minWidth,
            MacDetailContainerSizing.plannerTaskDetailMinWidth + 360 + 80,
            "Mac Home should not resize below the expanded-sidebar plus Planner companion layout, with transition breathing room."
        )

        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")

        XCTAssertTrue(
            detailSource.contains("detailContent\n            .clipped()"),
            "Mac detail content should clip oversized child surfaces at the NavigationSplitView detail boundary."
        )
        XCTAssertTrue(detailSource.contains("let contentWidth = max(proxy.size.width - filterPaneWidth, 0)"))
        XCTAssertTrue(detailSource.contains(".frame(width: contentWidth)"))
        XCTAssertTrue(detailSource.contains("let plannerContentWidth = plannerContentWidth("))
        XCTAssertTrue(detailSource.contains(".frame(width: plannerContentWidth)"))
        XCTAssertTrue(detailSource.contains("availableWidth - MacDetailContainerSizing.taskDetailPaneWidth"))
        XCTAssertTrue(
            dayPlanSource.contains("isExternalInspectorPresented: isExternalInspectorPresented"),
            "Planner adaptive range should know when a companion pane is consuming horizontal space."
        )
        XCTAssertTrue(
            detailSource.contains("macHeaderAvailableWidth: max(")
                && detailSource.contains("plannerContentWidth - DayPlanWeekCalendarSizing.detailHorizontalPadding"),
            "Mac Planner should pass its bounded column width to the header so tight inspector density is deterministic."
        )
        XCTAssertTrue(dayPlanSource.contains("parentAvailableWidth: macHeaderAvailableWidth"))
        XCTAssertTrue(dayPlanSource.contains("private var effectiveMacHeaderAvailableWidth: CGFloat"))
        XCTAssertTrue(
            detailSource.contains(".clipped()\n\n                if canShowTaskDetailPane"),
            "Planner content should clip at its own column boundary instead of drawing underneath a right companion pane."
        )
        XCTAssertTrue(dayPlanSource.contains(".background(macHeaderAvailableWidthReader)"))
        XCTAssertTrue(
            dayPlanSource.contains("DayPlanTimelinePanelView(\n                    planner: planner")
                && dayPlanSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"),
            "The bounded Planner column width should be forwarded through the detail and timeline panel stack."
        )
        XCTAssertTrue(
            dayPlanSource.contains("DayPlanWeekCalendarView(\n                dates: visibleDates")
                && dayPlanSource.contains(".dayPlanLifecycle("),
            "The calendar should remain in the filling Planner content stack so width proposals reach the grid."
        )
        XCTAssertFalse(
            dayPlanSource.contains("macHeaderRow(showsRangePicker: shouldShowMacHeaderRangePicker)\n            .background(macHeaderAvailableWidthReader)"),
            "Header available width should be measured from the bounded container, not the potentially overflowing controls row."
        )
        XCTAssertTrue(dayPlanSource.contains("usesIconOnlyMacDisplayModePicker"))
        XCTAssertTrue(dayPlanSource.contains("usesCompactMacDatePickerButton"))
        XCTAssertTrue(dayPlanSource.contains("macHeaderCollapsedRegularDateControlsWidthProbe"))
        XCTAssertTrue(dayPlanSource.contains("plannerDatePickerButtonMinimumWidth"))
        XCTAssertTrue(dayPlanSource.contains("plannerDatePickerButtonMaximumWidth"))
        XCTAssertTrue(dayPlanSource.contains("if displayMode.wrappedValue == .list, let listContent {\n                plannerListContent(listContent)"))
        XCTAssertTrue(dayPlanSource.contains("private var showsPlannerDatePickerButton: Bool"))
        XCTAssertTrue(dayPlanSource.contains("effectiveDisplayMode == .calendar || effectiveDisplayMode == .list"))
        XCTAssertTrue(
            dayPlanSource.contains("DayPlanDatePickerSidebar(\n                        selectedDate: selectedDateBinding"),
            "Planner Timeline should render the same Go to date sidebar as Calendar when the date button is pressed."
        )
        XCTAssertTrue(
            dayPlanSource.contains("usesCompactWidth ? 154 : nil"),
            "The date/range button should hug its content by default and only cap width in compact inspector layouts."
        )
        XCTAssertFalse(
            dayPlanSource.contains("usesCompactMacDatePickerButton ? nil : 210"),
            "The regular date/range button should not reserve blank horizontal space beyond its content."
        )
        XCTAssertTrue(dayPlanSource.contains(".layoutPriority(3)"))
        XCTAssertTrue(dayPlanSource.contains("inspectorRangePickerMinimumAvailableWidth"))
        XCTAssertTrue(dayPlanSource.contains("iconOnlyDisplayModePickerMaximumAvailableWidth"))
        XCTAssertTrue(dayPlanSource.contains("compactDatePickerButtonMaximumAvailableWidth"))
        XCTAssertTrue(dayPlanSource.contains("shouldUseIconOnlyDisplayModePicker"))
        XCTAssertTrue(dayPlanSource.contains("shouldUseCompactDatePickerButton"))
    }

    func testHomeDoneStatsDoesNotRewalkLogsForEachOutcome() throws {
        let source = try Self.sourceFile("SharedCore/Features/Home/HomeTaskSupport.swift")

        XCTAssertFalse(
            source.contains("logs.reduce"),
            "Home refresh should scan logs once when building done stats; repeated reductions are noticeable with large Home histories."
        )
        XCTAssertTrue(source.contains("for log in logs"))
    }

    func testMacTaskDetailDefersRoutineUpdateRefreshWhileInspectorIsOpen() throws {
        let refreshSource = try Self.sourceFile("SharedCore/Screens/Home/HomeTCAView+Refresh.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        let macHomeSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")

        XCTAssertTrue(refreshSource.contains("requestRoutineUpdateRefresh()"))
        XCTAssertTrue(refreshSource.contains("shouldDeferRoutineUpdateRefresh"))
        XCTAssertTrue(refreshSource.contains("RoutinaMacScrollInteractionGate"))
        XCTAssertTrue(dayPlanSource.contains("NSEvent.addLocalMonitorForEvents(matching: .scrollWheel)"))
        XCTAssertTrue(refreshSource.contains("scheduleDeferredRoutineUpdateRefreshRetry()"))
        XCTAssertTrue(refreshSource.contains("hasDeferredRoutineUpdateRefresh = true"))
        XCTAssertTrue(refreshSource.contains("requestDeferredRoutineUpdateRefreshIfNeeded()"))
        XCTAssertTrue(macHomeSource.contains("@State var hasDeferredRoutineUpdateRefresh = false"))
        XCTAssertTrue(macHomeSource.contains("@State var deferredRoutineUpdateRefreshTask: Task<Void, Never>?"))
        XCTAssertFalse(
            refreshSource.contains("publisher(for: .routineDidUpdate)\n                    .receive(on: RunLoop.main)\n            ) { _ in\n                requestRefresh()"),
            "Cloud routine-update pulses should not synchronously reload Home while a Mac task detail pane is being scrolled."
        )
    }

    func testTaskDetailHeaderStacksLongTitlesAwayFromActionCluster() throws {
        let source = try Self.sourceFile("SharedCore/Screens/TaskDetail/TaskDetailHeaderViews.swift")

        XCTAssertTrue(source.contains("private var usesStackedHeaderLayout"))
        XCTAssertTrue(source.contains("guard accessoryWidth > 0.5 else"))
        XCTAssertTrue(source.contains("titleWidth + accessoryWidth + TaskDetailHeaderSectionMetrics.titleAccessorySpacing > availableWidth"))
        XCTAssertTrue(source.contains("HStack {\n                    Spacer(minLength: 0)\n                    measuredHeaderAccessory"))
        XCTAssertTrue(source.contains("titleWidthProbe"))
        XCTAssertTrue(source.contains(".background(headerMetricReader(.accessoryWidth))"))
        XCTAssertTrue(source.contains(".allowsHitTesting(false)"))
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

    func testPlannerCalendarHeaderOnlyHidesUnassignedPlanFocusBadge() throws {
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        let badgeSource = try Self.sourceFile("RoutinaMacApp/Screens/Shared/RoutinaMacFocusTimerToolbarBadge.swift")

        XCTAssertTrue(
            dayPlanSource.contains("if effectiveDisplayMode == .calendar, let macFocusControl"),
            "Planner should keep the moved Focus control local to the Calendar header instead of showing it in Timeline mode."
        )
        XCTAssertTrue(
            detailSource.contains("RoutinaMacFocusTimerToolbarBadge(")
                && detailSource.contains("hiddenKinds: [.unassigned]"),
            "Planner should hide only its own unassigned Plan Focus badge while still showing active board or task timers."
        )
        XCTAssertFalse(
            detailSource.contains("if mainDetailMode != .planner"),
            "Do not hide the entire active focus badge in Planner; board/sprint focus still needs to be visible there."
        )
        XCTAssertTrue(badgeSource.contains("return !hiddenKinds.contains(kind)"))
    }

    func testMacHomeFocusToolbarUsesSingleTimerSlot() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift")
        let homeSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift")
        let rootSceneSource = try Self.sourceFile("RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift")
        let navigationSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeMacNavigationContent.swift")
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let taskDetailSource = try Self.sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift")
        let taskToolbarSource = try Self.sourceFile("RoutinaMacApp/Screens/TaskDetail/TaskDetailToolbarContent.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        let toolbarComponentsSource = try Self.sourceFile("RoutinaMacApp/Screens/Shared/MacToolbarComponents.swift")

        XCTAssertTrue(
            source.contains("HomeMacToolbarSearchField("),
            "Home should keep the global task and timeline search field visible in the top search affordance."
        )
        XCTAssertTrue(
            source.contains("struct HomeMacTopToolbarChrome: View"),
            "Home search should live in the SwiftUI top chrome so text input and animation remain in the main view hierarchy."
        )
        XCTAssertTrue(
            platformSource.contains("private var homeTopToolbarChrome: some View"),
            "The Home shell should own the Outlook-style top chrome from the same state that powers search, focus, and task creation."
        )
        XCTAssertTrue(platformSource.contains("ZStack(alignment: .top) {"))
        XCTAssertTrue(platformSource.contains(".padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight)"))
        XCTAssertTrue(platformSource.contains(".ignoresSafeArea(edges: .top)"))
        XCTAssertTrue(
            navigationSource.contains(".toolbar(removing: .sidebarToggle)")
        )
        XCTAssertTrue(homeSource.contains("@State var macHomeSidebarColumnVisibility: NavigationSplitViewVisibility = .all"))
        XCTAssertTrue(platformSource.contains("sidebarColumnVisibility: $macHomeSidebarColumnVisibility"))
        XCTAssertTrue(platformSource.contains("private func toggleMacHomeSidebar()"))
        XCTAssertTrue(navigationSource.contains("NavigationSplitView(columnVisibility: $sidebarColumnVisibility)"))
        XCTAssertTrue(platformSource.contains("HomeMacSidebarSplitViewConfigurator("))
        XCTAssertTrue(platformSource.contains("func routinaHomeSidebarSplitViewConstraints() -> some View"))
        XCTAssertTrue(navigationSource.contains(".routinaHomeSidebarSplitViewConstraints()"))
        XCTAssertTrue(platformSource.contains("minimumWidth: HomeSidebarSizing.minWidth"))
        XCTAssertTrue(platformSource.contains("maximumWidth: HomeSidebarSizing.maxWidth"))
        XCTAssertTrue(platformSource.contains("sidebarItem.maximumThickness = maximumWidth"))
        XCTAssertTrue(platformSource.contains("!sidebarItem.isCollapsed"))
        XCTAssertTrue(platformSource.contains("sidebarView.frame.width > 1"))
        XCTAssertTrue(platformSource.contains("context.allowsImplicitAnimation = false"))
        XCTAssertTrue(platformSource.contains("withAnimation(.easeInOut(duration: 0.22)) {\n            macHomeSidebarColumnVisibility"))
        XCTAssertFalse(platformSource.contains("transaction.disablesAnimations = true"))
        XCTAssertFalse(rootSceneSource.contains(".windowResizability(.contentMinSize)"))
        XCTAssertTrue(source.contains("HomeMacSidebarVisibilityToolbarButton("))
        XCTAssertTrue(source.contains("Collapse Sidebar"))
        XCTAssertTrue(source.contains("Expand Sidebar"))
        XCTAssertTrue(source.contains("static let sidebarToggleButtonSize: CGFloat = 28"))
        XCTAssertTrue(source.contains("width: HomeMacToolbarSearchLayout.sidebarToggleButtonSize"))
        XCTAssertTrue(source.contains("height: HomeMacToolbarSearchLayout.sidebarToggleButtonSize"))
        guard
            let sidebarToggleStart = source.range(of: "private struct HomeMacSidebarVisibilityToolbarButton: View"),
            let toolbarLayoutStart = source.range(of: "enum HomeMacToolbarSearchLayout")
        else {
            XCTFail("Expected the Mac Home sidebar toggle and toolbar layout definitions to exist.")
            return
        }
        let sidebarToggleSource = String(source[sidebarToggleStart.lowerBound..<toolbarLayoutStart.lowerBound])
        XCTAssertTrue(
            sidebarToggleSource.contains(".contentShape(Rectangle())"),
            "The sidebar visibility button should make the whole fixed toolbar target clickable."
        )
        XCTAssertTrue(toolbarComponentsSource.contains("private final class RoutinaMacToolbarIconButton: NSButton"))
        XCTAssertTrue(toolbarComponentsSource.contains("override func acceptsFirstMouse(for event: NSEvent?) -> Bool"))
        XCTAssertTrue(toolbarComponentsSource.contains("override func hitTest(_ point: NSPoint) -> NSView?"))
        XCTAssertTrue(
            toolbarComponentsSource.contains("bounds.contains(point)"),
            "AppKit-backed toolbar icons should claim their entire NSButton bounds, not just the drawn symbol."
        )
        XCTAssertFalse(source.contains("struct HomeMacTitlebarSearchInstaller"))
        XCTAssertFalse(platformSource.contains("HomeMacTitlebarSearchInstaller("))
        XCTAssertFalse(source.contains("NSTitlebarAccessoryViewController"))
        XCTAssertFalse(source.contains("HomeMacTitlebarSearchHostingView"))
        XCTAssertFalse(source.contains("window.standardWindowButton(.closeButton)"))
        XCTAssertFalse(platformSource.contains("homeTitlebarSearchInstaller"))
        XCTAssertFalse(platformSource.contains(".safeAreaInset(edge: .top, spacing: 0)"))
        XCTAssertFalse(source.contains("ToolbarItem(placement: .principal)"))
        XCTAssertFalse(source.contains("struct HomeMacExpandedToolbarSearchOverlay: View"))
        XCTAssertTrue(source.contains("static let compactWidth: CGFloat = 620"))
        XCTAssertTrue(source.contains("static let focusedWidth: CGFloat = 860"))
        XCTAssertTrue(source.contains("static let topToolbarHeight: CGFloat = 62"))
        XCTAssertTrue(source.contains("static let topToolbarHorizontalPadding: CGFloat = 18"))
        XCTAssertTrue(source.contains("static let trafficLightReservedLeadingPadding: CGFloat = 142"))
        XCTAssertTrue(
            source.contains("ZStack(alignment: .center) {"),
            "The toolbar row should center search independently of asymmetric leading and trailing controls."
        )
        XCTAssertTrue(source.contains("private var toolbarSearch: some View"))
        XCTAssertTrue(
            source.contains("toolbarSearch\n                .frame(maxWidth: .infinity, alignment: .center)"),
            "The search field should stay centered against the full toolbar width, not the remaining space in an HStack."
        )
        XCTAssertTrue(source.contains("private var toolbarTrailingCluster: some View"))
        XCTAssertFalse(
            source.contains("Spacer(minLength: 8)\n\n            HomeMacToolbarSearchField("),
            "Search should not be pushed by a leading spacer in the same HStack as the command controls."
        )
        XCTAssertTrue(source.contains("private var toolbarCommandCluster: some View"))
        XCTAssertFalse(source.contains("private var commandRow: some View"))
        XCTAssertFalse(source.contains("static let commandRowHeight"))
        XCTAssertFalse(source.contains("commandRowBackground"))
        XCTAssertFalse(source.contains("static let titlebarHostWidth"))
        XCTAssertFalse(source.contains("static let titlebarToolbarGapHeight"))
        XCTAssertFalse(source.contains("titlebarTopPadding"))
        XCTAssertFalse(source.contains("static let minimumExpandedWidth"))
        XCTAssertFalse(source.contains("static let expandedSearchRowHeight"))
        XCTAssertFalse(source.contains("static let expandedSearchHorizontalInset"))
        XCTAssertFalse(source.contains("static let expandedOverlayTopPadding"))
        XCTAssertFalse(source.contains("static let activeHostWidth"))
        XCTAssertFalse(source.contains("static let hostReleaseDelay"))
        XCTAssertTrue(source.contains("static let height: CGFloat = 44"))
        XCTAssertTrue(source.contains("static let toolbarActionRestoreDelay: TimeInterval = animationDuration"))
        XCTAssertTrue(homeSource.contains("@State var isToolbarSearchTextFocused = false"))
        XCTAssertTrue(homeSource.contains("@State var isToolbarSearchExpanded = false"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchExpansionTransitionID = 0"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchFocusRequestID = 0"))
        XCTAssertTrue(homeSource.contains("@State var toolbarSearchFocusDismissRequestID = 0"))
        XCTAssertTrue(homeSource.contains("@State var isMacWindowFullscreen = false"))
        XCTAssertFalse(homeSource.contains("isMacFullscreenTitlebarRevealed"))
        XCTAssertTrue(platformSource.contains("isSearchTextFocused: $isToolbarSearchTextFocused"))
        XCTAssertTrue(platformSource.contains("searchVisiblePillWidth: $toolbarSearchVisiblePillWidth"))
        XCTAssertTrue(platformSource.contains("searchExpansionTransitionID: $toolbarSearchExpansionTransitionID"))
        XCTAssertTrue(platformSource.contains("searchFocusRequestID: $toolbarSearchFocusRequestID"))
        XCTAssertTrue(platformSource.contains("searchFocusDismissRequestID: $toolbarSearchFocusDismissRequestID"))
        XCTAssertFalse(detailSource.contains("matchedGeometryEffect("))
        XCTAssertFalse(detailSource.contains("taskDetailSurfaceMotion("))
        XCTAssertFalse(detailSource.contains("MacTaskDetailSurfaceMotionModifier"))
        XCTAssertTrue(
            detailSource.contains("static func taskDetailFullscreen(edge: Edge) -> AnyTransition {\n        .identity\n    }"),
            "Task details should not duplicate translucent surfaces while expanding into Full Details."
        )
        XCTAssertTrue(
            detailSource.contains("static func taskDetailPane(edge: Edge) -> AnyTransition {\n        .identity\n    }"),
            "Task detail companion panes should enter and leave without opacity/scale compositing."
        )
        XCTAssertTrue(
            detailSource.contains("static var taskDetailWorkspace: AnyTransition {\n        .identity\n    }"),
            "The workspace behind task details should not fade under duplicated detail cards."
        )
        XCTAssertTrue(platformSource.contains("private func focusExpandedToolbarSearchFromCommand()"))
        XCTAssertTrue(platformSource.contains("focusExpandedToolbarSearchFromCommand()"))
        XCTAssertTrue(platformSource.contains("toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth\n            isToolbarSearchExpanded = true"))
        XCTAssertFalse(platformSource.contains("HomeMacExpandedToolbarSearchOverlay("))
        XCTAssertFalse(platformSource.contains("private var expandedToolbarSearchRow: some View"))
        XCTAssertFalse(platformSource.contains(".frame(height: HomeMacToolbarSearchLayout.expandedSearchRowHeight)"))
        XCTAssertFalse(platformSource.contains("expandedOverlayTopPadding"))
        XCTAssertFalse(platformSource.contains(".transition(.identity)"))
        XCTAssertFalse(platformSource.contains(".zIndex(30)"))
        XCTAssertTrue(source.contains("@Binding var isTextFocused: Bool"))
        XCTAssertTrue(source.contains("@Binding var isSearchExpanded: Bool"))
        XCTAssertTrue(source.contains("@Binding var visiblePillWidth: CGFloat"))
        XCTAssertTrue(source.contains("@Binding var searchExpansionTransitionID: Int"))
        XCTAssertTrue(source.contains("@Binding var focusRequestID: Int"))
        XCTAssertTrue(source.contains("@Binding var focusDismissRequestID: Int"))
        XCTAssertFalse(source.contains("@State private var isTextFocused = false"))
        XCTAssertFalse(source.contains("@State private var visiblePillWidth = HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertFalse(source.contains("@State private var searchModeTransitionID"))
        XCTAssertFalse(source.contains("@State private var searchExpansionTransitionID = 0"))
        XCTAssertFalse(source.contains("@State private var focusRequestID = 0"))
        XCTAssertFalse(source.contains("@State private var focusDismissRequestID = 0"))
        XCTAssertTrue(source.contains("private func beginSearchFocusRequest()"))
        XCTAssertTrue(source.contains("focusRequestID += 1\n        setSearchFocused(true)"))
        XCTAssertTrue(source.contains("guard focusTextField(selectingText: false) else { return }\n            handledFocusRequestID = requestID"))
        XCTAssertFalse(source.contains("setSearchFocused(true)\n        DispatchQueue.main.async"))
        XCTAssertFalse(source.contains("private func setSearchModeActive"))
        XCTAssertFalse(source.contains("transaction.disablesAnimations = true"))
        XCTAssertFalse(source.contains("activeHostWidth"))
        XCTAssertFalse(source.contains("private var layoutWidth: CGFloat"))
        XCTAssertFalse(source.contains("isSearchExpanded ? HomeMacToolbarSearchLayout.focusedWidth : HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertFalse(source.contains("if !isSearchExpanded {\n            ToolbarItem(placement: .navigation)"))
        XCTAssertFalse(source.contains("ToolbarItem(placement: .principal) {\n            HomeMacToolbarSearchField("))
        XCTAssertTrue(source.contains("RoutinaMacPlaceCheckInToolbarButton("))
        XCTAssertTrue(source.contains("MacToolbarStatusBadge("))
        XCTAssertTrue(source.contains("let showsDoneCount: Bool"))
        XCTAssertTrue(source.contains("if showsDoneCount {\n                MacToolbarStatusBadge("))
        XCTAssertTrue(source.contains("HomeMacBoardInspectorToolbarButton("))
        XCTAssertFalse(source.contains("let titlebarContainerView = closeButton.superview"))
        XCTAssertFalse(source.contains("containerView.addSubview(hostingView, positioned: .above, relativeTo: nil)"))
        XCTAssertFalse(source.contains("alignmentButton.convert(buttonCenter, to: containerView).y"))
        XCTAssertFalse(source.contains("hostingView.frame = NSRect("))
        XCTAssertFalse(source.contains("NSWindow.didResizeNotification"))
        XCTAssertFalse(source.contains("window.addTitlebarAccessoryViewController(accessory)"))
        XCTAssertFalse(source.contains("hittableWidth = parent.visiblePillWidth"))
        XCTAssertTrue(platformSource.contains("isSearchExpanded: $isToolbarSearchExpanded"))
        XCTAssertTrue(platformSource.contains("isSearchTextFocused: $isToolbarSearchTextFocused"))
        XCTAssertTrue(platformSource.contains("isCreatingTaskFromSearch: isToolbarSearchCreateInProgress"))
        XCTAssertFalse(platformSource.contains(".background(homeTitlebarSearchInstaller)"))
        XCTAssertFalse(platformSource.contains("ToolbarItemGroup(placement: .primaryAction) {\n            if isDevelopmentAppVariant"))
        XCTAssertFalse(platformSource.contains("if !isToolbarSearchExpanded {\n            ToolbarItemGroup(placement: .primaryAction)"))
        XCTAssertFalse(platformSource.contains("if !isToolbarSearchExpanded {\n            ToolbarItem(placement: .primaryAction)"))
        XCTAssertFalse(platformSource.contains("hidesTaskDetailToolbarActions: isToolbarSearchExpanded"))
        XCTAssertFalse(homeSource.contains("hidesToolbarActions: isToolbarSearchExpanded"))
        XCTAssertFalse(detailSource.contains("let hidesTaskDetailToolbarActions: Bool"))
        XCTAssertFalse(detailSource.contains("hidesToolbarActions: hidesTaskDetailToolbarActions"))
        XCTAssertFalse(taskDetailSource.contains("hidesToolbarActions: Bool = false"))
        XCTAssertFalse(taskDetailSource.contains("hidesToolbarActions: hidesToolbarActions"))
        XCTAssertFalse(taskToolbarSource.contains("let hidesToolbarActions: Bool"))
        XCTAssertFalse(taskToolbarSource.contains("if !hidesToolbarActions {"))
        XCTAssertTrue(
            taskDetailSource.contains("headerAccessory: {\n                taskDetailActionCluster"),
            "Task-specific actions should live in the task detail header card instead of competing with toolbar search."
        )
        XCTAssertFalse(taskDetailSource.contains("taskDetailActionBar"))
        XCTAssertTrue(taskToolbarSource.contains("struct TaskDetailActionClusterView: View"))
        XCTAssertFalse(taskToolbarSource.contains("ToolbarItem(placement: .primaryAction)"))
        XCTAssertTrue(source.contains("let textField = HomeMacToolbarSearchClickableTextField(string: text)"))
        XCTAssertFalse(source.contains("HomeMacToolbarSearchNSTextField"))
        XCTAssertFalse(source.contains("onPrepareForFocus:"))
        XCTAssertFalse(source.contains("parent.onPrepareForFocus()"))
        XCTAssertFalse(source.contains("override func becomeFirstResponder() -> Bool"))
        XCTAssertTrue(source.contains("private final class HomeMacToolbarSearchClickableTextField: NSTextField"))
        XCTAssertTrue(source.contains("var onMouseDown: (() -> Void)?"))
        XCTAssertTrue(source.contains("override func mouseDown(with event: NSEvent)"))
        XCTAssertTrue(source.contains("func pointerFocusRequested()"))
        XCTAssertFalse(source.contains("HomeMacToolbarSearchAnimatedHost"))
        XCTAssertFalse(source.contains("HomeMacToolbarSearchHostNSView"))
        XCTAssertFalse(source.contains("PillTransitionDirection"))
        XCTAssertFalse(source.contains("keepsActiveHost"))
        XCTAssertTrue(source.contains("searchShell(width: visiblePillWidth)"))
        XCTAssertTrue(source.contains("value: visiblePillWidth"))
        XCTAssertFalse(source.contains("targetWidth"))
        XCTAssertTrue(source.contains("private func searchShell(width: CGFloat) -> some View"))
        XCTAssertTrue(source.contains("private var textLeading: CGFloat"))
        XCTAssertTrue(source.contains(".offset(x: HomeMacToolbarSearchLayout.horizontalPadding)"))
        XCTAssertTrue(source.contains(".padding(.leading, textLeading)"))
        XCTAssertTrue(source.contains(".frame(width: width, height: HomeMacToolbarSearchLayout.height, alignment: .leading)"))
        XCTAssertTrue(source.contains(".frame(width: width, height: HomeMacToolbarSearchLayout.height)"))
        XCTAssertTrue(source.contains(".frame(width: visiblePillWidth,"))
        XCTAssertFalse(source.contains(".frame(width: layoutWidth,"))
        XCTAssertFalse(source.contains("HStack(spacing: 10) {\n            Image(systemName: \"magnifyingglass\")"))
        XCTAssertTrue(source.contains("private var searchFocusBinding: Binding<Bool>"))
        XCTAssertTrue(source.contains("set: { setSearchFocused($0) }"))
        XCTAssertFalse(source.contains("(isFocused || keepsActiveHost) ? HomeMacToolbarSearchLayout.activeHostWidth : HomeMacToolbarSearchLayout.compactWidth"))
        XCTAssertFalse(source.contains(".onChange(of: isFocused)"))
        XCTAssertFalse(source.contains("DispatchQueue.main.asyncAfter(deadline: .now() + HomeMacToolbarSearchLayout.hostReleaseDelay)"))
        XCTAssertTrue(source.contains("DispatchQueue.main.asyncAfter(deadline: .now() + HomeMacToolbarSearchLayout.toolbarActionRestoreDelay)"))
        XCTAssertTrue(source.contains("if nextValue {\n            searchExpansionTransitionID += 1\n            let transitionID = searchExpansionTransitionID\n            if !isSearchExpanded {"))
        XCTAssertTrue(source.contains("visiblePillWidth = HomeMacToolbarSearchLayout.compactWidth\n                isSearchExpanded = true\n                DispatchQueue.main.async"))
        XCTAssertTrue(source.contains("animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.focusedWidth)"))
        XCTAssertFalse(source.contains("guard !isTextFocused else { return }"))
        XCTAssertTrue(source.contains("animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.compactWidth)"))
        XCTAssertTrue(source.contains("private func animateVisiblePillWidth(to width: CGFloat)"))
        XCTAssertTrue(source.contains("let transitionID = searchExpansionTransitionID\n        DispatchQueue.main.asyncAfter"))
        XCTAssertTrue(source.contains("guard searchExpansionTransitionID == transitionID else { return }"))
        XCTAssertFalse(source.contains("guard searchExpansionTransitionID == transitionID, !self.isTextFocused else { return }"))
        XCTAssertTrue(source.contains("isSearchExpanded = false"))
        XCTAssertFalse(source.contains("animationStageWidth"))
        XCTAssertFalse(source.contains(".frame(maxWidth: .infinity, maxHeight: HomeMacToolbarSearchLayout.height)"))
        XCTAssertTrue(source.contains("HomeMacToolbarSearchTextEditorView"))
        XCTAssertTrue(source.contains("Image(systemName: \"magnifyingglass\")"))
        XCTAssertTrue(source.contains("private var centeredIdleContent: some View"))
        XCTAssertTrue(source.contains("private var usesCenteredIdleContent: Bool"))
        XCTAssertTrue(source.contains("!isTextFocused && text.isEmpty"))
        XCTAssertTrue(source.contains("HomeMacToolbarSearchLayout.searchBackgroundColor(isFocused: isTextFocused)"))
        XCTAssertTrue(source.contains("static func searchBackgroundColor(isFocused: Bool) -> Color"))
        XCTAssertTrue(source.contains("Color(nsColor: .textBackgroundColor).opacity(0.98)"))
        XCTAssertTrue(source.contains("textField.isBordered = false"))
        XCTAssertTrue(source.contains("textField.drawsBackground = false"))
        XCTAssertTrue(source.contains("textField.leadingAnchor.constraint(equalTo: leadingAnchor)"))
        XCTAssertTrue(source.contains("textField.trailingAnchor.constraint(equalTo: trailingAnchor)"))
        XCTAssertTrue(source.contains("setContentHuggingPriority(.defaultLow, for: .horizontal)"))
        XCTAssertTrue(source.contains("NSView.noIntrinsicMetric"))
        XCTAssertTrue(source.contains("textField.alignment = .left"))
        XCTAssertTrue(source.contains("textField.cell?.alignment = .left"))
        XCTAssertTrue(source.contains("textField.cell?.usesSingleLineMode = true"))
        XCTAssertTrue(source.contains("Image(systemName: \"xmark.circle.fill\")"))
        XCTAssertTrue(source.contains("Clear search"))
        XCTAssertTrue(source.contains("isTextFocused && (isCreatingTask || canCreateTaskFromQuery)"))
        XCTAssertTrue(source.contains("controlTextDidBeginEditing"))
        XCTAssertTrue(source.contains("@Binding var isFocused: Bool"))
        XCTAssertTrue(source.contains("self.handledFocusRequestID = parent.focusRequestID - 1"))
        XCTAssertTrue(source.contains("guard handledFocusRequestID == parent.focusRequestID else { return }\n            parent.isFocused = false"))
        XCTAssertTrue(source.contains("guard parent.isFocused else {\n                handledFocusRequestID = requestID\n                return\n            }\n            guard focusTextField(selectingText: false) else { return }"))
        XCTAssertTrue(source.contains("focusDismissRequestID += 1"))
        XCTAssertTrue(source.contains("private func dismissSearchFocusFromKeycap()"))
        XCTAssertTrue(source.contains("setSearchFocused(false)\n        focusDismissRequestID += 1"))
        XCTAssertTrue(source.contains("searchFocusTarget(width: width)"))
        XCTAssertFalse(source.contains(".onTapGesture {\n            beginSearchFocusRequest()\n        }"))
        XCTAssertTrue(source.contains("dismissFocusIfNeeded(for: focusDismissRequestID)"))
        XCTAssertTrue(source.contains("HomeMacToolbarSearchOutsideClickDismissView"))
        XCTAssertTrue(source.contains("NSEvent.addLocalMonitorForEvents"))
        XCTAssertTrue(source.contains("NSEvent.addLocalMonitorForEvents(matching: .keyDown)"))
        XCTAssertTrue(source.contains("guard event.keyCode == 53"))
        XCTAssertTrue(source.contains("matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]"))
        XCTAssertTrue(source.contains("clickIsInsideVisiblePill"))
        XCTAssertTrue(source.contains("view.bounds.insetBy(dx: -2, dy: -2).contains(viewLocation)"))
        XCTAssertTrue(source.contains("parent.isFocused = true\n                parent.focusRequestID += 1"))
        XCTAssertTrue(source.contains("view.setPrefersIBeamCursor(isFocused)"))
        XCTAssertTrue(source.contains("window.invalidateCursorRects(for: self)"))
        XCTAssertTrue(source.contains("addCursorRect(bounds, cursor: .iBeam)"))
        XCTAssertTrue(source.contains("#selector(NSResponder.cancelOperation(_:))"))
        XCTAssertTrue(source.contains("dismissSearchFocus()"))
        XCTAssertTrue(source.contains("window.makeFirstResponder(nil)"))
        XCTAssertTrue(source.contains("Text(\"Esc\")"))
        XCTAssertTrue(source.contains("Dismiss search focus"))
        XCTAssertFalse(source.contains("Image(systemName: \"xmark\")"))
        XCTAssertTrue(
            rootSceneSource.contains("window.toolbarStyle = .unifiedCompact"),
            "The native Mac window chrome should stay compact because Home draws its own titlebar-height toolbar row."
        )
        XCTAssertTrue(
            rootSceneSource.contains("setFullSizeContentView(\n                isEnabled: !window.styleMask.contains(.fullScreen),\n                for: window\n            )"),
            "Normal Home windows should keep full-size transparent titlebar content, while fullscreen should not let split/sidebar backing draw behind traffic lights."
        )
        XCTAssertTrue(rootSceneSource.contains("NSWindow.didEnterFullScreenNotification"))
        XCTAssertTrue(rootSceneSource.contains("NSWindow.didExitFullScreenNotification"))
        XCTAssertTrue(rootSceneSource.contains("configureFullscreenTitlebarMode(\n                    isFullscreen: true"))
        XCTAssertTrue(rootSceneSource.contains("configureFullscreenTitlebarMode(\n                    isFullscreen: false"))
        XCTAssertTrue(rootSceneSource.contains("window.styleMask.insert(.fullSizeContentView)"))
        XCTAssertTrue(rootSceneSource.contains("window.styleMask.remove(.fullSizeContentView)"))
        XCTAssertTrue(rootSceneSource.contains("window.titlebarSeparatorStyle = .none"))
        XCTAssertTrue(rootSceneSource.contains("window.toolbar?.sizeMode = .small"))
        XCTAssertFalse(rootSceneSource.contains("showsBaselineSeparator"))
        XCTAssertFalse(
            rootSceneSource.contains("window.toolbarStyle = .expanded"),
            "Expanded native toolbar chrome creates a separate fullscreen strip over the custom Home toolbar."
        )
        XCTAssertTrue(
            platformSource.contains(".toolbarBackgroundVisibility(.hidden, for: .windowToolbar)"),
            "The native window toolbar background should not paint an opaque strip over the SwiftUI-owned Home toolbar in fullscreen."
        )
        XCTAssertTrue(platformSource.contains("HomeMacWindowFullscreenObserver(isFullscreen: $isMacWindowFullscreen)"))
        XCTAssertTrue(platformSource.contains(".routinaMacHomeToolbarTitlebarIntegration(isFullscreen: isMacWindowFullscreen)"))
        XCTAssertTrue(
            platformSource.contains("func routinaMacHomeToolbarTitlebarIntegration(isFullscreen: Bool) -> some View"),
            "Mac Home should keep fullscreen titlebar behavior centralized instead of scattering safe-area tweaks through Home content."
        )
        XCTAssertTrue(platformSource.contains("if isFullscreen {\n            self"))
        XCTAssertTrue(platformSource.contains("} else {\n            ignoresSafeArea(edges: .top)\n        }"))
        XCTAssertFalse(platformSource.contains("static let stableTitlebarHeight"))
        XCTAssertFalse(platformSource.contains("HomeMacFullscreenChrome"))
        XCTAssertFalse(platformSource.contains("HomeMacFullscreenTitlebarReserveBackground"))
        XCTAssertFalse(platformSource.contains("padding(.top, HomeMacFullscreenChrome.stableTitlebarHeight)"))
        XCTAssertFalse(
            platformSource.contains(".overlay(alignment: .top) {\n                    HomeMacFullscreenTitlebarReserveBackground()"),
            "Fullscreen must not add a separate visible reserve band above the integrated Home toolbar."
        )
        XCTAssertTrue(platformSource.contains(".padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight)"))
        XCTAssertTrue(source.contains("static let trafficLightReservedLeadingPadding: CGFloat = 142"))
        XCTAssertTrue(source.contains("static let sidebarToggleLeadingPadding: CGFloat = 28"))
        XCTAssertTrue(
            source.contains(".padding(.leading, HomeMacToolbarSearchLayout.trafficLightReservedLeadingPadding)"),
            "Toolbar controls should start after the native traffic-light region so fullscreen can avoid a separate vertical dead band."
        )
        XCTAssertFalse(platformSource.contains("routinaMacFullscreenTitlebarSafeArea"))
        XCTAssertFalse(platformSource.contains("routinaMacFullscreenTitlebarSpacing"))
        XCTAssertFalse(platformSource.contains("NSEvent.mouseLocation"))
        XCTAssertFalse(platformSource.contains("titlebarRevealPollingTask"))
        XCTAssertFalse(platformSource.contains("titlebarHideTask"))
        XCTAssertFalse(platformSource.contains("isTitlebarRevealed"))
        XCTAssertFalse(platformSource.contains("setTitlebarRevealed"))
        XCTAssertTrue(platformSource.contains("NSWindow.willEnterFullScreenNotification"))
        XCTAssertTrue(platformSource.contains("NSWindow.didExitFullScreenNotification"))
        XCTAssertTrue(platformSource.contains("private var isAttachRetryScheduled = false"))
        XCTAssertFalse(
            platformSource.contains("observedWindow = nil\n            setFullscreen(false)"),
            "Detaching the helper NSView must not clear fullscreen state; SwiftUI detach/reattach can otherwise make fullscreen chrome blink."
        )
        XCTAssertTrue(source.contains("textField.controlSize = .large"))
        XCTAssertTrue(source.contains("textField.focusRingType = .none"))
        XCTAssertFalse(source.contains("focusRingType = .default"))
        XCTAssertTrue(source.contains("Search or create a task"))
        XCTAssertTrue(source.contains("canCreateTaskFromQuery"))
        XCTAssertTrue(source.contains("Return"))
        XCTAssertTrue(source.contains("Create task"))
        XCTAssertTrue(source.contains("static let createHintWidth: CGFloat = 154"))
        XCTAssertTrue(
            source.contains(".frame(width: HomeMacToolbarSearchLayout.createHintWidth, alignment: .leading)"),
            "The Return/Create task hint needs a reserved width so the transparent text editor cannot compress it out of view."
        )
        XCTAssertTrue(
            source.contains("createHint\n                        .transition(.opacity.combined(with: .scale(scale: 0.98)))\n                        .layoutPriority(3)"),
            "The create hint should outrank the flexible text editor during toolbar search layout."
        )
        XCTAssertTrue(source.contains("HomeMacToolbarSearchParserPreview"))
        XCTAssertTrue(source.contains("Detected details"))
        XCTAssertTrue(source.contains("RoutinaQuickAddDraft"))
        XCTAssertTrue(source.contains("enum HomeMacToolbarSearchLayout"))
        XCTAssertFalse(source.contains("parserPreviewDraft"))
        XCTAssertFalse(source.contains("parserPreviewPresentation"))
        XCTAssertFalse(source.contains(".popover("))
        XCTAssertFalse(source.contains("NSSearchField"))
        XCTAssertTrue(source.contains("routinaMacFocusSearchOrCreate"))
        XCTAssertTrue(source.contains("parent.onSubmit"))
        XCTAssertTrue(source.contains("restoreFocusAfterSearchUpdate()"))
        XCTAssertTrue(source.contains("let selectedRange = textField.currentEditor()?.selectedRange"))
        XCTAssertTrue(source.contains("editor.selectedRange = HomeMacToolbarSearchTextField.clampedSelectionRange("))
        XCTAssertFalse(
            source.contains("location: textField.stringValue.count"),
            "Toolbar search focus restore must preserve the field editor selection so mid-string typing does not jump to the end."
        )
        XCTAssertTrue(
            source.contains("shouldLeaveCurrentTextEditorFocused"),
            "Toolbar search may restore focus after filtering, but it must not steal focus from an intentionally focused comment, note, or other text editor."
        )
        XCTAssertTrue(source.contains("window.firstResponder as? NSTextView"))
        XCTAssertTrue(source.contains("activeEditor !== textField.currentEditor()"))
        XCTAssertTrue(platformSource.contains("createTaskFromToolbarSearch"))
        XCTAssertTrue(platformSource.contains("canCreateTaskFromToolbarSearch"))
        XCTAssertTrue(platformSource.contains("toolbarSearchCreateDraft"))
        XCTAssertFalse(platformSource.contains("parserPreviewDraft: toolbarSearchCreateDraft"))
        XCTAssertTrue(platformSource.contains("RoutinaQuickAddParser.parse"))
        XCTAssertTrue(platformSource.contains("draft.hasDetectedMetadata"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchParserPreview(draft: toolbarSearchCreateDraft)"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchLayout.focusedWidth"))
        XCTAssertTrue(platformSource.contains("HomeMacToolbarSearchLayout.parserPreviewTopPadding"))
        XCTAssertTrue(source.contains("static let parserPreviewTrailingPadding: CGFloat = 22"))
        XCTAssertFalse(source.contains(".background(.bar)"))
        XCTAssertTrue(
            platformSource.contains("HomeMacToolbarSearchLayout.topToolbarHeight\n                                + HomeMacToolbarSearchLayout.parserPreviewTopPadding"),
            "Quick-add parser previews should appear below the custom top toolbar chrome instead of covering the search row."
        )
        XCTAssertFalse(platformSource.contains("HomeMacToolbarSearchLayout.parserPreviewTrailingPadding"))
        XCTAssertFalse(platformSource.contains("HomeMacToolbarSearchLayout.expandedSearchHorizontalInset"))
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
        XCTAssertFalse(source.contains("RoutinaMacFocusTimerToolbarItem(hiddenKinds: [.unassigned])"))
        XCTAssertTrue(detailSource.contains("macHeaderFocusControl:"))
        XCTAssertTrue(detailSource.contains("HomeMacActivePlanFocusToolbarButton("))
        XCTAssertTrue(detailSource.contains("RoutinaMacFocusTimerToolbarBadge("))
        XCTAssertTrue(detailSource.contains("HomeMacPlanFocusToolbarButton("))
        XCTAssertTrue(dayPlanSource.contains("if effectiveDisplayMode == .calendar, let macFocusControl"))
        XCTAssertFalse(
            source.contains("Assign Pending Focus"),
            "The Planner Calendar focus menu should only start task-backed timers; pending unassigned focus assignment is no longer a header action."
        )
    }

    func testMacHomeFiltersUseRightSideCompanionPane() throws {
        let detailSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift")
        let filterContainerSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacFilterDetailContainerView.swift")
        let routineFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift")
        let timelineFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTimelineFiltersDetailView.swift")
        let calendarFilterSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacCalendarFiltersDetailView.swift")
        let toolbarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift")
        let boardSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Board.swift")
        let timelineSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift")

        XCTAssertTrue(detailSource.contains("static let filterDetailPaneWidth: CGFloat = 420"))
        XCTAssertTrue(detailSource.contains("private var filterDetailPane: some View"))
        XCTAssertTrue(detailSource.contains("private var fullscreenFilterDetailContent: some View"))
        XCTAssertTrue(detailSource.contains("onMinimizeFullscreenFilterDetail"))
        XCTAssertEqual(
            detailSource.components(separatedBy: ".background(Color.secondary.opacity(0.045), ignoresSafeAreaEdges: [])").count - 1,
            2,
            "Right-side companion pane backgrounds should stop at the toolbar safe area instead of tinting behind the principal search field."
        )
        XCTAssertTrue(detailSource.contains("onCloseTaskDetails()\n                        onCloseFilterDetail()"))
        XCTAssertTrue(filterContainerSource.contains("GeometryReader"))
        XCTAssertTrue(filterContainerSource.contains(".frame(width: proxy.size.width, alignment: .topLeading)"))
        XCTAssertTrue(filterContainerSource.contains("compactHorizontalPadding"))
        XCTAssertTrue(sidebarSource.contains("case .calendar:"))
        XCTAssertTrue(sidebarSource.contains("macCalendarFiltersDetailContent"))
        XCTAssertTrue(sidebarSource.contains("minimumSegmentWidth: 82"))
        XCTAssertTrue(sidebarSource.contains("horizontalPadding: 8"))
        XCTAssertFalse(sidebarSource.contains("minimumSegmentWidth: 132"))
        XCTAssertFalse(sidebarSource.contains(".frame(maxWidth: 520)"))
        XCTAssertFalse(routineFilterSource.contains(".frame(width: 520)"))
        XCTAssertTrue(routineFilterSource.contains(".frame(maxWidth: .infinity)"))
        XCTAssertFalse(timelineFilterSource.contains(".frame(width: 420)"))
        XCTAssertTrue(timelineFilterSource.contains(".frame(maxWidth: .infinity)"))
        XCTAssertTrue(calendarFilterSource.contains("HomeMacCalendarFiltersDetailView"))
        XCTAssertTrue(calendarFilterSource.contains("DayPlanCalendarFilterState"))
        XCTAssertFalse(toolbarSource.contains("HomeMacToolbarFilterButton"))
        XCTAssertTrue(dayPlanSource.contains("onCalendarFilterButtonPressed"))
        XCTAssertTrue(dayPlanSource.contains("if showsCalendarFilterButton {\n                calendarFilterButton\n            }\n\n            if effectiveDisplayMode == .calendar"))
        XCTAssertFalse(
            detailSource.contains("if store.isMacFilterDetailPresented {\n                filterView()"),
            "Home filters should no longer replace the full detail area when opened from the Planner filter button."
        )
        XCTAssertTrue(sidebarSource.contains("func toggleMacCalendarFilterDetailFromPlanner()"))
        XCTAssertTrue(sidebarSource.contains("func expandMacFilterDetailPane()"))
        XCTAssertTrue(sidebarSource.contains("isMacFilterDetailFullscreen = true"))
        XCTAssertTrue(sidebarSource.contains("taskDetailPanePlacement = nil\n            store.send(.setMacFilterDetailPresented(true))"))
        XCTAssertTrue(platformSource.contains("onToggleDayPlanCalendarFilters: toggleMacCalendarFilterDetailFromPlanner"))
        XCTAssertTrue(platformSource.contains("isFilterDetailFullscreen: isMacFilterDetailFullscreen"))
        XCTAssertTrue(boardSource.contains("var macBoardCenterContent: some View {\n        macTodoBoardContent\n    }"))
        XCTAssertTrue(timelineSource.contains("isActive: isMacTimelineMode,\n                allowsFallbackSelection: !store.isMacFilterDetailPresented"))
    }

    func testPlannerTimelineListUsesHomeTimelineFilters() throws {
        let source = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift")
        let listSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacTimelineSidebarView.swift")
        let sidebarSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        let platformSource = try Self.sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift")
        let dayPlanSource = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")
        guard
            let start = source.range(of: "var plannerTimelineEntries: [TimelineEntry] {"),
            let end = source.range(
                of: "var groupedPlannerTimelineEntries: [(date: Date, entries: [TimelineEntry])] {",
                range: start.upperBound..<source.endIndex
            )
        else {
            XCTFail("Expected planner timeline entry derivation to be present")
            return
        }
        let plannerEntriesSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(
            plannerEntriesSource.contains("timelineEntries"),
            "Planner List mode should use the same Home timeline entries as the Timeline sidebar so Both/Timeline filters apply consistently."
        )
        XCTAssertFalse(
            plannerEntriesSource.contains("unfilteredPlannerTimelineEntries"),
            "The unfiltered Planner Timeline source is only for empty-state counting and toolbar search result detection, not visible rows."
        )
        XCTAssertTrue(
            listSource.contains("Try a different timeline search or filters."),
            "Planner List's empty state should mention filters now that Home Timeline filters affect its visible rows."
        )
        XCTAssertTrue(
            listSource.contains("HomeMacPlannerTimelineFilterNotice"),
            "Planner Timeline should show active Timeline filters above older matching rows so hidden recent activity is discoverable."
        )
        XCTAssertTrue(
            listSource.contains("Clear Filters"),
            "Planner Timeline should expose a direct clear action for active Timeline filters."
        )
        XCTAssertTrue(
            source.contains("Newer activity hidden by filters"),
            "Planner Timeline should call out the specific case where filters hide newer activity while older rows remain visible."
        )
        XCTAssertTrue(
            sidebarSource.contains("dayPlanDisplayMode == .list ? .timeline : .calendar"),
            "The Planner filter button should open Timeline scope while Planner Timeline is selected."
        )
        XCTAssertTrue(
            platformSource.contains("isPlannerTimelineFilterActive: macHasActiveTimelineFilters"),
            "Planner Timeline filter state should drive the header filter button's active treatment."
        )
        XCTAssertTrue(
            dayPlanSource.contains("let isListMode = effectiveDisplayMode == .list"),
            "The shared Planner header should distinguish Timeline filters from Calendar layer filters."
        )
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
