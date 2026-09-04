import Foundation
import SwiftData

extension HomeFeature {
    @MainActor
    static func detailLogs(taskID: UUID, context: ModelContext) -> [RoutineLog] {
        HomeTaskSupport.detailLogs(taskID: taskID, context: context)
    }

    static func availableTags(from routineDisplays: [RoutineDisplay]) -> [String] {
        HomeRoutineDisplayQuerySupport.availableTags(from: routineDisplays)
    }

    static func tagSummaries(from routineDisplays: [RoutineDisplay]) -> [RoutineTagSummary] {
        HomeRoutineDisplayQuerySupport.tagSummaries(from: routineDisplays)
    }

    static func matchesSelectedTag(_ selectedTag: String?, in tags: [String]) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesSelectedTag(selectedTag, in: tags)
    }

    static func matchesSelectedTags(
        _ selectedTags: Set<String>,
        mode: RoutineTagMatchMode,
        in tags: [String]
    ) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesSelectedTags(selectedTags, mode: mode, in: tags)
    }

    static func matchesExcludedTags(_ excludedTags: Set<String>, in tags: [String]) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesExcludedTags(excludedTags, in: tags)
    }

    static func matchesExcludedTags(
        _ excludedTags: Set<String>,
        mode: RoutineTagMatchMode,
        in tags: [String]
    ) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesExcludedTags(excludedTags, mode: mode, in: tags)
    }

    static func matchesImportanceUrgencyFilter(
        _ selectedFilter: ImportanceUrgencyFilterCell?,
        importance: RoutineTaskImportance,
        urgency: RoutineTaskUrgency
    ) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesImportanceUrgencyFilter(
            selectedFilter,
            importance: importance,
            urgency: urgency
        )
    }

    static func matchesTodoStateFilter(_ filter: TodoState?, task: RoutineDisplay) -> Bool {
        HomeRoutineDisplayQuerySupport.matchesTodoStateFilter(filter, task: task)
    }
}
