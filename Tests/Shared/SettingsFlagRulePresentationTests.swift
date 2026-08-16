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
            definedFlags: ["Tracking"],
            rules: [
                RoutineFlagRule(flag: "tracking", kind: .autoAssumeDone),
                RoutineFlagRule(flag: "Tracking", kind: .hideFromTaskLists)
            ]
        )

        #expect(state.assignedRuleKinds(for: "Tracking") == [
            .hideFromTaskLists,
            .autoAssumeDone
        ])
        #expect(state.availableRuleKinds(for: "TRACKING") == [
            .hideFromTimeline,
            .hideFromTaskLadder
        ])
    }

    @Test
    func flagSettingsRenderAssignedRulesAndOfferRemainingRules() throws {
        let sourcePaths = [
            "RoutinaMacApp/Screens/Settings/SettingsMacTagsDetailView.swift",
            "iOS/Screens/Settings/SettingsTagsDetailView.swift"
        ]

        for sourcePath in sourcePaths {
            let source = try Self.sourceFile(sourcePath)

            #expect(source.contains("ForEach(assignedRuleKinds)"))
            #expect(source.contains("ForEach(availableRuleKinds)"))
            #expect(source.contains("Label(\"Add Rule\", systemImage: \"plus\")"))
            #expect(source.contains("No rules added"))
            #expect(!source.contains("ForEach(RoutineFlagRuleKind.allCases)"))
            #expect(!source.contains("Toggle(isOn: flagRuleBinding"))
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
