import SwiftUI

extension HomeTCAView {
    var macStatsSidebarView: some View {
        HomeMacStatsSidebarView(
            selectedTaskTypeFilter: statsStore?.taskTypeFilter ?? .all,
            onSelectTaskTypeFilter: { filter in
                statsStore?.send(.taskTypeFilterChanged(filter))
            },
            selectedRange: statsStore?.selectedRange ?? .week,
            onSelectRange: { range in
                statsStore?.send(.selectedRangeChanged(range))
            },
            advancedQuery: Binding(
                get: { statsStore?.advancedQuery ?? "" },
                set: { statsStore?.send(.advancedQueryChanged($0)) }
            ),
            queryOptions: HomeAdvancedQueryOptions(
                tags: statsAllTags,
                places: []
            ),
            selectedImportanceUrgencyFilter: Binding(
                get: { statsStore?.selectedImportanceUrgencyFilter },
                set: { statsStore?.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            importanceUrgencySummary: statsImportanceUrgencySummary,
            allTags: statsAllTags,
            tagSummaries: statsTagSummaries,
            suggestedRelatedTags: suggestedRelatedStatsTags,
            taskCountForSelectedTypeFilter: statsTaskCountForSelectedTypeFilter,
            selectedTags: selectedStatsTags,
            includeTagMatchMode: statsStore?.includeTagMatchMode ?? .all,
            onSelectTags: { tags in
                relatedStatsTagSuggestionAnchor = tags.sorted().last
                statsStore?.send(.selectedTagsChanged(tags))
            },
            onIncludeTagMatchModeChange: { mode in
                statsStore?.send(.includeTagMatchModeChanged(mode))
            },
            onSelectSuggestedTag: { tag in
                guard let mutation = statsFilterPresentation.addedIncludedTag(tag) else { return }
                statsStore?.send(.selectedTagsChanged(mutation.selectedTags))
            },
            selectedExcludedTags: selectedStatsExcludedTags,
            excludeTagMatchMode: statsStore?.excludeTagMatchMode ?? .any,
            onExcludeTagMatchModeChange: { mode in
                statsStore?.send(.excludeTagMatchModeChanged(mode))
            },
            availableExcludeTags: statsAvailableExcludeTags,
            excludedTagSummary: statsExcludedTagSummary,
            tagSelectionSummary: statsTagSelectionSummary,
            tagCount: { tag in
                statsTagCount(for: tag)
            },
            onToggleExcludedTag: { tag in
                let mutation = statsFilterPresentation.toggledExcludedTag(tag)
                statsStore?.send(.selectedTagsChanged(mutation.selectedTags))
                statsStore?.send(.excludedTagsChanged(mutation.excludedTags))
            }
        )
    }

    private var statsFilterPresentation: StatsFilterPresentation {
        StatsFilterPresentation(
            taskTypeFilter: statsStore?.taskTypeFilter ?? .all,
            advancedQuery: statsStore?.advancedQuery ?? "",
            selectedTags: selectedStatsTags,
            includeTagMatchMode: statsStore?.includeTagMatchMode ?? .all,
            excludedTags: selectedStatsExcludedTags,
            excludeTagMatchMode: statsStore?.excludeTagMatchMode ?? .any,
            selectedImportanceUrgencyFilter: statsStore?.selectedImportanceUrgencyFilter,
            availableTags: statsAllTags,
            relatedTagRules: store.relatedTagRules,
            tagColors: store.tagColors
        )
    }

    private var statsAllTags: [String] {
        if let statsStore {
            return statsStore.availableTags
        }

        var seen = Set<String>()
        var result: [String] = []
        for task in store.routineTasks {
            for tag in task.tags where !seen.contains(tag) {
                seen.insert(tag)
                result.append(tag)
            }
        }
        return result.sorted()
    }

    private var suggestedRelatedStatsTags: [String] {
        statsFilterPresentation.suggestedRelatedTags(
            suggestionAnchor: relatedStatsTagSuggestionAnchor
        )
    }

    private var statsTagSummaries: [RoutineTagSummary] {
        statsFilterPresentation.tagSummaries(from: statsStore?.tasks ?? store.routineTasks)
    }

    private var statsTaskCountForSelectedTypeFilter: Int {
        statsFilterPresentation.taskCountForSelectedTypeFilter(in: statsStore?.tasks ?? store.routineTasks)
    }

    private var selectedStatsTag: String? {
        statsStore?.selectedTag
    }

    private var selectedStatsTags: Set<String> {
        statsStore?.effectiveSelectedTags ?? []
    }

    private var selectedStatsExcludedTags: Set<String> {
        statsStore?.excludedTags ?? []
    }

    private var statsTagSelectionSummary: String {
        statsFilterPresentation.tagSelectionSummary(tagCount: statsTagSummaries.count)
    }

    private var statsAvailableExcludeTags: [String] {
        statsFilterPresentation.availableExcludeTags(from: statsStore?.tasks ?? store.routineTasks)
    }

    private var statsExcludedTagSummary: String {
        statsFilterPresentation.excludedTagSummary
    }

    private var statsImportanceUrgencySummary: String {
        guard let filter = statsStore?.selectedImportanceUrgencyFilter else {
            return "Choose a cell to show stats only for tasks that meet or exceed that importance and urgency."
        }
        return "Showing stats for tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    private func statsTagCount(for tag: String) -> Int {
        statsTagSummaries.first(where: { RoutineTag.contains(tag, in: [$0.name]) })?.linkedRoutineCount ?? 0
    }
}
