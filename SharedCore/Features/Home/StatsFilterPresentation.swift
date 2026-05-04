import Foundation

enum StatsTaskTypeFilter: String, CaseIterable, Identifiable, Sendable, Equatable, Codable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"

    var id: Self { self }
}

struct StatsIncludedTagMutation: Equatable {
    let selectedTags: Set<String>
    let suggestionAnchor: String?
}

struct StatsTagFilterMutation: Equatable {
    let selectedTags: Set<String>
    let excludedTags: Set<String>
}

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
            !selectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
    }

    func toggledIncludedTag(
        _ tag: String,
        currentSuggestionAnchor: String?
    ) -> StatsIncludedTagMutation {
        var selected = selectedTags
        var suggestionAnchor = currentSuggestionAnchor

        if selected.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            selected.insert(tag)
            suggestionAnchor = tag
        }

        if selected.isEmpty {
            suggestionAnchor = nil
        }

        return StatsIncludedTagMutation(
            selectedTags: selected,
            suggestionAnchor: suggestionAnchor
        )
    }

    func addedIncludedTag(_ tag: String) -> StatsIncludedTagMutation? {
        guard !selectedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) else { return nil }
        var selected = selectedTags
        selected.insert(tag)
        return StatsIncludedTagMutation(selectedTags: selected, suggestionAnchor: nil)
    }

    func toggledExcludedTag(_ tag: String) -> StatsTagFilterMutation {
        var excluded = excludedTags
        var selected = selectedTags

        if excluded.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            excluded = excluded.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            excluded.insert(tag)
            selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
        }

        return StatsTagFilterMutation(
            selectedTags: selected,
            excludedTags: excluded
        )
    }

    private func tasksMatchingTaskTypeAndMatrixFilters(in tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.filter { task in
            switch taskTypeFilter {
            case .all:
                return true
            case .routines:
                return !task.isOneOffTask
            case .todos:
                return task.isOneOffTask
            }
        }.filter { task in
            HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
                selectedImportanceUrgencyFilter,
                importance: task.importance,
                urgency: task.urgency
            )
        }
    }
}
