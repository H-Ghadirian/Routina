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
        if isMacBoardMode {
            ToolbarItemGroup(placement: .primaryAction) {
                macBoardFinishSprintToolbarItem
                macBoardOpenCountToolbarItem
                macBoardInProgressCountToolbarItem
                macBoardBlockedCountToolbarItem
                if !isBacklogScope(store.selectedBoardScope) {
                    macBoardDoneCountToolbarItem
                }
            }
        } else if isMacGoalsMode {
            ToolbarItem(placement: .primaryAction) {
                MacGoalsNewGoalButton(store: goalsStore)
            }
        } else {
            ToolbarItemGroup(placement: .primaryAction) {
                macDoneCountToolbarItem
                macCanceledCountToolbarItem
                macRoutineCountToolbarItem
                macTodoCountToolbarItem
            }
        }
    }

    var platformNavigationContent: some View {
        Group {
            if isMacBoardMode {
                NavigationSplitView {
                    WithPerceptionTracking {
                        macSidebarContent
                    }
                } detail: {
                    macBoardCenterContent
                        .navigationTitle(macSidebarNavigationTitle)
                        .toolbar { macBoardDetailToolbarContent }
                        .environment(\.addEditFormCoordinator, addEditFormCoordinator)
                }
                .inspector(isPresented: macBoardInspectorPresentedBinding) {
                    macBoardTaskInspector
                        .inspectorColumnWidth(min: 320, ideal: 400, max: 460)
                        .environment(\.addEditFormCoordinator, addEditFormCoordinator)
                }
            } else if isMacGoalsMode {
                NavigationSplitView {
                    WithPerceptionTracking {
                        macSidebarContent
                    }
                } detail: {
                    MacGoalsDetailView(store: goalsStore)
                }
            } else {
                NavigationSplitView {
                    WithPerceptionTracking {
                        macSidebarContent
                    }
                } detail: {
                    MacDetailContainerView(
                        store: store,
                        isBoardPresented: isMacBoardMode,
                        isTimelinePresented: isMacTimelineMode,
                        isStatsPresented: isMacStatsMode,
                        isSettingsPresented: isMacSettingsMode,
                        settingsStore: settingsStore,
                        statsStore: statsStore,
                        selectedSettingsSection: store.selectedSettingsSection ?? .notifications,
                        addRoutineStore: self.store.scope(
                            state: \.addRoutineState,
                            action: \.addRoutineSheet
                        )
                    ) {
                        macActiveFiltersDetailView
                    } boardView: {
                        macTodoBoardDetailView
                    }
                    .navigationTitle(macSidebarNavigationTitle)
                    .environment(\.addEditFormCoordinator, addEditFormCoordinator)
                }
            }
        }
    }

    @ToolbarContentBuilder
    var macBoardDetailToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            macBoardTicketInspectorToolbarItem
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(searchPlaceholderText, text: searchText)
                .textFieldStyle(.plain)

            if !searchText.wrappedValue.isEmpty {
                Button {
                    searchText.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
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
        view
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenRoutinesInSidebar)) { _ in
                showRoutinesInSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenAddTask)) { _ in
                openAddTask()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenTimelineInSidebar)) { _ in
                openTimelineInSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenStatsInSidebar)) { _ in
                openStatsInSidebar()
            }
            .onChange(of: store.macSidebarMode) { _, mode in
                if mode == .settings {
                    settingsStore.send(.onAppear)
                } else if mode == .goals {
                    goalsStore.send(.onAppear)
                }
            }
    }

    var searchPlaceholderText: String {
        if store.macSidebarMode == .goals {
            return "Search goals"
        }
        if store.macSidebarMode == .timeline {
            return "Search dones"
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
        let countableDisplays = (
            store.routineDisplays
            + store.awayRoutineDisplays
            + store.archivedRoutineDisplays
        )
        let linkedRoutineCounts = HomeFeature.placeLinkedCounts(
            from: countableDisplays,
            taskListMode: store.taskListMode
        )

        return sortedRoutinePlaces.map { place in
            let linkedRoutineCount = linkedRoutineCounts[place.id, default: 0]
            let status: MacPlaceFilterOption.Status

            if let coordinate = store.locationSnapshot.coordinate,
               store.locationSnapshot.authorizationStatus.isAuthorized {
                if place.contains(coordinate) {
                    status = .here
                } else {
                    status = .away(distanceMeters: place.distance(to: coordinate))
                }
            } else {
                status = .unknown
            }

            return MacPlaceFilterOption(
                place: place,
                linkedRoutineCount: linkedRoutineCount,
                linkedItemText: placeFilterCountText(linkedRoutineCount),
                status: status
            )
        }
    }

    func placeFilterCountText(_ count: Int) -> String {
        switch store.taskListMode {
        case .all:
            return count == 1 ? "1 task" : "\(count) tasks"
        case .routines:
            return count == 1 ? "1 routine" : "\(count) routines"
        case .todos:
            return count == 1 ? "1 todo" : "\(count) todos"
        }
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

    var macDoneCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(store.doneStats.totalCount) dones",
            systemImage: "checkmark.seal.fill",
            tintColor: .systemGreen
        )
        .help("\(store.doneStats.totalCount) total dones")
    }

    var macCanceledCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(store.doneStats.canceledTotalCount) cancels",
            systemImage: "xmark.seal.fill",
            tintColor: .systemOrange
        )
        .help("\(store.doneStats.canceledTotalCount) total cancels")
    }

    var macRoutineCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(store.routineTasks.filter { !$0.isOneOffTask }.count) routines",
            systemImage: "arrow.clockwise",
            tintColor: .secondaryLabelColor
        )
        .help("Total routines")
    }

    var macTodoCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(store.routineTasks.filter { $0.isOneOffTask && !$0.isCompletedOneOff && !$0.isCanceledOneOff }.count) todos",
            systemImage: "checkmark.circle",
            tintColor: .secondaryLabelColor
        )
        .help("Total todos")
    }

    var macBoardOpenCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(boardOpenTodoCount) open",
            systemImage: "square.grid.3x3.topleft.filled",
            tintColor: .secondaryLabelColor
        )
        .help("Open todos in the current board view")
    }

    var macBoardTicketInspectorToolbarItem: some View {
        MacToolbarIconButton(
            title: isMacBoardTicketInspectorPresented ? "Hide Ticket Details" : "Show Ticket Details",
            systemImage: "sidebar.right"
        ) {
            withAnimation(.easeInOut(duration: 0.22)) {
                isMacBoardTicketInspectorPresented.toggle()
            }
        }
        .help(isMacBoardTicketInspectorPresented ? "Hide ticket details" : "Show ticket details")
    }

    @ViewBuilder
    var macBoardFinishSprintToolbarItem: some View {
        if !store.isMacFilterDetailPresented {
            let finishableSprints = boardFinishableSprintsInCurrentScope

            if finishableSprints.count == 1, let sprint = finishableSprints.first {
                Button {
                    store.send(.finishSprintTapped(sprint.id))
                } label: {
                    Label("Finish Sprint", systemImage: "flag.checkered")
                }
                .help("Finish \(sprint.title)")
            } else if finishableSprints.count > 1 {
                Menu {
                    ForEach(finishableSprints) { sprint in
                        Button(sprint.title) {
                            store.send(.finishSprintTapped(sprint.id))
                        }
                    }
                } label: {
                    Label("Finish Sprint", systemImage: "flag.checkered")
                }
                .help("Finish an active sprint")
            }
        }
    }

    var macBoardInProgressCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(boardInProgressTodoCount) in progress",
            systemImage: "arrow.clockwise.circle.fill",
            tintColor: .systemBlue
        )
        .help("In-progress todos in the current board view")
    }

    var macBoardBlockedCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(boardBlockedTodoCount) blocked",
            systemImage: "exclamationmark.circle.fill",
            tintColor: .systemRed
        )
        .help("Blocked todos in the current board view")
    }

    var macBoardDoneCountToolbarItem: some View {
        MacToolbarStatusBadge(
            title: "\(boardDoneTodoCount) done",
            systemImage: "checkmark.circle.fill",
            tintColor: .systemGreen
        )
        .help("Done todos in the current board view")
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
        .task {
            appStore.send(.onAppear)
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
}
