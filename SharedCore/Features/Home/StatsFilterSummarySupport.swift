import Foundation

enum StatsFilterSummarySupport {
    static func trimmedAdvancedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func hasActiveSheetFilters(
        taskTypeFilter: StatsTaskTypeFilter,
        advancedQuery: String,
        selectedTags: Set<String>,
        excludedTags: Set<String>,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    ) -> Bool {
        taskTypeFilter != .all
            || !trimmedAdvancedQuery(advancedQuery).isEmpty
            || !selectedTags.isEmpty
            || !excludedTags.isEmpty
            || selectedImportanceUrgencyFilter != nil
    }

    static func activeSheetFilterCount(
        taskTypeFilter: StatsTaskTypeFilter,
        advancedQuery: String,
        selectedTags: Set<String>,
        excludedTags: Set<String>,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    ) -> Int {
        var count = 0
        if taskTypeFilter != .all { count += 1 }
        if !trimmedAdvancedQuery(advancedQuery).isEmpty { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        count += excludedTags.count
        if selectedImportanceUrgencyFilter != nil { count += 1 }
        return count
    }

    static func excludedTagSummary(excludedTags: Set<String>) -> String {
        if !excludedTags.isEmpty {
            return "Hiding tasks tagged: \(excludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }
        return "Select tags to hide tasks that have them."
    }

    static func tagSelectionSummary(
        selectedTags: Set<String>,
        includeTagMatchMode: RoutineTagMatchMode,
        tagCount: Int
    ) -> String {
        if !selectedTags.isEmpty {
            return "\(includeTagMatchMode.rawValue) of \(selectedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }
        return "\(tagCount) \(tagCount == 1 ? "tag" : "tags") available"
    }
}
