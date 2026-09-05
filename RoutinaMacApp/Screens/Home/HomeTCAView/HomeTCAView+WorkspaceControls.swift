import SwiftUI

extension HomeTCAView {
    var persistedDayPlanDisplayModeBinding: Binding<DayPlanDisplayMode> {
        Binding(
            get: { dayPlanDisplayMode },
            set: { mode in
                dayPlanDisplayMode = mode
                MacPlannerPresentationPreferencesStore.update { preferences in
                    preferences.displayMode = mode
                }
            }
        )
    }

    var persistedDayPlanCalendarTaskViewModeBinding: Binding<DayPlanCalendarTaskViewMode> {
        Binding(
            get: { dayPlanCalendarTaskViewMode },
            set: { mode in
                dayPlanCalendarTaskViewMode = mode
                MacPlannerPresentationPreferencesStore.update { preferences in
                    preferences.calendarTaskViewMode = mode
                }
            }
        )
    }

    var homeToolbarControlSummary: WorkspaceControlSummary {
        if isMacBacklogMode {
            return backlogStore.filters.workspaceControlSummary.appending(
                backlogRowVisibility == .backlogDefaultValue
                    ? nil
                    : .init(category: .appearance, title: "Custom row")
            )
        }
        if isMacTaskLadderMode {
            return taskRankingStore.workspaceControlSummary.appending(
                taskLadderRowVisibility == .taskLadderDefaultValue
                    ? nil
                    : .init(category: .appearance, title: "Custom row")
            )
        }
        guard isMacRoutinesMode else { return .empty }
        var summary = macHomeFilterPresentation.workspaceControlSummary
        if macFilterScopeIsActive(.timeline) {
            summary.items.append(.init(category: .filter, title: "Timeline filters"))
        }
        if macFilterScopeIsActive(.calendar) {
            summary.items.append(.init(category: .filter, title: "Calendar filters"))
        }
        return summary.appending(
            taskRowVisibility == .defaultValue
                ? nil
                : .init(category: .appearance, title: "Custom row")
        )
    }

    func toggleHomeToolbarFilters() {
        if isMacBacklogMode || isMacTaskLadderMode {
            if store.isMacFilterDetailPresented {
                closeMacFilterDetailPane()
            } else {
                macWorkspaceControlInitialTab = initialMacWorkspaceControlTab
                withAnimation(MacHomeDetailAnimation.secondaryPane) {
                    isMacFilterDetailFullscreen = false
                    store.send(.setMacFilterDetailPresented(true))
                }
            }
            return
        }

        guard isMacRoutinesMode else { return }
        if !homeToolbarControlSummary.isEmpty {
            toggleMacHomeFilterDetail(scope: preferredMacHomeFilterScope)
            return
        }
        toggleMacCalendarFilterDetailFromPlanner()
    }

    private var backlogRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: backlogTaskRowHiddenFieldsRawValue)
    }

    private var taskLadderRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: taskLadderTaskRowHiddenFieldsRawValue)
    }

    private var preferredMacHomeFilterScope: HomeMacFilterDetailScope {
        if macFilterScopeIsActive(.taskList) || taskRowVisibility != .defaultValue {
            return .taskList
        }
        if macFilterScopeIsActive(.timeline) {
            return .timeline
        }
        if macFilterScopeIsActive(.calendar) {
            return .calendar
        }
        return .both
    }

    private func toggleMacHomeFilterDetail(scope: HomeMacFilterDetailScope) {
        if store.isMacFilterDetailPresented && macFilterDetailScope == scope {
            closeMacFilterDetailPane()
            return
        }

        macFilterDetailScope = scope
        withAnimation(MacHomeDetailAnimation.secondaryPane) {
            isMacFilterDetailFullscreen = false
            taskDetailPanePlacement = nil
            store.send(.setMacFilterDetailPresented(true))
        }
    }

    private var initialMacWorkspaceControlTab: HomeMacFilterDetailTab {
        if isMacBacklogMode {
            if backlogStore.filters.hasNonDefaultFilters { return .filter }
            if backlogStore.filters.hasNonDefaultSortOrder { return .sort }
            if backlogRowVisibility != .backlogDefaultValue { return .appearance }
        }
        if isMacTaskLadderMode {
            if taskRankingStore.hasNonDefaultViewControls { return .filter }
            if taskRankingStore.hasNonDefaultSortControls { return .sort }
            if taskLadderRowVisibility != .taskLadderDefaultValue { return .appearance }
        }
        switch homeToolbarControlSummary.preferredCategory {
        case .sort:
            return .sort
        case .appearance:
            return .appearance
        case .filter, .view, nil:
            return .filter
        }
    }
}
