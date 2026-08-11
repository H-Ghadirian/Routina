import Foundation
import Testing

@Suite("iOS scrolling performance regression")
struct IOSScrollingPerformanceRegressionTests {
    @Test
    func homeUsesCachedPresentationAndStableTaskIDs() throws {
        let home = try Self.sourceFile("iOS/Screens/Home/HomeTCAView.swift")
        let platform = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let taskList = try Self.sourceFile("iOS/Screens/Home/HomeIOSTaskListView.swift")

        #expect(home.contains(".task(id: taskListPresentationRefreshToken)"))
        #expect(!platform.contains("let presentation = HomeTaskListPresentation.iOS("))
        #expect(taskList.contains("ForEach(group.tasks, id: \\.taskID)"))
        #expect(!taskList.contains("Array(group.tasks.enumerated())"))
        #expect(taskList.contains("@State private var rowNumberCache"))
        #expect(taskList.contains(".task(id: rowNumberCacheInvalidation)"))
        #expect(taskList.contains("HomeIOSTaskListRowNumberCache.make"))
        #expect(!taskList.contains("visibleRowNumberOffsets"))
        #expect(!taskList.contains("section.taskGroups.reduce"))
    }

    @Test
    func searchKeepsInputImmediateWhileDebouncingHomePresentationWork() throws {
        let appView = try Self.sourceFile("iOS/Screens/App/AppView.swift")

        #expect(appView.contains("@State private var appliedSearchText = \"\""))
        #expect(appView.contains("platformSearchHomeView(searchText: $appliedSearchText)"))
        #expect(appView.contains(".searchable(text: $searchText, prompt: \"Search routines and todos\")"))
        #expect(appView.contains(".onChange(of: searchText)"))
        #expect(appView.contains("scheduleSearchPresentationUpdate(for: rawSearchText)"))
        #expect(appView.contains("searchPresentationUpdateTask?.cancel()"))
        #expect(appView.contains("IOSSearchPresentationPolicy.inputDebounce"))
        #expect(appView.contains("guard !rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else"))
        #expect(appView.contains("appliedSearchText = rawSearchText"))
        #expect(appView.contains("guard !Task.isCancelled, searchText == rawSearchText else { return }"))
        #expect(!appView.contains("if store.selectedTab == .search"))
    }

    @Test
    func homeDefersItsTagCatalogUntilTheTagPickerOpens() throws {
        let platform = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let filters = try Self.sourceFile("iOS/Screens/Home/HomeFiltersSheetView.swift")
        let picker = try Self.sourceFile("iOS/Screens/Home/HomeTagFilterPickerSheet.swift")

        #expect(!platform.contains("tagData: homeTagFilterData"))
        #expect(filters.contains("let tagPicker: () -> TagPicker"))
        #expect(filters.contains("HomeFiltersTagFilterEntrySection"))
        #expect(!filters.contains("HomeFiltersTagRulesSection("))
        #expect(picker.contains("@State private var displayedTagSummaries"))
        #expect(picker.contains("@State private var selectedTagSelections"))
        #expect(picker.contains("Section(\"Selected tags\")"))
        #expect(picker.contains("data.excludedTags.isEmpty ? .include : .exclude"))
        #expect(picker.contains(".onChange(of: searchText)"))
        #expect(!picker.contains("ForEach(data.tagSummaries"))
    }

    @Test
    func timelineRowsConsumeCachedRoutingAndLookupArtifacts() throws {
        let feature = try Self.sourceFile("SharedCore/Features/Timeline/TimelineFeature.swift")
        let view = try Self.sourceFile("iOS/Screens/Timeline/TimelineView.swift")

        #expect(feature.contains("var visibleEntriesByID: [UUID: TimelineEntry]"))
        #expect(feature.contains("var noteAttachmentsByNoteID: [UUID: [RoutineNoteAttachment]]"))
        #expect(view.contains(".onChange(of: store.presentationRevision)"))
        #expect(view.contains("selectedTimelineEntryID.flatMap { store.visibleEntriesByID[$0] }"))
        #expect(feature.contains("@ObservationStateIgnored var rowNumberCache"))
        #expect(feature.contains("TimelineLogic.rowNumbersByEntryID"))
        #expect(view.contains("rowNumbersByEntryID[entry.id]"))
        #expect(!view.contains("visibleTimelineEntryIDs"))
        #expect(!view.contains("TimelineLogic.filteredEntries("))
    }

    @Test
    func goalsAndStatsDoNotRebuildWholeCollectionsFromRows() throws {
        let goals = try Self.sourceFile("SharedCore/Features/Goals/GoalsFeature.swift")
        let stats = try Self.sourceFile("iOS/Screens/Stats/StatsView.swift")
        let unassignedCard = try Self.sourceFile("SharedCore/Views/UnassignedFocusSessionsCard.swift")

        #expect(goals.contains("var filteredGoalSnapshot: [GoalDisplay]"))
        #expect(goals.contains("mutating func refreshGoalPresentation()"))
        #expect(goals.contains("var taskSummary: GoalTaskSummary?"))
        #expect(stats.contains("store.availableExcludeTags"))
        #expect(stats.contains("assignableTasks: store.assignableFocusTasks"))
        #expect(!unassignedCard.contains("@Query"))
        #expect(!unassignedCard.contains("FocusSessionSupport.unassignedCompletedSessions"))
    }

    @Test
    func plannerLifecycleUsesItsSnapshotRevisionInsteadOfHistoryTokens() throws {
        let planner = try Self.sourceFile("SharedCore/Views/DayPlanView.swift")

        #expect(planner.contains(".onChange(of: dataRevision)"))
        #expect(planner.contains("dataRevision: dataSnapshotID"))
        #expect(!planner.contains("taskChangeToken"))
        #expect(!planner.contains("focusSessionChangeToken"))
        #expect(!planner.contains("sleepSessionChangeToken"))
        #expect(!planner.contains("awaySessionChangeToken"))
    }

    @Test
    func taskFormsAvoidLiquidGlassAndDuplicateSectionDerivationWhileScrolling() throws {
        let form = try Self.sourceFile("iOS/Screens/Shared/TaskFormContentPlatform.swift")
        let formSections = try Self.sourceFile("iOS/Screens/Shared/TaskFormIOSSections.swift")
        let segmentedControl = try Self.sourceFile("SharedCore/Views/RoutinaLiquidGlass.swift")

        #expect(form.contains("let sectionPresentation = compactSectionPresentation"))
        #expect(form.contains(".routinaSegmentedControlSurfaceStyle(.scrolling)"))
        #expect(!form.contains("private var visibleCompactSections"))
        #expect(segmentedControl.contains("if surfaceStyle == .scrolling"))
        #expect(segmentedControl.contains("RoutinaSegmentedControlSurfaceStyle.glass"))
        #expect(formSections.contains(".routinaScrollingPillFill("))
        #expect(!formSections.contains(".routinaGlassPill(tint: tint, tintOpacity: tintOpacity)"))
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
