import Foundation

/// Stores and restores per-tab filter state so that switching between
/// the Routines and Todos tabs doesn't wipe filters the user already set.
struct TabFilterStateManager {

    struct Snapshot: Equatable, Codable, Sendable {
        var selectedTag: String?
        var excludedTags: Set<String>
        var selectedFilter: RoutineListFilter
        var selectedManualPlaceFilterID: UUID?

        static var `default`: Snapshot {
            Snapshot(
                selectedTag: nil,
                excludedTags: [],
                selectedFilter: .all,
                selectedManualPlaceFilterID: nil
            )
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
    var homeTabFilterSnapshots: [String: TabFilterStateManager.Snapshot]
    var hideUnavailableRoutines: Bool
    var homeSelectedTimelineRange: TimelineRange
    var homeSelectedTimelineFilterType: TimelineFilterType
    var homeSelectedTimelineTag: String?
    var homeSelectedTimelineExcludedTags: Set<String> = []
    var macHomeSidebarModeRawValue: String?
    var macSelectedSettingsSectionRawValue: String?
    var timelineSelectedRange: TimelineRange
    var timelineFilterType: TimelineFilterType
    var timelineSelectedTag: String?
    var statsSelectedRange: DoneChartRange
    var statsSelectedTag: String?
    var statsExcludedTags: Set<String>
    var statsTaskTypeFilterRawValue: String?

    static let `default` = TemporaryViewState(
        selectedAppTabRawValue: Tab.home.rawValue,
        homeTaskListModeRawValue: nil,
        homeSelectedFilter: .all,
        homeSelectedTag: nil,
        homeExcludedTags: [],
        homeSelectedManualPlaceFilterID: nil,
        homeTabFilterSnapshots: [:],
        hideUnavailableRoutines: false,
        homeSelectedTimelineRange: .all,
        homeSelectedTimelineFilterType: .all,
        homeSelectedTimelineTag: nil,
        homeSelectedTimelineExcludedTags: [],
        macHomeSidebarModeRawValue: nil,
        macSelectedSettingsSectionRawValue: nil,
        timelineSelectedRange: .all,
        timelineFilterType: .all,
        timelineSelectedTag: nil,
        statsSelectedRange: .week,
        statsSelectedTag: nil,
        statsExcludedTags: [],
        statsTaskTypeFilterRawValue: nil
    )
}
