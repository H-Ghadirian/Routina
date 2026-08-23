import Foundation
import Testing

struct TaskFormIOSLayoutRegressionTests {
    @Test
    func taskTypeUsesSeparateSectionsWithoutSpacerRows() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSIdentitySections.swift"
        )
        let taskTypeSection = try Self.sourceSection(
            startingAt: "struct TaskFormIOSTaskTypeSection",
            endingAt: "struct TaskFormIOSEmojiSection",
            in: source
        )

        #expect(taskTypeSection.contains("Section(header: Text(\"Task Type\"))"))
        #expect(taskTypeSection.contains("Section(header: Text(\"Duration\"))"))
        #expect(taskTypeSection.contains("Section(header: Text(\"Availability\"))"))
        #expect(!taskTypeSection.contains("Divider()"))
    }

    @Test
    func availabilityUsesReadableNavigationChoicesInsteadOfFiveSegments() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSIdentitySections.swift"
        )
        let taskTypeSection = try Self.sourceSection(
            startingAt: "struct TaskFormIOSTaskTypeSection",
            endingAt: "struct TaskFormIOSEmojiSection",
            in: source
        )

        #expect(taskTypeSection.contains("Picker(\"Dates\""))
        #expect(taskTypeSection.contains("Picker(\"Time\""))
        #expect(taskTypeSection.contains(".pickerStyle(.navigationLink)"))
        #expect(!taskTypeSection.contains("accessibilityLabel: \"Time availability\""))
    }

    @Test
    func progressiveDetailsRevealOneChosenSectionAndScrollToIt() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormContentPlatform.swift"
        )

        #expect(source.contains("@State private var revealedSections"))
        #expect(source.contains("Label(\"Add details\", systemImage: \"plus.circle.fill\")"))
        #expect(source.contains("_ = revealedSections.insert(section)"))
        #expect(source.contains("proxy.scrollTo(section, anchor: .top)"))
        #expect(source.contains(".frame(maxWidth: .infinity, minHeight: 44"))
        #expect(source.contains(".contentShape(.rect)"))
        #expect(!source.contains("isShowingMoreDetails.toggle()"))
    }

    @Test
    func tagsKeepSuggestionsBoundedAndBrowseTheFullCatalogInASearchablePicker() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSOrganizationSection.swift"
        )
        let tagChips = try Self.sourceSection(
            startingAt: "private var tagChipsContent",
            endingAt: "private var browseTagsButton",
            in: source
        )

        #expect(source.contains("ForEach(visibleAvailableTags, id: \\.self)"))
        #expect(!source.contains("ForEach(unselectedAvailableTags, id: \\.self)"))
        #expect(source.contains("Label(\"Browse all tags\", systemImage: \"magnifyingglass\")"))
        #expect(source.contains("struct TaskFormIOSTagPicker"))
        #expect(source.contains("@State private var displayedTags: [String] = []"))
        #expect(source.contains(".searchable(text: $searchText, prompt: \"Search tags\")"))
        #expect(source.contains(".onChange(of: searchText)"))
        #expect(source.contains("displayedTags = availableTags.filter"))
        #expect(source.contains("let remainingTagCount: Int"))
        #expect(!source.contains("let remainingTags: [String]"))
        #expect(tagChips.contains("HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8)"))
        #expect(!tagChips.contains("GridItem(.adaptive(minimum: 90)"))
    }

    @Test
    func filterTagsUseTheTaskTagPickerSelectionPatternWithoutDuplicateRows() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Home/HomeTagFilterPickerSheet.swift"
        )

        #expect(source.contains(".navigationBarTitleDisplayMode(.large)"))
        #expect(source.contains("selectedRule?.selectedSymbol ?? \"plus.circle\""))
        #expect(source.contains("switch selectedRule ?? rule"))
        #expect(source.contains("displayedTagSummaries = selected + unselected"))
        #expect(source.contains("displayedTagSummaries = selected + unselected.filter"))
        #expect(!source.contains("Section(\"Selected tags\")"))
        #expect(!source.contains(".presentationDetents([.medium, .large])"))
    }

    @Test
    func filterTagEntryWrapsAndNamesEverySelectedTag() throws {
        let tagFilter = try Self.sourceSection(
            startingAt: "struct HomeFiltersTagFilterEntrySection",
            endingAt: "struct HomeTagFilterPickerSheet",
            in: try Self.sourceFile("iOS/Screens/Home/HomeTagFilterPickerSheet.swift")
        )
        let detailEntry = try Self.sourceSection(
            startingAt: "struct HomeFiltersDetailEntry",
            endingAt: "struct HomeFiltersPickerEntry",
            in: try Self.sourceFile("iOS/Screens/Home/HomeFiltersListSections.swift")
        )

        #expect(tagFilter.contains("allowsMultilineValue: true"))
        #expect(tagFilter.contains("names.map { \"#\\($0)\" }.joined(separator: \", \")"))
        #expect(!tagFilter.contains("remainingCount"))
        #expect(!tagFilter.contains("suffix"))
        #expect(detailEntry.contains(".lineLimit(allowsMultilineValue ? nil : 1)"))
        #expect(detailEntry.contains(".fixedSize(horizontal: false, vertical: allowsMultilineValue)"))
    }

    @Test
    func flagsUseIntrinsicWidthBeforeWrappingInTaskForms() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSOrganizationSection.swift"
        )
        let flagEditor = try Self.sourceSection(
            startingAt: "private var flagEditor",
            endingAt: "private var unselectedAvailableFlags",
            in: source
        )

        #expect(flagEditor.contains("HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8)"))
        #expect(!flagEditor.contains("LazyVGrid"))
        #expect(!flagEditor.contains("GridItem(.adaptive(minimum: 90)"))
    }

    @Test
    func tagPickerPresentationIsOwnedByTheStableFormRoot() throws {
        let formSource = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let tagsSource = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSOrganizationSection.swift"
        )

        #expect(formSource.contains("@State private var isTagPickerPresented = false"))
        #expect(formSource.contains(".sheet(isPresented: $isTagPickerPresented)"))
        #expect(formSource.contains("isTagPickerPresented: $isTagPickerPresented"))
        #expect(tagsSource.contains("@Binding var isTagPickerPresented: Bool"))
        #expect(!tagsSource.contains(".sheet(isPresented: $isTagPickerPresented)"))
    }

    @Test
    func taskLadderValuesShareOneIOSSectionWithIndependentControlsAndTimeRules() throws {
        let formSections = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSSections.swift"
        )
        let formValuesSection = try Self.sourceSection(
            startingAt: "struct TaskFormIOSTaskLadderValuesSection",
            endingAt: "struct TaskFormIOSScheduleTypeSection",
            in: formSections
        )
        let homeFilters = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersListSections.swift"
        )
        let homePriorityEntries = try Self.sourceSection(
            startingAt: "struct HomeFiltersImportanceUrgencyEntries",
            endingAt: "struct HomeFiltersImportancePickerSheet",
            in: homeFilters
        )
        let homeFilterSheet = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersSheetView.swift"
        )

        #expect(formValuesSection.contains("Section(header: Text(\"Task Ladder values\"))"))
        #expect(formValuesSection.contains("TaskTemporalWeightRuleEditor("))
        #expect(formValuesSection.contains("importance: model.importance"))
        #expect(formValuesSection.contains("urgency: model.urgency"))
        #expect(formValuesSection.contains("pressure: model.pressure"))
        #expect(formValuesSection.contains("TaskTemporalThinkingSentenceEditor("))
        #expect(formValuesSection.contains("maximumBeforeDueDays: model.maximumTemporalWeightBeforeDueDays"))
        #expect(formValuesSection.contains("model.temporalWeightAvailabilityMessage"))
        #expect(!formValuesSection.contains("RoutinaGlassSegmentedControl"))
        #expect(!formValuesSection.contains("ImportanceUrgencyMatrixPicker"))
        #expect(!formValuesSection.contains(".sheet("))
        #expect(!formSections.contains("TaskFormIOSPriorityPickerSheet"))

        #expect(homePriorityEntries.contains("title: \"Importance\""))
        #expect(homePriorityEntries.contains("destination: .importance"))
        #expect(homePriorityEntries.contains("title: \"Urgency\""))
        #expect(homePriorityEntries.contains("destination: .urgency"))
        #expect(!homePriorityEntries.contains("ImportanceUrgencyMatrixPicker"))
        #expect(homeFilters.contains("struct HomeFiltersImportancePickerSheet"))
        #expect(homeFilters.contains("struct HomeFiltersUrgencyPickerSheet"))
        #expect(homeFilterSheet.contains("Section(\"Priority\")"))
        #expect(homeFilterSheet.contains("case .importance:"))
        #expect(homeFilterSheet.contains("HomeFiltersImportancePickerSheet("))
        #expect(homeFilterSheet.contains("case .urgency:"))
        #expect(homeFilterSheet.contains("HomeFiltersUrgencyPickerSheet("))
    }

    @Test
    func organizationKeepsPathTagsFlagsAndTaskLadderGroupTogether() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSOrganizationSection.swift"
        )

        #expect(source.contains("struct TaskFormIOSOrganizationSection"))
        #expect(source.contains("Section(header: Text(\"Organization\"))"))
        #expect(source.contains("Picker(\"Path\""))
        #expect(source.contains("Text(\"Tags\")"))
        #expect(source.contains("Text(\"Flags\")"))
        #expect(source.contains("Toggle(\"Use as Task Ladder group\""))
    }

    @Test
    func homeGroupingSortingAndFlagsOpenInDedicatedSheets() throws {
        let filterSections = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersListSections.swift"
        )
        let groupingSection = try Self.sourceSection(
            startingAt: "struct HomeFiltersGroupingSection",
            endingAt: "struct HomeFiltersCreatedSection",
            in: filterSections
        )
        let sortSection = try Self.sourceSection(
            startingAt: "struct HomeFiltersSortSection",
            endingAt: "struct HomeFiltersDetailEntry",
            in: filterSections
        )
        let flagSection = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersFlagSection.swift"
        )

        let homeFilterSheet = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersSheetView.swift"
        )

        #expect(groupingSection.contains("onPresent(.grouping)"))
        #expect(!groupingSection.contains(".sheet("))
        #expect(!groupingSection.contains(".pickerStyle(.inline)"))
        #expect(homeFilterSheet.contains("case .grouping:"))
        #expect(homeFilterSheet.contains("HomeFiltersGroupingPickerSheet("))

        #expect(sortSection.contains("onPresent(.sort)"))
        #expect(!sortSection.contains(".sheet("))
        #expect(!sortSection.contains(".pickerStyle(.inline)"))
        #expect(homeFilterSheet.contains("case .sort:"))
        #expect(homeFilterSheet.contains("HomeFiltersSortPickerSheet("))
        #expect(filterSections.contains(".frame(maxWidth: .infinity, minHeight: 44"))

        #expect(flagSection.contains("onPresent(.flags)"))
        #expect(!flagSection.contains(".sheet("))
        #expect(homeFilterSheet.contains("case .flags:"))
        #expect(homeFilterSheet.contains("HomeFiltersFlagPickerSheet("))
        #expect(flagSection.contains("@State private var displayedFlagOptions"))
        #expect(flagSection.contains("Section(\"Selected flags\")"))
        #expect(flagSection.contains(".searchable(text: $searchText, prompt: \"Search flags\")"))
        #expect(flagSection.contains("refreshDisplayedFlagOptions"))
        #expect(!flagSection.contains("HomeFilterFlowLayout"))
    }

    @Test
    func allHomeFilterControlsUsePersistentDedicatedSheets() throws {
        let filterSections = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersListSections.swift"
        )
        let filterSheet = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersSheetView.swift"
        )

        for destination in [
            "advancedQuery",
            "homeTaskType",
            "visibility",
            "created",
            "status",
            "todoState",
            "importance",
            "urgency",
            "pressure",
            "thinkingNeeded",
            "goal",
            "media",
            "estimation",
            "place"
        ] {
            #expect(filterSections.contains("destination: .\(destination)"))
        }

        #expect(!filterSections.contains("sectionTitle:"))
        #expect(!filterSections.contains("Section(\"Group\")"))
        #expect(!filterSections.contains("Section(\"Sort\")"))
        #expect(filterSheet.contains("Section(\"Priority\")"))
        #expect(filterSheet.contains("HomeFiltersImportanceUrgencyEntries("))
        #expect(filterSheet.contains("HomeFiltersPressureSection("))
        #expect(filterSheet.contains("HomeFiltersThinkingNeededSection("))
        #expect(filterSheet.contains("@State private var presentedDetail: IOSFilterDetailDestination?"))
        #expect(filterSheet.contains(".sheet(item: $presentedDetail, content: detailSheet)"))
        #expect(filterSheet.contains("private func detailSheet("))
        #expect(!filterSections.contains(".sheet(isPresented:"))
    }

    @Test
    func statsAndTimelineFilterControlsUseDedicatedSheets() throws {
        let statsFilters = try Self.sourceFile("iOS/Screens/Stats/StatsFilterViews.swift")
        let timeline = try Self.sourceFile("iOS/Screens/Timeline/TimelineView.swift")

        #expect(statsFilters.contains("destination: .advancedQuery"))
        #expect(statsFilters.contains("destination: .statsTaskType"))
        #expect(statsFilters.contains("Section(\"Priority\")"))
        #expect(statsFilters.contains("HomeFiltersImportanceUrgencyEntries("))
        #expect(!statsFilters.contains("sectionTitle:"))
        #expect(statsFilters.contains("HomeFiltersTagFilterEntrySection"))
        #expect(!statsFilters.contains("HomeFiltersTagRulesSection("))
        #expect(statsFilters.contains("@State private var presentedDetail: IOSFilterDetailDestination?"))
        #expect(statsFilters.contains(".sheet(item: $presentedDetail, content: detailSheet)"))
        #expect(statsFilters.contains("case .tags:"))

        #expect(timeline.contains("destination: .timelineRange"))
        #expect(timeline.contains("destination: .timelineType"))
        #expect(timeline.contains("Section(\"Priority\")"))
        #expect(timeline.contains("HomeFiltersImportanceUrgencyEntries("))
        #expect(!timeline.contains("sectionTitle:"))
        #expect(timeline.contains("HomeFiltersMediaSection(\n                    selectedMediaFilter: mediaFilterBinding,"))
        #expect(timeline.contains("HomeFiltersTagFilterEntrySection"))
        #expect(!timeline.contains("HomeFiltersTagRulesSection("))
        #expect(timeline.contains("@State private var presentedFilterDetail: IOSFilterDetailDestination?"))
        #expect(timeline.contains(".sheet(item: $presentedFilterDetail, content: timelineFilterDetailSheet)"))
        #expect(timeline.contains("case .tags:\n            HomeTagFilterPickerSheet("))
    }

    @Test
    func iosFilterListsDoNotRepeatNavigationOrEntryTitles() throws {
        let filterSections = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersListSections.swift"
        )
        let homeFilterSheet = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersSheetView.swift"
        )
        let tagFilter = try Self.sourceSection(
            startingAt: "struct HomeFiltersTagFilterEntrySection",
            endingAt: "struct HomeTagFilterPickerSheet",
            in: try Self.sourceFile("iOS/Screens/Home/HomeTagFilterPickerSheet.swift")
        )
        let flagFilter = try Self.sourceSection(
            startingAt: "struct HomeFiltersFlagSection",
            endingAt: "struct HomeFiltersFlagPickerSheet",
            in: try Self.sourceFile("iOS/Screens/Home/HomeFiltersFlagSection.swift")
        )
        let mediaDetail = try Self.sourceSection(
            startingAt: "case .media:",
            endingAt: "case .estimation:",
            in: homeFilterSheet
        )

        #expect(!filterSections.contains("Section(sectionTitle)"))
        #expect(!tagFilter.contains("Section(\"Tags\")"))
        #expect(!flagFilter.contains("Section(\"Flags\")"))
        #expect(mediaDetail.contains(".labelsHidden()"))
    }

    @Test
    func homeFiltersHideGoalsWhenTheGoalsFeatureIsDisabled() throws {
        let home = try Self.sourceFile("iOS/Screens/Home/HomeTCAView.swift")
        let platform = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let configuration = try Self.sourceFile(
            "iOS/Screens/Home/HomeFiltersSheetConfiguration.swift"
        )
        let filters = try Self.sourceFile("iOS/Screens/Home/HomeFiltersSheetView.swift")

        #expect(home.contains("UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue"))
        #expect(home.contains("var isGoalsEnabled = false"))
        #expect(configuration.contains("let isGoalsEnabled: Bool"))
        #expect(platform.contains("isGoalsEnabled: isGoalsEnabled"))
        #expect(filters.contains("if configuration.isGoalsEnabled {\n                    HomeFiltersGoalSection("))
    }

    @Test
    func addTaskHidesGoalsWhenTheGoalsFeatureIsDisabled() throws {
        let source = try Self.sourceFile("iOS/Screens/Shared/TaskFormContentPlatform.swift")
        let sectionFiltering = try Self.sourceSection(
            startingAt: "private func filteredCompactSections(",
            endingAt: "private func reveal(",
            in: source
        )

        #expect(source.contains("UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue"))
        #expect(source.contains("private var isGoalsTabEnabled = false"))
        #expect(sectionFiltering.contains("case .goals:\n                return isGoalsTabEnabled"))
    }

    @Test
    func descriptionIsIndependentFromExperimentalNotesAndSupportsTargetedReveal() throws {
        let formSource = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let textSource = try Self.sourceFile(
            "iOS/Screens/Shared/TaskFormIOSTextSections.swift"
        )
        let detailSource = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailTCAView.swift"
        )

        #expect(textSource.contains("struct TaskFormIOSDescriptionSection"))
        #expect(formSource.contains("case .taskDescription:\n            taskDescriptionSection"))
        #expect(formSource.contains("_revealedSections = State(initialValue: model.initiallyRevealedCompactSections)"))
        #expect(formSource.contains("case .notes, .voiceNote:\n                return isNotesEnabled"))
        #expect(detailSource.contains("requestedEditSection = .taskDescription"))
        #expect(detailSource.contains("taskDescription: store.task.taskDescription"))
    }

    @Test
    func linkTaskPickerKeepsDesktopMinimumSizeOutOfIOSSheets() throws {
        let source = try Self.sourceFile(
            "SharedCore/Views/TaskRelationshipsEditor.swift"
        )
        let picker = try Self.sourceSection(
            startingAt: "struct TaskRelationshipPickerSheet",
            endingAt: "private var taskSearchField",
            in: source
        )

        #expect(picker.contains("#if os(macOS)\n            .frame(minWidth: 520, minHeight: 420)\n#endif"))
    }

    private static func sourceSection(
        startingAt startMarker: String,
        endingAt endMarker: String,
        in source: String
    ) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(
            source.range(
                of: endMarker,
                range: start.upperBound..<source.endIndex
            )
        )
        return String(source[start.lowerBound..<end.lowerBound])
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
