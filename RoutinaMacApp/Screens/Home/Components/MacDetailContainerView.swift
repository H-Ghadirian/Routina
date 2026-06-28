import ComposableArchitecture
import SwiftUI

private enum MacDetailContainerSizing {
    static let plannerContentMinWidth: CGFloat = 520
    static let plannerInspectorContentMinWidth: CGFloat = 400
    static let taskDetailPaneWidth: CGFloat = 420
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
    let onEditNote: (UUID) -> Void
    let onDeleteNote: (UUID) -> Void
    let onToggleBoardInspector: () -> Void
    let onExpandTaskDetails: () -> Void
    let fullscreenTaskDetailReturnPlacement: MacTaskDetailPanePlacement?
    let onMinimizeFullscreenTaskDetails: (() -> Void)?
    let onCloseTaskDetails: () -> Void
    let onCloseFullscreenTaskDetails: () -> Void
    let addRoutineStore: StoreOf<AddRoutineFeature>?
    @ViewBuilder let filterView: () -> FilterView
    @ViewBuilder let plannerListView: () -> PlannerListView
    @ViewBuilder let boardView: () -> BoardView
    @ViewBuilder let boardInspectorView: () -> BoardInspectorView
    @Namespace private var taskDetailSurfaceNamespace

    var body: some View {
        Group {
            if store.isMacFilterDetailPresented {
                filterView()
            } else if isBoardPresented {
                boardDetailContent
            } else if let addRoutineStore {
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
    private var mainDetailContent: some View {
        HStack(spacing: 0) {
            if shouldShowListTaskDetailPane {
                taskDetailPane(edge: .leading)
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
                    onMinimizeFullscreen: onMinimizeFullscreenTaskDetails,
                    onCloseFullscreen: onCloseFullscreenTaskDetails
                )
                .taskDetailSurfaceMotion(
                    id: taskDetailSurfaceMotionID,
                    namespace: taskDetailSurfaceNamespace,
                    edge: fullscreenTaskDetailEdge,
                    isActive: shouldMatchTaskDetailSurface
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

            HStack(spacing: 0) {
                DayPlanDetailView(
                    planner: dayPlanPlanner,
                    selectedTaskID: selectedTaskID,
                    isTaskDetailInspectorPresented: canShowTaskDetailPane,
                    displayMode: $dayPlanDisplayMode,
                    listContent: {
                        AnyView(plannerListView())
                    },
                    onSelectUnplannedCompletedDate: onSelectDayPlanUnplannedCompletedDate,
                    onOpenTaskDetails: onOpenDayPlanTaskDetails,
                    onOpenEventDetails: onOpenEventDetails,
                    onPlannerSidebarPresentationRequested: onCloseTaskDetails
                )
                .frame(
                    minWidth: canShowTaskDetailPane ? MacDetailContainerSizing.plannerInspectorContentMinWidth : 0,
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

                if canShowTaskDetailPane {
                    taskDetailPane(edge: .trailing)
                }
            }
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(MacHomeDetailAnimation.secondaryPane, value: shouldShowPlannerTaskDetailPane)
    }

    private var shouldShowListTaskDetailPane: Bool {
        taskDetailPanePlacement == .listAdjacent
            && selectedTaskID != nil
            && mainDetailMode.visibleSurfaceMode != .details
            && mainDetailMode.visibleSurfaceMode != .planner
    }

    private var shouldShowPlannerTaskDetailPane: Bool {
        taskDetailPanePlacement == .plannerAdjacent
            && selectedTaskID != nil
            && mainDetailMode.visibleSurfaceMode == .planner
    }

    private func canShowPlannerTaskDetailPane(in availableWidth: CGFloat) -> Bool {
        shouldShowPlannerTaskDetailPane
            && availableWidth >= MacDetailContainerSizing.plannerTaskDetailMinWidth
    }

    private func taskDetailPane(edge: Edge) -> some View {
        VStack(spacing: 0) {
            taskDetailPaneHeader
            Divider()
            selectedTaskDetailContent(presentation: .companionPane)
        }
        .frame(width: MacDetailContainerSizing.taskDetailPaneWidth)
        .frame(maxHeight: .infinity)
        .background(Color.secondary.opacity(0.045))
        .overlay(alignment: edge == .leading ? .trailing : .leading) {
            Divider()
        }
        .taskDetailSurfaceMotion(
            id: taskDetailSurfaceMotionID,
            namespace: taskDetailSurfaceNamespace,
            edge: edge,
            isActive: shouldMatchTaskDetailSurface
        )
        .transition(.taskDetailPane(edge: edge))
        .zIndex(1)
    }

    private var shouldMatchTaskDetailSurface: Bool {
        selectedTaskID != nil
    }

    private var fullscreenTaskDetailEdge: Edge {
        taskDetailEdge(for: fullscreenTaskDetailReturnPlacement ?? taskDetailPanePlacement)
    }

    private var taskDetailSurfaceMotionID: String {
        "mac-task-detail-surface-\(selectedTaskID?.uuidString ?? "empty")"
    }

    private func taskDetailEdge(for placement: MacTaskDetailPanePlacement?) -> Edge {
        switch placement {
        case .listAdjacent:
            return .leading
        case .plannerAdjacent, nil:
            return .trailing
        }
    }

    private var taskDetailPaneHeader: some View {
        HStack(spacing: 10) {
            Label("Task Details", systemImage: "sidebar.right")
                .font(.headline)
                .lineLimit(1)

            Spacer(minLength: 8)

            taskDetailPaneButton(
                systemName: "arrow.up.left.and.arrow.down.right",
                title: "Open Fullscreen"
            ) {
                onExpandTaskDetails()
            }

            taskDetailPaneButton(
                systemName: "xmark",
                title: "Close"
            ) {
                onCloseTaskDetails()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func taskDetailPaneButton(
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

            if isBoardInspectorPresented {
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
                presentation: presentation,
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

private extension View {
    func taskDetailSurfaceMotion(
        id: String,
        namespace: Namespace.ID,
        edge: Edge,
        isActive: Bool
    ) -> some View {
        modifier(
            MacTaskDetailSurfaceMotionModifier(
                id: id,
                namespace: namespace,
                edge: edge,
                isActive: isActive
            )
        )
    }
}

private struct MacTaskDetailSurfaceMotionModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let edge: Edge
    let isActive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isActive {
            content
                .matchedGeometryEffect(
                    id: id,
                    in: namespace,
                    properties: .frame,
                    anchor: edge.taskDetailMotionAnchor
                )
        } else {
            content
        }
    }
}

private struct MacTaskDetailDirectionalTransitionModifier: ViewModifier {
    let edge: Edge
    let xScale: CGFloat
    let xOffset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: xScale,
                y: 1,
                anchor: edge.taskDetailMotionAnchor
            )
            .offset(x: xOffset * edge.taskDetailMotionDirection)
            .opacity(opacity)
    }
}

private struct MacTaskDetailWorkspaceTransitionModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .center)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static func taskDetailFullscreen(edge: Edge) -> AnyTransition {
        .modifier(
            active: MacTaskDetailDirectionalTransitionModifier(
                edge: edge,
                xScale: 0.965,
                xOffset: 34,
                opacity: 0.96
            ),
            identity: MacTaskDetailDirectionalTransitionModifier(
                edge: edge,
                xScale: 1,
                xOffset: 0,
                opacity: 1
            )
        )
    }

    static func taskDetailPane(edge: Edge) -> AnyTransition {
        .modifier(
            active: MacTaskDetailDirectionalTransitionModifier(
                edge: edge,
                xScale: 0.985,
                xOffset: 24,
                opacity: 0.98
            ),
            identity: MacTaskDetailDirectionalTransitionModifier(
                edge: edge,
                xScale: 1,
                xOffset: 0,
                opacity: 1
            )
        )
    }

    static var taskDetailWorkspace: AnyTransition {
        .modifier(
            active: MacTaskDetailWorkspaceTransitionModifier(
                scale: 0.992,
                opacity: 0.88
            ),
            identity: MacTaskDetailWorkspaceTransitionModifier(
                scale: 1,
                opacity: 1
            )
        )
    }
}

private extension Edge {
    var taskDetailMotionAnchor: UnitPoint {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }

    var taskDetailMotionDirection: CGFloat {
        switch self {
        case .leading:
            return -1
        case .trailing:
            return 1
        case .top, .bottom:
            return 0
        }
    }
}
