import Foundation
import Testing

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
        let ladderSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
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
        let toolbarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift"
        )
        let platformSource = try SourceInspectionSupport.readMacHomePlatformSources()
        let detailContainerSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift"
        )
        let backlogSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView.swift"
        )
        let backlogFiltersSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacFiltersDetailView.swift"
        )
        let backlogSupportSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView+Support.swift"
        )
        let ladderSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView.swift"
        )
        let ladderControlsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacControlsDetailView.swift"
        )
        let ladderControlsPresentationSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskRanking/TaskRankingMacView+ControlsPresentation.swift"
        )
        let sidebarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift"
        )

        #expect(toolbarSource.contains("mode == .routines || mode == .backlog || mode == .taskLadder"))
        #expect(toolbarSource.contains("HomeMacToolbarFilterButton("))
        let commandClusterStart = try #require(
            toolbarSource.range(of: "private var toolbarCommandCluster")
        )
        let commandClusterSource = toolbarSource[commandClusterStart.lowerBound...]
        let filterButtonRange = try #require(
            commandClusterSource.range(of: "HomeMacToolbarFilterButton(")
        )
        let workspaceControlRange = try #require(
            commandClusterSource.range(of: "HomeMacWorkspaceToolbarControls(")
        )
        #expect(filterButtonRange.lowerBound < workspaceControlRange.lowerBound)
        #expect(toolbarSource.contains("workspace: selectedSidebarMode"))
        #expect(platformSource.contains("onToggleFilters: toggleHomeToolbarFilters"))
        #expect(detailContainerSource.contains("showsCalendarFilterButton: false"))
        #expect(backlogSource.contains("\"Filter, Sort, and Appearance\""))
        #expect(!backlogSource.contains("Tasks kept off your main task list"))
        #expect(!backlogSource.contains("backlogCountLabel"))
        #expect(backlogFiltersSource.contains("struct BacklogMacFiltersDetailView"))
        #expect(!backlogFiltersSource.contains("Filtering, sorting, and appearance affect Backlog only."))
        #expect(!backlogFiltersSource.contains("private var header"))
        #expect(backlogFiltersSource.contains("private var sectionControls"))
        #expect(backlogFiltersSource.contains("Text(backlogCountLabel)"))
        #expect(backlogFiltersSource.contains("store.send(.refresh)"))
        #expect(backlogFiltersSource.contains("\"Refresh Backlog\""))
        #expect(backlogFiltersSource.contains("\"Reset \\(selectedTab.title)\""))
        #expect(backlogFiltersSource.contains("store.filters.resettingFilters()"))
        #expect(backlogFiltersSource.contains("store.filters.resettingSortOrder()"))
        #expect(backlogFiltersSource.contains("persistTaskRowVisibility(.backlogDefaultValue)"))
        #expect(backlogFiltersSource.contains("HomeMacFilterDetailTabStrip("))
        #expect(backlogFiltersSource.contains("case .filter:"))
        #expect(backlogFiltersSource.contains("case .sort:"))
        #expect(backlogFiltersSource.contains("case .appearance:"))
        #expect(backlogFiltersSource.contains("HomeMacAdaptiveFilterControlRow(\"Due\")"))
        #expect(backlogFiltersSource.contains("options: BacklogDueDateFilter.allCases"))
        #expect(backlogFiltersSource.contains("filterBinding(\\.dueDateFilter)"))
        #expect(backlogFiltersSource.contains("HomeMacAdaptiveFilterControlRow(\"Sort\")"))
        #expect(backlogFiltersSource.contains("options: BacklogSortOrder.allCases"))
        #expect(backlogFiltersSource.contains("UserDefaultStringValueKey.appSettingBacklogTaskRowHiddenFields"))
        #expect(backlogFiltersSource.contains("HomeMacFilterAppearanceToggleRow("))
        #expect(backlogFiltersSource.contains("HomeTaskRowField.backlogAppearanceFields"))
        #expect(backlogSupportSource.contains("store.presentation.rowPresentationsByTaskID[task.id]"))
        #expect(backlogSupportSource.contains("store.presentation.rowNumbersByTaskID[task.id]"))
        #expect(!ladderSource.contains("private func workspaceControls("))
        #expect(ladderControlsSource.contains("struct TaskRankingMacControlsDetailView"))
        #expect(ladderControlsSource.contains("case .filter:"))
        #expect(ladderControlsSource.contains("case .sort:"))
        #expect(ladderControlsSource.contains("case .appearance:"))
        #expect(ladderControlsSource.contains("TaskRankingMetric.allCases"))
        #expect(ladderControlsSource.contains("options: [false, true]"))
        #expect(ladderControlsSource.contains("HomeTaskRowField.taskLadderAppearanceFields"))
        #expect(ladderControlsPresentationSource.contains("\"View, Sort, and Appearance\""))
        #expect(sidebarSource.contains("func clearAllMacTimelineFilters()"))
        #expect(sidebarSource.contains("store.send(.clearTimelineAndSharedFilters)"))
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

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
