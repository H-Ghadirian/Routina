import ComposableArchitecture
import SwiftUI

/// Separate View struct so SwiftUI gives it its own observation lifecycle.
/// Inline closures inside `NavigationSplitView.detail` on macOS can lose
/// observation tracking after several view swaps, causing state changes
/// (like toggling the filter panel) to stop updating the detail column.
struct MacDetailContainerView<FilterView: View, BoardView: View, BoardInspectorView: View>: View {
    let store: StoreOf<HomeFeature>
    let isBoardPresented: Bool
    let isTimelinePresented: Bool
    let isStatsPresented: Bool
    let isSettingsPresented: Bool
    let placeCheckInMapActivity: PlaceCheckInActivity?
    let settingsStore: StoreOf<SettingsFeature>
    let statsStore: StoreOf<StatsFeature>?
    let selectedSettingsSection: SettingsMacSection
    let dayPlanPlanner: DayPlanPlannerState
    @Binding var mainDetailMode: MacHomeDetailMode
    @Binding var isBoardInspectorPresented: Bool
    let selectedTaskID: UUID?
    let onSelectDayPlanUnplannedCompletedDate: (Date) -> Void
    let onOpenDayPlanTaskDetails: (UUID) -> Void
    let onToggleBoardInspector: () -> Void
    let addRoutineStore: StoreOf<AddRoutineFeature>?
    @ViewBuilder let filterView: () -> FilterView
    @ViewBuilder let boardView: () -> BoardView
    @ViewBuilder let boardInspectorView: () -> BoardInspectorView

    var body: some View {
        WithPerceptionTracking {
            if store.isMacFilterDetailPresented {
                filterView()
            } else if isBoardPresented {
                boardDetailContent
            } else if let addRoutineStore {
                AddRoutineTCAView(store: addRoutineStore)
            } else if isStatsPresented, let statsStore {
                StatsViewWrapper(
                    store: statsStore,
                    showsFocusTimerToolbarItem: false
                )
            } else if isStatsPresented {
                ContentUnavailableView(
                    "Stats unavailable",
                    systemImage: "chart.bar.xaxis",
                    description: Text("The stats store is not currently connected for this view.")
                )
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
            RoutinaMacFocusTimerToolbarItem()

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
        VStack(spacing: 0) {
            if shouldShowDetailModePicker {
                detailModePickerHeader
                Divider()
            }

            mainDetailBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailModePickerHeader: some View {
        MacHomeDetailModePickerHeader(selection: $mainDetailMode)
    }

    @ViewBuilder
    private var mainDetailBody: some View {
        Group {
            switch mainDetailMode {
            case .details:
                selectedTaskDetailContent
            case .planner:
                DayPlanDetailView(
                    planner: dayPlanPlanner,
                    selectedTaskID: selectedTaskID,
                    onSelectUnplannedCompletedDate: onSelectDayPlanUnplannedCompletedDate,
                    onOpenTaskDetails: onOpenDayPlanTaskDetails
                )
            case .board:
                boardDetailContent
            case .places:
                placesDetailContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placesDetailContent: some View {
        PlaceCheckInMapSheet(
            selectedActivity: placeCheckInMapActivity,
            showsNavigationChrome: false,
            showsInlineHeader: false,
            layout: .mapOnly
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var boardDetailContent: some View {
        HStack(spacing: 0) {
            boardView()
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)

            if isBoardInspectorPresented {
                boardInspectorView()
                    .frame(width: 400)
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
    private var timelineDetailContent: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
            )
        } else {
            ContentUnavailableView(
                "Select a done item or filters",
                systemImage: "clock.arrow.circlepath",
                description: Text("Choose a completed routine or todo from the sidebar, or open filters beside search to refine the done history.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var selectedTaskDetailContent: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
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

struct MacHomeDetailModePickerHeader: View {
    @Binding var selection: MacHomeDetailMode

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            MacHomeDetailModePicker(selection: $selection)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .routinaGlassPanel(cornerRadius: 0, tint: .secondary, tintOpacity: 0.04)
    }
}

struct MacHomeDetailModePicker: View {
    @Binding var selection: MacHomeDetailMode

    var body: some View {
        MacLiquidGlassHomeDetailModePicker(selection: $selection)
    }
}

private struct MacLiquidGlassHomeDetailModePicker: View {
    @Binding var selection: MacHomeDetailMode
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(MacHomeDetailMode.allCases) { mode in
                    segmentButton(for: mode)
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        }
        .frame(width: 420)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Detail mode")
    }

    private func segmentButton(for mode: MacHomeDetailMode) -> some View {
        let isSelected = selection == mode

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = mode
            }
        } label: {
            Text(mode.rawValue)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .glassEffect(
                        .regular.tint(Color.accentColor.opacity(0.34)).interactive(),
                        in: .rect(cornerRadius: 10)
                    )
                    .glassEffectID("MacHomeDetailModeSelection", in: glassNamespace)
            }
        }
        .accessibilityLabel(mode.rawValue)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}
