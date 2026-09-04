import Foundation
import Testing

struct MacStatsSummaryTaskListSourceTests {
    @Test
    func taskBackedStatsRectanglesOpenLazyAnchoredPopoversFromTheirFullSurface() throws {
        let statsView = try Self.sourceFile("RoutinaMacApp/Screens/StatsView.swift")
        let popover = try Self.sourceFile("RoutinaMacApp/Screens/StatsSummaryTaskListPopover.swift")

        #expect(statsView.contains("StatsSummaryTaskListKind("))
        #expect(statsView.contains(".contentShape(RoundedRectangle("))
        #expect(statsView.contains(".onTapGesture"))
        #expect(statsView.contains(".focusable()"))
        #expect(statsView.contains(".onKeyPress(.return)"))
        #expect(statsView.contains(".popover("))
        #expect(statsView.contains("summaryTaskListPopoverBinding(for:"))
        #expect(statsView.contains("StatsSummaryTaskListPresentationBuilder.build("))
        #expect(popover.contains("ScrollView"))
        #expect(popover.contains("LazyVStack"))
        #expect(popover.contains("ForEach(Array(presentation.rows.enumerated())"))
    }

    @Test
    func taskListEvidenceIsBuiltOnlyByTheDeliberateCardAction() throws {
        let statsView = try Self.sourceFile("RoutinaMacApp/Screens/StatsView.swift")
        let builderCalls = statsView.components(
            separatedBy: "StatsSummaryTaskListPresentationBuilder.build("
        ).count - 1

        #expect(builderCalls == 1)
        #expect(statsView.contains("private func showSummaryTaskList("))
        #expect(statsView.contains("store.filteredTaskIDs"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
