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
    static let fullscreenFilterContentMaxWidth: CGFloat = 840
    static let plannerTaskDetailMinWidth: CGFloat = plannerInspectorContentMinWidth + taskDetailPaneWidth
    static let boardInspectorWidth: CGFloat = 400
}

struct MacPlannerDoneTaskDetailSelection: Equatable {
    let taskID: UUID
    let date: Date
    let occurrence: DayPlanDoneTaskOccurrence
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
    @Environment(\.calendar) var calendar

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
    @Binding var isBoardInspectorPresented: Bool
    @Binding var taskDetailPanePlacement: MacTaskDetailPanePlacement?
    let plannerTaskDetailDoneSelection: MacPlannerDoneTaskDetailSelection?
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
    let onOpenDayPlanCalendarListTaskDetails: (DayPlanDayTaskListItem, Date) -> Void
    let onOpenEventDetails: (UUID) -> Void
    let onToggleDayPlanCalendarFilters: () -> Void
    let onEditNote: (UUID) -> Void
    let onDeleteNote: (UUID) -> Void
    let onToggleBoardInspector: () -> Void
    let onExpandTaskDetails: () -> Void
    let taskSidebarLocation: (UUID) -> TaskDetailSidebarLocation?
    let onLocateTaskInSidebar: () -> Void
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

    var shouldShowFilterDetailPane: Bool {
        store.isMacFilterDetailPresented && !isFilterDetailFullscreen
    }

    private func detailContentWithOptionalFilterPane<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        GeometryReader { proxy in
            let filterPaneWidth =
                shouldShowFilterDetailPane
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
                .frame(
                    maxWidth: MacDetailContainerSizing.fullscreenFilterContentMaxWidth,
                    maxHeight: .infinity,
                    alignment: .top
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

extension AnyTransition {
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
