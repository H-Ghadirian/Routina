import AppKit
import Combine
import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

extension HomeTCAView {
    var effectiveMacSidebarMode: HomeFeature.MacSidebarMode {
        guard !isGoalsTabEnabled else { return store.macSidebarMode }
        return store.macSidebarMode == .goals ? .routines : store.macSidebarMode
    }

    @ViewBuilder
    var locationFilterPanel: some View {
        EmptyView()
    }

    @ViewBuilder
    var homeFiltersSheet: some View {
        EmptyView()
    }

    func matchesCurrentTaskListMode(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch store.taskListMode {
        case .all:
            return true
        case .routines:
            return task.scheduleMode.taskType == .routine
        case .todos:
            return task.isOneOffTask
        }
    }

    var macAvailableFilters: [RoutineListFilter] {
        macHomeFilterPresentation.availableStatusFilters
    }

    var macPlaceFilterOptions: [MacPlaceFilterOption] {
        guard isPlacesEnabled else { return [] }
        return MacPlaceFilterOptionFactory.options(
            places: sortedRoutinePlaces,
            displays: store.routineDisplays
                + store.awayRoutineDisplays
                + store.archivedRoutineDisplays,
            taskListMode: store.taskListMode,
            locationSnapshot: store.locationSnapshot
        )
    }

    var platformTimelineRangePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Range",
            options: TimelineRange.allCases,
            selection: Binding(
                get: { store.selectedTimelineRange },
                set: { store.send(.selectedTimelineRangeChanged($0)) }
            )
        ) { range in
            Text(range.rawValue)
        }
    }

    @ViewBuilder
    var platformTimelineTypePicker: some View {
        if areMacTimelineQuickFiltersVisible {
            TimelinePigmentControl(
                selection: Binding(
                    get: {
                        store.selectedTimelineFilterType.normalized(
                            includingEventEmotion: areMacEventEmotionActionsEnabled,
                            includingPlaces: isPlacesEnabled,
                            includingNotes: isNotesEnabled,
                            includingAway: isAwayEnabled,
                            includingSleep: includesMacSleepTimelineFilters
                        )
                    },
                    set: {
                        store.send(
                            .selectedTimelineFilterTypeChanged(
                                $0.normalized(
                                    includingEventEmotion: areMacEventEmotionActionsEnabled,
                                    includingPlaces: isPlacesEnabled,
                                    includingNotes: isNotesEnabled,
                                    includingAway: isAwayEnabled,
                                    includingSleep: includesMacSleepTimelineFilters
                                )
                            ))
                    }
                ),
                includesEventEmotion: areMacEventEmotionActionsEnabled,
                includesPlaces: isPlacesEnabled,
                includesNotes: isNotesEnabled,
                includesAway: isAwayEnabled,
                includesSleep: includesMacSleepTimelineFilters
            )
        }
    }

    @ViewBuilder
    var platformTagFilterBar: some View {
        let showsFlagFilters = !isMacBoardSidebarPresented && homeFlagFilterData.hasFlags
        if homeTagFilterData.hasTags || showsFlagFilters {
            VStack(alignment: .leading, spacing: 16) {
                if homeTagFilterData.hasTags {
                    HomeMacRoutineTagFiltersView(
                        bindings: homeFilterBindings.tagRules,
                        data: homeTagFilterData,
                        actions: homeTagFilterActions
                    )
                }

                if showsFlagFilters {
                    HomeMacRoutineFlagFiltersView(
                        includeFlagMatchMode: homeFilterBindings.includeFlagMatchMode,
                        data: homeFlagFilterData,
                        actions: homeFlagFilterActions
                    )
                }
            }
        }
    }

    @ViewBuilder
    var platformFlagFilterBar: some View {
        if !isMacBoardSidebarPresented, homeFlagFilterData.hasFlags {
            HomeMacRoutineFlagFiltersView(
                includeFlagMatchMode: homeFilterBindings.includeFlagMatchMode,
                data: homeFlagFilterData,
                actions: homeFlagFilterActions
            )
        }
    }

    @ViewBuilder
    var platformCompactHomeHeader: some View {
        EmptyView()
    }

    var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isDeleteConfirmationPresented },
            set: { store.send(.setDeleteConfirmation($0)) }
        )
    }

    var deleteConfirmationTitle: String {
        store.pendingDeleteTaskIDs.count == 1 ? "Delete task?" : "Delete tasks?"
    }

    var deleteConfirmationMessage: String {
        guard store.pendingDeleteTaskIDs.count == 1 else {
            return "This will permanently remove \(store.pendingDeleteTaskIDs.count) tasks and their logs."
        }

        let taskID = store.pendingDeleteTaskIDs[0]
        let routineName = store.routineTasks.first(where: { $0.id == taskID })?.name ?? "this task"
        return "This will permanently remove \(routineName) and its logs."
    }

}
