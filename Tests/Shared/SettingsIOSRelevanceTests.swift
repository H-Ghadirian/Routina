import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

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

    @Test
    func unavailableStandaloneEventsAreRemovedFromIOSRelationshipAndSettingsSurfaces() throws {
        let taskFormSource = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let taskDetailSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let tagsSource = try Self.sourceFile(
            "iOS/Screens/Settings/SettingsTagsDetailView.swift"
        )
        let notificationsSource = try Self.sourceFile(
            "iOS/Screens/Settings/SettingsIOSViews.swift"
        )
        let dataQuerySource = try Self.sourceFile(
            "SharedCore/Features/Settings/SettingsDataQuerySupport.swift"
        )
        let executionSource = try Self.sourceFile(
            "SharedCore/Features/Settings/SettingsExecutionSupport.swift"
        )
        let tagPersistenceSource = try Self.sourceFile(
            "SharedCore/Features/Settings/SettingsTagPersistenceSupport.swift"
        )

        #expect(taskFormSource.contains(
            "case .events:\n                return areEventEmotionActionsEnabled"
        ))
        #expect(taskDetailSource.contains(
            "areEventEmotionActionsEnabled && !store.taskEventCandidates.isEmpty"
        ))
        #expect(taskDetailSource.contains(
            "areEventActionsEnabled: areEventEmotionActionsEnabled"
        ))
        #expect(tagsSource.contains(
            "includesEvents: areEventEmotionActionsEnabled"
        ))
        #expect(notificationsSource.contains(
            "areEventEmotionActionsEnabled || $0.sourceKind != .event"
        ))
        #expect(dataQuerySource.contains(
            "#if os(iOS)\n        return SharedDefaults.app[.appSettingMacEventEmotionActionsEnabled]"
        ))
        #expect(dataQuerySource.components(
            separatedBy: "let events = shouldIncludeEvents"
        ).count - 1 == 2)
        #expect(executionSource.contains(
            "#if os(iOS)\n        guard appSettingsClient.eventEmotionActionsEnabled() else { return }"
        ))
        #expect(tagPersistenceSource.contains(
            "#if os(iOS)\n        return SharedDefaults.app[.appSettingMacEventEmotionActionsEnabled]"
        ))
        #expect(tagPersistenceSource.components(
            separatedBy: "let events = shouldMutateEvents"
        ).count - 1 == 2)
    }

    @Test
    func tagSourceCopyOmitsUnavailableEventsWithoutBreakingGrammar() {
        #expect(SettingsTagSourcePresentation.pluralSourceList(
            includesNotes: false,
            includesEvents: false,
            conjunction: "or"
        ) == "tasks or goals")
        #expect(SettingsTagSourcePresentation.pluralSourceList(
            includesNotes: true,
            includesEvents: false,
            conjunction: "or"
        ) == "tasks, goals, or notes")
        #expect(SettingsTagSourcePresentation.pluralSourceList(
            includesNotes: true,
            includesEvents: true,
            conjunction: "and"
        ) == "tasks, goals, notes, and events")
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
