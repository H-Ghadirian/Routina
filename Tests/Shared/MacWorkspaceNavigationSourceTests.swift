import Foundation
import Testing

struct MacWorkspaceNavigationSourceTests {
    @Test
    func backlogAndTaskLadderAreMainWindowWorkspaces() throws {
        let appFeatureSource = try Self.sourceFile(
            "RoutinaMacApp/Features/App/AppFeature.swift"
        )
        let homeFeatureSource = try Self.sourceFile(
            "RoutinaMacApp/Features/Home/HomeFeature.swift"
        )
        let sceneSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/App/RoutinaMacRootScene.swift"
        )
        let platformSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift"
        )
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
        #expect(platformSource.contains("TaskRankingMacView(store: taskRankingStore)"))
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
        let platformSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift"
        )
        let backlogSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView.swift"
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
        #expect(backlogSource.contains("Found outside Backlog"))
        #expect(backlogSource.contains("Button(\"Show in Planner\")"))
        #expect(backlogSource.contains("Button(\"Show in Timeline\")"))
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
    }

    @Test
    func filterEntryLivesBesidePlannerAndBacklogWorkspaceControl() throws {
        let toolbarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacHomeToolbarContent.swift"
        )
        let platformSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift"
        )
        let detailContainerSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift"
        )
        let backlogSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Backlog/BacklogMacView.swift"
        )
        let sidebarSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Sidebar.swift"
        )

        #expect(toolbarSource.contains("mode == .routines || mode == .backlog"))
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
        #expect(platformSource.contains("onToggleFilters: toggleHomeToolbarFilters"))
        #expect(detailContainerSource.contains("showsCalendarFilterButton: false"))
        #expect(backlogSource.contains("These filters affect Backlog only."))
        #expect(backlogSource.contains("BacklogMacFiltersDetailView"))
        #expect(sidebarSource.contains("func clearAllMacTimelineFilters()"))
        #expect(sidebarSource.contains("store.send(.clearTimelineAndSharedFilters)"))
    }

    @Test
    func backlogCreationChooserNamesTheDestinationInUserTerms() throws {
        let homeSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift"
        )
        let platformSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift"
        )

        #expect(homeSource.contains("Where should this task go?"))
        #expect(homeSource.contains("Button(\"Main task list\")"))
        #expect(homeSource.contains("add the task to your main task list"))
        #expect(!homeSource.contains("Button(\"Radar\")"))
        #expect(platformSource.contains("title: \"Backlog › \\(section.title)\""))
        #expect(platformSource.contains("title: \"Backlog › \\(section.title) › \\(subsection.title)\""))
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
