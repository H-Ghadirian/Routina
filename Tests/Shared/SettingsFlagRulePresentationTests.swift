import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct SettingsFlagRulePresentationTests {
    @Test
    func assignedAndAvailableRuleListsPartitionTheCatalog() {
        let state = SettingsFlagsState(
            definedFlags: ["Reference"],
            rules: [
                RoutineFlagRule(flag: "reference", kind: .autoAssumeDone),
                RoutineFlagRule(flag: "Reference", kind: .hideFromTaskLists)
            ]
        )

        #expect(state.assignedRuleKinds(for: "Reference") == [
            .hideFromTaskLists,
            .autoAssumeDone
        ])
        #expect(state.availableRuleKinds(for: "reference") == [
            .hideFromCalendarList,
            .hideFromTimeline,
            .hideFromTaskLadder
        ])
    }

    @Test
    func builtInCatalogIncludesCalendarListVisibility() {
        #expect(RoutineFlagRuleKind.allCases == [
            .hideFromTaskLists,
            .hideFromCalendarList,
            .hideFromTimeline,
            .hideFromTaskLadder,
            .autoAssumeDone
        ])
        #expect(RoutineFlagRuleKind.hideFromCalendarList.builtInFlagName == "Hide from Calendar List")
    }

    @Test
    func iOSPresentationOmitsTheMacOnlyCalendarListRuleWithoutChangingTheCatalog() {
        #expect(RoutineFlagRuleKind.iOSVisibleCases == [
            .hideFromTaskLists,
            .hideFromTimeline,
            .hideFromTaskLadder,
            .autoAssumeDone
        ])
        #expect(RoutineFlag.iOSVisible(RoutineFlagRuleKind.builtInFlags) == [
            "Hide from Task Lists",
            "Hide from Timeline",
            "Hide from Task Ladder",
            "Auto Assume Done"
        ])
        #expect(RoutineFlagRuleKind.builtInFlags.contains("Hide from Calendar List"))
    }

    @Test
    func flagSettingsRenderBuiltInRulesWithoutCustomRuleEditors() throws {
        let sourcePaths = [
            (
                path: "RoutinaMacApp/Screens/Settings/SettingsMacTagsDetailView.swift",
                casesExpression: "ForEach(RoutineFlagRuleKind.allCases)"
            ),
            (
                path: "iOS/Screens/Settings/SettingsTagsDetailView.swift",
                casesExpression: "ForEach(RoutineFlagRuleKind.iOSVisibleCases)"
            )
        ]

        for sourcePath in sourcePaths {
            let source = try Self.sourceFile(sourcePath.path)

            #expect(source.contains(sourcePath.casesExpression))
            #expect(source.contains("builtInFlagName"))
            #expect(source.contains("ordinary labels belong in Tags"))
            #expect(!source.contains("Create a Flag"))
            #expect(!source.contains("Add Rule"))
            #expect(!source.contains("About Flags"))
            #expect(!source.lowercased().contains("migrat"))
        }
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
