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
                var selected = selectedStatsTags
                selected.insert(tag)
                statsStore?.send(.selectedTagsChanged(selected))
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
                if selectedStatsExcludedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
                    statsStore?.send(.excludedTagsChanged(selectedStatsExcludedTags.filter { $0 != tag }))
                } else {
                    var newTags = selectedStatsExcludedTags
                    newTags.insert(tag)
                    statsStore?.send(.excludedTagsChanged(newTags))
                    statsStore?.send(.selectedTagsChanged(selectedStatsTags.filter { !RoutineTag.contains($0, in: [tag]) }))
                }
            }
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
        guard !selectedStatsTags.isEmpty else { return [] }
        let suggestionSource = relatedStatsTagSuggestionAnchor.map { [$0] } ?? Array(selectedStatsTags)
        return RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: store.relatedTagRules,
            availableTags: statsAllTags
        )
    }

    private var statsTagSummaries: [RoutineTagSummary] {
        if let statsStore {
            let filteredTasks = statsStore.tasks.filter { task in
                switch statsStore.taskTypeFilter {
                case .all:
                    return true
                case .routines:
                    return !task.isOneOffTask
                case .todos:
                    return task.isOneOffTask
                }
            }.filter { task in
                HomeFeature.matchesImportanceUrgencyFilter(
                    statsStore.selectedImportanceUrgencyFilter,
                    importance: task.importance,
                    urgency: task.urgency
                )
            }
            return RoutineTag.summaries(from: filteredTasks)
        }

        return RoutineTag.summaries(from: store.routineTasks)
    }

    private var statsTaskCountForSelectedTypeFilter: Int {
        if let statsStore {
            return statsStore.tasks.filter { task in
                switch statsStore.taskTypeFilter {
                case .all:
                    return true
                case .routines:
                    return !task.isOneOffTask
                case .todos:
                    return task.isOneOffTask
                }
            }.filter { task in
                HomeFeature.matchesImportanceUrgencyFilter(
                    statsStore.selectedImportanceUrgencyFilter,
                    importance: task.importance,
                    urgency: task.urgency
                )
            }.count
        }

        return store.routineTasks.count
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
        if !selectedStatsTags.isEmpty {
            return "\((statsStore?.includeTagMatchMode ?? .all).rawValue) of \(selectedStatsTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }

        let tagCount = statsTagSummaries.count
        return "\(tagCount) \(tagCount == 1 ? "tag" : "tags") available"
    }

    private var statsAvailableExcludeTags: [String] {
        statsAllTags.filter { tag in
            !selectedStatsTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
    }

    private var statsExcludedTagSummary: String {
        if !selectedStatsExcludedTags.isEmpty {
            return "Hiding tasks tagged: \(selectedStatsExcludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }

        return "Select tags to hide tasks that have them."
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
