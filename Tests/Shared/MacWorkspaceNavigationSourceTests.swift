import Foundation
import Testing

private struct MacWorkspaceControlSources {
    var toolbar: String
    var platform: String
    var detailContainer: String
    var backlog: String
    var backlogFilters: String
    var backlogSupport: String
    var ladder: String
    var ladderControls: String
    var ladderControlsPresentation: String
    var sidebar: String
}

struct MacWorkspaceNavigationSourceTests {
    @Test
    func backlogAndTaskLadderAreMainWindowWorkspaces() throws {
        let appFeatureSource = try Self.sourceFile(
            "RoutinaMacApp/Features/App/AppFeature.swift"
        )
        let homeFeatureSource = try Self.sourceFile(
            "RoutinaMacApp/Features/Home/HomeFeature+Types.swift"
        )
        let sceneSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift"
        )
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let toolbarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift"
        )
        let controlsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacSidebarModeStripView.swift"
        )
        let commandSource = try Self.sourceFile(
            "RoutinaMacApp/Commands/RoutineCommands.swift"
        )

        #expect(appFeatureSource.contains("var backlog = BacklogFeature.State()"))
        #expect(appFeatureSource.contains("var taskRanking = TaskRankingFeature.State()"))
        #expect(homeFeatureSource.contains("case backlog = \"Backlog\""))
        #expect(homeFeatureSource.contains("case taskLadder = \"Task Ladder\""))
        #expect(homeFeatureSource.contains("static let workspaceModes: [Self]"))
        #expect(!sceneSource.contains("Window(\"Backlog\""))
        #expect(!sceneSource.contains("Window(\"Task Ladder\""))
        #expect(platformSource.contains("BacklogMacView("))
        #expect(platformSource.contains("store: backlogStore"))
        #expect(platformSource.contains("onShowTaskInPlanner: showBacklogTaskInPlanner"))
        #expect(platformSource.contains("onShowTaskInTimeline: showBacklogTaskInTimeline"))
        #expect(platformSource.contains("TaskRankingMacView("))
        #expect(platformSource.contains("isControlsPresented: store.isMacFilterDetailPresented"))
        #expect(toolbarSource.contains("HomeMacWorkspaceToolbarControls("))
        #expect(controlsSource.contains("private var combinedMenuLabel: some View"))
        #expect(controlsSource.contains("ForEach(combinedMenuShortcuts)"))
        #expect(controlsSource.contains("ForEach(availableWorkspaceModes)"))
        #expect(!controlsSource.contains("private var addControl: some View"))
        #expect(controlsSource.contains("Button(action: onOpenSettings)"))
        #expect(commandSource.contains("openWindow(id: RoutinaMacSceneID.home)"))
        #expect(commandSource.contains(".routinaMacOpenBacklogInMainWindow"))
        #expect(commandSource.contains(".routinaMacOpenTaskLadderInMainWindow"))
    }

    @Test
    func topSearchIsWorkspaceAwareForPlannerBacklogAndTaskLadder() throws {
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let backlogSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView.swift"
        )
        let backlogSupportSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView+Support.swift"
        )
        let ladderSource =
            try Self.sourceFile(
                "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
            )
            + Self.sourceFile(
                "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacSearchContent.swift"
            )

        #expect(platformSource.contains("searchText: toolbarSearchTextBinding"))
        #expect(platformSource.contains("get: { backlogStore.searchText }"))
        #expect(platformSource.contains("get: { taskRankingStore.searchText }"))
        #expect(platformSource.contains("showBacklogTaskInPlanner"))
        #expect(platformSource.contains("showBacklogTaskInTimeline"))
        #expect(!backlogSource.contains("TextField(\"Search backlog\""))
        #expect(backlogSupportSource.contains("Found outside Backlog"))
        #expect(backlogSupportSource.contains("Button(\"Show in Planner\")"))
        #expect(backlogSupportSource.contains("Button(\"Show in Timeline\")"))
        #expect(backlogSource.contains("showsPrincipalToolbarTitle: false"))
        #expect(ladderSource.contains("Found in Task Ladder"))
        #expect(ladderSource.contains("Outside Task Ladder"))
        #expect(ladderSource.contains("showsPrincipalToolbarTitle: false"))
    }

    @Test
    func backlogWorkspaceDepartureRemovesEmbeddedDetailBeforeChangingSplitLayouts() throws {
        let sidebarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift"
        )
        let backlogFeatureSource = try Self.sourceFile(
            "SharedCore/Features/Home/BacklogFeature.swift"
        )

        #expect(sidebarSource.contains("backlogStore.send(.workspaceDeactivated)"))
        #expect(sidebarSource.contains("DispatchQueue.main.async"))
        #expect(backlogFeatureSource.contains("case workspaceDeactivated"))
        #expect(backlogFeatureSource.contains("state.taskDetailState = nil"))
        #expect(backlogFeatureSource.contains("case dueDateBoundaryReached"))
        #expect(backlogFeatureSource.contains("state.filters.dueDateFilter.dependsOnCurrentDay"))
        #expect(backlogFeatureSource.contains(".cancel(id: CancelID.dueDateBoundaryRefresh)"))
    }

    @Test
    func workspaceControlsEntryLivesBesidePlannerBacklogAndTaskLadder() throws {
        let sources = try Self.workspaceControlSources()

        #expect(sources.toolbar.contains("mode == .routines || mode == .backlog || mode == .taskLadder"))
        #expect(sources.toolbar.contains("HomeMacToolbarFilterButton("))
        let commandClusterStart = try #require(
            sources.toolbar.range(of: "private var toolbarCommandCluster")
        )
        let commandClusterSource = sources.toolbar[commandClusterStart.lowerBound...]
        let filterButtonRange = try #require(
            commandClusterSource.range(of: "HomeMacToolbarFilterButton(")
        )
        let workspaceControlRange = try #require(
            commandClusterSource.range(of: "HomeMacWorkspaceToolbarControls(")
        )
        #expect(filterButtonRange.lowerBound < workspaceControlRange.lowerBound)
        #expect(sources.toolbar.contains("workspace: selectedSidebarMode"))
        #expect(sources.toolbar.contains("summary: filterSummary"))
        #expect(sources.platform.contains("controlSummary.text(maximumItemCount: 3)"))
        #expect(sources.platform.contains("initialTab: macWorkspaceControlInitialTab"))
        #expect(sources.platform.contains("onToggleFilters: toggleHomeToolbarFilters"))
        #expect(sources.detailContainer.contains("showsCalendarFilterButton: false"))
        #expect(sources.backlog.contains("\"Filter, Sort, and Appearance\""))
        #expect(!sources.backlog.contains("Tasks kept off your main task list"))
        #expect(!sources.backlog.contains("backlogCountLabel"))
        #expect(sources.backlogFilters.contains("struct BacklogMacFiltersDetailView"))
        #expect(!sources.backlogFilters.contains("Filtering, sorting, and appearance affect Backlog only."))
        #expect(!sources.backlogFilters.contains("private var header"))
        #expect(sources.backlogFilters.contains("private var sectionControls"))
        #expect(sources.backlogFilters.contains("Text(backlogCountLabel)"))
        #expect(sources.backlogFilters.contains("store.send(.refresh)"))
        #expect(sources.backlogFilters.contains("\"Refresh Backlog\""))
        #expect(sources.backlogFilters.contains("\"Reset \\(selectedTab.title)\""))
        #expect(sources.backlogFilters.contains("store.filters.resettingFilters()"))
        #expect(sources.backlogFilters.contains("store.filters.resettingSortOrder()"))
        #expect(sources.backlogFilters.contains("persistTaskRowVisibility(.backlogDefaultValue)"))
        #expect(sources.backlogFilters.contains("HomeMacFilterDetailTabStrip("))
        #expect(sources.backlogFilters.contains("case .filter:"))
        #expect(sources.backlogFilters.contains("case .sort:"))
        #expect(sources.backlogFilters.contains("case .appearance:"))
        #expect(sources.backlogFilters.contains("HomeMacAdaptiveFilterControlRow(\"Due\")"))
        #expect(sources.backlogFilters.contains("options: BacklogDueDateFilter.allCases"))
        #expect(sources.backlogFilters.contains("filterBinding(\\.dueDateFilter)"))
        #expect(sources.backlogFilters.contains("HomeMacAdaptiveFilterControlRow(\"Sort\")"))
        #expect(sources.backlogFilters.contains("options: BacklogSortOrder.allCases"))
        #expect(sources.backlogFilters.contains("UserDefaultStringValueKey.appSettingBacklogTaskRowHiddenFields"))
        #expect(sources.backlogFilters.contains("HomeMacFilterAppearanceToggleRow("))
        #expect(sources.backlogFilters.contains("HomeTaskRowField.backlogAppearanceFields"))
        #expect(sources.backlogSupport.contains("store.presentation.rowPresentationsByTaskID[task.id]"))
        #expect(sources.backlogSupport.contains("store.presentation.rowNumbersByTaskID[task.id]"))
        #expect(!sources.ladder.contains("private func workspaceControls("))
        #expect(sources.ladderControls.contains("struct TaskRankingMacControlsDetailView"))
        #expect(sources.ladderControls.contains("case .filter:"))
        #expect(sources.ladderControls.contains("case .sort:"))
        #expect(sources.ladderControls.contains("case .appearance:"))
        #expect(sources.ladderControls.contains("TaskRankingMetric.allCases"))
        #expect(sources.ladderControls.contains("options: [false, true]"))
        #expect(sources.ladderControls.contains("HomeTaskRowField.taskLadderAppearanceFields"))
        #expect(sources.ladderControls.contains("Button(\"Reset \\(tabTitle(selectedTab))\")"))
        #expect(sources.ladderControls.contains("private func resetSelectedTab()"))
        #expect(sources.ladderControlsPresentation.contains("\"View, Sort, and Appearance\""))
        #expect(sources.sidebar.contains("func clearAllMacTimelineFilters()"))
        #expect(sources.sidebar.contains("store.send(.clearTimelineAndSharedFilters)"))
    }

    @Test
    func backlogCreationChooserNamesTheDestinationInUserTerms() throws {
        let homeSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift"
        )
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()

        #expect(homeSource.contains("Where should this task go?"))
        #expect(homeSource.contains("Button(\"Main task list\")"))
        #expect(homeSource.contains("add the task to your main task list"))
        #expect(!homeSource.contains("Button(\"Radar\")"))
        #expect(platformSource.contains("title: \"Backlog › \\(section.title)\""))
        #expect(platformSource.contains("title: \"Backlog › \\(section.title) › \\(subsection.title)\""))
    }

    @Test
    func backlogTaskContextMenuOffersTheMainTaskListPlanningChoices() throws {
        let rowSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacTaskRow.swift"
        )
        let backlogSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView.swift"
        )
        let supportSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView+Support.swift"
        )

        #expect(rowSource.contains("if task.supportsStoredPlanning"))
        #expect(rowSource.contains("Menu(\"Plan to do\")"))
        #expect(rowSource.contains("Button(\"Today\""))
        #expect(rowSource.contains("Button(\"Tomorrow\""))
        #expect(rowSource.contains("Button(\"Choose Date...\""))
        #expect(rowSource.contains("Button(\"Clear Plan\""))
        #expect(backlogSource.contains("appSettingShowTomorrowInTaskList"))
        #expect(backlogSource.contains("TaskPlanningDatePickerSheet("))
        #expect(supportSource.contains("store.send(.planTask("))
    }

    @Test
    func macSectionSettingsSeparatesRadarAndBacklogCatalogs() throws {
        let sectionsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Settings/SettingsMacTaskSectionsDetailView.swift"
        )

        #expect(sectionsSource.contains("@State private var selectedSurface: HomeTaskSectionSurface = .radar"))
        #expect(sectionsSource.contains("Picker(\"Section destination\", selection: $selectedSurface)"))
        #expect(sectionsSource.contains("Text(\"Main task list\")"))
        #expect(sectionsSource.contains("Text(\"Backlog\")"))
        #expect(sectionsSource.contains(".pickerStyle(.segmented)"))
        #expect(sectionsSource.contains("surface: selectedSurface"))
        #expect(sectionsSource.contains("topLevelSections(\n            in: customTaskSections,\n            surface: selectedSurface"))
        #expect(sectionsSource.contains("movingSection(\n            section.id,\n            by: offset,\n            surface:"))
        #expect(sectionsSource.contains(".transition(.identity)"))
        #expect(sectionsSource.contains(".clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))"))
        #expect(!sectionsSource.contains(".transition(.opacity.combined(with: .move(edge: .top)))"))
    }

    private static func workspaceControlSources() throws -> MacWorkspaceControlSources {
        try MacWorkspaceControlSources(
            toolbar: sourceFile("RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift"),
            platform: SourceInspectionSupport.readMacHomePlatformSources(),
            detailContainer: sourceFile("RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift"),
            backlog: sourceFile("RoutinaMacApp/Screens/Backlog/BacklogMacView.swift"),
            backlogFilters: sourceFile("RoutinaMacApp/Screens/Backlog/BacklogMacFiltersDetailView.swift"),
            backlogSupport: sourceFile("RoutinaMacApp/Screens/Backlog/BacklogMacView+Support.swift"),
            ladder: sourceFile("RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"),
            ladderControls: sourceFile("RoutinaMacApp/Screens/TaskRanking/TaskRankingMacControlsDetailView.swift"),
            ladderControlsPresentation: sourceFile(
                "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView+ControlsPresentation.swift"
            ),
            sidebar: sourceFile("RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift")
        )
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
