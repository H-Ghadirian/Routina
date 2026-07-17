import ComposableArchitecture
import SwiftUI

enum MacDetailContainerSizing {
    static let plannerContentMinWidth: CGFloat = DayPlanWeekCalendarSizing.minimumDetailWidth(
        isExternalInspectorPresented: false
    )
    static let plannerInspectorContentMinWidth: CGFloat = DayPlanWeekCalendarSizing.minimumDetailWidth(
        isExternalInspectorPresented: true
    )
    static let taskDetailPaneWidth: CGFloat = 420
    static let filterDetailPaneWidth: CGFloat = 420
    static let plannerTaskDetailMinWidth: CGFloat = plannerInspectorContentMinWidth + taskDetailPaneWidth
    static let boardInspectorWidth: CGFloat = 400
}

enum MacHomeDetailAnimation {
    static let taskDetailSurface = Animation.spring(
        response: 0.34,
        dampingFraction: 0.88,
        blendDuration: 0.08
    )

    static let secondaryPane = Animation.spring(
        response: 0.28,
        dampingFraction: 0.9,
        blendDuration: 0.05
    )
}

/// Separate View struct so SwiftUI gives it its own observation lifecycle.
/// Inline closures inside `NavigationSplitView.detail` on macOS can lose
/// observation tracking after several view swaps, causing state changes
/// (like toggling the filter panel) to stop updating the detail column.
struct MacDetailContainerView<FilterView: View, PlannerListView: View, BoardView: View, BoardInspectorView: View>: View {
    let store: StoreOf<HomeFeature>
    let isBoardPresented: Bool
    let isTimelinePresented: Bool
    let isStatsPresented: Bool
    let currentProgressMode: MacHomeProgressMode
    let isSettingsPresented: Bool
    let settingsStore: StoreOf<SettingsFeature>
    let statsStore: StoreOf<StatsFeature>?
    @Binding var selectedStatsDashboardScope: StatsDashboardScope
    let selectedSettingsSection: SettingsMacSection
    let dayPlanPlanner: DayPlanPlannerState
    let adventureProgression: HomeAdventureProgression?
    let showsPlaces: Bool
    @Binding var mainDetailMode: MacHomeDetailMode
    @Binding var dayPlanDisplayMode: DayPlanDisplayMode
    @Binding var dayPlanCalendarTaskViewMode: DayPlanCalendarTaskViewMode
    @Binding var dayPlanCalendarFilters: DayPlanCalendarFilterState
    let isDayPlanCalendarFilterDetailPresented: Bool
    let plannerTimelineActivityDates: [Date]
    let isPlannerTimelineFilterActive: Bool
    let plannerTimelineFilterSummary: String?
    let plannerSearchText: String
    let focusStartTaskCount: Int
    let activePlanFocusSession: FocusSession?
    let isPlanFocusStartDisabled: Bool
    @Binding var isBoardInspectorPresented: Bool
    @Binding var taskDetailPanePlacement: MacTaskDetailPanePlacement?
    @Binding var placeCheckInSelectedPlaceID: UUID?
    @Binding var placeCheckInSelectedHistoryMarkerID: PlaceCheckInHistoryMapMarker.ID?
    let selectedTaskID: UUID?
    let selectedTimelineEntry: TimelineEntry?
    let selectedTimelineEmotion: EmotionLog?
    let selectedTimelineEvent: RoutineEvent?
    let selectedTimelineNote: RoutineNote?
    let selectedTimelineNoteAttachments: [RoutineNoteAttachment]
    let selectedTimelinePlaceCheckInSession: PlaceCheckInSession?
    let selectedTimelineAwaySession: AwaySession?
    let onSelectDayPlanUnplannedCompletedDate: (Date) -> Void
    let onOpenDayPlanTaskDetails: (UUID) -> Void
    let onOpenEventDetails: (UUID) -> Void
    let onToggleDayPlanCalendarFilters: () -> Void
    let onTaskFocusDurationSelected: (TimeInterval) -> Void
    let onPausePlanFocus: (FocusSession) -> Void
    let onResumePlanFocus: (FocusSession) -> Void
    let onFinishPlanFocus: (FocusSession) -> Void
    let onAbandonPlanFocus: (FocusSession) -> Void
    let onEditNote: (UUID) -> Void
    let onDeleteNote: (UUID) -> Void
    let onToggleBoardInspector: () -> Void
    let onExpandTaskDetails: () -> Void
    let fullscreenTaskDetailReturnPlacement: MacTaskDetailPanePlacement?
    let onMinimizeFullscreenTaskDetails: (() -> Void)?
    let onCloseTaskDetails: () -> Void
    let onCloseFullscreenTaskDetails: () -> Void
    let isFilterDetailFullscreen: Bool
    let onExpandFilterDetail: () -> Void
    let onMinimizeFullscreenFilterDetail: (() -> Void)?
    let onCloseFilterDetail: () -> Void
    let addRoutineStore: StoreOf<AddRoutineFeature>?
    @ViewBuilder let filterView: () -> FilterView
    @ViewBuilder let plannerListView: (DayPlanTimelineDateJumpRequest?) -> PlannerListView
    @ViewBuilder let boardView: () -> BoardView
    @ViewBuilder let boardInspectorView: () -> BoardInspectorView

    var body: some View {
        detailContent
            .clipped()
            .toolbar {
                if shouldShowBoardInspectorToolbarButton {
                    ToolbarItem(placement: .primaryAction) {
                        HomeMacBoardInspectorToolbarButton(
                            isPresented: isBoardInspectorPresented,
                            onToggle: onToggleBoardInspector
                        )
                    }
                }
            }
    }

    @ViewBuilder
    private var detailContent: some View {
        Group {
            if shouldShowFullscreenFilterDetail {
                fullscreenFilterDetailContent
            } else if isBoardPresented {
                detailContentWithOptionalFilterPane {
                    boardDetailContent
                }
            } else {
                detailContentWithOptionalFilterPane {
                    if let addRoutineStore {
                        AddRoutineTCAView(store: addRoutineStore)
                    } else if isStatsPresented {
                        progressDetailContent
                    } else if isSettingsPresented {
                        EmbeddedSettingsMacDetailView(
                            store: settingsStore,
                            section: selectedSettingsSection
                        )
                    } else if isTimelinePresented {
                        timelineDetailContent
                    } else {
                        mainDetailContent
                    }
                }
            }
        }
    }

    private var shouldShowFullscreenFilterDetail: Bool {
        store.isMacFilterDetailPresented && isFilterDetailFullscreen
    }

    private var shouldShowFilterDetailPane: Bool {
        store.isMacFilterDetailPresented && !isFilterDetailFullscreen
    }

    private func detailContentWithOptionalFilterPane<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { proxy in
            let filterPaneWidth = shouldShowFilterDetailPane
                ? MacDetailContainerSizing.filterDetailPaneWidth
                : 0
            let contentWidth = max(proxy.size.width - filterPaneWidth, 0)

            HStack(spacing: 0) {
                content()
                    .frame(width: contentWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()

                if shouldShowFilterDetailPane {
                    filterDetailPane
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MacHomeDetailAnimation.secondaryPane, value: shouldShowFilterDetailPane)
    }

    private var filterDetailPane: some View {
        VStack(spacing: 0) {
            filterDetailPaneHeader
            Divider()
            filterView()
        }
        .frame(width: MacDetailContainerSizing.filterDetailPaneWidth)
        .frame(maxHeight: .infinity)
        .background(Color.secondary.opacity(0.045), ignoresSafeAreaEdges: [])
        .overlay(alignment: .leading) {
            Divider()
        }
        .transition(.taskDetailPane(edge: .trailing))
        .zIndex(1)
    }

    private var filterDetailPaneHeader: some View {
        HStack(spacing: 10) {
            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            secondaryPaneButton(
                systemName: "arrow.up.left.and.arrow.down.right",
                title: "Open Fullscreen"
            ) {
                onExpandFilterDetail()
            }

            secondaryPaneButton(
                systemName: "xmark",
                title: "Close"
            ) {
                onCloseFilterDetail()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var fullscreenFilterDetailContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let onMinimizeFullscreenFilterDetail {
                    secondaryPaneButton(
                        systemName: "arrow.down.right.and.arrow.up.left",
                        title: "Minimize"
                    ) {
                        onMinimizeFullscreenFilterDetail()
                    }
                }

                secondaryPaneButton(
                    systemName: "xmark",
                    title: "Close"
                ) {
                    onCloseFilterDetail()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            filterView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.taskDetailFullscreen(edge: .trailing))
    }
    @ViewBuilder
    private var mainDetailContent: some View {
        HStack(spacing: 0) {
            if shouldShowListTaskDetailPane {
                taskDetailPane(edge: .leading, allowsTitlePlannerDrag: false)
            }

            mainDetailBody
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MacHomeDetailAnimation.secondaryPane, value: shouldShowListTaskDetailPane)
    }

    @ViewBuilder
    private var mainDetailBody: some View {
        Group {
            switch mainDetailMode.visibleSurfaceMode {
            case .details:
                selectedTaskDetailContent(
                    allowsTitlePlannerDrag: fullscreenTaskDetailReturnPlacement == .plannerAdjacent,
                    onMinimizeFullscreen: onMinimizeFullscreenTaskDetails,
                    onCloseFullscreen: onCloseFullscreenTaskDetails
                )
                .transition(.taskDetailFullscreen(edge: fullscreenTaskDetailEdge))
                .zIndex(2)
            case .planner:
                plannerDetailContent
                    .transition(.taskDetailWorkspace)
                    .zIndex(0)
            case .board:
                boardDetailContent
            case .places:
                if showsPlaces {
                    placesDetailContent
                } else {
                    selectedTaskDetailContent()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var plannerDetailContent: some View {
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
                    listFilterButtonIsActive: isPlannerTimelineFilterActive,
                    listFilterButtonAccessibilityValue: plannerTimelineFilterSummary,
                    calendarSearchText: plannerSearchText,
                    calendarTaskFilter: calendarTaskFilter,
                    calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed,
                    macHeaderFocusControl: {
                        AnyView(plannerHeaderFocusControl)
                    },
                    listContent: { dateJumpRequest in
                        AnyView(plannerListView(dateJumpRequest))
                    },
                    timelineActivityDates: plannerTimelineActivityDates,
                    onSelectUnplannedCompletedDate: onSelectDayPlanUnplannedCompletedDate,
                    onOpenTaskDetails: onOpenDayPlanTaskDetails,
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
        let selectedTags = store.selectedTags
        let includeTagMatchMode = store.includeTagMatchMode
        let excludedTags = store.excludedTags
        let excludeTagMatchMode = store.excludeTagMatchMode
        let hasSelectedTags = !selectedTags.isEmpty
        let hasExcludedTags = !excludedTags.isEmpty

        guard selectedImportanceUrgencyFilter != nil || hasSelectedTags || hasExcludedTags else {
            return { _ in true }
        }

        return { task in
            if !HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
                selectedImportanceUrgencyFilter,
                importance: task.importance,
                urgency: task.urgency
            ) {
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
        let selectedTags = store.selectedTags
        let includeTagMatchMode = store.includeTagMatchMode
        let excludedTags = store.excludedTags
        let excludeTagMatchMode = store.excludeTagMatchMode

        guard selectedImportanceUrgencyFilter != nil || !selectedTags.isEmpty || !excludedTags.isEmpty else {
            return 0
        }

        var hasher = Hasher()
        hasher.combine(selectedImportanceUrgencyFilter)
        hasher.combine(selectedTags.sorted())
        hasher.combine(includeTagMatchMode.rawValue)
        hasher.combine(excludedTags.sorted())
        hasher.combine(excludeTagMatchMode.rawValue)
        return hasher.finalize()
    }

    @ViewBuilder
    private var plannerHeaderFocusControl: some View {
        if let activePlanFocusSession {
            HomeMacActivePlanFocusToolbarButton(
                session: activePlanFocusSession,
                onPause: onPausePlanFocus,
                onResume: onResumePlanFocus,
                onFinish: onFinishPlanFocus,
                onAbandon: onAbandonPlanFocus,
                trailingPadding: 0
            )
        } else if isPlanFocusStartDisabled {
            RoutinaMacFocusTimerToolbarBadge(
                hiddenKinds: [.unassigned]
            )
        } else if focusStartTaskCount > 0 {
            HomeMacPlanFocusToolbarButton(
                focusStartTaskCount: focusStartTaskCount,
                isDisabled: isPlanFocusStartDisabled,
                onTaskFocusDurationSelected: onTaskFocusDurationSelected,
                trailingPadding: 0
            )
        }
    }

    private var shouldShowListTaskDetailPane: Bool {
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

    private func taskDetailPane(edge: Edge, allowsTitlePlannerDrag: Bool) -> some View {
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

    private var fullscreenTaskDetailEdge: Edge {
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

    private func secondaryPaneButton(
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

    private var placesDetailContent: some View {
        PlaceCheckInMapSheet(
            showsNavigationChrome: false,
            showsInlineHeader: false,
            layout: .mapOnly,
            selectedPlaceID: $placeCheckInSelectedPlaceID,
            selectedHistoryMarkerID: $placeCheckInSelectedHistoryMarkerID
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var boardDetailContent: some View {
        HStack(spacing: 0) {
            boardView()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)

            if isBoardInspectorPresented && !store.isMacFilterDetailPresented {
                boardInspectorView()
                    .frame(width: MacDetailContainerSizing.boardInspectorWidth)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .leading) {
                        Divider()
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isBoardInspectorPresented)
        .animation(MacHomeDetailAnimation.secondaryPane, value: store.isMacFilterDetailPresented)
    }

    private var shouldShowDetailModePicker: Bool {
        !store.isMacFilterDetailPresented
            && !isBoardPresented
            && !isTimelinePresented
            && !isStatsPresented
            && !isSettingsPresented
            && addRoutineStore == nil
    }

    private var shouldShowBoardInspectorToolbarButton: Bool {
        shouldShowDetailModePicker && mainDetailMode == .board
    }

    @ViewBuilder
    private var progressDetailContent: some View {
        switch currentProgressMode {
        case .adventure:
            if let adventureProgression {
                HomeMacAdventureView(progression: adventureProgression)
            } else {
                ContentUnavailableView(
                    "Adventure unavailable",
                    systemImage: "sparkles",
                    description: Text("Adventure progress is not currently available for this view.")
                )
            }
        case .stats:
            if let statsStore {
            StatsViewWrapper(
                store: statsStore,
                selectedDashboardScope: $selectedStatsDashboardScope,
                showsFocusTimerToolbarItem: false
            )
        } else {
            ContentUnavailableView(
                "Stats unavailable",
                systemImage: "chart.bar.xaxis",
                description: Text("The stats store is not currently connected for this view.")
            )
        }
        }
    }

    @ViewBuilder
    private var timelineDetailContent: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false,
                onOpenEventDetails: onOpenEventDetails
            )
        } else if let selectedTimelineEmotion {
            EmotionLogDetailView(emotion: selectedTimelineEmotion)
        } else if let selectedTimelineEvent {
            RoutineEventDetailView(event: selectedTimelineEvent)
        } else if let selectedTimelineNote {
            RoutineNoteDetailView(
                note: selectedTimelineNote,
                attachments: selectedTimelineNoteAttachments,
                onEdit: { onEditNote(selectedTimelineNote.id) },
                onDelete: { onDeleteNote(selectedTimelineNote.id) }
            )
        } else if showsPlaces, let selectedTimelinePlaceCheckInSession {
            PlaceCheckInSessionDetailView(session: selectedTimelinePlaceCheckInSession)
        } else if let selectedTimelineAwaySession {
            AwaySessionEditSheet(session: selectedTimelineAwaySession)
                .id(selectedTimelineAwaySession.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isSleep {
            ContentUnavailableView(
                "Sleep record",
                systemImage: "bed.double.fill",
                description: Text("Sleep detail is not available yet.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isFocus {
            ContentUnavailableView(
                "Focus record",
                systemImage: "timer",
                description: Text(timelineFocusSubtitle(for: selectedTimelineEntry))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Select a timeline entry or filters",
                systemImage: "clock.arrow.circlepath",
                description: Text(timelineEmptyDescription)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var timelineEmptyDescription: String {
        showsPlaces
            ? "Choose a task, note, or place check-in from the sidebar, or open filters beside search to refine the timeline."
            : "Choose a task or note from the sidebar, or open filters beside search to refine the timeline."
    }

    private func timelineFocusSubtitle(for entry: TimelineEntry) -> String {
        let startedAt = entry.startTimestamp ?? entry.timestamp
        let range: String
        if let endedAt = entry.endTimestamp {
            range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
        } else {
            range = "Since \(startedAt.formatted(date: .omitted, time: .shortened))"
        }
        let duration = entry.durationSeconds.map { FocusSessionFormatting.compactDurationText(seconds: $0) }
        return [range, duration, entry.activityTitle].compactMap(\.self).joined(separator: " · ")
    }

    @ViewBuilder
    private func selectedTaskDetailContent(
        presentation: TaskDetailTCAView.Presentation = .fullDetail,
        allowsTitlePlannerDrag: Bool = false,
        onExpandCompanion: (() -> Void)? = nil,
        onCloseCompanion: (() -> Void)? = nil,
        onMinimizeFullscreen: (() -> Void)? = nil,
        onCloseFullscreen: (() -> Void)? = nil
    ) -> some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false,
                allowsTitlePlannerDrag: allowsTitlePlannerDrag,
                presentation: presentation,
                onExpandCompanion: onExpandCompanion,
                onCloseCompanion: onCloseCompanion,
                onMinimizeFullscreen: onMinimizeFullscreen,
                onCloseFullscreen: onCloseFullscreen,
                onOpenEventDetails: onOpenEventDetails
            )
        } else {
            ContentUnavailableView(
                store.routineTasks.isEmpty ? "Add a task to get started" : "Select a task",
                systemImage: "sidebar.right",
                description: Text(
                    store.routineTasks.isEmpty
                        ? "Add a routine or to-do to see its details here."
                        : "Choose a routine or to-do from the sidebar to see its details."
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct MacHomeProgressModePicker: View {
    @Binding var selection: MacHomeProgressMode

    var body: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Progress mode",
            options: MacHomeProgressMode.visibleModes,
            selection: $selection,
            minimumSegmentWidth: 92,
            fillsAvailableWidth: true
        ) { mode in
            Text(mode.rawValue)
        }
        .frame(width: 260)
    }
}

private extension AnyTransition {
    static func taskDetailFullscreen(edge: Edge) -> AnyTransition {
        .identity
    }

    static func taskDetailPane(edge: Edge) -> AnyTransition {
        .identity
    }

    static var taskDetailWorkspace: AnyTransition {
        .identity
    }
}
