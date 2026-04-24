import Foundation

enum HomeTaskListViewMode: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case all = "All"
    case actionable = "Actionable"

    var id: Self { self }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "list.bullet"
        case .actionable:
            return "scope"
        }
    }
}

/// Stores and restores per-tab filter state so that switching between
/// the Routines and Todos tabs doesn't wipe filters the user already set.
struct TabFilterStateManager {

    struct Snapshot: Equatable, Codable, Sendable {
        var selectedTag: String?
        var excludedTags: Set<String>
        var selectedFilter: RoutineListFilter
        var selectedManualPlaceFilterID: UUID?
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var selectedTodoStateFilter: TodoState? = nil
        var taskListViewMode: HomeTaskListViewMode = .all

        static var `default`: Snapshot {
            Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil,
                taskListViewMode: .all
            )
        }

        init(
            selectedTag: String?,
            excludedTags: Set<String>,
            selectedFilter: RoutineListFilter,
            selectedManualPlaceFilterID: UUID?,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            selectedTodoStateFilter: TodoState? = nil,
            taskListViewMode: HomeTaskListViewMode = .all
        ) {
            self.selectedTag = selectedTag
            self.excludedTags = excludedTags
            self.selectedFilter = selectedFilter
            self.selectedManualPlaceFilterID = selectedManualPlaceFilterID
            self.selectedImportanceUrgencyFilter = selectedImportanceUrgencyFilter
            self.selectedTodoStateFilter = selectedTodoStateFilter
            self.taskListViewMode = taskListViewMode
        }

        private enum CodingKeys: String, CodingKey {
            case selectedTag
            case excludedTags
            case selectedFilter
            case selectedManualPlaceFilterID
            case selectedImportanceUrgencyFilter
            case selectedTodoStateFilter
            case taskListViewMode
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            selectedTag = try container.decodeIfPresent(String.self, forKey: .selectedTag)
            excludedTags = try container.decodeIfPresent(Set<String>.self, forKey: .excludedTags) ?? []
            selectedFilter = try container.decodeIfPresent(RoutineListFilter.self, forKey: .selectedFilter) ?? .all
            selectedManualPlaceFilterID = try container.decodeIfPresent(UUID.self, forKey: .selectedManualPlaceFilterID)
            selectedImportanceUrgencyFilter = try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .selectedImportanceUrgencyFilter)
            selectedTodoStateFilter = try container.decodeIfPresent(TodoState.self, forKey: .selectedTodoStateFilter)
            taskListViewMode = try container.decodeIfPresent(HomeTaskListViewMode.self, forKey: .taskListViewMode) ?? .all
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

struct TemporaryViewState: Equatable, Codable, Sendable {
    var selectedAppTabRawValue: String?
    var homeTaskListModeRawValue: String?
    var homeSelectedFilter: RoutineListFilter
    var homeSelectedTag: String?
    var homeExcludedTags: Set<String>
    var homeSelectedManualPlaceFilterID: UUID?
    var homeSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var homeSelectedTodoStateFilter: TodoState? = nil
    var homeTaskListViewMode: HomeTaskListViewMode = .all
    var homeTabFilterSnapshots: [String: TabFilterStateManager.Snapshot]
    var hideUnavailableRoutines: Bool
    var homeSelectedTimelineRange: TimelineRange
    var homeSelectedTimelineFilterType: TimelineFilterType
    var homeSelectedTimelineTag: String?
    var homeSelectedTimelineExcludedTags: Set<String> = []
    var homeSelectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var macHomeSidebarModeRawValue: String?
    var macSelectedSettingsSectionRawValue: String?
    var timelineSelectedRange: TimelineRange
    var timelineFilterType: TimelineFilterType
    var timelineSelectedTag: String?
    var timelineSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var statsSelectedRange: DoneChartRange
    var statsSelectedTag: String?
    var statsExcludedTags: Set<String>
    var statsSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var statsTaskTypeFilterRawValue: String?

    init(
        selectedAppTabRawValue: String?,
        homeTaskListModeRawValue: String?,
        homeSelectedFilter: RoutineListFilter,
        homeSelectedTag: String?,
        homeExcludedTags: Set<String>,
        homeSelectedManualPlaceFilterID: UUID?,
        homeSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        homeSelectedTodoStateFilter: TodoState? = nil,
        homeTaskListViewMode: HomeTaskListViewMode = .all,
        homeTabFilterSnapshots: [String: TabFilterStateManager.Snapshot],
        hideUnavailableRoutines: Bool,
        homeSelectedTimelineRange: TimelineRange,
        homeSelectedTimelineFilterType: TimelineFilterType,
        homeSelectedTimelineTag: String?,
        homeSelectedTimelineExcludedTags: Set<String> = [],
        homeSelectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        macHomeSidebarModeRawValue: String?,
        macSelectedSettingsSectionRawValue: String?,
        timelineSelectedRange: TimelineRange,
        timelineFilterType: TimelineFilterType,
        timelineSelectedTag: String?,
        timelineSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        statsSelectedRange: DoneChartRange,
        statsSelectedTag: String?,
        statsExcludedTags: Set<String>,
        statsSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        statsTaskTypeFilterRawValue: String?
    ) {
        self.selectedAppTabRawValue = selectedAppTabRawValue
        self.homeTaskListModeRawValue = homeTaskListModeRawValue
        self.homeSelectedFilter = homeSelectedFilter
        self.homeSelectedTag = homeSelectedTag
        self.homeExcludedTags = homeExcludedTags
        self.homeSelectedManualPlaceFilterID = homeSelectedManualPlaceFilterID
        self.homeSelectedImportanceUrgencyFilter = homeSelectedImportanceUrgencyFilter
        self.homeSelectedTodoStateFilter = homeSelectedTodoStateFilter
        self.homeTaskListViewMode = homeTaskListViewMode
        self.homeTabFilterSnapshots = homeTabFilterSnapshots
        self.hideUnavailableRoutines = hideUnavailableRoutines
        self.homeSelectedTimelineRange = homeSelectedTimelineRange
        self.homeSelectedTimelineFilterType = homeSelectedTimelineFilterType
        self.homeSelectedTimelineTag = homeSelectedTimelineTag
        self.homeSelectedTimelineExcludedTags = homeSelectedTimelineExcludedTags
        self.homeSelectedTimelineImportanceUrgencyFilter = homeSelectedTimelineImportanceUrgencyFilter
        self.macHomeSidebarModeRawValue = macHomeSidebarModeRawValue
        self.macSelectedSettingsSectionRawValue = macSelectedSettingsSectionRawValue
        self.timelineSelectedRange = timelineSelectedRange
        self.timelineFilterType = timelineFilterType
        self.timelineSelectedTag = timelineSelectedTag
        self.timelineSelectedImportanceUrgencyFilter = timelineSelectedImportanceUrgencyFilter
        self.statsSelectedRange = statsSelectedRange
        self.statsSelectedTag = statsSelectedTag
        self.statsExcludedTags = statsExcludedTags
        self.statsSelectedImportanceUrgencyFilter = statsSelectedImportanceUrgencyFilter
        self.statsTaskTypeFilterRawValue = statsTaskTypeFilterRawValue
    }

    private enum CodingKeys: String, CodingKey {
        case selectedAppTabRawValue
        case homeTaskListModeRawValue
        case homeSelectedFilter
        case homeSelectedTag
        case homeExcludedTags
        case homeSelectedManualPlaceFilterID
        case homeSelectedImportanceUrgencyFilter
        case homeSelectedTodoStateFilter
        case homeTaskListViewMode
        case homeTabFilterSnapshots
        case hideUnavailableRoutines
        case homeSelectedTimelineRange
        case homeSelectedTimelineFilterType
        case homeSelectedTimelineTag
        case homeSelectedTimelineExcludedTags
        case homeSelectedTimelineImportanceUrgencyFilter
        case macHomeSidebarModeRawValue
        case macSelectedSettingsSectionRawValue
        case timelineSelectedRange
        case timelineFilterType
        case timelineSelectedTag
        case timelineSelectedImportanceUrgencyFilter
        case statsSelectedRange
        case statsSelectedTag
        case statsExcludedTags
        case statsSelectedImportanceUrgencyFilter
        case statsTaskTypeFilterRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedAppTabRawValue: try container.decodeIfPresent(String.self, forKey: .selectedAppTabRawValue),
            homeTaskListModeRawValue: try container.decodeIfPresent(String.self, forKey: .homeTaskListModeRawValue),
            homeSelectedFilter: try container.decodeIfPresent(RoutineListFilter.self, forKey: .homeSelectedFilter) ?? .all,
            homeSelectedTag: try container.decodeIfPresent(String.self, forKey: .homeSelectedTag),
            homeExcludedTags: try container.decodeIfPresent(Set<String>.self, forKey: .homeExcludedTags) ?? [],
            homeSelectedManualPlaceFilterID: try container.decodeIfPresent(UUID.self, forKey: .homeSelectedManualPlaceFilterID),
            homeSelectedImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .homeSelectedImportanceUrgencyFilter),
            homeSelectedTodoStateFilter: try container.decodeIfPresent(TodoState.self, forKey: .homeSelectedTodoStateFilter),
            homeTaskListViewMode: try container.decodeIfPresent(HomeTaskListViewMode.self, forKey: .homeTaskListViewMode) ?? .all,
            homeTabFilterSnapshots: try container.decodeIfPresent([String: TabFilterStateManager.Snapshot].self, forKey: .homeTabFilterSnapshots) ?? [:],
            hideUnavailableRoutines: try container.decodeIfPresent(Bool.self, forKey: .hideUnavailableRoutines) ?? false,
            homeSelectedTimelineRange: try container.decodeIfPresent(TimelineRange.self, forKey: .homeSelectedTimelineRange) ?? .all,
            homeSelectedTimelineFilterType: try container.decodeIfPresent(TimelineFilterType.self, forKey: .homeSelectedTimelineFilterType) ?? .all,
            homeSelectedTimelineTag: try container.decodeIfPresent(String.self, forKey: .homeSelectedTimelineTag),
            homeSelectedTimelineExcludedTags: try container.decodeIfPresent(Set<String>.self, forKey: .homeSelectedTimelineExcludedTags) ?? [],
            homeSelectedTimelineImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .homeSelectedTimelineImportanceUrgencyFilter),
            macHomeSidebarModeRawValue: try container.decodeIfPresent(String.self, forKey: .macHomeSidebarModeRawValue),
            macSelectedSettingsSectionRawValue: try container.decodeIfPresent(String.self, forKey: .macSelectedSettingsSectionRawValue),
            timelineSelectedRange: try container.decodeIfPresent(TimelineRange.self, forKey: .timelineSelectedRange) ?? .all,
            timelineFilterType: try container.decodeIfPresent(TimelineFilterType.self, forKey: .timelineFilterType) ?? .all,
            timelineSelectedTag: try container.decodeIfPresent(String.self, forKey: .timelineSelectedTag),
            timelineSelectedImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .timelineSelectedImportanceUrgencyFilter),
            statsSelectedRange: try container.decodeIfPresent(DoneChartRange.self, forKey: .statsSelectedRange) ?? .week,
            statsSelectedTag: try container.decodeIfPresent(String.self, forKey: .statsSelectedTag),
            statsExcludedTags: try container.decodeIfPresent(Set<String>.self, forKey: .statsExcludedTags) ?? [],
            statsSelectedImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .statsSelectedImportanceUrgencyFilter),
            statsTaskTypeFilterRawValue: try container.decodeIfPresent(String.self, forKey: .statsTaskTypeFilterRawValue)
        )
    }

    static let `default` = TemporaryViewState(
        selectedAppTabRawValue: Tab.home.rawValue,
        homeTaskListModeRawValue: nil,
        homeSelectedFilter: .all,
        homeSelectedTag: nil,
        homeExcludedTags: [],
        homeSelectedManualPlaceFilterID: nil,
        homeSelectedImportanceUrgencyFilter: nil,
        homeSelectedTodoStateFilter: nil,
        homeTaskListViewMode: .all,
        homeTabFilterSnapshots: [:],
        hideUnavailableRoutines: false,
        homeSelectedTimelineRange: .all,
        homeSelectedTimelineFilterType: .all,
        homeSelectedTimelineTag: nil,
        homeSelectedTimelineExcludedTags: [],
        homeSelectedTimelineImportanceUrgencyFilter: nil,
        macHomeSidebarModeRawValue: nil,
        macSelectedSettingsSectionRawValue: nil,
        timelineSelectedRange: .all,
        timelineFilterType: .all,
        timelineSelectedTag: nil,
        timelineSelectedImportanceUrgencyFilter: nil,
        statsSelectedRange: .week,
        statsSelectedTag: nil,
        statsExcludedTags: [],
        statsSelectedImportanceUrgencyFilter: nil,
        statsTaskTypeFilterRawValue: nil
    )
}
