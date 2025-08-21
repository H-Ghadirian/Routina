import SwiftUI

extension HomeTCAView {
    var macStatsSidebarView: some View {
        let filterPresentation = statsFilterPresentation
        let statsTasks = statsStore?.tasks ?? store.routineTasks
        let allTags = statsAllTags
        let tagSummaries = statsStore?.tagSummaries ?? filterPresentation.tagSummaries(from: statsTasks)
        let taskCountForSelectedTypeFilter = statsStore?.taskCountForSelectedTypeFilter
            ?? filterPresentation.taskCountForSelectedTypeFilter(in: statsTasks)
        let availableExcludeTags = statsStore?.availableExcludeTags
            ?? filterPresentation.availableExcludeTags(from: statsTasks)
        let tagCountsByNormalizedName = Dictionary(
            uniqueKeysWithValues: tagSummaries.compactMap { summary in
                RoutineTag.normalized(summary.name).map { ($0, summary.linkedRoutineCount) }
            }
        )

        return HomeMacStatsSidebarView(
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
                tags: allTags,
                places: []
            ),
            selectedImportanceUrgencyFilter: Binding(
                get: { statsStore?.selectedImportanceUrgencyFilter },
                set: { statsStore?.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            importanceUrgencySummary: statsImportanceUrgencySummary,
            allTags: allTags,
            tagSummaries: tagSummaries,
            suggestedRelatedTags: filterPresentation.suggestedRelatedTags(
                suggestionAnchor: relatedStatsTagSuggestionAnchor
            ),
            taskCountForSelectedTypeFilter: taskCountForSelectedTypeFilter,
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
                guard let mutation = filterPresentation.addedIncludedTag(tag) else { return }
                statsStore?.send(.selectedTagsChanged(mutation.selectedTags))
            },
            selectedExcludedTags: selectedStatsExcludedTags,
            excludeTagMatchMode: statsStore?.excludeTagMatchMode ?? .any,
            onExcludeTagMatchModeChange: { mode in
                statsStore?.send(.excludeTagMatchModeChanged(mode))
            },
            availableExcludeTags: availableExcludeTags,
            excludedTagSummary: statsExcludedTagSummary,
            tagSelectionSummary: filterPresentation.tagSelectionSummary(tagCount: tagSummaries.count),
            tagCount: { tag in
                guard let normalizedTag = RoutineTag.normalized(tag) else { return 0 }
                return tagCountsByNormalizedName[normalizedTag] ?? 0
            },
            onToggleExcludedTag: { tag in
                let mutation = filterPresentation.toggledExcludedTag(tag)
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

    private var selectedStatsTag: String? {
        statsStore?.selectedTag
    }

    private var selectedStatsTags: Set<String> {
        statsStore?.effectiveSelectedTags ?? []
    }

    private var selectedStatsExcludedTags: Set<String> {
        statsStore?.excludedTags ?? []
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
}
