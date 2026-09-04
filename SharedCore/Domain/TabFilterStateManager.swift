import Foundation

enum HomeTaskListViewMode: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all = "All"
    case actionable = "Actionable"

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            return rawValue
        case .actionable:
            return "Don't show blocked tasks"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "list.bullet"
        case .actionable:
            return "scope"
        }
    }
}

enum HomeTaskListSortOrder: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case smart = "Smart"
    case createdNewestFirst = "Created Newest"
    case createdOldestFirst = "Created Oldest"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .smart:
            return "sparkles"
        case .createdNewestFirst:
            return "arrow.down.to.line"
        case .createdOldestFirst:
            return "arrow.up.to.line"
        }
    }
}

enum HomeTaskCreatedDateFilter: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all = "All"
    case today = "Today"
    case yesterday = "Yesterday"
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "calendar"
        case .today:
            return "calendar.badge.clock"
        case .yesterday:
            return "calendar.day.timeline.left"
        case .last7Days, .last30Days:
            return "calendar.badge.plus"
        }
    }
}

enum HomeTaskGoalFilter: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all = "All"
    case withGoal = "Has Goal"
    case withoutGoal = "No Goal"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "target"
        case .withGoal:
            return "target"
        case .withoutGoal:
            return "circle.slash"
        }
    }
}

enum TaskMediaFilter: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all = "All"
    case anyMedia = "Any Media"
    case withImage = "Image"
    case withFile = "File"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "paperclip"
        case .anyMedia:
            return "photo.on.rectangle.angled"
        case .withImage:
            return "photo"
        case .withFile:
            return "paperclip"
        }
    }
}

enum TaskEstimationFilter: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all = "All"
    case withEstimate = "Has Estimate"
    case withoutEstimate = "No Estimate"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "timer"
        case .withEstimate:
            return "timer"
        case .withoutEstimate:
            return "timer"
        }
    }
}

enum RoutineTagMatchMode: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all = "All"
    case any = "Any"

    var id: Self { self }
}

/// Stores and restores per-tab filter state so that switching between
/// the Routines and Todos tabs doesn't wipe filters the user already set.
struct TabFilterStateManager {

    struct Snapshot: Equatable, Codable, Sendable {
        var selectedTag: String?
        var selectedTags: Set<String>
        var includeTagMatchMode: RoutineTagMatchMode
        var selectedFlags: Set<String> = []
        var includeFlagMatchMode: RoutineTagMatchMode = .all
        var excludedFlags: Set<String> = []
        var excludeFlagMatchMode: RoutineTagMatchMode = .any
        var excludedTags: Set<String>
        var excludeTagMatchMode: RoutineTagMatchMode
        var selectedFilter: RoutineListFilter
        var advancedQuery: String
        var selectedManualPlaceFilterID: UUID?
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
        var selectedTodoStateFilter: TodoState?
        var selectedPressureFilter: RoutineTaskPressure?
        var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
        var selectedGoalFilter: HomeTaskGoalFilter = .all
        var selectedMediaFilter: TaskMediaFilter = .all
        var selectedEstimationFilter: TaskEstimationFilter = .all
        var hideAssumedDoneTasks: Bool = false
        var taskListViewMode: HomeTaskListViewMode = .all
        var taskListSortOrder: HomeTaskListSortOrder = .smart
        var createdDateFilter: HomeTaskCreatedDateFilter = .all
        var showArchivedTasks: Bool = true

        static var `default`: Snapshot {
            Snapshot(
                selectedTag: nil,
                selectedTags: [],
                includeTagMatchMode: .all,
                selectedFlags: [],
                includeFlagMatchMode: .all,
                excludedFlags: [],
                excludeFlagMatchMode: .any,
                excludedTags: [],
                excludeTagMatchMode: .any,
                selectedFilter: .all,
                advancedQuery: "",
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil,
                selectedPressureFilter: nil,
                selectedThinkingNeededFilter: nil,
                selectedGoalFilter: .all,
                selectedMediaFilter: .all,
                selectedEstimationFilter: .all,
                hideAssumedDoneTasks: false,
                taskListViewMode: .all,
                taskListSortOrder: .smart,
                createdDateFilter: .all,
                showArchivedTasks: true
            )
        }

        init(
            selectedTag: String?,
            selectedTags: Set<String>? = nil,
            includeTagMatchMode: RoutineTagMatchMode = .all,
            selectedFlags: Set<String> = [],
            includeFlagMatchMode: RoutineTagMatchMode = .all,
            excludedFlags: Set<String> = [],
            excludeFlagMatchMode: RoutineTagMatchMode = .any,
            excludedTags: Set<String>,
            excludeTagMatchMode: RoutineTagMatchMode = .any,
            selectedFilter: RoutineListFilter,
            advancedQuery: String = "",
            selectedManualPlaceFilterID: UUID?,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            selectedTodoStateFilter: TodoState? = nil,
            selectedPressureFilter: RoutineTaskPressure? = nil,
            selectedThinkingNeededFilter: RoutineTaskThinkingNeeded? = nil,
            selectedGoalFilter: HomeTaskGoalFilter = .all,
            selectedMediaFilter: TaskMediaFilter = .all,
            selectedEstimationFilter: TaskEstimationFilter = .all,
            hideAssumedDoneTasks: Bool = false,
            taskListViewMode: HomeTaskListViewMode = .all,
            taskListSortOrder: HomeTaskListSortOrder = .smart,
            createdDateFilter: HomeTaskCreatedDateFilter = .all,
            showArchivedTasks: Bool = true
        ) {
            self.selectedTag = selectedTag
            self.selectedTags = selectedTags ?? selectedTag.map { [$0] } ?? []
            self.includeTagMatchMode = includeTagMatchMode
            self.selectedFlags = selectedFlags
            self.includeFlagMatchMode = includeFlagMatchMode
            self.excludedFlags = excludedFlags
            self.excludeFlagMatchMode = excludeFlagMatchMode
            self.excludedTags = excludedTags
            self.excludeTagMatchMode = excludeTagMatchMode
            self.selectedFilter = selectedFilter
            self.advancedQuery = advancedQuery
            self.selectedManualPlaceFilterID = selectedManualPlaceFilterID
            self.selectedImportanceUrgencyFilter = selectedImportanceUrgencyFilter
            self.selectedTodoStateFilter = selectedTodoStateFilter
            self.selectedPressureFilter = selectedPressureFilter
            self.selectedThinkingNeededFilter = selectedThinkingNeededFilter
            self.selectedGoalFilter = selectedGoalFilter
            self.selectedMediaFilter = selectedMediaFilter
            self.selectedEstimationFilter = selectedEstimationFilter
            self.hideAssumedDoneTasks = hideAssumedDoneTasks
            self.taskListViewMode = taskListViewMode
            self.taskListSortOrder = taskListSortOrder
            self.createdDateFilter = createdDateFilter
            self.showArchivedTasks = showArchivedTasks
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: TabFilterSnapshotCodingKey.self)
            selectedTag = try container.decodeIfPresent(String.self, forKey: .selectedTag)
            selectedTags =
                try container.decodeIfPresent(Set<String>.self, forKey: .selectedTags)
                ?? selectedTag.map { [$0] } ?? []
            includeTagMatchMode = try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .includeTagMatchMode) ?? .all
            selectedFlags = try container.decodeIfPresent(Set<String>.self, forKey: .selectedFlags) ?? []
            includeFlagMatchMode = try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .includeFlagMatchMode) ?? .all
            excludedFlags = try container.decodeIfPresent(Set<String>.self, forKey: .excludedFlags) ?? []
            excludeFlagMatchMode = try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .excludeFlagMatchMode) ?? .any
            excludedTags = try container.decodeIfPresent(Set<String>.self, forKey: .excludedTags) ?? []
            excludeTagMatchMode = try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .excludeTagMatchMode) ?? .any
            selectedFilter = try container.decodeIfPresent(RoutineListFilter.self, forKey: .selectedFilter) ?? .all
            advancedQuery = try container.decodeIfPresent(String.self, forKey: .advancedQuery) ?? ""
            selectedManualPlaceFilterID = try container.decodeIfPresent(UUID.self, forKey: .selectedManualPlaceFilterID)
            selectedImportanceUrgencyFilter = try container.decodeIfPresent(
                ImportanceUrgencyFilterCell.self, forKey: .selectedImportanceUrgencyFilter)
            selectedTodoStateFilter = try container.decodeIfPresent(TodoState.self, forKey: .selectedTodoStateFilter)
            selectedPressureFilter = try container.decodeIfPresent(RoutineTaskPressure.self, forKey: .selectedPressureFilter)
            selectedThinkingNeededFilter = try container.decodeIfPresent(
                RoutineTaskThinkingNeeded.self,
                forKey: .selectedThinkingNeededFilter
            )
            selectedGoalFilter = try container.decodeIfPresent(HomeTaskGoalFilter.self, forKey: .selectedGoalFilter) ?? .all
            selectedMediaFilter = try container.decodeIfPresent(TaskMediaFilter.self, forKey: .selectedMediaFilter) ?? .all
            selectedEstimationFilter = try container.decodeIfPresent(TaskEstimationFilter.self, forKey: .selectedEstimationFilter) ?? .all
            hideAssumedDoneTasks = try container.decodeIfPresent(Bool.self, forKey: .hideAssumedDoneTasks) ?? false
            taskListViewMode = try container.decodeIfPresent(HomeTaskListViewMode.self, forKey: .taskListViewMode) ?? .all
            taskListSortOrder = try container.decodeIfPresent(HomeTaskListSortOrder.self, forKey: .taskListSortOrder) ?? .smart
            createdDateFilter = try container.decodeIfPresent(HomeTaskCreatedDateFilter.self, forKey: .createdDateFilter) ?? .all
            showArchivedTasks = try container.decodeIfPresent(Bool.self, forKey: .showArchivedTasks) ?? true
        }
    }

    private var snapshots: [String: Snapshot] = [:]

    /// Saves the current filter state for `tabKey`, overwriting any previous snapshot.
    mutating func save(_ snapshot: Snapshot, for tabKey: String) {
        snapshots[tabKey] = snapshot
    }

    /// Returns the previously saved snapshot for `tabKey`, or `.default` if none exists.
    func snapshot(for tabKey: String) -> Snapshot {
        snapshots[tabKey] ?? .default
    }

    /// Returns true when a snapshot has been previously saved for `tabKey`.
    func hasSnapshot(for tabKey: String) -> Bool {
        snapshots[tabKey] != nil
    }
}

private enum TabFilterSnapshotCodingKey: String, CodingKey {
    case selectedTag
    case selectedTags
    case includeTagMatchMode
    case selectedFlags
    case includeFlagMatchMode
    case excludedFlags
    case excludeFlagMatchMode
    case excludedTags
    case excludeTagMatchMode
    case selectedFilter
    case advancedQuery
    case selectedManualPlaceFilterID
    case selectedImportanceUrgencyFilter
    case selectedTodoStateFilter
    case selectedPressureFilter
    case selectedThinkingNeededFilter
    case selectedGoalFilter
    case selectedMediaFilter
    case selectedEstimationFilter
    case hideAssumedDoneTasks
    case taskListViewMode
    case taskListSortOrder
    case createdDateFilter
    case showArchivedTasks
}
