import ComposableArchitecture
import MapKit
import SwiftUI

private enum HomeSidebarSizing {
    static let minWidth: CGFloat = 220
    static let idealWidth: CGFloat = 300
    static let maxWidth: CGFloat = 360
}

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        navigationSplitViewColumnWidth(
            min: HomeSidebarSizing.minWidth,
            ideal: HomeSidebarSizing.idealWidth,
            max: HomeSidebarSizing.maxWidth
        )
    }
}

extension HomeTCAView {
    // Typealiases for brevity — the canonical definitions live in HomeFeature
    typealias MacSidebarMode = HomeFeature.MacSidebarMode
    typealias MacSidebarSelection = HomeFeature.MacSidebarSelection

    @ToolbarContentBuilder
    var homeToolbarContent: some ToolbarContent {
        HomeMacHomeToolbarContent(
            mode: homeToolbarMode,
            goalsStore: goalsStore,
            showsDetailModePicker: showsDetailModePickerInToolbar,
            detailMode: mainDetailModeBinding
        )
    }

    private var showsDetailModePickerInToolbar: Bool {
        !store.isMacFilterDetailPresented
            && !isMacBoardMode
            && !isMacTimelineMode
            && !isMacStatsMode
            && !isMacSettingsMode
            && !isMacGoalsMode
            && !isMacAddTaskMode
            && store.addRoutineState == nil
    }

    private var homeToolbarMode: HomeMacHomeToolbarContent.Mode {
        if isMacBoardSidebarPresented {
            return .board
        }
        if isMacGoalsMode {
            return .goals
        }
        return .standard
    }

    @ViewBuilder
    var platformNavigationContent: some View {
        HomeMacNavigationContent(
            isBoardMode: isMacBoardMode,
            isGoalsMode: isMacGoalsMode,
            isBoardInspectorPresented: macBoardInspectorPresentedBinding,
            addEditFormCoordinator: addEditFormCoordinator
        ) {
            macSidebarContent
                .toolbar {
                    macSidebarDoneToolbarContent
                }
        } boardCenterContent: {
            macBoardCenterContent
        } boardInspectorContent: {
            macBoardTaskInspector
        } goalsDetailContent: {
            MacGoalsDetailView(store: goalsStore)
        } mainDetailContent: {
            MacDetailContainerView(
                store: store,
                isBoardPresented: isMacBoardMode,
                isTimelinePresented: isMacTimelineMode,
                isStatsPresented: isMacStatsMode,
                isSettingsPresented: isMacSettingsMode,
                placeCheckInMapActivity: placeCheckInMapActivity,
                settingsStore: settingsStore,
                statsStore: statsStore,
                selectedSettingsSection: store.selectedSettingsSection ?? .notifications,
                dayPlanPlanner: dayPlanPlanner,
                mainDetailMode: mainDetailModeBinding,
                isBoardInspectorPresented: macBoardInspectorPresentedBinding,
                placeCheckInSelectedPlaceID: $placeCheckInSelectedPlaceID,
                placeCheckInSelectedHistoryMarkerID: $placeCheckInSelectedHistoryMarkerID,
                selectedTaskID: store.selectedTaskID,
                onSelectDayPlanUnplannedCompletedDate: { date in
                    focusMacSidebarOnDayPlanUnplannedCompletedTasks(on: date)
                },
                onOpenDayPlanTaskDetails: { taskID in
                    openDayPlanTaskDetails(taskID)
                },
                onToggleBoardInspector: toggleMacBoardTicketInspector,
                addRoutineStore: self.store.scope(
                    state: \.addRoutineState,
                    action: \.addRoutineSheet
                )
            ) {
                macActiveFiltersDetailView
            } boardView: {
                macTodoBoardDetailView
            } boardInspectorView: {
                macBoardTaskInspector
            }
        } homeToolbarContent: {
            homeToolbarContent
        } boardToolbarContent: {
            macBoardDetailToolbarContent
        }
    }

    @ToolbarContentBuilder
    private var macSidebarDoneToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            MacToolbarStatusBadge(
                title: "\(store.doneStats.totalCount) done",
                systemImage: "checkmark.seal.fill",
                tintColor: .systemGreen
            )
            .help("\(store.doneStats.totalCount) total done")
        }
    }

    @ToolbarContentBuilder
    var macBoardDetailToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HomeMacBoardInspectorToolbarButton(
                isPresented: isMacBoardTicketInspectorPresented,
                onToggle: toggleMacBoardTicketInspector
            )
        }
    }

    private func toggleMacBoardTicketInspector() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isMacBoardTicketInspectorPresented.toggle()
        }
    }

    var macBoardInspectorPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                isMacBoardTicketInspectorPresented
            },
            set: { isPresented in
                isMacBoardTicketInspectorPresented = isPresented
            }
        )
    }

    func applyPlatformDeleteConfirmation<Content: View>(to view: Content) -> some View {
        view.alert(
            deleteConfirmationTitle,
            isPresented: deleteConfirmationBinding
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteTasksConfirmed)
            }
            Button("Cancel", role: .cancel) {
                store.send(.setDeleteConfirmation(false))
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    func applyPlatformSearchExperience<Content: View>(
        to view: Content,
        searchText: Binding<String>
    ) -> some View {
        view
    }

    @ViewBuilder
    func platformSearchField(searchText: Binding<String>) -> some View {
        HomeMacSearchField(
            placeholder: searchPlaceholderText,
            text: searchText
        )
    }

    func applyPlatformRefresh<Content: View>(to view: Content) -> some View {
        view
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        MacToolbarIconButton(title: "Sync with iCloud", systemImage: "arrow.clockwise") {
            Task { @MainActor in
                await store.send(.manualRefreshRequested).finish()
            }
        }
    }

    func applyPlatformHomeObservers<Content: View>(to view: Content) -> some View {
        HomeMacSidebarCommandRouter(
            content: view,
            mode: store.macSidebarMode,
            onOpenRoutines: showRoutinesInSidebar,
            onOpenAddTask: openAddTask,
            onOpenQuickAdd: showQuickAddSpotlight,
            onOpenTimeline: openTimelineInSidebar,
            onOpenStats: openStatsInSidebar
        ) { mode in
            if mode == .settings {
                settingsStore.send(.onAppear)
            } else if mode == .goals {
                goalsStore.send(.onAppear)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            alignMacDetailModeForDeepLinkNotification(notification)
        }
    }

    private func alignMacDetailModeForDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        switch deepLink {
        case .task:
            macHomeDetailMode = .details
        case .sprint:
            macHomeDetailMode = .board
        }
    }

    var searchPlaceholderText: String {
        if store.macSidebarMode == .goals {
            return "Search goals"
        }
        if store.macSidebarMode == .timeline {
            return "Search timeline"
        }
        if isMacBoardSidebarPresented {
            return "Search todos"
        }
        switch store.taskListMode {
        case .all:
            return "Search routines and todos"
        case .routines:
            return "Search routines"
        case .todos:
            return "Search todos"
        }
    }

    func applyAddRoutinePresentation<Content: View>(to content: Content) -> some View {
        content
            .overlay {
                if isQuickAddSheetPresented {
                    MacQuickAddSpotlightOverlay(
                        isPresented: $isQuickAddSheetPresented,
                        onCreated: requestRefresh
                    )
                }
            }
    }

    func showQuickAddSpotlight() {
        isQuickAddSheetPresented = true
    }

    func openAddTask() {
        store.send(.macSidebarModeChanged(.addTask))
        store.send(.setAddRoutineSheet(true))
        scheduleAddTaskNameFocus()
    }

    private func scheduleAddTaskNameFocus() {
        let delays: [TimeInterval] = [0, 0.05, 0.15, 0.3, 0.6, 1.0, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                addEditFormCoordinator.requestNameFocus()
            }
        }
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
            return !task.isOneOffTask
        case .todos:
            return task.isOneOffTask
        }
    }

    var macAvailableFilters: [RoutineListFilter] {
        [.all, .due, .doneToday]
    }

    var macPlaceFilterOptions: [MacPlaceFilterOption] {
        MacPlaceFilterOptionFactory.options(
            places: sortedRoutinePlaces,
            displays: store.routineDisplays
                + store.awayRoutineDisplays
                + store.archivedRoutineDisplays,
            taskListMode: store.taskListMode,
            locationSnapshot: store.locationSnapshot
        )
    }

    var platformTimelineRangePicker: some View {
        Picker("Range", selection: Binding(
            get: { store.selectedTimelineRange },
            set: { store.send(.selectedTimelineRangeChanged($0)) }
        )) {
            ForEach(TimelineRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    var platformTimelineTypePicker: some View {
        Picker("Type", selection: Binding(
            get: { store.selectedTimelineFilterType },
            set: { store.send(.selectedTimelineFilterTypeChanged($0)) }
        )) {
            ForEach(TimelineFilterType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    var platformTagFilterBar: some View {
        if homeTagFilterData.hasTags {
            HomeMacRoutineTagFiltersView(
                bindings: homeFilterBindings.tagRules,
                data: homeTagFilterData,
                actions: homeTagFilterActions
            )
        }
    }

    @ViewBuilder
    var platformCompactHomeHeader: some View {
        EmptyView()
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.isDeleteConfirmationPresented },
            set: { store.send(.setDeleteConfirmation($0)) }
        )
    }

    private var deleteConfirmationTitle: String {
        store.pendingDeleteTaskIDs.count == 1 ? "Delete routine?" : "Delete routines?"
    }

    private var deleteConfirmationMessage: String {
        guard store.pendingDeleteTaskIDs.count == 1 else {
            return "This will permanently remove \(store.pendingDeleteTaskIDs.count) routines and their logs."
        }

        let taskID = store.pendingDeleteTaskIDs[0]
        let routineName = store.routineTasks.first(where: { $0.id == taskID })?.name ?? "this routine"
        return "This will permanently remove \(routineName) and its logs."
    }

}

struct HomeMacView: View {
    let appStore: StoreOf<AppFeature>
    let store: StoreOf<HomeFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let goalsStore: StoreOf<GoalsFeature>
    let statsStore: StoreOf<StatsFeature>

    var body: some View {
        HomeTCAView(
            store: store,
            settingsStore: settingsStore,
            goalsStore: goalsStore,
            statsStore: statsStore
        )
        .sleepModeGate()
        .task {
            appStore.send(.onAppear)
            handlePendingDeepLink()
        }
        .onOpenURL(perform: handleOpenURL)
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            handleDeepLinkNotification(notification)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsStore.send(.onAppBecameActive)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: CloudKitSyncDiagnostics.didUpdateNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            settingsStore.send(.cloudDiagnosticsUpdated)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)
                .receive(on: RunLoop.main)
        ) { _ in
            appStore.send(.cloudSettingsChanged)
            store.send(.onAppear)
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard let deepLink = RoutinaDeepLink(url: url) else { return }
        RoutinaDeepLinkDispatcher.open(deepLink)
    }

    @MainActor
    private func handleDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        RoutinaDeepLinkDispatcher.markHandled(deepLink)
        appStore.send(.openDeepLink(deepLink))
    }

    @MainActor
    private func handlePendingDeepLink() {
        guard let deepLink = RoutinaDeepLinkDispatcher.consumePendingDeepLink() else { return }
        appStore.send(.openDeepLink(deepLink))
    }
}
