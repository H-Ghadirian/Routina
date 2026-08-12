import Foundation
import Testing

@Suite("iOS scrolling performance regression")
struct IOSScrollingPerformanceRegressionTests {
    @Test
    func homeUsesCachedPresentationAndStableTaskIDs() throws {
        let home = try Self.sourceFile("iOS/Screens/Home/HomeTCAView.swift")
        let platform = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let taskList = try Self.sourceFile("iOS/Screens/Home/HomeIOSTaskListView.swift")
        let metadata = try Self.sourceFile("iOS/Screens/Home/HomeTCAView+Metadata.swift")

        #expect(home.contains(".task(id: taskListPresentationRefreshToken)"))
        #expect(home.contains("await refreshTaskListPresentation()"))
        #expect(home.contains("Task.detached(priority: .userInitiated)"))
        #expect(home.contains("withTaskCancellationHandler"))
        #expect(home.contains("guard !Task.isCancelled, let result else { return }"))
        #expect(!platform.contains("let presentation = HomeTaskListPresentation.iOS("))
        #expect(taskList.contains("ForEach(group.tasks, id: \\.taskID)"))
        #expect(!taskList.contains("Array(group.tasks.enumerated())"))
        #expect(taskList.contains("@State private var rowNumberCache"))
        #expect(taskList.contains(".task(id: rowNumberCacheInvalidation)"))
        #expect(taskList.contains("HomeIOSTaskListRowNumberCacheRequest("))
        #expect(taskList.contains("Task.detached(priority: .userInitiated)"))
        #expect(taskList.contains("withTaskCancellationHandler"))
        #expect(taskList.contains("guard !Task.isCancelled, let cache else { return }"))
        #expect(taskList.contains("private struct HomeIOSTaskListRowNumberCacheRequest: @unchecked Sendable"))
        #expect(taskList.contains("guard !Task.isCancelled else { return nil }"))
        #expect(!taskList.contains("visibleRowNumberOffsets"))
        #expect(!taskList.contains("section.taskGroups.reduce"))
        #expect(taskList.contains("ZStack(alignment: .top)"))
        #expect(taskList.contains(".allowsHitTesting(presentation.emptyState == nil)"))
        #expect(taskList.contains(".animation(.easeOut(duration: 0.18), value: presentation.emptyState)"))
        #expect(!taskList.contains("value: presentationRevision"))
        #expect(metadata.contains("referenceDate: Date()"))
        #expect(!metadata.contains("taskListFiltering()"))
    }

    @Test
    func searchKeepsInputImmediateWhileDebouncingHomePresentationWork() throws {
        let appView = try Self.sourceFile("iOS/Screens/App/AppView.swift")

        #expect(appView.contains("@State private var appliedSearchText = \"\""))
        #expect(appView.contains("platformSearchHomeView(searchText: $appliedSearchText)"))
        #expect(appView.contains("platformSearchHomeView(searchText: $appliedSearchText)\n            .searchable(text: $searchText, prompt: \"Search routines and todos\")"))
        #expect(appView.contains(".tabViewSearchActivation(.searchTabSelection)"))
        #expect(!appView.contains("tabView\n            .searchable"))
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
    func activeIOSSurfaceOwnsRefreshWorkAndHomeMaintenanceRunsOnce() throws {
        let appView = try Self.sourceFile("iOS/Screens/App/AppView.swift")
        let appPlatform = try Self.sourceFile("iOS/Screens/App/AppViewPlatform.swift")
        let home = try Self.sourceFile("iOS/Screens/Home/HomeTCAView.swift")
        let homeFeature = try Self.sourceFile("iOS/Features/Home/HomeFeature.swift")
        let homeRefresh = try Self.sourceFile("SharedCore/Screens/Home/HomeTCAView+Refresh.swift")
        let timeline = try Self.sourceFile("iOS/Screens/Timeline/TimelineView.swift")

        #expect(appView.contains("isActive: store.selectedTab == .timeline"))
        #expect(appPlatform.contains("isActive: store.selectedTab == .home"))
        #expect(appPlatform.contains("isActive: store.selectedTab == .search"))
        #expect(home.contains("let isActive: Bool"))
        #expect(home.contains("@State var needsRefreshWhenActive = false"))
        #expect(home.contains("let isActive: Bool\n    let displayRevision"))
        #expect(home.contains("guard isActive else { return }\n                    await refreshTaskListPresentation()"))
        #expect(homeRefresh.contains(".onChange(of: isActive)"))
        #expect(homeRefresh.contains("needsRefreshWhenActive = true"))
        #expect(homeFeature.contains("loadTasksEffect(performingMaintenance: !state.hasLoadedTaskSnapshot)"))
        #expect(homeFeature.contains("private func loadTasksEffect(performingMaintenance: Bool = false)"))
        #expect(timeline.contains("let isActive: Bool"))
        #expect(timeline.contains(".task(id: isActive)"))
        #expect(timeline.contains("guard isActive else { return }\n                refreshTimelineDataSnapshot()"))
    }

    @Test
    func foregroundCloudKitFocusSyncUsesBoundedQueriesAndBatchedTombstones() throws {
        let service = try Self.sourceFile("SharedCore/Sync/CloudKitDirectPullService.swift")
        let fetcher = try Self.sourceFile("SharedCore/Sync/CloudKitDirectPullFetcher.swift")
        let deletionHandler = try Self.sourceFile("SharedCore/Sync/CloudKitDirectPullDeletionHandler.swift")
        let housekeeping = try Self.sourceFile("SharedCore/Sync/CloudKitDirectPullMergeHousekeeping.swift")

        #expect(service.contains("CloudKitDirectPullFetcher.fetchActiveFocusRecords"))
        #expect(service.contains("knownActiveFocusIDs: try activeFocusRecordIDs(in: modelContext)"))
        #expect(service.contains("private static func mergeActiveFocusRecords"))
        #expect(fetcher.contains("recordType: \"CD_FocusSession\""))
        #expect(fetcher.contains("CD_completedAt == nil AND CD_abandonedAt == nil"))
        #expect(fetcher.contains("recordType: \"CD_SprintFocusSessionRecord\""))
        #expect(fetcher.contains("static func fetchActiveFocusRecords"))
        #expect(fetcher.contains("let currentLocalFocusRecords = try await fetchRecords("))
        #expect(fetcher.contains("CKFetchRecordsOperation(recordIDs: cloudRecordIDs)"))
        #expect(deletionHandler.contains("let deletedIDs = Set("))
        #expect(!deletionHandler.contains("for recordID in recordIDs"))
        #expect(deletionHandler.contains("deleteRows(\n                forTaskIDs: deletedTaskIDs"))
        #expect(housekeeping.contains("[CloudKitDirectPullMergeSupport.LogDeduplicationKey: RoutineLog]"))
        #expect(!housekeeping.contains("logs.first(where:"))
    }

    @Test
    func homeDefersItsTagCatalogUntilTheTagPickerOpens() throws {
        let platform = try Self.sourceFile("iOS/Screens/Home/HomeTCAViewPlatform.swift")
        let filters = try Self.sourceFile("iOS/Screens/Home/HomeFiltersSheetView.swift")
        let picker = try Self.sourceFile("iOS/Screens/Home/HomeTagFilterPickerSheet.swift")
        let statsFilters = try Self.sourceFile("iOS/Screens/Stats/StatsFilterViews.swift")
        let stats = try Self.sourceFile("iOS/Screens/Stats/StatsView.swift")
        let timeline = try Self.sourceFile("iOS/Screens/Timeline/TimelineView.swift")

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

        #expect(statsFilters.contains("HomeFiltersTagFilterEntrySection"))
        #expect(!statsFilters.contains("HomeFiltersTagRulesSection("))
        #expect(stats.contains("tagPicker: {\n                HomeTagFilterPickerSheet("))
        #expect(timeline.contains("HomeFiltersTagFilterEntrySection"))
        #expect(!timeline.contains("HomeFiltersTagRulesSection("))
        #expect(timeline.contains("case .tags:\n            HomeTagFilterPickerSheet("))
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
