import Foundation

extension AppFeature {
    func performanceInteraction(
        for action: Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case let .tabSelected(tab):
            return RoutinaPerformanceInteraction.navigationTab(named: tab.rawValue)

        case let .home(homeAction):
            return performanceInteraction(for: homeAction)

        case let .timeline(timelineAction):
            return performanceInteraction(for: timelineAction)

        case let .stats(statsAction):
            return performanceInteraction(for: statsAction)

        case .settings(.syncNowTapped):
            return .settingsSyncRequested
        case .settings(.exportRoutineDataTapped):
            return .settingsBackupExportRequested

        default:
            return nil
        }
    }

    private func performanceInteraction(
        for action: HomeFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        navigationPerformanceInteraction(for: action)
            ?? filterPerformanceInteraction(for: action)
            ?? taskPerformanceInteraction(for: action)
    }

    private func navigationPerformanceInteraction(
        for action: HomeFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .manualRefreshRequested:
            return .manualRefreshRequested
        case .setSelectedTask(.some):
            return .taskDetailOpened
        case .setSelectedTask(.none):
            return .taskDetailClosed
        case .setAddRoutineSheet(true), .openAddTaskSheet, .openAddTaskInCustomSection:
            return .taskComposerOpened
        case .setAddRoutineSheet(false):
            return .taskComposerClosed
        case .taskListModeChanged, .taskListModeFilterChanged:
            return .taskListModeChanged
        case let .macSidebarModeChanged(mode):
            return RoutinaPerformanceInteraction.macSidebar(named: mode.rawValue)
        default:
            return nil
        }
    }

    private func filterPerformanceInteraction(
        for action: HomeFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .setMacFilterDetailPresented(true):
            return .homeFilterOpened
        case .setMacFilterDetailPresented(false):
            return nil
        case .clearTaskListAndSharedFilters:
            return .homeFilterCleared
        case .clearTimelineAndSharedFilters:
            return .timelineFilterCleared
        case .selectedFilterChanged,
            .advancedQueryChanged,
            .selectedTagChanged,
            .selectedTagsChanged,
            .taskDetailTagFilterTapped,
            .includeTagMatchModeChanged,
            .selectedFlagsChanged,
            .includeFlagMatchModeChanged,
            .excludedFlagsChanged,
            .excludeFlagMatchModeChanged,
            .excludedTagsChanged,
            .excludeTagMatchModeChanged,
            .selectedManualPlaceFilterIDChanged,
            .selectedImportanceUrgencyFilterChanged,
            .selectedTodoStateFilterChanged,
            .selectedPressureFilterChanged,
            .selectedThinkingNeededFilterChanged,
            .selectedGoalFilterChanged,
            .selectedMediaFilterChanged,
            .selectedEstimationFilterChanged,
            .hideAssumedDoneTasksChanged,
            .taskListViewModeChanged,
            .taskListSortOrderChanged,
            .createdDateFilterChanged,
            .showArchivedTasksChanged:
            return .homeFilterChanged
        default:
            return nil
        }
    }

    private func taskPerformanceInteraction(
        for action: HomeFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .markTaskDone, .confirmAssumedTaskDone:
            return .taskMarkedDone
        case .markTaskMissed, .markAssumedTaskMissed:
            return .taskMarkedMissed
        case .markTaskCanceled:
            return .taskMarkedCanceled
        case .pauseTask:
            return .taskPaused
        case .resumeTask:
            return .taskResumed
        case .planTask:
            return .taskPlanned
        default:
            return nil
        }
    }

    private func performanceInteraction(
        for action: TimelineFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .setFilterSheet(true):
            return .timelineFilterOpened
        case .clearFilters:
            return .timelineFilterCleared
        case .selectedRangeChanged,
            .filterTypeChanged,
            .selectedTagChanged,
            .selectedTagsChanged,
            .includeTagMatchModeChanged,
            .excludedTagsChanged,
            .excludeTagMatchModeChanged,
            .selectedFlagsChanged,
            .includeFlagMatchModeChanged,
            .selectedImportanceUrgencyFilterChanged,
            .mediaFilterChanged:
            return .timelineFilterChanged
        default:
            return nil
        }
    }

    private func performanceInteraction(
        for action: StatsFeature.Action
    ) -> RoutinaPerformanceInteraction? {
        switch action {
        case .clearFilters:
            return .statsFilterCleared
        case .selectedRangeChanged,
            .taskTypeFilterChanged,
            .createdChartTaskTypeFilterChanged,
            .selectedTagChanged,
            .selectedTagsChanged,
            .includeTagMatchModeChanged,
            .advancedQueryChanged,
            .selectedImportanceUrgencyFilterChanged,
            .excludedTagsChanged,
            .excludeTagMatchModeChanged,
            .selectedFlagsChanged,
            .includeFlagMatchModeChanged,
            .excludedFlagsChanged,
            .excludeFlagMatchModeChanged:
            return .statsFilterChanged
        default:
            return nil
        }
    }

}
