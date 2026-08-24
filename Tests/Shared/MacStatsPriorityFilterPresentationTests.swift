import Foundation
import Testing

struct MacStatsPriorityFilterPresentationTests {
    @Test
    func statsSidebarUsesSeparateImportanceAndUrgencySections() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarView.swift"
        )

        #expect(source.contains("HomeMacStatsImportanceFilterSection("))
        #expect(source.contains("HomeMacStatsUrgencyFilterSection("))
        #expect(!source.contains("HomeMacImportanceUrgencyDisclosureSection("))
    }

    @Test
    func separateSectionsOnlyUpdateTheirOwnThreshold() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(source.contains("ImportanceUrgencyFilterCell.updatingMinimumImportance("))
        #expect(source.contains("ImportanceUrgencyFilterCell.updatingMinimumUrgency("))
    }

    @Test
    func singleChoiceSectionsShareOneTemporaryExpansionState() throws {
        let sidebar = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarView.swift"
        )

        #expect(sidebar.contains("@State private var expandedSingleChoiceSection"))
        #expect(sidebar.contains("isExpanded: expansionBinding(for: .scope)"))
        #expect(sidebar.contains("isExpanded: expansionBinding(for: .taskType)"))
        #expect(sidebar.contains("isExpanded: expansionBinding(for: .timeRange)"))
        #expect(sidebar.contains("isExpanded: expansionBinding(for: .importance)"))
        #expect(sidebar.contains("isExpanded: expansionBinding(for: .urgency)"))
        #expect(sidebar.contains("expandedSingleChoiceSection = isExpanded ? section : nil"))
    }

    @Test
    func singleChoiceSelectionsCollapseButCustomDateEditingStaysExpanded() throws {
        let sections = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarSections.swift"
        )

        #expect(sections.contains("onPresetSelectionComplete()"))
        #expect(sections.contains("onSelectionComplete()"))
        #expect(sections.contains("onSelectRange(.custom(from: customStart, through: customEnd))"))

        let customSelection = try #require(
            sections.range(of: "onSelectRange(.custom(from: customStart, through: customEnd))")
        )
        let followingText = sections[customSelection.upperBound...].prefix(100)
        #expect(!followingText.contains("onPresetSelectionComplete()"))
        #expect(sections.contains("selectedRange.kind == .custom ? selectedRange.periodDescription"))
    }

    @Test
    func collapsibleSectionsRespectReduceMotionAndExposeCurrentSummary() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacImportanceUrgencyMatrixView.swift"
        )

        #expect(source.contains("@Environment(\\.accessibilityReduceMotion)"))
        #expect(source.contains("accessibilityReduceMotion ? nil : .snappy"))
        #expect(source.contains(".accessibilityValue(accessibilityValue)"))
        #expect(source.contains(".accessibilityHint(isExpanded ? \"Hide options\" : \"Show all options\")"))
        #expect(source.contains(".contentShape(Rectangle())"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
