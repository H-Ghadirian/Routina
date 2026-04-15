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
            selectedImportanceUrgencyFilter: Binding(
                get: { statsStore?.selectedImportanceUrgencyFilter },
                set: { statsStore?.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            importanceUrgencySummary: statsImportanceUrgencySummary,
            allTags: statsAllTags,
            tagSummaries: statsTagSummaries,
            taskCountForSelectedTypeFilter: statsTaskCountForSelectedTypeFilter,
            selectedTag: selectedStatsTag,
            onSelectTag: { tag in
                statsStore?.send(.selectedTagChanged(tag))
            },
            selectedExcludedTags: selectedStatsExcludedTags,
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
                    if selectedStatsTag.map({ RoutineTag.contains($0, in: [tag]) }) == true {
                        statsStore?.send(.selectedTagChanged(nil))
                    }
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

    private var selectedStatsExcludedTags: Set<String> {
        statsStore?.excludedTags ?? []
    }

    private var statsTagSelectionSummary: String {
        if let selectedStatsTag {
            let matchingCount = statsTagSummaries.first(where: { $0.name == selectedStatsTag })?.linkedRoutineCount ?? 0
            return "#\(selectedStatsTag) across \(matchingCount) \(matchingCount == 1 ? "routine" : "routines")"
        }

        let tagCount = statsTagSummaries.count
        return "\(tagCount) \(tagCount == 1 ? "tag" : "tags") available"
    }

    private var statsAvailableExcludeTags: [String] {
        statsAllTags.filter { tag in
            selectedStatsTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
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
