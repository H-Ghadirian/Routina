import ComposableArchitecture
import SwiftUI

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        self
    }
}

extension HomeTCAView {
    var homeNavigationTitle: String {
        switch store.taskListMode {
        case .all:
            return "All"
        case .todos:
            return "Todos"
        case .routines:
            return "Routines"
        }
    }

    @ToolbarContentBuilder
    var homeToolbarContent: some ToolbarContent {
        HomeIOSHomeToolbarContent(
            taskListMode: store.taskListMode,
            areTaskListModeActionsExpanded: areTaskListModeActionsExpanded,
            areTopActionsExpanded: areTopActionsExpanded,
            hasActiveOptionalFilters: hasActiveOptionalFilters,
            onSelectTaskListMode: { mode in
                store.send(.taskListModeChanged(mode))
                collapseExpandedToolbarActions()
            },
            onToggleTaskListModeActions: {
                withAnimation(.snappy(duration: 0.2)) {
                    areTaskListModeActionsExpanded.toggle()
                    if areTaskListModeActionsExpanded {
                        areTopActionsExpanded = false
                    }
                }
            },
            onQuickAdd: {
                collapseExpandedToolbarActions()
                isQuickAddSheetPresented = true
            },
            onShowFilters: {
                collapseExpandedToolbarActions()
                store.send(.isFilterSheetPresentedChanged(true))
            },
            onAddTask: {
                collapseExpandedToolbarActions()
                openAddTask()
            },
            onToggleTopActions: {
                withAnimation(.snappy(duration: 0.2)) {
                    areTopActionsExpanded.toggle()
                    if areTopActionsExpanded {
                        areTaskListModeActionsExpanded = false
                    }
                }
            }
        )
    }

    var platformNavigationContent: some View {
        NavigationSplitView {
            WithPerceptionTracking {
                iosSidebarContent
            }
        } detail: {
            WithPerceptionTracking {
                detailContent
            }
        }
    }

    func applyPlatformDeleteConfirmation<Content: View>(to view: Content) -> some View {
        view
    }

    func applyPlatformSearchExperience<Content: View>(
        to view: Content,
        searchText: Binding<String>
    ) -> some View {
        view
    }

    @ViewBuilder
    func platformSearchField(searchText: Binding<String>) -> some View {
        EmptyView()
    }

    func applyPlatformRefresh<Content: View>(to view: Content) -> some View {
        view.refreshable {
            await store.send(.manualRefreshRequested).finish()
        }
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        EmptyView()
    }

    func applyPlatformHomeObservers<Content: View>(to view: Content) -> some View {
        view // Filter snapshot management is handled in the reducer's taskListModeChanged case
    }

    var searchPlaceholderText: String {
        switch store.taskListMode {
        case .all:
            return "Search tasks"
        case .routines:
            return "Search routines"
        case .todos:
            return "Search todos"
        }
    }

    @ViewBuilder
    func applyAddRoutinePresentation<Content: View>(to content: Content) -> some View {
        content.sheet(isPresented: addRoutineSheetBinding) {
            addRoutineSheetContent
        }
    }

    func openAddTask() {
        store.send(.setAddRoutineSheet(true))
    }

    var filterPicker: some View {
        Picker("Routine Filter", selection: Binding(
            get: { store.selectedFilter },
            set: { store.send(.selectedFilterChanged($0)) }
        )) {
            ForEach(iOSAvailableFilters) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    @ViewBuilder
    var locationFilterPanel: some View {
        if hasPlaceAwareContent {
            HomeIOSLocationFilterPanel(
                isLocationAuthorized: store.locationSnapshot.authorizationStatus.isAuthorized,
                places: sortedRoutinePlaces,
                placeFilterAllTitle: placeFilterAllTitle,
                manualPlaceFilterDescription: manualPlaceFilterDescription,
                locationStatusText: locationStatusText,
                hideUnavailableRoutines: hideUnavailableRoutinesBinding,
                selectedPlaceID: manualPlaceFilterBinding
            )
        }
    }

    var homeFiltersSheet: some View {
        HomeFiltersSheetView(
            configuration: homeFiltersSheetConfiguration,
            bindings: homeFilterBindings,
            tagData: homeTagFilterData,
            actions: homeFiltersSheetActions
        )
    }

    var homeFiltersSheetConfiguration: HomeFiltersSheetConfiguration {
        HomeFiltersSheetConfiguration(
            taskListMode: store.taskListMode,
            availableFilters: iOSAvailableFilters,
            place: HomeFiltersPlaceConfiguration(
                sortedRoutinePlaces: sortedRoutinePlaces,
                hasSavedPlaces: hasSavedPlaces,
                hasPlaceLinkedRoutines: hasPlaceLinkedRoutines,
                isLocationAuthorized: store.locationSnapshot.authorizationStatus.isAuthorized,
                placeFilterPluralNoun: placeFilterPluralNoun,
                placeFilterAllTitle: placeFilterAllTitle,
                placeFilterSectionDescription: placeFilterSectionDescription,
                locationStatusText: locationStatusText
            ),
            importanceUrgencySummary: importanceUrgencyFilterSummary,
            hasActiveOptionalFilters: hasActiveOptionalFilters
        )
    }

    var homeFiltersSheetActions: HomeFiltersSheetActions {
        HomeFiltersSheetActions(
            tagActions: homeTagFilterActions,
            onClearOptionalFilters: {
                store.send(.clearOptionalFilters)
            },
            onDismiss: {
                store.send(.isFilterSheetPresentedChanged(false))
            }
        )
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

    var platformTimelineRangePicker: some View {
        Picker("Range", selection: Binding(
            get: { store.selectedTimelineRange },
            set: { store.send(.selectedTimelineRangeChanged($0)) }
        )) {
            ForEach(TimelineRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
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
    }

    @ViewBuilder
    var platformTagFilterBar: some View {
        if homeTagFilterData.hasTags {
            HomeTagFilterBar(
                data: homeTagFilterData,
                actions: homeTagFilterActions
            )
        }
    }

    var platformCompactHomeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            activeFilterChipBar
        }
    }

    @ViewBuilder
    func platformListOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
        let presentation = HomeTaskListPresentation.iOS(
            filtering: taskListFiltering(),
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            taskListKind: store.taskListMode.filterTaskListKind
        )

        HomeIOSTaskListView(
            presentation: presentation,
            selectedTaskID: selectedTaskBinding,
            isCompactHeaderHidden: isCompactHeaderHidden,
            hasActiveOptionalFilters: hasActiveOptionalFilters
        ) {
            compactHomeHeader
        } emptyRowContent: { emptyState in
            inlineEmptyStateRow(
                title: emptyState.title,
                message: emptyState.message,
                systemImage: emptyState.systemImage
            )
        } rowContent: { task, rowNumber, includeMarkDone, moveContext in
            routineNavigationRow(
                for: task,
                rowNumber: rowNumber,
                includeMarkDone: includeMarkDone,
                moveContext: moveContext
            )
        } onDelete: { offsets, sectionTasks in
            deleteTasks(at: offsets, from: sectionTasks)
        } onScroll: { oldOffset, newOffset in
            handleCompactHeaderScroll(oldOffset: oldOffset, newOffset: newOffset)
        } destinationContent: { taskID in
            taskDetailDestination(taskID: taskID)
        }
    }

    func platformRoutineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        HomeIOSRoutineRowView(
            task: task,
            rowNumber: rowNumber,
            metadataText: rowMetadataText(for: task),
            showTaskTypeBadge: store.taskListMode == .all,
            statusBadgeStyle: badgeStyle(for: task).map { HomeStatusBadgeStyle($0) },
            iconBackgroundColor: rowIconBackgroundColor(for: task),
            tagColor: tagColor(for:)
        )
    }

    private func tagColor(for tag: String) -> Color? {
        let tagColors = appSettingsClient.tagColors().merging(store.tagColors) { _, storeColor in storeColor }
        return Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: tagColors))
    }

    func platformDeleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        let ids = offsets.compactMap { sectionTasks[$0].taskID }
        if let selectedTaskID = store.selectedTaskID, ids.contains(selectedTaskID) {
            store.send(.setSelectedTask(nil))
        }
        store.send(.deleteTasks(ids))
    }

    func platformOpenTask(_ taskID: UUID) {
        store.send(.setSelectedTask(taskID))
    }

    func platformDeleteTask(_ taskID: UUID) {
        if store.selectedTaskID == taskID {
            store.send(.setSelectedTask(nil))
        }
        store.send(.deleteTasks([taskID]))
    }

    func platformRoutineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext?
    ) -> some View {
        NavigationLink(value: task.taskID) {
            routineRow(for: task, rowNumber: rowNumber)
        }
        .listRowBackground(routineListRowBackground(for: task))
        .contentShape(Rectangle())
        .contextMenu {
            routineContextMenu(for: task, includeMarkDone: includeMarkDone, moveContext: moveContext)
        }
    }

    @ViewBuilder
    private func routineListRowBackground(for task: HomeFeature.RoutineDisplay) -> some View {
        if let color = task.color.swiftUIColor {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.12))
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var iosSidebarContent: some View {
        HomeIOSSidebarContent(
            isEmpty: store.routineTasks.isEmpty,
            navigationTitle: homeNavigationTitle
        ) {
            emptyStateView(
                title: "No tasks yet",
                message: "Add a routine or to-do, and the home list will organize what needs attention for you.",
                systemImage: "checklist"
            ) {
                openAddTask()
            }
        } taskListContent: {
            listOfSortedTasksView(
                routineDisplays: store.routineDisplays,
                awayRoutineDisplays: store.awayRoutineDisplays,
                archivedRoutineDisplays: store.archivedRoutineDisplays
            )
        } toolbarItems: {
            homeToolbarContent
        }
    }
}

struct HomeIOSView: View {
    let store: StoreOf<HomeFeature>
    private let searchText: Binding<String>?

    init(
        store: StoreOf<HomeFeature>,
        searchText: Binding<String>? = nil
    ) {
        self.store = store
        self.searchText = searchText
    }

    var body: some View {
        HomeTCAView(
            store: store,
            searchText: searchText
        )
    }
}
