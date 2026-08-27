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
    func compactTaskLadderFiltersPairLeadingTitlesWithEqualWidthTrailingPickers() throws {
        let controls = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacImportanceUrgencyMatrixView.swift"
        )
        let adaptivePicker = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacFilterDetailContainerView.swift"
        )

        #expect(
            controls.components(
                separatedBy: "HomeMacAdaptiveFilterControlRow(\""
            ).count - 1 == 5
        )
        #expect(
            controls.components(
                separatedBy: "compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth"
            ).count - 1 == 5
        )
        #expect(adaptivePicker.contains("static let compactPickerWidth: CGFloat = 156"))
        #expect(adaptivePicker.contains("HStack(alignment: .center, spacing: 12)"))
        #expect(adaptivePicker.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(adaptivePicker.contains(".frame(width: compactPickerWidth, alignment: .leading)"))
    }

    @Test
    func compactTaskListPickersPairLeadingTitlesWithTheSharedPickerWidth() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacRoutineFiltersDetailView.swift"
        )

        for title in ["Created", "Media", "One-time State", "Grouping", "Sort"] {
            #expect(source.contains("HomeMacAdaptiveFilterControlRow(\"\(title)\")"))
        }
        #expect(source.contains("pairsInCompactLayout: availableFilters.count > 3"))
        #expect(
            source.components(
                separatedBy: "compactPickerWidth: HomeMacFilterControlLayout.compactPickerWidth"
            ).count - 1 == 6
        )
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
    func sharedTagsUseOneCombinedRulePickerWithVisibleActiveRules() throws {
        let sharedFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/HomeTCAView/HomeTCAView+SharedFilters.swift"
        )
        let tagFilters = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacTimelineTagFiltersView.swift"
        )

        #expect(sharedFilters.contains("presentation: .compactActions"))
        #expect(!sharedFilters.contains("HomeMacCollapsibleFilterSection("))
        #expect(!sharedFilters.contains("private var tagsSummary"))
        #expect(tagFilters.contains("Label(\"Edit tag filters…\", systemImage: \"slider.horizontal.3\")"))
        #expect(tagFilters.contains("Color.teal.opacity(0.18)"))
        #expect(tagFilters.contains("HomeMacDirectFilterGroup("))
        #expect(tagFilters.contains("title: \"Tags\""))
        #expect(tagFilters.contains("systemImage: \"tag.fill\""))
        #expect(tagFilters.contains("private var compactTagRuleSummary"))
        #expect(tagFilters.contains("selectedTagChips(tags: tags, isExcluded: isExcluded)"))
        #expect(tagFilters.contains("HomeMacCombinedTagFilterPicker("))
        #expect(tagFilters.contains("Text(\"Tag filters\")"))
        #expect(tagFilters.contains("options: HomeMacFilterRuleSide.allCases"))
        #expect(tagFilters.contains("if activeSelectedTags.count > 1"))
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
        #expect(flagFilters.contains("HomeMacDirectFilterGroup("))
        #expect(flagFilters.contains("title: \"Flags\""))
        #expect(flagFilters.contains("systemImage: \"flag.fill\""))
        #expect(flagFilters.contains("Label(\"Edit flag filters…\", systemImage: \"slider.horizontal.3\")"))
        #expect(flagFilters.contains("private var flagRuleSummary"))
        #expect(flagFilters.contains("HomeMacSharedFlagFilterPicker("))
        #expect(flagFilters.contains("Text(\"Flag filters\")"))
        #expect(flagFilters.contains("if activeSelectedFlags.count > 1"))
        #expect(!flagFilters.contains("Text(\"Add more\")"))
        #expect(!flagFilters.contains("title: \"All Flags\""))

        let group = try Self.sourceFile(
            "RoutinaMacApp/Screens/Home/Components/HomeMacImportanceUrgencyMatrixView.swift"
        )
        #expect(group.contains("struct HomeMacDirectFilterGroup<Content: View>: View"))
        #expect(group.contains("enum HomeMacFilterRuleSide: String, CaseIterable, Identifiable"))
        #expect(group.contains(".routinaGlassPanel("))
        #expect(group.contains("tintOpacity: 0.08"))

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
