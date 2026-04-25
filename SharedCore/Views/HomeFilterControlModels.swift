import Foundation
import SwiftUI

struct HomeFilterBindings {
    let taskListViewMode: Binding<HomeTaskListViewMode>
    let selectedFilter: Binding<RoutineListFilter>
    let selectedTodoStateFilter: Binding<TodoState?>
    let selectedImportanceUrgencyFilter: Binding<ImportanceUrgencyFilterCell?>
    let includeTagMatchMode: Binding<RoutineTagMatchMode>
    let excludeTagMatchMode: Binding<RoutineTagMatchMode>
    let selectedPlaceID: Binding<UUID?>
    let hideUnavailableRoutines: Binding<Bool>

    var tagRules: HomeTagRuleBindings {
        HomeTagRuleBindings(
            includeTagMatchMode: includeTagMatchMode,
            excludeTagMatchMode: excludeTagMatchMode
        )
    }
}

struct HomeTagRuleBindings {
    let includeTagMatchMode: Binding<RoutineTagMatchMode>
    let excludeTagMatchMode: Binding<RoutineTagMatchMode>
}

struct HomeTagFilterData {
    let selectedTags: Set<String>
    let excludedTags: Set<String>
    let tagSummaries: [RoutineTagSummary]
    let allTagTaskCount: Int
    let suggestedRelatedTags: [String]
    let availableExcludeTagSummaries: [RoutineTagSummary]

    var hasTags: Bool {
        !tagSummaries.isEmpty
    }

    func isIncludedTagSelected(_ tag: String) -> Bool {
        selectedTags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    func isExcludedTagSelected(_ tag: String) -> Bool {
        excludedTags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    func linkedTaskCount(for tag: String) -> Int {
        tagSummaries.first { RoutineTag.contains($0.name, in: [tag]) }?.linkedRoutineCount ?? 0
    }
}

struct HomeTagFilterActions {
    let onShowAllTags: () -> Void
    let onToggleIncludedTag: (String) -> Void
    let onAddIncludedTag: (String) -> Void
    let onToggleExcludedTag: (String) -> Void
}

struct HomeTagFilterCoordinator<Display> {
    let support: HomeTagFilterSupport<Display>
    let excludedTags: Set<String>
    let setSelectedTags: (Set<String>) -> Void
    let setExcludedTags: (Set<String>) -> Void
    let setSuggestionAnchor: (String?) -> Void

    var data: HomeTagFilterData {
        HomeTagFilterData(
            selectedTags: support.selectedTags,
            excludedTags: excludedTags,
            tagSummaries: support.tagSummaries,
            allTagTaskCount: support.allTagTaskCount,
            suggestedRelatedTags: support.suggestedRelatedTags,
            availableExcludeTagSummaries: support.availableExcludeTagSummaries
        )
    }

    var actions: HomeTagFilterActions {
        HomeTagFilterActions(
            onShowAllTags: {
                applyIncludedTagMutation(support.clearedIncludedTags())
            },
            onToggleIncludedTag: { tag in
                applyIncludedTagMutation(support.toggledIncludedTag(tag))
            },
            onAddIncludedTag: { tag in
                guard let mutation = support.addedIncludedTag(tag) else { return }
                applyIncludedTagMutation(mutation)
            },
            onToggleExcludedTag: { tag in
                let mutation = support.toggledExcludedTag(tag, excludedTags: excludedTags)
                setSelectedTags(mutation.selectedTags)
                setExcludedTags(mutation.excludedTags)
            }
        )
    }

    private func applyIncludedTagMutation(_ mutation: HomeIncludedTagMutation) {
        setSuggestionAnchor(mutation.suggestionAnchor)
        setSelectedTags(mutation.selectedTags)
    }
}
