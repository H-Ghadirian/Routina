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
            .hideFromTimeline,
            .hideFromTaskLadder
        ])
    }

    @Test
    func flagSettingsRenderBuiltInRulesWithoutCustomRuleEditors() throws {
        let sourcePaths = [
            "RoutinaMacApp/Screens/Settings/SettingsMacTagsDetailView.swift",
            "iOS/Screens/Settings/SettingsTagsDetailView.swift"
        ]

        for sourcePath in sourcePaths {
            let source = try Self.sourceFile(sourcePath)

            #expect(source.contains("ForEach(RoutineFlagRuleKind.allCases)"))
            #expect(source.contains("builtInFlagName"))
            #expect(source.contains("ordinary labels belong in Tags"))
            #expect(!source.contains("Create a Flag"))
            #expect(!source.contains("Add Rule"))
        }
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
