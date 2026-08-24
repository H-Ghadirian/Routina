import Foundation
import Testing

struct HomeMacAllFiltersSourceTests {
    @Test
    func allScopeOwnsEveryTaskLadderValueFilterAcrossSupportedSurfaces() throws {
        let sharedFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+SharedFilters.swift"
        )
        let timeline = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+Timeline.swift"
        )
        let calendar = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/MacDetailContainerView.swift"
        )

        #expect(sharedFilters.contains("HomeMacTaskLadderFiltersSection("))
        #expect(sharedFilters.contains("selectedPressureFilter: macSharedPressureFilterBinding"))
        #expect(sharedFilters.contains("selectedThinkingNeededFilter: macSharedThinkingNeededFilterBinding"))
        #expect(sharedFilters.contains("selectedEstimationFilter: macSharedEstimationFilterBinding"))
        #expect(timeline.contains("guard entry.hasTaskLadderValues else { return false }"))
        #expect(timeline.contains("pressure: entry.currentPressure"))
        #expect(calendar.contains("RoutineTaskTemporalWeightResolver.effectiveWeights("))
        #expect(calendar.contains("selectedEstimationFilter"))
    }

    @Test
    func tagCatalogIsOnlyShownInsideTheSearchablePicker() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacTimelineTagFiltersView.swift"
        )

        #expect(source.contains("Text(\"No tag filter\")"))
        #expect(source.contains("selectedTagChips(tags: selectedTags"))
        #expect(source.contains("if selectedTags.count > 1"))
        #expect(source.contains("Label(\"Add tags…\", systemImage: \"plus\")"))
        #expect(source.contains("TextField(\"Search tags\", text: $searchText)"))
        #expect(source.contains("LazyVStack(alignment: .leading"))
        #expect(source.contains("pickerSection(\"Selected\""))
        #expect(source.contains("pickerSection(\"Suggested\""))
        #expect(source.contains("pickerSection(\"Browse\""))
    }

    @Test
    func statsUsesTheCompactSearchableTagFilterInsteadOfCatalogClouds() throws {
        let tagSection = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsTagSections.swift"
        )
        let sidebar = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacStatsSidebarView.swift"
        )

        #expect(tagSection.contains("HomeMacTimelineTagFiltersView("))
        #expect(tagSection.contains("return \"No tag filter\""))
        #expect(!tagSection.contains("ForEach(tagSummaries"))
        #expect(!tagSection.contains("availableExcludedTagsView"))
        #expect(sidebar.contains("HomeMacStatsTagFilterSection("))
        #expect(!sidebar.contains("HomeMacStatsSuggestedRelatedTagSection("))
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
