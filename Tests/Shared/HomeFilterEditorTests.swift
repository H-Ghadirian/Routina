import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct HomeFilterEditorTests {
    @Test
    func advancedQueryInputSuggestsAndCommitsAtomicTokens() {
        let state = HomeAdvancedQueryInputState(query: "pressure:>lo")

        #expect(state.primarySuggestion?.token == "Low")
        #expect(state.primaryGhostSuffix == "w")
        #expect(state.accepting(state.primarySuggestion!) == "pressure:>low ")
        #expect(HomeAdvancedQueryInputState(query: "pressure:>lo ").normalizingCommittedAtomicTokens() == "pressure:>low ")
    }

    @Test
    func advancedQueryInputRemovesCommittedTokenBlocks() {
        let state = HomeAdvancedQueryInputState(query: "pressure:>low tag:work ")

        #expect(state.tokens == ["pressure:>low", "tag:work"])
        #expect(state.removingToken(at: 0) == "tag:work ")
    }

    @Test
    func advancedQueryInputKeepsOpenFieldSuggestionsEditable() {
        let state = HomeAdvancedQueryInputState(query: "ta")
        let suggestion = state.primarySuggestion!

        #expect(suggestion.token == "tag")
        #expect(state.accepting(suggestion) == "tag")
        #expect(HomeAdvancedQueryInputState(query: "tag").accepting(HomeAdvancedQueryInputState(query: "tag").suggestions[0]) == "tag:")
        #expect(HomeAdvancedQueryInputState(query: "tag:").tokens.isEmpty)
    }

    @Test
    func advancedQueryInputAutoCommitsExactAtomicValues() {
        let state = HomeAdvancedQueryInputState(query: "")

        #expect(state.replacingDraftOrCommittingExactAtomicToken(with: "pressure:medium") == "pressure:medium ")
        #expect(HomeAdvancedQueryInputState(query: "tag").replacingDraftOrCommittingExactAtomicToken(with: "tag:") == "tag:")
    }

    @Test
    func advancedQueryInputSuggestsAndCommitsKnownTagValues() {
        let state = HomeAdvancedQueryInputState(
            query: "tag:fo",
            options: HomeAdvancedQueryOptions(tags: ["Focus", "Deep Work"])
        )

        #expect(state.suggestions.map(\.token).contains("Focus"))
        #expect(HomeAdvancedQueryInputState(query: "tag:", options: state.options).suggestions.map(\.token) == ["Focus", "Deep Work"])
        #expect(state.replacingDraftOrCommittingExactAtomicToken(with: "tag:focus") == "tag:focus ")
        #expect(state.committingDraft("tag:unknown") == "tag:unknown")
    }

    @Test
    func advancedQueryInputSuggestsOperatorsSeparatelyFromKeysAndValues() {
        let keyState = HomeAdvancedQueryInputState(query: "pressure")

        #expect(keyState.suggestions.map(\.token).prefix(3) == [":", ">", ">="])
        #expect(keyState.accepting(keyState.suggestions[1]) == "pressure:>")

        let valueState = HomeAdvancedQueryInputState(query: "pressure:>")
        #expect(valueState.suggestions.map(\.token) == ["Low", "Medium", "High"])
        #expect(valueState.accepting(valueState.suggestions[0]) == "pressure:>low ")
    }

    @Test
    func advancedQueryInputSuggestsOperatorsAfterCommittedToken() {
        let state = HomeAdvancedQueryInputState(query: "pressure:>low ")

        #expect(state.suggestions.map(\.token).prefix(2) == ["AND", "OR"])
        #expect(state.accepting(state.suggestions[0]) == "pressure:>low AND ")
    }

    @Test
    func taskFilterMutation_selectedTagKeepsSingleAndSetSelectionInSync() {
        var taskFilters = HomeTaskFiltersState()
        var hideUnavailableRoutines = false

        let result = HomeFilterEditor.apply(
            .selectedTag("Focus"),
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )

        #expect(taskFilters.selectedTag == "Focus")
        #expect(taskFilters.effectiveSelectedTags == ["Focus"])
        #expect(result == HomeFilterMutationResult())
    }

    @Test
    func taskFilterMutation_isFilterSheetPresentedDoesNotRequestPersistence() {
        var taskFilters = HomeTaskFiltersState()
        var hideUnavailableRoutines = false

        let result = HomeFilterEditor.apply(
            .isFilterSheetPresented(true),
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )

        #expect(taskFilters.isFilterSheetPresented)
        #expect(result == HomeFilterMutationResult(shouldPersistTemporaryViewState: false))
    }

    @Test
    func taskFilterMutation_clearOptionalFiltersResetsFiltersAndHiddenPreference() {
        var taskFilters = HomeTaskFiltersState(
            selectedFilter: .doneToday,
            advancedQuery: "tag:work",
            selectedTag: "Focus",
            selectedTags: ["Focus", "Health"],
            includeTagMatchMode: .any,
            excludedTags: ["Admin"],
            excludeTagMatchMode: .all,
            selectedManualPlaceFilterID: UUID(),
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell(importance: .level4, urgency: .level3),
            selectedTodoStateFilter: .blocked,
            selectedPressureFilter: .high,
            taskListViewMode: .actionable,
            taskListSortOrder: .createdNewestFirst,
            createdDateFilter: .today
        )
        var hideUnavailableRoutines = true

        let result = HomeFilterEditor.apply(
            .clearOptionalFilters,
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )

        #expect(taskFilters.selectedFilter == .doneToday)
        #expect(taskFilters.advancedQuery.isEmpty)
        #expect(taskFilters.selectedTag == nil)
        #expect(taskFilters.effectiveSelectedTags.isEmpty)
        #expect(taskFilters.includeTagMatchMode == .all)
        #expect(taskFilters.excludedTags.isEmpty)
        #expect(taskFilters.excludeTagMatchMode == .any)
        #expect(taskFilters.selectedManualPlaceFilterID == nil)
        #expect(taskFilters.selectedImportanceUrgencyFilter == nil)
        #expect(taskFilters.selectedTodoStateFilter == nil)
        #expect(taskFilters.selectedPressureFilter == nil)
        #expect(taskFilters.taskListViewMode == .all)
        #expect(taskFilters.taskListSortOrder == .smart)
        #expect(taskFilters.createdDateFilter == .all)
        #expect(!hideUnavailableRoutines)
        #expect(result.didResetHideUnavailableRoutines)
        #expect(result.shouldPersistTemporaryViewState)
    }

    @Test
    func transitionTaskListModePreservesFullFilterSnapshot() {
        let placeID = UUID()
        var taskFilters = HomeTaskFiltersState(
            selectedFilter: .due,
            advancedQuery: "tag:focus",
            selectedTag: "Focus",
            selectedTags: ["Focus", "Health"],
            includeTagMatchMode: .all,
            excludedTags: ["Admin"],
            excludeTagMatchMode: .all,
            selectedManualPlaceFilterID: placeID,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell(importance: .level3, urgency: .level4),
            selectedTodoStateFilter: .inProgress,
            selectedPressureFilter: .medium,
            taskListViewMode: .actionable,
            taskListSortOrder: .createdOldestFirst,
            createdDateFilter: .last7Days,
            tabFilterSnapshots: [
                "Todos": TabFilterStateManager.Snapshot(
                    selectedTag: "Errands",
                    selectedTags: ["Errands"],
                    includeTagMatchMode: .any,
                    excludedTags: ["Home"],
                    excludeTagMatchMode: .any,
                    selectedFilter: .all,
                    advancedQuery: "type:todo",
                    selectedManualPlaceFilterID: nil,
                    selectedTodoStateFilter: .ready,
                    selectedPressureFilter: RoutineTaskPressure.none,
                    taskListViewMode: .all,
                    taskListSortOrder: .createdNewestFirst,
                    createdDateFilter: .today
                )
            ]
        )
        var hideUnavailableRoutines = true

        let didResetHidden = HomeFilterEditor.transitionTaskListMode(
            from: "Routines",
            to: "Todos",
            taskFilters: &taskFilters,
            hideUnavailableRoutines: &hideUnavailableRoutines
        )

        #expect(!didResetHidden)
        #expect(hideUnavailableRoutines)
        #expect(taskFilters.selectedTag == "Errands")
        #expect(taskFilters.advancedQuery == "type:todo")
        #expect(taskFilters.effectiveSelectedTags == ["Errands"])
        #expect(taskFilters.includeTagMatchMode == .any)
        #expect(taskFilters.excludedTags == ["Home"])
        #expect(taskFilters.excludeTagMatchMode == .any)
        #expect(taskFilters.selectedTodoStateFilter == .ready)
        #expect(taskFilters.selectedPressureFilter == RoutineTaskPressure.none)
        #expect(taskFilters.taskListViewMode == .all)
        #expect(taskFilters.taskListSortOrder == .createdNewestFirst)
        #expect(taskFilters.createdDateFilter == .today)
        #expect(taskFilters.tabFilterSnapshots["Routines"] == TabFilterStateManager.Snapshot(
            selectedTag: "Focus",
            selectedTags: ["Focus", "Health"],
            includeTagMatchMode: .all,
            excludedTags: ["Admin"],
            excludeTagMatchMode: .all,
            selectedFilter: .due,
            advancedQuery: "tag:focus",
            selectedManualPlaceFilterID: placeID,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell(importance: .level3, urgency: .level4),
            selectedTodoStateFilter: .inProgress,
            selectedPressureFilter: .medium,
            taskListViewMode: .actionable,
            taskListSortOrder: .createdOldestFirst,
            createdDateFilter: .last7Days
        ))
    }

    @Test
    func timelineFilterMutation_selectedTagsKeepsLegacySelectedTagInSync() {
        var timelineFilters = HomeTimelineFiltersState()

        HomeFilterEditor.apply(
            .selectedTags(["Writing", "Focus"]),
            timelineFilters: &timelineFilters
        )

        #expect(timelineFilters.effectiveSelectedTags == ["Focus", "Writing"])
        #expect(timelineFilters.selectedTag == "Focus")
    }

    @Test
    func statsFilterMutation_selectedTagsKeepsLegacySelectedTagInSync() {
        var statsFilters = HomeStatsFiltersState()

        HomeFilterEditor.apply(
            .selectedTags(["Health", "Focus"]),
            statsFilters: &statsFilters
        )

        #expect(statsFilters.effectiveSelectedTags == ["Focus", "Health"])
        #expect(statsFilters.selectedTag == "Focus")
    }
}
