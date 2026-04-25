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
