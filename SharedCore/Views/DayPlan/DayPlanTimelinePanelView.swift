import SwiftData
import SwiftUI

struct DayPlanTimelinePanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var planner: DayPlanPlannerState
    var onSelectUnplannedCompletedDate: ((Date) -> Void)?
    var onOpenTaskDetails: ((UUID) -> Void)?
    var onOpenCalendarListTaskDetails: ((DayPlanDayTaskListItem, Date) -> Void)?
    var onOpenEventDetails: ((UUID) -> Void)?
    var calendarFilters: Binding<DayPlanCalendarFilterState> = .constant(DayPlanCalendarFilterState())
    var calendarSearchText = ""
    var calendarTaskFilter: (RoutineTask) -> Bool = { _ in true }
    var calendarTaskFilterCacheSeed = 0
    var calendarListRevealsHiddenTasks = false
    var calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule
    var isCalendarFilterSidebarPresented: Binding<Bool> = .constant(false)
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var parentAvailableWidth: CGFloat?
    var isExternalInspectorPresented = false
    var onSidebarPresentationRequested: (() -> Void)?
    @State private var dataSnapshot = DayPlanTimelineDataSnapshot()
    @State private var hasDeferredTimelineDataSnapshotRefresh = false
    #if os(macOS)
        @State private var deferredTimelineDataSnapshotRefreshTask: Task<Void, Never>?
    #endif
    @StateObject private var timelinePlacementCache = DayPlanTimelinePlacementCache()
    @StateObject private var allDayBlocksCache = DayPlanAllDayBlocksCache()
    @StateObject private var visibleBlockContextCache = DayPlanVisibleBlockContextCache()
    @StateObject private var sleepBlocksCache = DayPlanSleepBlocksCache()
    @StateObject private var awayBlocksCache = DayPlanAwayBlocksCache()
    @StateObject private var completedSprintFocusBlocksCache = DayPlanSprintFocusBlocksCache()
    @StateObject private var activeSprintFocusBlocksCache = DayPlanSprintFocusBlocksCache()
    @StateObject private var renderSnapshotCache = DayPlanTimelineRenderSnapshotCache()
    @StateObject private var calendarTaskFilterCache = DayPlanCalendarTaskFilterCache()
    @StateObject private var plannedDateTaskVisibilityCache = DayPlanPlannedDateTaskVisibilityCache()
    @StateObject private var dayTaskListItemsCache = DayPlanDayTaskListItemsCache()
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false

    var body: some View {
        DayPlanTimelinePanelContentView(
            planner: planner,
            onSelectUnplannedCompletedDate: onSelectUnplannedCompletedDate,
            onOpenTaskDetails: onOpenTaskDetails,
            onOpenCalendarListTaskDetails: onOpenCalendarListTaskDetails,
            onOpenEventDetails: onOpenEventDetails,
            dataSnapshotID: dataSnapshot.id,
            tasks: dataSnapshot.tasks,
            logs: dataSnapshot.logs,
            sleepSessions: dataSnapshot.sleepSessions,
            awaySessions: isAwayEnabled ? dataSnapshot.awaySessions : [],
            events: dataSnapshot.events,
            sprintFocusSessions: dataSnapshot.sprintFocusSessions,
            sprintFocusAllocations: dataSnapshot.sprintFocusAllocations,
            boardSprints: dataSnapshot.boardSprints,
            focusSessions: dataSnapshot.focusSessions,
            includesEvents: areMacEventEmotionActionsEnabled,
            includesAway: isAwayEnabled,
            timelinePlacementCache: timelinePlacementCache,
            allDayBlocksCache: allDayBlocksCache,
            visibleBlockContextCache: visibleBlockContextCache,
            sleepBlocksCache: sleepBlocksCache,
            awayBlocksCache: awayBlocksCache,
            completedSprintFocusBlocksCache: completedSprintFocusBlocksCache,
            activeSprintFocusBlocksCache: activeSprintFocusBlocksCache,
            renderSnapshotCache: renderSnapshotCache,
            calendarTaskFilterCache: calendarTaskFilterCache,
            plannedDateTaskVisibilityCache: plannedDateTaskVisibilityCache,
            dayTaskListItemsCache: dayTaskListItemsCache,
            calendarFilters: calendarFilters,
            calendarSearchText: calendarSearchText,
            calendarTaskFilter: calendarTaskFilter,
            calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed,
            calendarListRevealsHiddenTasks: calendarListRevealsHiddenTasks,
            calendarTaskViewMode: calendarTaskViewMode,
            isCalendarFilterSidebarPresented: isCalendarFilterSidebarPresented,
            isDatePickerSidebarPresented: isDatePickerSidebarPresented,
            parentAvailableWidth: parentAvailableWidth,
            isExternalInspectorPresented: isExternalInspectorPresented,
            onSidebarPresentationRequested: onSidebarPresentationRequested
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            refreshTimelineDataSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            requestTimelineDataSnapshotRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshTimelineDataSnapshot()
            }
        }
        .onChange(of: isExternalInspectorPresented) { _, isPresented in
            guard !isPresented else { return }
            refreshDeferredTimelineDataSnapshotIfNeeded()
        }
    }

    private func requestTimelineDataSnapshotRefresh() {
        #if os(macOS)
            guard !RoutinaMacScrollInteractionGate.isScrollActive else {
                hasDeferredTimelineDataSnapshotRefresh = true
                scheduleDeferredTimelineDataSnapshotRefreshRetry()
                return
            }
        #endif

        hasDeferredTimelineDataSnapshotRefresh = false
        refreshTimelineDataSnapshot()
    }

    private func refreshDeferredTimelineDataSnapshotIfNeeded() {
        guard hasDeferredTimelineDataSnapshotRefresh else { return }
        #if os(macOS)
            guard !isExternalInspectorPresented else { return }
            guard !RoutinaMacScrollInteractionGate.isScrollActive else {
                scheduleDeferredTimelineDataSnapshotRefreshRetry()
                return
            }
        #endif
        hasDeferredTimelineDataSnapshotRefresh = false
        #if os(macOS)
            deferredTimelineDataSnapshotRefreshTask?.cancel()
            deferredTimelineDataSnapshotRefreshTask = nil
        #endif
        refreshTimelineDataSnapshot()
    }

    #if os(macOS)
        private func scheduleDeferredTimelineDataSnapshotRefreshRetry() {
            deferredTimelineDataSnapshotRefreshTask?.cancel()
            let delayMilliseconds = RoutinaMacScrollInteractionGate.quietRetryDelayMilliseconds
            deferredTimelineDataSnapshotRefreshTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(delayMilliseconds))
                guard !Task.isCancelled else { return }
                refreshDeferredTimelineDataSnapshotIfNeeded()
            }
        }
    #endif

    private func refreshTimelineDataSnapshot() {
        do {
            let refreshedSnapshot = try DayPlanTimelineDataSnapshot.fetch(from: modelContext)
            if refreshedSnapshot.signature != dataSnapshot.signature {
                dataSnapshot = refreshedSnapshot
            }
        } catch {
            NSLog("DayPlanTimelinePanelView: failed to refresh planner data snapshot - \(error.localizedDescription)")
        }
    }
}
