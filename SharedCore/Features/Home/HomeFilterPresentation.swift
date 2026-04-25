import Foundation

enum HomeFilterTaskListKind: Equatable, Sendable {
    case all
    case routines
    case todos

    var placeFilterPluralNoun: String {
        switch self {
        case .all:
            return "tasks"
        case .routines:
            return "routines"
        case .todos:
            return "todos"
        }
    }

    var placeFilterAllTitle: String {
        switch self {
        case .all:
            return "All tasks"
        case .routines:
            return "All routines"
        case .todos:
            return "All todos"
        }
    }
}

struct HomeFilterPresentation: Equatable, Sendable {
    let taskListKind: HomeFilterTaskListKind
    let selectedFilter: RoutineListFilter
    let advancedQuery: String
    let taskListViewMode: HomeTaskListViewMode
    let selectedTodoStateFilter: TodoState?
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let selectedPlaceName: String?
    let hasSelectedPlaceFilter: Bool
    let selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let selectedPressureFilter: RoutineTaskPressure?
    let hideUnavailableRoutines: Bool
    let hasSavedPlaces: Bool
    let awayRoutineCount: Int
    let locationAuthorizationStatus: LocationAuthorizationStatus

    init(
        taskListKind: HomeFilterTaskListKind,
        selectedFilter: RoutineListFilter = .all,
        advancedQuery: String = "",
        taskListViewMode: HomeTaskListViewMode = .all,
        selectedTodoStateFilter: TodoState? = nil,
        selectedTags: Set<String> = [],
        includeTagMatchMode: RoutineTagMatchMode = .all,
        excludedTags: Set<String> = [],
        selectedPlaceName: String? = nil,
        hasSelectedPlaceFilter: Bool = false,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        selectedPressureFilter: RoutineTaskPressure? = nil,
        hideUnavailableRoutines: Bool = false,
        hasSavedPlaces: Bool = false,
        awayRoutineCount: Int = 0,
        locationAuthorizationStatus: LocationAuthorizationStatus = .notDetermined
    ) {
        self.taskListKind = taskListKind
        self.selectedFilter = selectedFilter
        self.advancedQuery = advancedQuery
        self.taskListViewMode = taskListViewMode
        self.selectedTodoStateFilter = selectedTodoStateFilter
        self.selectedTags = selectedTags
        self.includeTagMatchMode = includeTagMatchMode
        self.excludedTags = excludedTags
        self.selectedPlaceName = selectedPlaceName
        self.hasSelectedPlaceFilter = hasSelectedPlaceFilter
        self.selectedImportanceUrgencyFilter = selectedImportanceUrgencyFilter
        self.selectedPressureFilter = selectedPressureFilter
        self.hideUnavailableRoutines = hideUnavailableRoutines
        self.hasSavedPlaces = hasSavedPlaces
        self.awayRoutineCount = awayRoutineCount
        self.locationAuthorizationStatus = locationAuthorizationStatus
    }

    var activeOptionalFilterCount: Int {
        var count = 0
        if !selectedTags.isEmpty { count += 1 }
        count += excludedTags.count
        if hasSelectedPlaceFilter { count += 1 }
        if selectedImportanceUrgencyFilter != nil { count += 1 }
        if selectedTodoStateFilter != nil { count += 1 }
        if selectedPressureFilter != nil { count += 1 }
        if !advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { count += 1 }
        if taskListViewMode != .all { count += 1 }
        if hideUnavailableRoutines { count += 1 }
        return count
    }

    var hasActiveOptionalFilters: Bool {
        activeOptionalFilterCount > 0
    }

    var filterLabels: [String] {
        var labels: [String] = []

        if selectedFilter != .all {
            labels.append(selectedFilter.rawValue)
        }

        if taskListViewMode != .all {
            labels.append(taskListViewMode.title)
        }

        if let selectedTodoStateFilter {
            labels.append(selectedTodoStateFilter.displayTitle)
        }

        if let selectedPressureFilter {
            labels.append("Pressure \(selectedPressureFilter.title)")
        }

        let trimmedAdvancedQuery = advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAdvancedQuery.isEmpty {
            labels.append("Query \(trimmedAdvancedQuery)")
        }

        if !selectedTags.isEmpty {
            labels.append("\(includeTagMatchMode.rawValue) \(selectedTags.count) tags")
        }

        if !excludedTags.isEmpty {
            if excludedTags.count == 1, let tag = excludedTags.first {
                labels.append("not #\(tag)")
            } else {
                labels.append("not \(excludedTags.count) tags")
            }
        }

        if let selectedPlaceName {
            labels.append(selectedPlaceName)
        }

        if let selectedImportanceUrgencyFilterLabel {
            labels.append(selectedImportanceUrgencyFilterLabel)
        }

        if hideUnavailableRoutines {
            labels.append("Away hidden")
        }

        return labels
    }

    var placeFilterPluralNoun: String {
        taskListKind.placeFilterPluralNoun
    }

    var placeFilterAllTitle: String {
        taskListKind.placeFilterAllTitle
    }

    var manualPlaceFilterDescription: String {
        guard let selectedPlaceName else {
            return "Choose a saved place to show only \(placeFilterPluralNoun) linked to that place."
        }
        return "Showing only \(placeFilterPluralNoun) linked to \(selectedPlaceName)."
    }

    var placeFilterSectionDescription: String {
        if hasSavedPlaces {
            return manualPlaceFilterDescription
        }
        return "Save a place in Settings, then link it to a task to filter by place here."
    }

    var selectedImportanceUrgencyFilterLabel: String? {
        guard let selectedImportanceUrgencyFilter else { return nil }
        return "\(selectedImportanceUrgencyFilter.importance.shortTitle)/\(selectedImportanceUrgencyFilter.urgency.shortTitle)+"
    }

    var importanceUrgencyFilterSummary: String {
        guard let selectedImportanceUrgencyFilter else {
            return "Choose a cell to show tasks that meet or exceed that importance and urgency."
        }
        return "Showing tasks with at least \(selectedImportanceUrgencyFilter.importance.title.lowercased()) importance and \(selectedImportanceUrgencyFilter.urgency.title.lowercased()) urgency."
    }

    var locationStatusText: String {
        switch locationAuthorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if awayRoutineCount == 0 {
                return "All place-linked routines are currently available."
            }
            if hideUnavailableRoutines {
                return "\(awayRoutineCount) routines are hidden because you are away from their saved place."
            }
            return "\(awayRoutineCount) routines are away from their saved place and shown below."
        case .notDetermined:
            return "Allow location access to automatically separate place-based routines. Until then they stay visible."
        case .disabled:
            return "Location services are disabled on this device, so place-based routines stay visible."
        case .restricted, .denied:
            return "Location access is off, so place-based routines stay visible."
        }
    }

    func activeTaskFiltersSummary(resultCount: Int, maxVisibleCount: Int) -> String? {
        let summary = Self.summarizedFilterLabels(from: filterLabels, maxVisibleCount: maxVisibleCount)
        return Self.summaryWithResultCount(summary, resultCount: resultCount)
    }

    static func summarizedFilterLabels(from labels: [String], maxVisibleCount: Int) -> String {
        guard !labels.isEmpty else { return "" }
        let visibleLabels = Array(labels.prefix(maxVisibleCount))
        let remainderCount = labels.count - visibleLabels.count
        let baseSummary = visibleLabels.joined(separator: " • ")
        guard remainderCount > 0 else { return baseSummary }
        return "\(baseSummary) +\(remainderCount)"
    }

    static func summaryWithResultCount(_ summary: String, resultCount: Int) -> String? {
        guard !summary.isEmpty else { return nil }
        let resultLabel = resultCount == 1 ? "1 result" : "\(resultCount) results"
        return "\(summary) • \(resultLabel)"
    }
}
