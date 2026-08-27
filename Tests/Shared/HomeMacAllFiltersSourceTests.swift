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
    func compactTaskLadderFiltersPairLeadingTitlesWithTrailingPickers() throws {
        let controls = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacImportanceUrgencyMatrixView.swift"
        )
        let adaptivePicker = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacFilterDetailContainerView.swift"
        )

        #expect(controls.contains("@Environment(\\.homeMacFilterDetailLayout) private var filterLayout"))
        #expect(controls.contains("if filterLayout.usesCompactPickers"))
        #expect(controls.contains("HStack(alignment: .center, spacing: 12)"))
        #expect(controls.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(
            controls.components(separatedBy: "compactPickerFillsAvailableWidth: false").count - 1 == 5
        )
        #expect(adaptivePicker.contains(".fixedSize(horizontal: !compactPickerFillsAvailableWidth"))
        #expect(adaptivePicker.contains("alignment: compactPickerFillsAvailableWidth ? .leading : .trailing"))
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
    func sharedTagsUseDirectCompactActionsWithoutADisclosureCard() throws {
        let sharedFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+SharedFilters.swift"
        )
        let tagFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacTimelineTagFiltersView.swift"
        )

        #expect(sharedFilters.contains("presentation: .compactActions"))
        #expect(!sharedFilters.contains("HomeMacCollapsibleFilterSection("))
        #expect(!sharedFilters.contains("private var tagsSummary"))
        #expect(tagFilters.contains("Label(\"Include tags\", systemImage: \"plus\")"))
        #expect(tagFilters.contains("Label(\"Exclude tags\", systemImage: \"minus\")"))
        #expect(tagFilters.contains("Color.teal.opacity(0.18)"))
        #expect(tagFilters.contains("if !selectedTags.isEmpty"))
        #expect(tagFilters.contains("if !selectedExcludedTags.isEmpty"))
        #expect(tagFilters.contains("compactMatchModeControl("))
    }

    @Test
    func sharedFlagsUseTheCompactSearchableInteractionWithoutPerSurfaceDuplicates() throws {
        let flagFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFlagFiltersView.swift"
        )
        let sharedFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+SharedFilters.swift"
        )
        let timelineFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacTimelineFiltersDetailView.swift"
        )
        let taskListFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift"
        )

        #expect(flagFilters.contains("struct HomeMacCompactFlagFiltersView: View"))
        #expect(flagFilters.contains("actionTitle: \"Include flags\""))
        #expect(flagFilters.contains("actionSystemImage: \"plus\""))
        #expect(flagFilters.contains("TextField(\"Search flags\", text: $searchText)"))
        #expect(flagFilters.contains("pickerSection(\"Selected\""))
        #expect(flagFilters.contains("pickerSection(\"Browse\""))
        #expect(flagFilters.contains("if !selectedFlags.isEmpty"))
        #expect(flagFilters.contains("if selectedFlags.count > 1"))
        #expect(flagFilters.contains("struct HomeMacSharedFlagFiltersView: View"))
        #expect(flagFilters.contains("actionTitle: \"Exclude flags\""))
        #expect(flagFilters.contains("actionSystemImage: \"minus\""))
        #expect(!flagFilters.contains("Text(\"Add more\")"))
        #expect(!flagFilters.contains("title: \"All Flags\""))

        #expect(sharedFilters.contains("HomeMacSharedFlagFiltersView("))
        #expect(!taskListFilters.contains("if showsFlagSection"))
        #expect(!timelineFilters.contains("HomeMacCompactFlagFiltersView("))
        #expect(!timelineFilters.contains("HomeMacCollapsibleFilterSection("))
        #expect(!timelineFilters.contains("flagButton(\"Default Timeline\""))
        #expect(!timelineFilters.contains("Text(\"Reveal by Flag\")"))
    }

    @Test
    func taskListVisibilityTogglesPrecedeTaskTypeAndReuseAppearanceRows() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift"
        )

        #expect(source.range(
            of: #"blockedTasksToggle\s+assumedDoneTasksToggle\s+archivedToggle\s+}\s+filterControlSection\("Task type"\)"#,
            options: .regularExpression
        ) != nil)
        #expect(source.range(
            of: #"HomeMacFilterAppearanceToggleRow\(\s*"Show blocked tasks",\s*isOn: showBlockedTasksBinding\s*\)"#,
            options: .regularExpression
        ) != nil)
        #expect(source.range(
            of: #"HomeMacFilterAppearanceToggleRow\(\s*"Hide assumed-done tasks",\s*isOn: \$hideAssumedDoneTasks\s*\)"#,
            options: .regularExpression
        ) != nil)
        #expect(source.range(
            of: #"HomeMacFilterAppearanceToggleRow\(\s*"Show archived list",\s*isOn: \$showArchivedTasks\s*\)"#,
            options: .regularExpression
        ) != nil)
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
