import Foundation

enum HomeFilterEditor {
    @discardableResult
    static func transitionTaskListMode(
        from oldModeRawValue: String,
        to newModeRawValue: String,
        taskFilters: inout HomeTaskFiltersState,
        hideUnavailableRoutines: inout Bool
    ) -> Bool {
        taskFilters.tabFilterSnapshots[oldModeRawValue] = taskFilters.currentSnapshot

        let savedSnapshot = taskFilters.tabFilterSnapshots[newModeRawValue]
        taskFilters.apply(snapshot: savedSnapshot ?? .default)

        if savedSnapshot == nil && hideUnavailableRoutines {
            hideUnavailableRoutines = false
            return true
        }

        return false
    }

    @discardableResult
    static func clearOptionalFilters(
        taskFilters: inout HomeTaskFiltersState,
        hideUnavailableRoutines: inout Bool
    ) -> Bool {
        taskFilters.selectedTag = nil
        taskFilters.excludedTags = []
        taskFilters.selectedManualPlaceFilterID = nil
        taskFilters.selectedImportanceUrgencyFilter = nil
        taskFilters.selectedTodoStateFilter = nil
        taskFilters.taskListViewMode = .all

        if hideUnavailableRoutines {
            hideUnavailableRoutines = false
            return true
        }

        return false
    }
}
