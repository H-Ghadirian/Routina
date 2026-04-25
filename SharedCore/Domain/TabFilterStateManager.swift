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
        var excludedTags: Set<String>
        var excludeTagMatchMode: RoutineTagMatchMode
        var selectedFilter: RoutineListFilter
        var advancedQuery: String
        var selectedManualPlaceFilterID: UUID?
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var selectedTodoStateFilter: TodoState? = nil
        var selectedPressureFilter: RoutineTaskPressure? = nil
        var taskListViewMode: HomeTaskListViewMode = .all

        static var `default`: Snapshot {
            Snapshot(
                selectedTag: nil,
                selectedTags: [],
                includeTagMatchMode: .all,
                excludedTags: [],
                excludeTagMatchMode: .any,
                selectedFilter: .all,
                advancedQuery: "",
                selectedManualPlaceFilterID: nil,
                selectedImportanceUrgencyFilter: nil,
                selectedTodoStateFilter: nil,
                selectedPressureFilter: nil,
                taskListViewMode: .all
            )
        }

        init(
            selectedTag: String?,
            selectedTags: Set<String>? = nil,
            includeTagMatchMode: RoutineTagMatchMode = .all,
            excludedTags: Set<String>,
            excludeTagMatchMode: RoutineTagMatchMode = .any,
            selectedFilter: RoutineListFilter,
            advancedQuery: String = "",
            selectedManualPlaceFilterID: UUID?,
            selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
            selectedTodoStateFilter: TodoState? = nil,
            selectedPressureFilter: RoutineTaskPressure? = nil,
            taskListViewMode: HomeTaskListViewMode = .all
        ) {
            self.selectedTag = selectedTag
            self.selectedTags = selectedTags ?? selectedTag.map { [$0] } ?? []
            self.includeTagMatchMode = includeTagMatchMode
            self.excludedTags = excludedTags
            self.excludeTagMatchMode = excludeTagMatchMode
            self.selectedFilter = selectedFilter
            self.advancedQuery = advancedQuery
            self.selectedManualPlaceFilterID = selectedManualPlaceFilterID
            self.selectedImportanceUrgencyFilter = selectedImportanceUrgencyFilter
            self.selectedTodoStateFilter = selectedTodoStateFilter
            self.selectedPressureFilter = selectedPressureFilter
            self.taskListViewMode = taskListViewMode
        }

        private enum CodingKeys: String, CodingKey {
            case selectedTag
            case selectedTags
            case includeTagMatchMode
            case excludedTags
            case excludeTagMatchMode
            case selectedFilter
            case advancedQuery
            case selectedManualPlaceFilterID
            case selectedImportanceUrgencyFilter
            case selectedTodoStateFilter
            case selectedPressureFilter
            case taskListViewMode
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            selectedTag = try container.decodeIfPresent(String.self, forKey: .selectedTag)
            selectedTags = try container.decodeIfPresent(Set<String>.self, forKey: .selectedTags)
                ?? selectedTag.map { [$0] } ?? []
            includeTagMatchMode = try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .includeTagMatchMode) ?? .all
            excludedTags = try container.decodeIfPresent(Set<String>.self, forKey: .excludedTags) ?? []
            excludeTagMatchMode = try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .excludeTagMatchMode) ?? .any
            selectedFilter = try container.decodeIfPresent(RoutineListFilter.self, forKey: .selectedFilter) ?? .all
            advancedQuery = try container.decodeIfPresent(String.self, forKey: .advancedQuery) ?? ""
            selectedManualPlaceFilterID = try container.decodeIfPresent(UUID.self, forKey: .selectedManualPlaceFilterID)
            selectedImportanceUrgencyFilter = try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .selectedImportanceUrgencyFilter)
            selectedTodoStateFilter = try container.decodeIfPresent(TodoState.self, forKey: .selectedTodoStateFilter)
            selectedPressureFilter = try container.decodeIfPresent(RoutineTaskPressure.self, forKey: .selectedPressureFilter)
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
    var homeAdvancedQuery: String
    var homeSelectedTag: String?
    var homeSelectedTags: Set<String>
    var homeIncludeTagMatchMode: RoutineTagMatchMode
    var homeExcludedTags: Set<String>
    var homeExcludeTagMatchMode: RoutineTagMatchMode
    var homeSelectedManualPlaceFilterID: UUID?
    var homeSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var homeSelectedTodoStateFilter: TodoState? = nil
    var homeSelectedPressureFilter: RoutineTaskPressure? = nil
    var homeTaskListViewMode: HomeTaskListViewMode = .all
    var homeTabFilterSnapshots: [String: TabFilterStateManager.Snapshot]
    var hideUnavailableRoutines: Bool
    var homeSelectedTimelineRange: TimelineRange
    var homeSelectedTimelineFilterType: TimelineFilterType
    var homeSelectedTimelineTag: String?
    var homeSelectedTimelineTags: Set<String>
    var homeTimelineIncludeTagMatchMode: RoutineTagMatchMode
    var homeSelectedTimelineExcludedTags: Set<String> = []
    var homeTimelineExcludeTagMatchMode: RoutineTagMatchMode
    var homeSelectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var macHomeSidebarModeRawValue: String?
    var macSelectedSettingsSectionRawValue: String?
    var timelineSelectedRange: TimelineRange
    var timelineFilterType: TimelineFilterType
    var timelineSelectedTag: String?
    var timelineSelectedTags: Set<String>
    var timelineIncludeTagMatchMode: RoutineTagMatchMode
    var timelineExcludedTags: Set<String>
    var timelineExcludeTagMatchMode: RoutineTagMatchMode
    var timelineSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var statsSelectedRange: DoneChartRange
    var statsSelectedTag: String?
    var statsSelectedTags: Set<String>
    var statsIncludeTagMatchMode: RoutineTagMatchMode
    var statsExcludedTags: Set<String>
    var statsExcludeTagMatchMode: RoutineTagMatchMode
    var statsSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
    var statsTaskTypeFilterRawValue: String?

    init(
        selectedAppTabRawValue: String?,
        homeTaskListModeRawValue: String?,
        homeSelectedFilter: RoutineListFilter,
        homeAdvancedQuery: String = "",
        homeSelectedTag: String?,
        homeSelectedTags: Set<String>? = nil,
        homeIncludeTagMatchMode: RoutineTagMatchMode = .all,
        homeExcludedTags: Set<String>,
        homeExcludeTagMatchMode: RoutineTagMatchMode = .any,
        homeSelectedManualPlaceFilterID: UUID?,
        homeSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        homeSelectedTodoStateFilter: TodoState? = nil,
        homeSelectedPressureFilter: RoutineTaskPressure? = nil,
        homeTaskListViewMode: HomeTaskListViewMode = .all,
        homeTabFilterSnapshots: [String: TabFilterStateManager.Snapshot],
        hideUnavailableRoutines: Bool,
        homeSelectedTimelineRange: TimelineRange,
        homeSelectedTimelineFilterType: TimelineFilterType,
        homeSelectedTimelineTag: String?,
        homeSelectedTimelineTags: Set<String>? = nil,
        homeTimelineIncludeTagMatchMode: RoutineTagMatchMode = .all,
        homeSelectedTimelineExcludedTags: Set<String> = [],
        homeTimelineExcludeTagMatchMode: RoutineTagMatchMode = .any,
        homeSelectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        macHomeSidebarModeRawValue: String?,
        macSelectedSettingsSectionRawValue: String?,
        timelineSelectedRange: TimelineRange,
        timelineFilterType: TimelineFilterType,
        timelineSelectedTag: String?,
        timelineSelectedTags: Set<String>? = nil,
        timelineIncludeTagMatchMode: RoutineTagMatchMode = .all,
        timelineExcludedTags: Set<String> = [],
        timelineExcludeTagMatchMode: RoutineTagMatchMode = .any,
        timelineSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        statsSelectedRange: DoneChartRange,
        statsSelectedTag: String?,
        statsSelectedTags: Set<String>? = nil,
        statsIncludeTagMatchMode: RoutineTagMatchMode = .all,
        statsExcludedTags: Set<String>,
        statsExcludeTagMatchMode: RoutineTagMatchMode = .any,
        statsSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        statsTaskTypeFilterRawValue: String?
    ) {
        self.selectedAppTabRawValue = selectedAppTabRawValue
        self.homeTaskListModeRawValue = homeTaskListModeRawValue
        self.homeSelectedFilter = homeSelectedFilter
        self.homeAdvancedQuery = homeAdvancedQuery
        self.homeSelectedTag = homeSelectedTag
        self.homeSelectedTags = homeSelectedTags ?? homeSelectedTag.map { [$0] } ?? []
        self.homeIncludeTagMatchMode = homeIncludeTagMatchMode
        self.homeExcludedTags = homeExcludedTags
        self.homeExcludeTagMatchMode = homeExcludeTagMatchMode
        self.homeSelectedManualPlaceFilterID = homeSelectedManualPlaceFilterID
        self.homeSelectedImportanceUrgencyFilter = homeSelectedImportanceUrgencyFilter
        self.homeSelectedTodoStateFilter = homeSelectedTodoStateFilter
        self.homeSelectedPressureFilter = homeSelectedPressureFilter
        self.homeTaskListViewMode = homeTaskListViewMode
        self.homeTabFilterSnapshots = homeTabFilterSnapshots
        self.hideUnavailableRoutines = hideUnavailableRoutines
        self.homeSelectedTimelineRange = homeSelectedTimelineRange
        self.homeSelectedTimelineFilterType = homeSelectedTimelineFilterType
        self.homeSelectedTimelineTag = homeSelectedTimelineTag
        self.homeSelectedTimelineTags = homeSelectedTimelineTags ?? homeSelectedTimelineTag.map { [$0] } ?? []
        self.homeTimelineIncludeTagMatchMode = homeTimelineIncludeTagMatchMode
        self.homeSelectedTimelineExcludedTags = homeSelectedTimelineExcludedTags
        self.homeTimelineExcludeTagMatchMode = homeTimelineExcludeTagMatchMode
        self.homeSelectedTimelineImportanceUrgencyFilter = homeSelectedTimelineImportanceUrgencyFilter
        self.macHomeSidebarModeRawValue = macHomeSidebarModeRawValue
        self.macSelectedSettingsSectionRawValue = macSelectedSettingsSectionRawValue
        self.timelineSelectedRange = timelineSelectedRange
        self.timelineFilterType = timelineFilterType
        self.timelineSelectedTag = timelineSelectedTag
        self.timelineSelectedTags = timelineSelectedTags ?? timelineSelectedTag.map { [$0] } ?? []
        self.timelineIncludeTagMatchMode = timelineIncludeTagMatchMode
        self.timelineExcludedTags = timelineExcludedTags
        self.timelineExcludeTagMatchMode = timelineExcludeTagMatchMode
        self.timelineSelectedImportanceUrgencyFilter = timelineSelectedImportanceUrgencyFilter
        self.statsSelectedRange = statsSelectedRange
        self.statsSelectedTag = statsSelectedTag
        self.statsSelectedTags = statsSelectedTags ?? statsSelectedTag.map { [$0] } ?? []
        self.statsIncludeTagMatchMode = statsIncludeTagMatchMode
        self.statsExcludedTags = statsExcludedTags
        self.statsExcludeTagMatchMode = statsExcludeTagMatchMode
        self.statsSelectedImportanceUrgencyFilter = statsSelectedImportanceUrgencyFilter
        self.statsTaskTypeFilterRawValue = statsTaskTypeFilterRawValue
    }

    private enum CodingKeys: String, CodingKey {
        case selectedAppTabRawValue
        case homeTaskListModeRawValue
        case homeSelectedFilter
        case homeAdvancedQuery
        case homeSelectedTag
        case homeSelectedTags
        case homeIncludeTagMatchMode
        case homeExcludedTags
        case homeExcludeTagMatchMode
        case homeSelectedManualPlaceFilterID
        case homeSelectedImportanceUrgencyFilter
        case homeSelectedTodoStateFilter
        case homeSelectedPressureFilter
        case homeTaskListViewMode
        case homeTabFilterSnapshots
        case hideUnavailableRoutines
        case homeSelectedTimelineRange
        case homeSelectedTimelineFilterType
        case homeSelectedTimelineTag
        case homeSelectedTimelineTags
        case homeTimelineIncludeTagMatchMode
        case homeSelectedTimelineExcludedTags
        case homeTimelineExcludeTagMatchMode
        case homeSelectedTimelineImportanceUrgencyFilter
        case macHomeSidebarModeRawValue
        case macSelectedSettingsSectionRawValue
        case timelineSelectedRange
        case timelineFilterType
        case timelineSelectedTag
        case timelineSelectedTags
        case timelineIncludeTagMatchMode
        case timelineExcludedTags
        case timelineExcludeTagMatchMode
        case timelineSelectedImportanceUrgencyFilter
        case statsSelectedRange
        case statsSelectedTag
        case statsSelectedTags
        case statsIncludeTagMatchMode
        case statsExcludedTags
        case statsExcludeTagMatchMode
        case statsSelectedImportanceUrgencyFilter
        case statsTaskTypeFilterRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedAppTabRawValue: try container.decodeIfPresent(String.self, forKey: .selectedAppTabRawValue),
            homeTaskListModeRawValue: try container.decodeIfPresent(String.self, forKey: .homeTaskListModeRawValue),
            homeSelectedFilter: try container.decodeIfPresent(RoutineListFilter.self, forKey: .homeSelectedFilter) ?? .all,
            homeAdvancedQuery: try container.decodeIfPresent(String.self, forKey: .homeAdvancedQuery) ?? "",
            homeSelectedTag: try container.decodeIfPresent(String.self, forKey: .homeSelectedTag),
            homeSelectedTags: try container.decodeIfPresent(Set<String>.self, forKey: .homeSelectedTags),
            homeIncludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .homeIncludeTagMatchMode) ?? .all,
            homeExcludedTags: try container.decodeIfPresent(Set<String>.self, forKey: .homeExcludedTags) ?? [],
            homeExcludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .homeExcludeTagMatchMode) ?? .any,
            homeSelectedManualPlaceFilterID: try container.decodeIfPresent(UUID.self, forKey: .homeSelectedManualPlaceFilterID),
            homeSelectedImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .homeSelectedImportanceUrgencyFilter),
            homeSelectedTodoStateFilter: try container.decodeIfPresent(TodoState.self, forKey: .homeSelectedTodoStateFilter),
            homeSelectedPressureFilter: try container.decodeIfPresent(RoutineTaskPressure.self, forKey: .homeSelectedPressureFilter),
            homeTaskListViewMode: try container.decodeIfPresent(HomeTaskListViewMode.self, forKey: .homeTaskListViewMode) ?? .all,
            homeTabFilterSnapshots: try container.decodeIfPresent([String: TabFilterStateManager.Snapshot].self, forKey: .homeTabFilterSnapshots) ?? [:],
            hideUnavailableRoutines: try container.decodeIfPresent(Bool.self, forKey: .hideUnavailableRoutines) ?? false,
            homeSelectedTimelineRange: try container.decodeIfPresent(TimelineRange.self, forKey: .homeSelectedTimelineRange) ?? .all,
            homeSelectedTimelineFilterType: try container.decodeIfPresent(TimelineFilterType.self, forKey: .homeSelectedTimelineFilterType) ?? .all,
            homeSelectedTimelineTag: try container.decodeIfPresent(String.self, forKey: .homeSelectedTimelineTag),
            homeSelectedTimelineTags: try container.decodeIfPresent(Set<String>.self, forKey: .homeSelectedTimelineTags),
            homeTimelineIncludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .homeTimelineIncludeTagMatchMode) ?? .all,
            homeSelectedTimelineExcludedTags: try container.decodeIfPresent(Set<String>.self, forKey: .homeSelectedTimelineExcludedTags) ?? [],
            homeTimelineExcludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .homeTimelineExcludeTagMatchMode) ?? .any,
            homeSelectedTimelineImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .homeSelectedTimelineImportanceUrgencyFilter),
            macHomeSidebarModeRawValue: try container.decodeIfPresent(String.self, forKey: .macHomeSidebarModeRawValue),
            macSelectedSettingsSectionRawValue: try container.decodeIfPresent(String.self, forKey: .macSelectedSettingsSectionRawValue),
            timelineSelectedRange: try container.decodeIfPresent(TimelineRange.self, forKey: .timelineSelectedRange) ?? .all,
            timelineFilterType: try container.decodeIfPresent(TimelineFilterType.self, forKey: .timelineFilterType) ?? .all,
            timelineSelectedTag: try container.decodeIfPresent(String.self, forKey: .timelineSelectedTag),
            timelineSelectedTags: try container.decodeIfPresent(Set<String>.self, forKey: .timelineSelectedTags),
            timelineIncludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .timelineIncludeTagMatchMode) ?? .all,
            timelineExcludedTags: try container.decodeIfPresent(Set<String>.self, forKey: .timelineExcludedTags) ?? [],
            timelineExcludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .timelineExcludeTagMatchMode) ?? .any,
            timelineSelectedImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .timelineSelectedImportanceUrgencyFilter),
            statsSelectedRange: try container.decodeIfPresent(DoneChartRange.self, forKey: .statsSelectedRange) ?? .week,
            statsSelectedTag: try container.decodeIfPresent(String.self, forKey: .statsSelectedTag),
            statsSelectedTags: try container.decodeIfPresent(Set<String>.self, forKey: .statsSelectedTags),
            statsIncludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .statsIncludeTagMatchMode) ?? .all,
            statsExcludedTags: try container.decodeIfPresent(Set<String>.self, forKey: .statsExcludedTags) ?? [],
            statsExcludeTagMatchMode: try container.decodeIfPresent(RoutineTagMatchMode.self, forKey: .statsExcludeTagMatchMode) ?? .any,
            statsSelectedImportanceUrgencyFilter: try container.decodeIfPresent(ImportanceUrgencyFilterCell.self, forKey: .statsSelectedImportanceUrgencyFilter),
            statsTaskTypeFilterRawValue: try container.decodeIfPresent(String.self, forKey: .statsTaskTypeFilterRawValue)
        )
    }

    static let `default` = TemporaryViewState(
        selectedAppTabRawValue: Tab.home.rawValue,
        homeTaskListModeRawValue: nil,
        homeSelectedFilter: .all,
        homeAdvancedQuery: "",
        homeSelectedTag: nil,
        homeSelectedTags: [],
        homeIncludeTagMatchMode: .all,
        homeExcludedTags: [],
        homeExcludeTagMatchMode: .any,
        homeSelectedManualPlaceFilterID: nil,
        homeSelectedImportanceUrgencyFilter: nil,
        homeSelectedTodoStateFilter: nil,
        homeSelectedPressureFilter: nil,
        homeTaskListViewMode: .all,
        homeTabFilterSnapshots: [:],
        hideUnavailableRoutines: false,
        homeSelectedTimelineRange: .all,
        homeSelectedTimelineFilterType: .all,
        homeSelectedTimelineTag: nil,
        homeSelectedTimelineTags: [],
        homeTimelineIncludeTagMatchMode: .all,
        homeSelectedTimelineExcludedTags: [],
        homeTimelineExcludeTagMatchMode: .any,
        homeSelectedTimelineImportanceUrgencyFilter: nil,
        macHomeSidebarModeRawValue: nil,
        macSelectedSettingsSectionRawValue: nil,
        timelineSelectedRange: .all,
        timelineFilterType: .all,
        timelineSelectedTag: nil,
        timelineSelectedTags: [],
        timelineIncludeTagMatchMode: .all,
        timelineExcludedTags: [],
        timelineExcludeTagMatchMode: .any,
        timelineSelectedImportanceUrgencyFilter: nil,
        statsSelectedRange: .week,
        statsSelectedTag: nil,
        statsSelectedTags: [],
        statsIncludeTagMatchMode: .all,
        statsExcludedTags: [],
        statsExcludeTagMatchMode: .any,
        statsSelectedImportanceUrgencyFilter: nil,
        statsTaskTypeFilterRawValue: nil
    )
}
