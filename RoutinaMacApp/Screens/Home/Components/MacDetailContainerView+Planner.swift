import ComposableArchitecture
import SwiftUI

extension MacDetailContainerView {
    var plannerDetailContent: some View {
        GeometryReader { proxy in
            let canShowTaskDetailPane = canShowPlannerTaskDetailPane(in: proxy.size.width)
            let isHomeFilterPanePresented = shouldShowFilterDetailPane
            let isPlannerExternalPanePresented = canShowTaskDetailPane || isHomeFilterPanePresented
            let plannerContentWidth = plannerContentWidth(
                in: proxy.size.width,
                canShowTaskDetailPane: canShowTaskDetailPane
            )
            let calendarTaskFilter = plannerCalendarSharedFilter
            let calendarTaskFilterCacheSeed = plannerCalendarSharedFilterCacheSeed
            let selectedPlannerTask = selectedTaskID.flatMap { taskID in
                store.routineTasks.first { $0.id == taskID }
            }

            HStack(spacing: 0) {
                DayPlanDetailView(
                    planner: dayPlanPlanner,
                    selectedTaskID: selectedTaskID,
                    selectedTask: selectedPlannerTask,
                    isTaskDetailInspectorPresented: isPlannerExternalPanePresented,
                    macHeaderAvailableWidth: max(
                        plannerContentWidth - DayPlanWeekCalendarSizing.detailHorizontalPadding,
                        0
                    ),
                    displayMode: $dayPlanDisplayMode,
                    calendarTaskViewMode: $dayPlanCalendarTaskViewMode,
                    calendarFilters: $dayPlanCalendarFilters,
                    isCalendarFilterDetailPresented: isDayPlanCalendarFilterDetailPresented,
                    showsCalendarFilterButton: false,
                    listFilterButtonIsActive: isPlannerTimelineFilterActive,
                    listFilterButtonAccessibilityValue: plannerTimelineFilterSummary,
                    calendarSearchText: plannerSearchText,
                    calendarTaskFilter: calendarTaskFilter,
                    calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed,
                    calendarListRevealsHiddenTasks: plannerCalendarListRevealsHiddenTasks,
                    listContent: { dateJumpRequest in
                        AnyView(plannerListView(dateJumpRequest))
                    },
                    timelineActivityDates: plannerTimelineActivityDates,
                    onSelectUnplannedCompletedDate: onSelectDayPlanUnplannedCompletedDate,
                    onOpenTaskDetails: onOpenDayPlanTaskDetails,
                    onOpenCalendarListTaskDetails: onOpenDayPlanCalendarListTaskDetails,
                    onOpenEventDetails: onOpenEventDetails,
                    onCalendarFilterButtonPressed: onToggleDayPlanCalendarFilters,
                    onPlannerSidebarPresentationRequested: {
                        onCloseTaskDetails()
                        onCloseFilterDetail()
                    }
                )
                .frame(width: plannerContentWidth)
                .frame(maxHeight: .infinity)
                .clipped()

                if canShowTaskDetailPane {
                    taskDetailPane(edge: .trailing, allowsTitlePlannerDrag: true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MacHomeDetailAnimation.secondaryPane, value: shouldShowPlannerTaskDetailPane)
    }

    private func plannerContentWidth(
        in availableWidth: CGFloat,
        canShowTaskDetailPane: Bool
    ) -> CGFloat {
        guard canShowTaskDetailPane else { return availableWidth }
        return max(availableWidth - MacDetailContainerSizing.taskDetailPaneWidth, 0)
    }

    private var plannerCalendarSharedFilter: (RoutineTask) -> Bool {
        let selectedImportanceUrgencyFilter = store.selectedImportanceUrgencyFilter
        let selectedPressureFilter = store.selectedPressureFilter
        let selectedThinkingNeededFilter = store.selectedThinkingNeededFilter
        let selectedEstimationFilter = store.selectedEstimationFilter
        let selectedTags = store.selectedTags
        let includeTagMatchMode = store.includeTagMatchMode
        let excludedTags = store.excludedTags
        let excludeTagMatchMode = store.excludeTagMatchMode
        let selectedFlags = plannerCalendarSharedSelectedFlags
        let includeFlagMatchMode = plannerCalendarSharedIncludeFlagMatchMode
        let excludedFlags = store.excludedFlags
        let excludeFlagMatchMode = store.excludeFlagMatchMode
        let hasSelectedTags = !selectedTags.isEmpty
        let hasExcludedTags = !excludedTags.isEmpty
        let hasSelectedFlags = !selectedFlags.isEmpty
        let hasExcludedFlags = !excludedFlags.isEmpty
        let hasTaskLadderFilter =
            selectedImportanceUrgencyFilter != nil
            || selectedPressureFilter != nil
            || selectedThinkingNeededFilter != nil
            || selectedEstimationFilter != .all
        let referenceDate = Date()
        let filterCalendar = calendar

        guard
            hasTaskLadderFilter || hasSelectedTags || hasExcludedTags
                || hasSelectedFlags || hasExcludedFlags
        else {
            return { _ in true }
        }

        return { task in
            if hasTaskLadderFilter {
                let currentValues = RoutineTaskTemporalWeightResolver.effectiveWeights(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: filterCalendar
                )
                if !HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
                    selectedImportanceUrgencyFilter,
                    importance: currentValues.importance,
                    urgency: currentValues.urgency
                )
                    || !HomeDisplayFilterSupport.matchesMinimumPressureFilter(
                        selectedPressureFilter,
                        pressure: currentValues.pressure
                    )
                    || !HomeDisplayFilterSupport.matchesThinkingNeededFilter(
                        selectedThinkingNeededFilter,
                        thinkingNeeded: task.thinkingNeeded
                    )
                    || !HomeDisplayFilterSupport.matchesEstimationFilter(
                        selectedEstimationFilter,
                        estimatedDurationMinutes: task.estimatedDurationMinutes
                    )
                {
                    return false
                }
            }

            if !HomeDisplayFilterSupport.matchesSelectedFlags(
                selectedFlags,
                mode: includeFlagMatchMode,
                in: task.flags
            )
                || !HomeDisplayFilterSupport.matchesExcludedFlags(
                    excludedFlags,
                    mode: excludeFlagMatchMode,
                    in: task.flags
                )
            {
                return false
            }

            guard hasSelectedTags || hasExcludedTags else { return true }

            let tags = task.tags
            if !HomeDisplayFilterSupport.matchesSelectedTags(
                selectedTags,
                mode: includeTagMatchMode,
                in: tags
            ) {
                return false
            }

            return HomeDisplayFilterSupport.matchesExcludedTags(
                excludedTags,
                mode: excludeTagMatchMode,
                in: tags
            )
        }
    }

    private var plannerCalendarSharedFilterCacheSeed: Int {
        let selectedImportanceUrgencyFilter = store.selectedImportanceUrgencyFilter
        let selectedPressureFilter = store.selectedPressureFilter
        let selectedThinkingNeededFilter = store.selectedThinkingNeededFilter
        let selectedEstimationFilter = store.selectedEstimationFilter
        let selectedTags = store.selectedTags
        let includeTagMatchMode = store.includeTagMatchMode
        let excludedTags = store.excludedTags
        let excludeTagMatchMode = store.excludeTagMatchMode
        let selectedFlags = plannerCalendarSharedSelectedFlags
        let includeFlagMatchMode = plannerCalendarSharedIncludeFlagMatchMode
        let excludedFlags = store.excludedFlags
        let excludeFlagMatchMode = store.excludeFlagMatchMode

        guard
            selectedImportanceUrgencyFilter != nil
                || selectedPressureFilter != nil
                || selectedThinkingNeededFilter != nil
                || selectedEstimationFilter != .all
                || !selectedTags.isEmpty
                || !excludedTags.isEmpty
                || !selectedFlags.isEmpty
                || !excludedFlags.isEmpty
        else {
            return 0
        }

        var hasher = Hasher()
        hasher.combine(selectedImportanceUrgencyFilter)
        hasher.combine(selectedPressureFilter)
        hasher.combine(selectedThinkingNeededFilter)
        hasher.combine(selectedEstimationFilter)
        hasher.combine(calendar.startOfDay(for: Date()))
        hasher.combine(String(describing: calendar.identifier))
        hasher.combine(calendar.timeZone.identifier)
        hasher.combine(calendar.firstWeekday)
        hasher.combine(calendar.minimumDaysInFirstWeek)
        hasher.combine(selectedTags.sorted())
        hasher.combine(includeTagMatchMode.rawValue)
        hasher.combine(excludedTags.sorted())
        hasher.combine(excludeTagMatchMode.rawValue)
        hasher.combine(selectedFlags.sorted())
        hasher.combine(includeFlagMatchMode.rawValue)
        hasher.combine(excludedFlags.sorted())
        hasher.combine(excludeFlagMatchMode.rawValue)
        return hasher.finalize()
    }

    private var plannerCalendarSharedSelectedFlags: Set<String> {
        let excludedFlags = store.excludedFlags
        return Set(
            RoutineFlag.deduplicated(
                Array(store.selectedFlags) + Array(store.selectedTimelineFlags)
            )
        )
        .filter { selectedFlag in
            !HomeFlagFilterMutationSupport.contains(selectedFlag, in: excludedFlags)
        }
    }

    private var plannerCalendarSharedIncludeFlagMatchMode: RoutineTagMatchMode {
        if store.includeFlagMatchMode == store.selectedTimelineIncludeFlagMatchMode {
            return store.includeFlagMatchMode
        }
        if !store.selectedFlags.isEmpty && store.selectedTimelineFlags.isEmpty {
            return store.includeFlagMatchMode
        }
        if store.selectedFlags.isEmpty && !store.selectedTimelineFlags.isEmpty {
            return store.selectedTimelineIncludeFlagMatchMode
        }
        return .all
    }

    private var plannerCalendarListRevealsHiddenTasks: Bool {
        plannerCalendarSharedSelectedFlags.contains {
            RoutineFlag.contains(
                RoutineFlagRuleKind.hideFromCalendarList.builtInFlagName,
                in: [$0]
            )
        }
    }

    var shouldShowListTaskDetailPane: Bool {
        taskDetailPanePlacement == .listAdjacent
            && selectedTaskID != nil
            && !store.isMacFilterDetailPresented
            && mainDetailMode.visibleSurfaceMode != .details
            && mainDetailMode.visibleSurfaceMode != .planner
    }

    private var shouldShowPlannerTaskDetailPane: Bool {
        taskDetailPanePlacement == .plannerAdjacent
            && selectedTaskID != nil
            && !store.isMacFilterDetailPresented
            && mainDetailMode.visibleSurfaceMode == .planner
    }

    private func canShowPlannerTaskDetailPane(in availableWidth: CGFloat) -> Bool {
        shouldShowPlannerTaskDetailPane
            && availableWidth >= MacDetailContainerSizing.plannerTaskDetailMinWidth
    }

    func taskDetailPane(edge: Edge, allowsTitlePlannerDrag: Bool) -> some View {
        selectedTaskDetailContent(
            presentation: .companionPane,
            allowsTitlePlannerDrag: allowsTitlePlannerDrag,
            onExpandCompanion: onExpandTaskDetails,
            onCloseCompanion: onCloseTaskDetails
        )
        .frame(width: MacDetailContainerSizing.taskDetailPaneWidth)
        .frame(maxHeight: .infinity)
        .background(Color.secondary.opacity(0.045), ignoresSafeAreaEdges: [])
        .overlay(alignment: edge == .leading ? .trailing : .leading) {
            Divider()
        }
        .transition(.taskDetailPane(edge: edge))
        .zIndex(1)
    }

    var fullscreenTaskDetailEdge: Edge {
        taskDetailEdge(for: fullscreenTaskDetailReturnPlacement ?? taskDetailPanePlacement)
    }

    private func taskDetailEdge(for placement: MacTaskDetailPanePlacement?) -> Edge {
        switch placement {
        case .listAdjacent:
            return .leading
        case .plannerAdjacent, nil:
            return .trailing
        }
    }

    func secondaryPaneButton(
        systemName: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

}
