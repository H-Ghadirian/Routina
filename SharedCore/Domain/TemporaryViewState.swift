import Foundation

struct TemporaryViewState: Equatable, Codable, Sendable {
    var selectedAppTabRawValue: String?
    var homeTaskListModeRawValue: String?
    var homeSelectedFilter: RoutineListFilter
    var homeAdvancedQuery: String
    var homeSelectedTag: String?
    var homeSelectedTags: Set<String>
    var homeIncludeTagMatchMode: RoutineTagMatchMode
    var homeSelectedFlags: Set<String> = []
    var homeIncludeFlagMatchMode: RoutineTagMatchMode = .all
    var homeExcludedFlags: Set<String> = []
    var homeExcludeFlagMatchMode: RoutineTagMatchMode = .any
    var homeExcludedTags: Set<String>
    var homeExcludeTagMatchMode: RoutineTagMatchMode
    var homeSelectedManualPlaceFilterID: UUID?
    var homeSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var homeSelectedTodoStateFilter: TodoState?
    var homeSelectedPressureFilter: RoutineTaskPressure?
    var homeSelectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
    var homeSelectedGoalFilter: HomeTaskGoalFilter = .all
    var homeSelectedMediaFilter: TaskMediaFilter = .all
    var homeSelectedEstimationFilter: TaskEstimationFilter = .all
    var homeHideAssumedDoneTasks: Bool = false
    var homeTaskListViewMode: HomeTaskListViewMode = .all
    var homeTaskListSortOrder: HomeTaskListSortOrder = .smart
    var homeCreatedDateFilter: HomeTaskCreatedDateFilter = .all
    var homeShowArchivedTasks: Bool = true
    var homeTabFilterSnapshots: [String: TabFilterStateManager.Snapshot]
    var hideUnavailableRoutines: Bool
    var homeSelectedTimelineRange: TimelineRange
    var homeSelectedTimelineFilterType: TimelineFilterType
    var homeSelectedTimelineStatusFilter: TimelineStatusFilter = .all
    var homeSelectedTimelineTag: String?
    var homeSelectedTimelineTags: Set<String>
    var homeTimelineIncludeTagMatchMode: RoutineTagMatchMode
    var homeSelectedTimelineFlags: Set<String> = []
    var homeTimelineIncludeFlagMatchMode: RoutineTagMatchMode = .all
    var homeSelectedTimelineExcludedTags: Set<String> = []
    var homeTimelineExcludeTagMatchMode: RoutineTagMatchMode
    var homeSelectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var homeSelectedTimelinePressureFilter: RoutineTaskPressure?
    var homeSelectedTimelineThinkingNeededFilter: RoutineTaskThinkingNeeded?
    var homeSelectedTimelineEstimationFilter: TaskEstimationFilter = .all
    var homeSelectedTimelineMediaFilter: TaskMediaFilter = .all
    var macHomeSidebarModeRawValue: String?
    var macSelectedSettingsSectionRawValue: String?
    var timelineSelectedRange: TimelineRange
    var timelineFilterType: TimelineFilterType
    var timelineSelectedTag: String?
    var timelineSelectedTags: Set<String>
    var timelineIncludeTagMatchMode: RoutineTagMatchMode
    var timelineSelectedFlags: Set<String> = []
    var timelineIncludeFlagMatchMode: RoutineTagMatchMode = .all
    var timelineExcludedTags: Set<String>
    var timelineExcludeTagMatchMode: RoutineTagMatchMode
    var timelineSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var timelineMediaFilter: TaskMediaFilter = .all
    var statsSelectedRange: DoneChartRange
    var statsSelectedTag: String?
    var statsSelectedTags: Set<String>
    var statsIncludeTagMatchMode: RoutineTagMatchMode
    var statsExcludedTags: Set<String>
    var statsExcludeTagMatchMode: RoutineTagMatchMode
    var statsSelectedFlags: Set<String>
    var statsIncludeFlagMatchMode: RoutineTagMatchMode
    var statsExcludedFlags: Set<String>
    var statsExcludeFlagMatchMode: RoutineTagMatchMode
    var statsSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var statsTaskTypeFilterRawValue: String?
    var statsAdvancedQuery: String

    init(
        selectedAppTabRawValue: String?,
        homeTaskListModeRawValue: String?,
        homeSelectedFilter: RoutineListFilter,
        homeAdvancedQuery: String = "",
        homeSelectedTag: String?,
        homeSelectedTags: Set<String>? = nil,
        homeIncludeTagMatchMode: RoutineTagMatchMode = .all,
        homeSelectedFlags: Set<String> = [],
        homeIncludeFlagMatchMode: RoutineTagMatchMode = .all,
        homeExcludedFlags: Set<String> = [],
        homeExcludeFlagMatchMode: RoutineTagMatchMode = .any,
        homeExcludedTags: Set<String>,
        homeExcludeTagMatchMode: RoutineTagMatchMode = .any,
        homeSelectedManualPlaceFilterID: UUID?,
        homeSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        homeSelectedTodoStateFilter: TodoState? = nil,
        homeSelectedPressureFilter: RoutineTaskPressure? = nil,
        homeSelectedThinkingNeededFilter: RoutineTaskThinkingNeeded? = nil,
        homeSelectedGoalFilter: HomeTaskGoalFilter = .all,
        homeSelectedMediaFilter: TaskMediaFilter = .all,
        homeSelectedEstimationFilter: TaskEstimationFilter = .all,
        homeHideAssumedDoneTasks: Bool = false,
        homeTaskListViewMode: HomeTaskListViewMode = .all,
        homeTaskListSortOrder: HomeTaskListSortOrder = .smart,
        homeCreatedDateFilter: HomeTaskCreatedDateFilter = .all,
        homeShowArchivedTasks: Bool = true,
        homeTabFilterSnapshots: [String: TabFilterStateManager.Snapshot],
        hideUnavailableRoutines: Bool,
        homeSelectedTimelineRange: TimelineRange,
        homeSelectedTimelineFilterType: TimelineFilterType,
        homeSelectedTimelineStatusFilter: TimelineStatusFilter = .all,
        homeSelectedTimelineTag: String?,
        homeSelectedTimelineTags: Set<String>? = nil,
        homeTimelineIncludeTagMatchMode: RoutineTagMatchMode = .all,
        homeSelectedTimelineFlags: Set<String> = [],
        homeTimelineIncludeFlagMatchMode: RoutineTagMatchMode = .all,
        homeSelectedTimelineExcludedTags: Set<String> = [],
        homeTimelineExcludeTagMatchMode: RoutineTagMatchMode = .any,
        homeSelectedTimelineImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        homeSelectedTimelinePressureFilter: RoutineTaskPressure? = nil,
        homeSelectedTimelineThinkingNeededFilter: RoutineTaskThinkingNeeded? = nil,
        homeSelectedTimelineEstimationFilter: TaskEstimationFilter = .all,
        homeSelectedTimelineMediaFilter: TaskMediaFilter = .all,
        macHomeSidebarModeRawValue: String?,
        macSelectedSettingsSectionRawValue: String?,
        timelineSelectedRange: TimelineRange,
        timelineFilterType: TimelineFilterType,
        timelineSelectedTag: String?,
        timelineSelectedTags: Set<String>? = nil,
        timelineIncludeTagMatchMode: RoutineTagMatchMode = .all,
        timelineSelectedFlags: Set<String> = [],
        timelineIncludeFlagMatchMode: RoutineTagMatchMode = .all,
        timelineExcludedTags: Set<String> = [],
        timelineExcludeTagMatchMode: RoutineTagMatchMode = .any,
        timelineSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        timelineMediaFilter: TaskMediaFilter = .all,
        statsSelectedRange: DoneChartRange,
        statsSelectedTag: String?,
        statsSelectedTags: Set<String>? = nil,
        statsIncludeTagMatchMode: RoutineTagMatchMode = .all,
        statsExcludedTags: Set<String>,
        statsExcludeTagMatchMode: RoutineTagMatchMode = .any,
        statsSelectedFlags: Set<String> = [],
        statsIncludeFlagMatchMode: RoutineTagMatchMode = .all,
        statsExcludedFlags: Set<String> = [],
        statsExcludeFlagMatchMode: RoutineTagMatchMode = .any,
        statsSelectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
        statsTaskTypeFilterRawValue: String?,
        statsAdvancedQuery: String = ""
    ) {
        self.selectedAppTabRawValue = selectedAppTabRawValue
        self.homeTaskListModeRawValue = homeTaskListModeRawValue
        self.homeSelectedFilter = homeSelectedFilter
        self.homeAdvancedQuery = homeAdvancedQuery
        self.homeSelectedTag = homeSelectedTag
        self.homeSelectedTags = homeSelectedTags ?? homeSelectedTag.map { [$0] } ?? []
        self.homeIncludeTagMatchMode = homeIncludeTagMatchMode
        self.homeSelectedFlags = homeSelectedFlags
        self.homeIncludeFlagMatchMode = homeIncludeFlagMatchMode
        self.homeExcludedFlags = homeExcludedFlags
        self.homeExcludeFlagMatchMode = homeExcludeFlagMatchMode
        self.homeExcludedTags = homeExcludedTags
        self.homeExcludeTagMatchMode = homeExcludeTagMatchMode
        self.homeSelectedManualPlaceFilterID = homeSelectedManualPlaceFilterID
        self.homeSelectedImportanceUrgencyFilter = homeSelectedImportanceUrgencyFilter
        self.homeSelectedTodoStateFilter = homeSelectedTodoStateFilter
        self.homeSelectedPressureFilter = homeSelectedPressureFilter
        self.homeSelectedThinkingNeededFilter = homeSelectedThinkingNeededFilter
        self.homeSelectedGoalFilter = homeSelectedGoalFilter
        self.homeSelectedMediaFilter = homeSelectedMediaFilter
        self.homeSelectedEstimationFilter = homeSelectedEstimationFilter
        self.homeHideAssumedDoneTasks = homeHideAssumedDoneTasks
        self.homeTaskListViewMode = homeTaskListViewMode
        self.homeTaskListSortOrder = homeTaskListSortOrder
        self.homeCreatedDateFilter = homeCreatedDateFilter
        self.homeShowArchivedTasks = homeShowArchivedTasks
        self.homeTabFilterSnapshots = homeTabFilterSnapshots
        self.hideUnavailableRoutines = hideUnavailableRoutines
        self.homeSelectedTimelineRange = homeSelectedTimelineRange
        self.homeSelectedTimelineFilterType = homeSelectedTimelineFilterType
        self.homeSelectedTimelineStatusFilter = homeSelectedTimelineStatusFilter
        self.homeSelectedTimelineTag = homeSelectedTimelineTag
        self.homeSelectedTimelineTags = homeSelectedTimelineTags ?? homeSelectedTimelineTag.map { [$0] } ?? []
        self.homeTimelineIncludeTagMatchMode = homeTimelineIncludeTagMatchMode
        self.homeSelectedTimelineFlags = homeSelectedTimelineFlags
        self.homeTimelineIncludeFlagMatchMode = homeTimelineIncludeFlagMatchMode
        self.homeSelectedTimelineExcludedTags = homeSelectedTimelineExcludedTags
        self.homeTimelineExcludeTagMatchMode = homeTimelineExcludeTagMatchMode
        self.homeSelectedTimelineImportanceUrgencyFilter = homeSelectedTimelineImportanceUrgencyFilter
        self.homeSelectedTimelinePressureFilter = homeSelectedTimelinePressureFilter
        self.homeSelectedTimelineThinkingNeededFilter = homeSelectedTimelineThinkingNeededFilter
        self.homeSelectedTimelineEstimationFilter = homeSelectedTimelineEstimationFilter
        self.homeSelectedTimelineMediaFilter = homeSelectedTimelineMediaFilter
        self.macHomeSidebarModeRawValue = macHomeSidebarModeRawValue
        self.macSelectedSettingsSectionRawValue = macSelectedSettingsSectionRawValue
        self.timelineSelectedRange = timelineSelectedRange
        self.timelineFilterType = timelineFilterType
        self.timelineSelectedTag = timelineSelectedTag
        self.timelineSelectedTags = timelineSelectedTags ?? timelineSelectedTag.map { [$0] } ?? []
        self.timelineIncludeTagMatchMode = timelineIncludeTagMatchMode
        self.timelineSelectedFlags = timelineSelectedFlags
        self.timelineIncludeFlagMatchMode = timelineIncludeFlagMatchMode
        self.timelineExcludedTags = timelineExcludedTags
        self.timelineExcludeTagMatchMode = timelineExcludeTagMatchMode
        self.timelineSelectedImportanceUrgencyFilter = timelineSelectedImportanceUrgencyFilter
        self.timelineMediaFilter = timelineMediaFilter
        self.statsSelectedRange = statsSelectedRange
        self.statsSelectedTag = statsSelectedTag
        self.statsSelectedTags = statsSelectedTags ?? statsSelectedTag.map { [$0] } ?? []
        self.statsIncludeTagMatchMode = statsIncludeTagMatchMode
        self.statsExcludedTags = statsExcludedTags
        self.statsExcludeTagMatchMode = statsExcludeTagMatchMode
        self.statsSelectedFlags = statsSelectedFlags
        self.statsIncludeFlagMatchMode = statsIncludeFlagMatchMode
        self.statsExcludedFlags = statsExcludedFlags
        self.statsExcludeFlagMatchMode = statsExcludeFlagMatchMode
        self.statsSelectedImportanceUrgencyFilter = statsSelectedImportanceUrgencyFilter
        self.statsTaskTypeFilterRawValue = statsTaskTypeFilterRawValue
        self.statsAdvancedQuery = statsAdvancedQuery
    }

    private enum CodingKeys: String, CodingKey {
        case selectedAppTabRawValue
        case homeTaskListModeRawValue
        case homeSelectedFilter
        case homeAdvancedQuery
        case homeSelectedTag
        case homeSelectedTags
        case homeIncludeTagMatchMode
        case homeSelectedFlags
        case homeIncludeFlagMatchMode
        case homeExcludedFlags
        case homeExcludeFlagMatchMode
        case homeExcludedTags
        case homeExcludeTagMatchMode
        case homeSelectedManualPlaceFilterID
        case homeSelectedImportanceUrgencyFilter
        case homeSelectedTodoStateFilter
        case homeSelectedPressureFilter
        case homeSelectedThinkingNeededFilter
        case homeSelectedGoalFilter
        case homeSelectedMediaFilter
        case homeSelectedEstimationFilter
        case homeHideAssumedDoneTasks
        case homeTaskListViewMode
        case homeTaskListSortOrder
        case homeCreatedDateFilter
        case homeShowArchivedTasks
        case homeTabFilterSnapshots
        case hideUnavailableRoutines
        case homeSelectedTimelineRange
        case homeSelectedTimelineFilterType
        case homeSelectedTimelineStatusFilter
        case homeSelectedTimelineTag
        case homeSelectedTimelineTags
        case homeTimelineIncludeTagMatchMode
        case homeSelectedTimelineFlags
        case homeTimelineIncludeFlagMatchMode
        case homeSelectedTimelineExcludedTags
        case homeTimelineExcludeTagMatchMode
        case homeSelectedTimelineImportanceUrgencyFilter
        case homeSelectedTimelinePressureFilter
        case homeSelectedTimelineThinkingNeededFilter
        case homeSelectedTimelineEstimationFilter
        case homeSelectedTimelineMediaFilter
        case macHomeSidebarModeRawValue
        case macSelectedSettingsSectionRawValue
        case timelineSelectedRange
        case timelineFilterType
        case timelineSelectedTag
        case timelineSelectedTags
        case timelineIncludeTagMatchMode
        case timelineSelectedFlags
        case timelineIncludeFlagMatchMode
        case timelineExcludedTags
        case timelineExcludeTagMatchMode
        case timelineSelectedImportanceUrgencyFilter
        case timelineMediaFilter
        case statsSelectedRange
        case statsSelectedTag
        case statsSelectedTags
        case statsIncludeTagMatchMode
        case statsExcludedTags
        case statsExcludeTagMatchMode
        case statsSelectedFlags
        case statsIncludeFlagMatchMode
        case statsExcludedFlags
        case statsExcludeFlagMatchMode
        case statsSelectedImportanceUrgencyFilter
        case statsTaskTypeFilterRawValue
        case statsAdvancedQuery
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            selectedAppTabRawValue: try container.optional(.selectedAppTabRawValue),
            homeTaskListModeRawValue: try container.optional(.homeTaskListModeRawValue),
            homeSelectedFilter: try container.value(.homeSelectedFilter, default: .all),
            homeAdvancedQuery: try container.value(.homeAdvancedQuery, default: ""),
            homeSelectedTag: try container.optional(.homeSelectedTag),
            homeSelectedTags: try container.optional(.homeSelectedTags),
            homeIncludeTagMatchMode: try container.value(.homeIncludeTagMatchMode, default: .all),
            homeSelectedFlags: try container.value(.homeSelectedFlags, default: []),
            homeIncludeFlagMatchMode: try container.value(.homeIncludeFlagMatchMode, default: .all),
            homeExcludedFlags: try container.value(.homeExcludedFlags, default: []),
            homeExcludeFlagMatchMode: try container.value(.homeExcludeFlagMatchMode, default: .any),
            homeExcludedTags: try container.value(.homeExcludedTags, default: []),
            homeExcludeTagMatchMode: try container.value(.homeExcludeTagMatchMode, default: .any),
            homeSelectedManualPlaceFilterID: try container.optional(.homeSelectedManualPlaceFilterID),
            homeSelectedImportanceUrgencyFilter: try container.optional(.homeSelectedImportanceUrgencyFilter),
            homeSelectedTodoStateFilter: try container.optional(.homeSelectedTodoStateFilter),
            homeSelectedPressureFilter: try container.optional(.homeSelectedPressureFilter),
            homeSelectedThinkingNeededFilter: try container.optional(.homeSelectedThinkingNeededFilter),
            homeSelectedGoalFilter: try container.value(.homeSelectedGoalFilter, default: .all),
            homeSelectedMediaFilter: try container.value(.homeSelectedMediaFilter, default: .all),
            homeSelectedEstimationFilter: try container.value(.homeSelectedEstimationFilter, default: .all),
            homeHideAssumedDoneTasks: try container.value(.homeHideAssumedDoneTasks, default: false),
            homeTaskListViewMode: try container.value(.homeTaskListViewMode, default: .all),
            homeTaskListSortOrder: try container.value(.homeTaskListSortOrder, default: .smart),
            homeCreatedDateFilter: try container.value(.homeCreatedDateFilter, default: .all),
            homeShowArchivedTasks: try container.value(.homeShowArchivedTasks, default: true),
            homeTabFilterSnapshots: try container.value(.homeTabFilterSnapshots, default: [:]),
            hideUnavailableRoutines: try container.value(.hideUnavailableRoutines, default: false),
            homeSelectedTimelineRange: try container.value(.homeSelectedTimelineRange, default: .all),
            homeSelectedTimelineFilterType: try container.value(.homeSelectedTimelineFilterType, default: .all),
            homeSelectedTimelineStatusFilter: try container.value(.homeSelectedTimelineStatusFilter, default: .all),
            homeSelectedTimelineTag: try container.optional(.homeSelectedTimelineTag),
            homeSelectedTimelineTags: try container.optional(.homeSelectedTimelineTags),
            homeTimelineIncludeTagMatchMode: try container.value(.homeTimelineIncludeTagMatchMode, default: .all),
            homeSelectedTimelineFlags: try container.value(.homeSelectedTimelineFlags, default: []),
            homeTimelineIncludeFlagMatchMode: try container.value(.homeTimelineIncludeFlagMatchMode, default: .all),
            homeSelectedTimelineExcludedTags: try container.value(.homeSelectedTimelineExcludedTags, default: []),
            homeTimelineExcludeTagMatchMode: try container.value(.homeTimelineExcludeTagMatchMode, default: .any),
            homeSelectedTimelineImportanceUrgencyFilter: try container.optional(.homeSelectedTimelineImportanceUrgencyFilter),
            homeSelectedTimelinePressureFilter: try container.optional(.homeSelectedTimelinePressureFilter),
            homeSelectedTimelineThinkingNeededFilter: try container.optional(.homeSelectedTimelineThinkingNeededFilter),
            homeSelectedTimelineEstimationFilter: try container.value(.homeSelectedTimelineEstimationFilter, default: .all),
            homeSelectedTimelineMediaFilter: try container.value(.homeSelectedTimelineMediaFilter, default: .all),
            macHomeSidebarModeRawValue: try container.optional(.macHomeSidebarModeRawValue),
            macSelectedSettingsSectionRawValue: try container.optional(.macSelectedSettingsSectionRawValue),
            timelineSelectedRange: try container.value(.timelineSelectedRange, default: .all),
            timelineFilterType: try container.value(.timelineFilterType, default: .all),
            timelineSelectedTag: try container.optional(.timelineSelectedTag),
            timelineSelectedTags: try container.optional(.timelineSelectedTags),
            timelineIncludeTagMatchMode: try container.value(.timelineIncludeTagMatchMode, default: .all),
            timelineSelectedFlags: try container.value(.timelineSelectedFlags, default: []),
            timelineIncludeFlagMatchMode: try container.value(.timelineIncludeFlagMatchMode, default: .all),
            timelineExcludedTags: try container.value(.timelineExcludedTags, default: []),
            timelineExcludeTagMatchMode: try container.value(.timelineExcludeTagMatchMode, default: .any),
            timelineSelectedImportanceUrgencyFilter: try container.optional(.timelineSelectedImportanceUrgencyFilter),
            timelineMediaFilter: try container.value(.timelineMediaFilter, default: .all),
            statsSelectedRange: try container.value(.statsSelectedRange, default: .week),
            statsSelectedTag: try container.optional(.statsSelectedTag),
            statsSelectedTags: try container.optional(.statsSelectedTags),
            statsIncludeTagMatchMode: try container.value(.statsIncludeTagMatchMode, default: .all),
            statsExcludedTags: try container.value(.statsExcludedTags, default: []),
            statsExcludeTagMatchMode: try container.value(.statsExcludeTagMatchMode, default: .any),
            statsSelectedFlags: try container.value(.statsSelectedFlags, default: []),
            statsIncludeFlagMatchMode: try container.value(.statsIncludeFlagMatchMode, default: .all),
            statsExcludedFlags: try container.value(.statsExcludedFlags, default: []),
            statsExcludeFlagMatchMode: try container.value(.statsExcludeFlagMatchMode, default: .any),
            statsSelectedImportanceUrgencyFilter: try container.optional(.statsSelectedImportanceUrgencyFilter),
            statsTaskTypeFilterRawValue: try container.optional(.statsTaskTypeFilterRawValue),
            statsAdvancedQuery: try container.value(.statsAdvancedQuery, default: "")
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
        homeSelectedFlags: [],
        homeIncludeFlagMatchMode: .all,
        homeExcludedFlags: [],
        homeExcludeFlagMatchMode: .any,
        homeExcludedTags: [],
        homeExcludeTagMatchMode: .any,
        homeSelectedManualPlaceFilterID: nil,
        homeSelectedImportanceUrgencyFilter: nil,
        homeSelectedTodoStateFilter: nil,
        homeSelectedPressureFilter: nil,
        homeSelectedThinkingNeededFilter: nil,
        homeSelectedGoalFilter: .all,
        homeSelectedMediaFilter: .all,
        homeSelectedEstimationFilter: .all,
        homeHideAssumedDoneTasks: false,
        homeTaskListViewMode: .all,
        homeTaskListSortOrder: .smart,
        homeCreatedDateFilter: .all,
        homeShowArchivedTasks: true,
        homeTabFilterSnapshots: [:],
        hideUnavailableRoutines: false,
        homeSelectedTimelineRange: .all,
        homeSelectedTimelineFilterType: .all,
        homeSelectedTimelineStatusFilter: .all,
        homeSelectedTimelineTag: nil,
        homeSelectedTimelineTags: [],
        homeTimelineIncludeTagMatchMode: .all,
        homeSelectedTimelineFlags: [],
        homeTimelineIncludeFlagMatchMode: .all,
        homeSelectedTimelineExcludedTags: [],
        homeTimelineExcludeTagMatchMode: .any,
        homeSelectedTimelineImportanceUrgencyFilter: nil,
        homeSelectedTimelinePressureFilter: nil,
        homeSelectedTimelineThinkingNeededFilter: nil,
        homeSelectedTimelineEstimationFilter: .all,
        homeSelectedTimelineMediaFilter: .all,
        macHomeSidebarModeRawValue: nil,
        macSelectedSettingsSectionRawValue: nil,
        timelineSelectedRange: .all,
        timelineFilterType: .all,
        timelineSelectedTag: nil,
        timelineSelectedTags: [],
        timelineIncludeTagMatchMode: .all,
        timelineSelectedFlags: [],
        timelineIncludeFlagMatchMode: .all,
        timelineExcludedTags: [],
        timelineExcludeTagMatchMode: .any,
        timelineSelectedImportanceUrgencyFilter: nil,
        timelineMediaFilter: .all,
        statsSelectedRange: .week,
        statsSelectedTag: nil,
        statsSelectedTags: [],
        statsIncludeTagMatchMode: .all,
        statsExcludedTags: [],
        statsExcludeTagMatchMode: .any,
        statsSelectedFlags: [],
        statsIncludeFlagMatchMode: .all,
        statsExcludedFlags: [],
        statsExcludeFlagMatchMode: .any,
        statsSelectedImportanceUrgencyFilter: nil,
        statsTaskTypeFilterRawValue: nil,
        statsAdvancedQuery: ""
    )
}

private extension KeyedDecodingContainer {
    func optional<Value: Decodable>(_ key: Key) throws -> Value? {
        try decodeIfPresent(Value.self, forKey: key)
    }

    func value<Value: Decodable>(
        _ key: Key,
        default defaultValue: @autoclosure () -> Value
    ) throws -> Value {
        try decodeIfPresent(Value.self, forKey: key) ?? defaultValue()
    }
}
