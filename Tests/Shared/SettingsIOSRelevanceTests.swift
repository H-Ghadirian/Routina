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
    func unavailableGoalsAndStandaloneEventsAreRemovedFromRelationshipAndSettingsSurfaces() throws {
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
        let transferExecutionSource = try Self.sourceFile(
            "SharedCore/Features/Settings/SettingsRoutineDataTransferActionExecutionSupport.swift"
        )
        let tagPersistenceSource = try Self.sourceFile(
            "SharedCore/Features/Settings/SettingsTagPersistenceSupport.swift"
        )
        let macTaskFormSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let macTaskDetailSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/TaskDetail/TaskDetailTCAView.swift"
        )
        let macTagsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Settings/SettingsMacTagsListContent.swift"
        )
        let macNotificationsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Settings/SettingsMacView.swift"
        )
        let macTaskRowsSource = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+TaskList.swift"
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
            "return SharedDefaults.app[.appSettingMacEventEmotionActionsEnabled]"
        ))
        #expect(dataQuerySource.contains(
            "return SharedDefaults.app[.appSettingGoalsTabEnabled]"
        ))
        #expect(!dataQuerySource.contains("#if os(iOS)"))
        #expect(dataQuerySource.components(
            separatedBy: "let goals = shouldIncludeGoals"
        ).count - 1 == 2)
        #expect(dataQuerySource.components(
            separatedBy: "let events = shouldIncludeEvents"
        ).count - 1 == 2)
        #expect(executionSource.contains(
            "guard appSettingsClient.eventEmotionActionsEnabled() else { return }"
        ))
        #expect(transferExecutionSource.contains(
            "if SharedDefaults.app[.appSettingGoalsTabEnabled]"
        ))
        #expect(!executionSource.contains("#if os(iOS)"))
        #expect(tagPersistenceSource.contains(
            "return SharedDefaults.app[.appSettingMacEventEmotionActionsEnabled]"
        ))
        #expect(tagPersistenceSource.contains(
            "return SharedDefaults.app[.appSettingGoalsTabEnabled]"
        ))
        #expect(!tagPersistenceSource.contains("#if os(iOS)"))
        #expect(tagPersistenceSource.components(
            separatedBy: "let goals = shouldMutateGoals"
        ).count - 1 == 2)
        #expect(tagPersistenceSource.components(
            separatedBy: "let events = shouldMutateEvents"
        ).count - 1 == 2)
        #expect(macTaskFormSource.contains(
            "if section == .events {\n            return areMacEventEmotionActionsEnabled"
        ))
        #expect(macTaskDetailSource.contains(
            "areMacEventEmotionActionsEnabled && !store.taskEventCandidates.isEmpty"
        ))
        #expect(macTaskDetailSource.contains(
            "if areMacEventEmotionActionsEnabled,\n           let event = events.first"
        ))
        #expect(macTaskDetailSource.contains(
            "goals: isGoalsTabEnabled ? store.taskGoalSummaries : []"
        ))
        #expect(macTaskDetailSource.contains(
            "inlineEditSections.removeAll { $0 == .goals }"
        ))
        #expect(macTagsSource.contains(
            "includesEvents: areMacEventEmotionActionsEnabled"
        ))
        #expect(macTagsSource.contains(
            "includesGoals: isGoalsTabEnabled"
        ))
        #expect(macNotificationsSource.contains(
            "areMacEventEmotionActionsEnabled || $0.sourceKind != .event"
        ))
        #expect(macTaskRowsSource.contains(
            "isGoalsTabEnabled && rowVisibility.shows(.goals)"
        ))
        #expect(tagsSource.contains(
            "includesGoals: isGoalsTabEnabled"
        ))
    }

    @Test
    func tagSourceCopyOmitsUnavailableGoalsAndEventsWithoutBreakingGrammar() {
        #expect(SettingsTagSourcePresentation.pluralSourceList(
            includesGoals: false,
            includesNotes: false,
            includesEvents: false,
            conjunction: "or"
        ) == "tasks")
        #expect(SettingsTagSourcePresentation.pluralSourceList(
            includesGoals: false,
            includesNotes: true,
            includesEvents: false,
            conjunction: "or"
        ) == "tasks or notes")
        #expect(SettingsTagSourcePresentation.pluralSourceList(
            includesGoals: true,
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
