import Foundation

enum StatsTaskTypeFilter: String, CaseIterable, Identifiable, Sendable, Equatable, Codable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"
    case records = "Records"

    var id: Self { self }
}

typealias StatsIncludedTagMutation = HomeIncludedTagMutation
typealias StatsTagFilterMutation = HomeExcludedTagMutation

struct StatsFilterPresentation {
    let taskTypeFilter: StatsTaskTypeFilter
    let advancedQuery: String
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let availableTags: [String]
    let relatedTagRules: [RoutineRelatedTagRule]
    let tagColors: [String: String]

    var trimmedAdvancedQuery: String {
        StatsFilterSummarySupport.trimmedAdvancedQuery(advancedQuery)
    }

    var hasActiveSheetFilters: Bool {
        StatsFilterSummarySupport.hasActiveSheetFilters(
            taskTypeFilter: taskTypeFilter,
            advancedQuery: advancedQuery,
            selectedTags: selectedTags,
            excludedTags: excludedTags,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter
        )
    }

    var activeSheetFilterCount: Int {
        StatsFilterSummarySupport.activeSheetFilterCount(
            taskTypeFilter: taskTypeFilter,
            advancedQuery: advancedQuery,
            selectedTags: selectedTags,
            excludedTags: excludedTags,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter
        )
    }

    var excludedTagSummary: String {
        StatsFilterSummarySupport.excludedTagSummary(excludedTags: excludedTags)
    }

    func tagSelectionSummary(tagCount: Int) -> String {
        StatsFilterSummarySupport.tagSelectionSummary(
            selectedTags: selectedTags,
            includeTagMatchMode: includeTagMatchMode,
            tagCount: tagCount
        )
    }

    func suggestedRelatedTags(suggestionAnchor: String?) -> [String] {
        guard !selectedTags.isEmpty else { return [] }
        let source = suggestionAnchor.map { [$0] } ?? Array(selectedTags)
        return RoutineTagRelations.relatedTags(
            for: source,
            rules: relatedTagRules,
            availableTags: availableTags
        )
    }

    func tagRuleData(
        suggestedRelatedTags: [String],
        availableExcludeTags: [String],
        showsTagCounts: Bool = false
    ) -> HomeTagFilterData {
        HomeTagFilterData(
            selectedTags: selectedTags,
            excludedTags: excludedTags,
            tagSummaries: RoutineTagColors.applying(
                tagColors,
                to: availableTags.map { RoutineTagSummary(name: $0, linkedRoutineCount: 0) }
            ),
            allTagTaskCount: 0,
            suggestedRelatedTags: suggestedRelatedTags,
            availableExcludeTagSummaries: RoutineTagColors.applying(
                tagColors,
                to: availableExcludeTags.map { RoutineTagSummary(name: $0, linkedRoutineCount: 0) }
            ),
            showsTagCounts: showsTagCounts
        )
    }

    func taskCountForSelectedTypeFilter(in tasks: [RoutineTask]) -> Int {
        tasksMatchingTaskTypeAndMatrixFilters(in: tasks).count
    }

    func tagSummaries(from tasks: [RoutineTask]) -> [RoutineTagSummary] {
        RoutineTagColors.applying(
            tagColors,
            to: RoutineTag.summaries(from: tasksMatchingTaskTypeAndMatrixFilters(in: tasks))
        )
    }

    func availableExcludeTags(from tasks: [RoutineTask]) -> [String] {
        let baseTasks = tasksMatchingTaskTypeAndMatrixFilters(in: tasks).filter { task in
            HomeDisplayFilterSupport.matchesSelectedTags(
                selectedTags,
                mode: includeTagMatchMode,
                in: task.tags
            )
        }

        return RoutineTag.allTags(from: baseTasks.map(\.tags)).filter { tag in
            !HomeTagFilterMutationSupport.contains(tag, in: selectedTags)
        }
    }

    func toggledIncludedTag(
        _ tag: String,
        currentSuggestionAnchor: String?
    ) -> StatsIncludedTagMutation {
        HomeTagFilterMutationSupport.toggledIncludedTag(
            tag,
            selectedTags: selectedTags,
            suggestionAnchor: currentSuggestionAnchor
        )
    }

    func addedIncludedTag(_ tag: String) -> StatsIncludedTagMutation? {
        HomeTagFilterMutationSupport.addedIncludedTag(
            tag,
            selectedTags: selectedTags,
            suggestionAnchor: nil
        )
    }

    func toggledExcludedTag(_ tag: String) -> StatsTagFilterMutation {
        HomeTagFilterMutationSupport.toggledExcludedTag(
            tag,
            selectedTags: selectedTags,
            excludedTags: excludedTags
        )
    }

    private func tasksMatchingTaskTypeAndMatrixFilters(in tasks: [RoutineTask]) -> [RoutineTask] {
        StatsTaskTypeMatrixFilterSupport.filteredTasks(
            tasks,
            taskTypeFilter: taskTypeFilter,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell.normalized(selectedImportanceUrgencyFilter)
        )
    }
}
