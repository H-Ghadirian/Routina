import ComposableArchitecture
import SwiftData
import SwiftUI

struct StatsViewWrapper: View {
    let store: StoreOf<StatsFeature>
    @Binding var selectedDashboardScope: StatsDashboardScope
    var showsFocusTimerToolbarItem = true

    var body: some View {
        StatsView(
            store: store,
            selectedDashboardScope: $selectedDashboardScope,
            showsFocusTimerToolbarItem: showsFocusTimerToolbarItem
        )
        .background {
            StatsDataObserver(store: store)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }
}

private struct StatsDataObserver: View {
    let store: StoreOf<StatsFeature>
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    private var isPlacesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue, store: SharedDefaults.app)
    private var isNotesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue, store: SharedDefaults.app)
    private var isAwayEnabled = false

    var body: some View {
        Color.clear
            .task {
                store.send(.onAppear)
            }
            .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
                store.send(.dataRefreshRequested)
            }
            .onChange(of: isPlacesEnabled) { _, _ in
                store.send(.dataRefreshRequested)
            }
            .onChange(of: isNotesEnabled) { _, _ in
                store.send(.dataRefreshRequested)
            }
            .onChange(of: isAwayEnabled) { _, _ in
                store.send(.dataRefreshRequested)
            }
    }
}

struct StatsView: View {
    let store: StoreOf<StatsFeature>
    @Binding var selectedDashboardScope: StatsDashboardScope
    var showsFocusTimerToolbarItem = true
    @Environment(\.calendar) var calendar
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State var isActiveItemsInfoPresented = false
    @State var presentedSummaryTaskList: StatsSummaryTaskListPresentation?
    @State var isEditingDashboard = false
    @State var isAddDashboardItemSheetPresented = false
    @State var draggedDashboardItemID: String?
    @AppStorage(UserDefaultStringValueKey.appSettingMacStatsDashboardHiddenItemIDs.rawValue, store: SharedDefaults.app)
    var hiddenDashboardItemIDsRaw = StatsMacDashboardItem.defaultHiddenItemIDsRawValue
    @AppStorage(UserDefaultStringValueKey.appSettingMacStatsDashboardItemOrderIDs.rawValue, store: SharedDefaults.app)
    var dashboardItemOrderIDsRaw = ""
    @AppStorage(UserDefaultStringValueKey.appSettingMacStatsSummaryDisplayMode.rawValue, store: SharedDefaults.app)
    var summaryDisplayModeRaw = StatsSummaryDisplayMode.cards.rawValue
    @AppStorage(UserDefaultBoolValueKey.appSettingMacStatsDashboardControlsEnabled.rawValue, store: SharedDefaults.app)
    var areMacStatsDashboardControlsEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingStatsWinsEnabled.rawValue, store: SharedDefaults.app)
    var isStatsWinsEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingStatsSleepTabEnabled.rawValue, store: SharedDefaults.app)
    var isStatsSleepTabEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingStatsAchievementsEnabled.rawValue, store: SharedDefaults.app)
    var isStatsAchievementsEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue, store: SharedDefaults.app)
    var isGoalsTabEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue, store: SharedDefaults.app)
    var areMacEventEmotionActionsEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    var isPlacesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue, store: SharedDefaults.app)
    var isNotesEnabled = false
    @AppStorage(UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue, store: SharedDefaults.app)
    var isAwayEnabled = false

    typealias Metrics = StatsFeature.Metrics

    struct DashboardSnapshot {
        let selectedRange: DoneChartRange
        let selectedTaskTypeFilter: StatsTaskTypeFilter
        let selectedCreatedChartTaskTypeFilter: StatsTaskTypeFilter
        let metrics: Metrics
        let filteredTaskCount: Int
        let isGitFeaturesEnabled: Bool
        let gitHubConnection: GitHubConnectionStatus
        let gitHubStats: GitHubStatsSnapshot?
        let isGitHubStatsLoading: Bool
        let gitHubStatsErrorMessage: String?
        let chartPresentation: StatsChartPresentation
        let createdTasksPresentation: StatsCreatedTasksPresentation
    }

    private var dashboardSnapshot: DashboardSnapshot {
        let selectedRange = store.selectedRange
        let selectedCreatedChartTaskTypeFilter = store.createdChartTaskTypeFilter
        let chartPresentation = StatsChartPresentation(
            selectedRange: selectedRange,
            isCompact: horizontalSizeClass == .compact
        )

        return DashboardSnapshot(
            selectedRange: selectedRange,
            selectedTaskTypeFilter: store.taskTypeFilter,
            selectedCreatedChartTaskTypeFilter: selectedCreatedChartTaskTypeFilter,
            metrics: store.metrics,
            filteredTaskCount: store.filteredTaskCount,
            isGitFeaturesEnabled: store.isGitFeaturesEnabled,
            gitHubConnection: store.gitHubConnection,
            gitHubStats: store.gitHubStats,
            isGitHubStatsLoading: store.isGitHubStatsLoading,
            gitHubStatsErrorMessage: store.gitHubStatsErrorMessage,
            chartPresentation: chartPresentation,
            createdTasksPresentation: StatsCreatedTasksPresentation(
                taskTypeFilter: selectedCreatedChartTaskTypeFilter,
                selectedRange: selectedRange
            )
        )
    }

    var selectedRange: DoneChartRange {
        store.selectedRange
    }

    var visibleAchievementSnapshot: StatsAchievementPresentationSnapshot {
        store.achievementSnapshot.filteringDomains { domain in
            switch domain {
            case .places:
                isPlacesEnabled
            case .notes:
                isNotesEnabled
            case .sleep, .away:
                isAwayEnabled
            default:
                true
            }
        }
    }

    var activeItemsBreakdown: StatsActiveItemsBreakdown {
        StatsActiveItemsBreakdown(
            tasks: filteredTasksForCurrentStatsFilters,
            referenceDate: selectedRange.referenceDate(relativeTo: Date()),
            calendar: calendar
        )
    }

    private var filteredTasksForCurrentStatsFilters: [RoutineTask] {
        store.tasks.filter { store.filteredTaskIDs.contains($0.id) }
    }

    var surfaceGradient: LinearGradient {
        StatsDashboardPalette.surfaceGradient(colorScheme: colorScheme)
    }

    var heroGradient: LinearGradient {
        StatsDashboardPalette.heroGradient(colorScheme: colorScheme)
    }

    var pageBackground: LinearGradient {
        StatsDashboardPalette.pageBackground(colorScheme: colorScheme)
    }

    var baseBarFill: LinearGradient {
        StatsDashboardPalette.baseBarFill(colorScheme: colorScheme)
    }

    var createdBarFill: LinearGradient {
        StatsDashboardPalette.createdBarFill(colorScheme: colorScheme)
    }

    var highlightBarFill: LinearGradient {
        StatsDashboardPalette.highlightBarFill
    }

    var hiddenDashboardItemIDs: Set<String> {
        Set(
            hiddenDashboardItemIDsRaw
                .split(separator: ",")
                .map(String.init)
        )
    }

    private var availableDashboardItems: [StatsMacDashboardItem] {
        StatsMacDashboardItem.allCases.filter { item in
            (item != .notes || isNotesEnabled)
                && (item != .awayTime || isAwayEnabled)
                && (item != .sleepTime || isAwayEnabled)
                && (item != .sleepSessions || isAwayEnabled)
                && item.isAvailable(
                    selectedRange: selectedRange,
                    isGitFeaturesEnabled: store.isGitFeaturesEnabled,
                    isGoalsTabEnabled: isGoalsTabEnabled,
                    areMacEventEmotionActionsEnabled: areMacEventEmotionActionsEnabled,
                    isStatsWinsEnabled: isStatsWinsEnabled,
                    isStatsAchievementsEnabled: isStatsAchievementsEnabled
                )
                && item.isReportable(metrics: store.metrics)
        }
    }

    private var orderedAvailableDashboardItems: [StatsMacDashboardItem] {
        StatsDashboardOrderSupport.orderedItems(
            availableDashboardItems,
            storedRawValue: dashboardItemOrderIDsRaw
        )
    }

    private var visibleOrderedDashboardItems: [StatsMacDashboardItem] {
        orderedAvailableDashboardItems.filter {
            !hiddenDashboardItemIDs.contains($0.rawValue)
        }
    }

    var scopedVisibleOrderedDashboardItems: [StatsMacDashboardItem] {
        visibleOrderedDashboardItems.filter { $0.isIncluded(in: effectiveDashboardScope) }
    }

    var hiddenAvailableDashboardItems: [StatsMacDashboardItem] {
        orderedAvailableDashboardItems.filter { hiddenDashboardItemIDs.contains($0.rawValue) }
    }

    private var effectiveDashboardScope: StatsDashboardScope {
        if selectedDashboardScope == .wins && !isStatsWinsEnabled {
            return .all
        }
        if selectedDashboardScope == .sleep && (!isAwayEnabled || !isStatsSleepTabEnabled) {
            return .all
        }
        if selectedDashboardScope == .achievements && !isStatsAchievementsEnabled {
            return .all
        }
        return selectedDashboardScope
    }

    var summaryDisplayMode: StatsSummaryDisplayMode {
        StatsSummaryDisplayMode(rawValue: summaryDisplayModeRaw) ?? .cards
    }

    var summaryDisplayModeBinding: Binding<StatsSummaryDisplayMode> {
        Binding(
            get: { summaryDisplayMode },
            set: { mode in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    CloudSettingsKeyValueSync.setString(
                        mode.rawValue,
                        for: .appSettingMacStatsSummaryDisplayMode
                    )
                }
            }
        )
    }

    var body: some View {
        dashboardBody(snapshot: dashboardSnapshot)
    }
}
