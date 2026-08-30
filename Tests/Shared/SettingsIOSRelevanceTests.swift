import Foundation
import Testing

struct SettingsIOSRelevanceTests {
    @Test
    func iOSCalendarOmitsTheMacPlannerPreferenceWhileMacRetainsIt() throws {
        let iOSSource = try Self.sourceFile("iOS/Screens/Settings/SettingsIOSViews.swift")
        let macSource = try Self.sourceFile("RoutinaMacApp/Screens/Settings/SettingsMacView.swift")

        #expect(!iOSSource.contains("Section(\"Planner Calendar\")"))
        #expect(!iOSSource.contains("showTimelineTasksInDayPlannerBinding"))
        #expect(macSource.contains("SettingsMacDetailCard(title: \"Planner Calendar\")"))
        #expect(macSource.contains("showTimelineTasksInDayPlannerBinding"))
    }

    @Test
    func taskDependentAndFeatureDependentSettingsAreAdaptive() throws {
        let generalSource = try Self.sourceFile("iOS/Screens/Settings/SettingsAppearanceDetailView.swift")
        let shortcutsSource = try Self.sourceFile("iOS/Screens/Settings/SettingsIOSViews.swift")

        #expect(generalSource.contains("IOSFirstTaskExperience.completionDefaultsKey"))
        #expect(generalSource.contains("if hasCompletedFirstTaskExperience"))
        #expect(generalSource.contains("Show Home task-type control"))
        #expect(!generalSource.contains("Show Home task-type tabs"))
        #expect(generalSource.contains("if batteryRoutineMonitoringEnabled"))
        #expect(!generalSource.contains(".disabled(!batteryRoutineMonitoringEnabled)"))

        #expect(shortcutsSource.contains("if hasCompletedFirstTaskExperience"))
        #expect(shortcutsSource.contains("if showsSleepShortcuts"))
        #expect(shortcutsSource.contains("isAwayEnabled && isSleepEnabled"))
    }

    @Test
    func macOnlyCalendarListFlagIsFilteredAtEveryIOSPresentationBoundary() throws {
        let settingsSource = try Self.sourceFile("iOS/Screens/Settings/SettingsTagsDetailView.swift")
        let taskFormSource = try Self.sourceFile("iOS/Screens/Shared/TaskFormIOSOrganizationSection.swift")
        let taskDetailSource = try Self.sourceFile("iOS/Screens/TaskDetail/TaskDetailTCAView.swift")
        let timelineSource = try Self.sourceFile("iOS/Screens/Timeline/TimelineView.swift")
        let statsSource = try Self.sourceFile("iOS/Screens/Stats/StatsView.swift")

        #expect(settingsSource.contains("RoutineFlagRuleKind.iOSVisibleCases"))
        #expect(taskFormSource.contains("RoutineFlag.iOSVisible(model.routineFlags)"))
        #expect(taskDetailSource.contains("RoutineFlag.iOSVisible(store.task.flags)"))
        #expect(timelineSource.contains("RoutineFlag.iOSVisible(store.availableFlags)"))
        #expect(statsSource.contains("RoutineFlag.iOSVisible(store.availableFlags)"))
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
