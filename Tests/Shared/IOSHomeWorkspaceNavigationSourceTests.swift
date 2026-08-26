import Foundation
import Testing

struct IOSHomeWorkspaceNavigationSourceTests {
    @Test
    func homeEndsWithBacklogTimelineAndTaskLadderWithoutChangingTabs() throws {
        let appFeature = try Self.sourceFile("iOS/Features/App/AppFeature.swift")
        let appView = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let appPlatform = try Self.sourceFile("iOS/Screens/App/AppViewPlatform.swift")
        let homePlatform = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let taskList = try Self.sourceFile("iOS/Screens/Home/HomeIOSTaskListView.swift")
        let navigation = try Self.sourceFile(
            "iOS/Screens/Home/HomeIOSWorkspaceNavigation.swift"
        )

        #expect(appFeature.contains("var backlog = BacklogFeature.State()"))
        #expect(appFeature.contains("var taskRanking = TaskRankingFeature.State()"))
        #expect(appFeature.contains("Scope(state: \\.backlog, action: \\.backlog)"))
        #expect(appFeature.contains("Scope(state: \\.taskRanking, action: \\.taskRanking)"))
        #expect(appPlatform.contains("backlogStore: store.scope(state: \\.backlog"))
        #expect(appPlatform.contains("taskRankingStore: store.scope(state: \\.taskRanking"))

        let backlog = try #require(navigation.range(of: "title: \"Backlog\""))
        let timeline = try #require(navigation.range(of: "title: \"Timeline\""))
        let taskLadder = try #require(navigation.range(of: "title: \"Task Ladder\""))
        #expect(backlog.lowerBound < timeline.lowerBound)
        #expect(timeline.lowerBound < taskLadder.lowerBound)

        let taskSections = try #require(taskList.range(of: "ForEach(presentation.sections)"))
        let workspaceRows = try #require(taskList.range(of: "workspaceNavigationContent()"))
        #expect(taskSections.lowerBound < workspaceRows.lowerBound)
        #expect(homePlatform.contains("externalSearchText == nil"))
        #expect(homePlatform.contains("homeWorkspaceNavigationSection"))
        #expect(homePlatform.contains("title: \"No tasks yet\""))

        #expect(appView.contains("SwiftUI.Tab(Tab.timeline.rawValue"))
        #expect(appView.contains("SwiftUI.Tab(Tab.more.rawValue"))
    }

    @Test
    func homeDestinationsReuseCachedFeaturesAndOneNavigationHierarchy() throws {
        let navigation = try Self.sourceFile(
            "iOS/Screens/Home/HomeIOSWorkspaceNavigation.swift"
        )
        let timeline = try Self.sourceFile("iOS/Screens/Timeline/TimelineView.swift")
        let backlogView = try Self.sourceFile("iOS/Screens/Backlog/BacklogIOSView.swift")
        let taskLadderView = try Self.sourceFile(
            "iOS/Screens/TaskRanking/TaskRankingIOSView.swift"
        )
        let backlogFeature = try Self.sourceFile(
            "SharedCore/Features/Home/BacklogFeature.swift"
        )
        let taskLadderFeature = try Self.sourceFile(
            "SharedCore/Features/Home/TaskRankingFeature.swift"
        )

        #expect(navigation.contains("BacklogIOSView(store: backlogStore)"))
        #expect(navigation.contains("TaskRankingIOSView(store: taskRankingStore)"))
        #expect(navigation.contains("ownsNavigationContainer: false"))
        #expect(timeline.contains("let ownsNavigationContainer: Bool"))
        #expect(timeline.contains("if usesSidebarLayout && ownsNavigationContainer"))
        #expect(!navigation.contains("NavigationStack"))

        #expect(backlogView.contains("ForEach(store.presentation.sections)"))
        #expect(backlogView.contains("ForEach(store.presentation.hiddenByFlagTasks)"))
        #expect(backlogView.contains(".customSectionsChanged("))
        #expect(backlogFeature.contains("BacklogTaskListPresentation.make("))

        #expect(taskLadderView.contains("ForEach(store.presentation.sections)"))
        #expect(taskLadderView.contains("ForEach(TaskRankingMetric.allCases)"))
        #expect(taskLadderView.contains("store.send(.childLadderOpened(task.id))"))
        #expect(taskLadderFeature.contains("TaskRankingPresentation.make("))
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
