import Foundation

/// Centralizes the few tests that intentionally guard source-level architecture
/// invariants which cannot be expressed as runtime behavior.
enum SourceInspectionSupport {
    static func readProjectFile(
        _ relativePath: String,
        callerFile: StaticString = #filePath
    ) throws -> String {
        return try String(
            contentsOf: projectRoot(for: callerFile).appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    static func readProjectSwiftFiles(
        in relativeDirectory: String,
        callerFile: StaticString = #filePath
    ) throws -> String {
        try FileManager.default
            .contentsOfDirectory(
                at: projectRoot(for: callerFile).appendingPathComponent(relativeDirectory, isDirectory: true),
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    static func readMacTaskDetailSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+Overview.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+OptionalDetails.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+HeaderSections.swift",
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView+ContentSections.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readMacTimelineSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/Timeline/TimelineView.swift",
            "RoutinaMacApp/Screens/Timeline/TimelineView+Filters.swift",
            "RoutinaMacApp/Screens/Timeline/TimelineView+Rows.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readMacHomeTimelineSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeMacTimelinePresentationModels.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TimelinePresentation.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TimelineRowPresentation.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readStatsFocusChartSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "SharedCore/Views/StatsFocusChartSection.swift",
            "SharedCore/Views/StatsFocusChartGrouping.swift",
            "SharedCore/Views/StatsFocusCumulativeChart.swift",
            "SharedCore/Views/StatsFocusWeekdayAverageChart.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readGoalsFeatureSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "SharedCore/Features/Goals/GoalsFeature.swift",
            "SharedCore/Features/Goals/GoalsFeaturePersistence.swift",
            "SharedCore/Features/Goals/GoalsFeaturePresentation.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readIOSStatsFeatureSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "iOS/Features/App/StatsFeature.swift",
            "iOS/Features/App/StatsFeatureEffects.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readDayPlanWeekCalendarSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "SharedCore/Views/DayPlan/DayPlanWeekCalendarView.swift",
            "SharedCore/Views/DayPlan/DayPlanWeekCalendarInteractionSupport.swift",
            "SharedCore/Views/DayPlan/DayPlanWeekCalendarSidebarSupport.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readIOSHomeSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "iOS/Screens/Home/HomeTCAView.swift",
            "iOS/Screens/Home/IOSSmartAddTaskSheet.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readMacHomePlatformSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAViewPlatform.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacToolbar.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+WorkspaceControls.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacSearchRefresh.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacQuickAddPresentation.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacQuickAddCreation.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+MacFilters.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readMacHomeRootSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeMacRootModels.swift",
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+CorePresentation.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    static func readMacDetailContainerSources(
        callerFile: StaticString = #filePath
    ) throws -> String {
        try [
            "RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift",
            "RoutinaMacApp/Screens/Home/Components/MacDetailContainerView+Planner.swift",
            "RoutinaMacApp/Screens/Home/Components/MacDetailContainerView+Timeline.swift",
        ]
        .map { try readProjectFile($0, callerFile: callerFile) }
        .joined(separator: "\n")
    }

    private static func projectRoot(for callerFile: StaticString) -> URL {
        URL(fileURLWithPath: "\(callerFile)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
