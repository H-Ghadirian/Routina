import ComposableArchitecture
import SwiftData
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
iosSidebarContent
        } detail: {
detailContent
        }
    }

    private var topActionRail: some View {
        HomeIOSTopActionRail(
            hasActiveOptionalFilters: hasActiveOptionalFilters,
            showsSleepAction: shouldShowHomeSleepAction,
            onQuickAdd: {
                collapseExpandedToolbarActions()
                openAddTask()
            },
            onShowFilters: {
                collapseExpandedToolbarActions()
                store.send(.isFilterSheetPresentedChanged(true))
            },
            onAddNote: {
                collapseExpandedToolbarActions()
                isNoteEditorPresented = true
            },
            onCheckIn: {
                collapseExpandedToolbarActions()
                isPlaceCheckInMapPresented = true
            },
            onStartSleep: {
                requestStartSleepFromHomeAction()
            }
        )
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
        store.send(.setSmartAddTaskSheet(true))
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
            showArchivedTasks: store.showArchivedTasks,
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
            rowVisibility: taskRowVisibility,
            showTaskTypeBadge: store.taskListMode == .all,
            statusBadgeStyle: badgeStyle(for: task).map { HomeStatusBadgeStyle($0) },
            iconBackgroundColor: rowIconBackgroundColor(for: task),
            tagColor: tagColor(for:)
        )
    }

    private func tagColor(for tag: String) -> Color? {
        guard let normalizedTag = RoutineTag.normalized(tag) else { return nil }
        return Color(routineTagHex: store.tagColors[normalizedTag])
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
                .padding(.trailing, routineListRowColorBadgeTrailingSpace(for: task))
        }
        .listRowBackground(routineListRowBackground(for: task))
        .overlay(alignment: .topTrailing) {
            routineListRowColorBadge(for: task)
        }
        .contentShape(Rectangle())
        .contextMenu {
            routineContextMenu(for: task, includeMarkDone: includeMarkDone, moveContext: moveContext)
        }
    }

    @ViewBuilder
    private func routineListRowBackground(for task: HomeFeature.RoutineDisplay) -> some View {
        if taskRowVisibility.shows(.rowColor),
           let color = task.color.swiftUIColor {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.12))
                .padding(.vertical, 4)
        }
    }

    private func routineListRowColorBadgeTrailingSpace(for task: HomeFeature.RoutineDisplay) -> CGFloat {
        taskRowVisibility.shows(.colorBadge) && task.color.swiftUIColor != nil ? 14 : 0
    }

    @ViewBuilder
    private func routineListRowColorBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        if taskRowVisibility.shows(.colorBadge),
           let color = task.color.swiftUIColor {
            HomeTaskRowColorMarkerShape()
                .fill(color)
                .frame(width: 10, height: 18)
                .padding(.top, 8)
                .padding(.trailing, 8)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var iosSidebarContent: some View {
        HomeIOSSidebarContent(
            isEmpty: store.routineTasks.isEmpty && !store.isLoading,
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
            if store.isLoading && store.routineTasks.isEmpty {
                HomeLoadingStateView()
            } else {
                listOfSortedTasksView(
                    routineDisplays: store.routineDisplays,
                    awayRoutineDisplays: store.awayRoutineDisplays,
                    archivedRoutineDisplays: store.archivedRoutineDisplays
                )
            }
        } toolbarItems: {
            homeToolbarContent
        }
        .overlay(alignment: .topTrailing) {
            if areTopActionsExpanded {
                topActionRail
                    .padding(.top, 8)
                    .padding(.trailing, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HomePinnedFocusTimerBanner { deepLink in
                switch deepLink {
                case let .task(taskID):
                    openTask(taskID)
                case .goal, .note, .sprint:
                    RoutinaDeepLinkDispatcher.open(deepLink)
                }
            }
        }
    }
}

private struct HomeIOSTopActionRail: View {
    let hasActiveOptionalFilters: Bool
    let showsSleepAction: Bool
    let onQuickAdd: () -> Void
    let onShowFilters: () -> Void
    let onAddNote: () -> Void
    let onCheckIn: () -> Void
    let onStartSleep: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            actionButton(
                title: "Quick Add",
                systemImage: "text.badge.plus",
                tint: .accentColor,
                action: onQuickAdd
            )

            actionButton(
                title: "Filters",
                systemImage: hasActiveOptionalFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle",
                tint: hasActiveOptionalFilters ? .accentColor : .secondary,
                action: onShowFilters
            )

            actionButton(
                title: "Add Note",
                systemImage: "note.text",
                tint: .blue,
                action: onAddNote
            )

            actionButton(
                title: "Check In",
                systemImage: "mappin.and.ellipse",
                tint: .teal,
                action: onCheckIn
            )

            if showsSleepAction {
                actionButton(
                    title: "Going to sleep",
                    systemImage: "bed.double.fill",
                    tint: .indigo,
                    action: onStartSleep
                )
            }
        }
        .padding(7)
        .routinaGlassPanel(cornerRadius: 28, tint: .secondary, tintOpacity: 0.08, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
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

private struct HomePinnedFocusTimerBanner: View {
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query private var tasks: [RoutineTask]
    @Query(sort: \SprintFocusSessionRecord.startedAt, order: .reverse) private var sprintFocusSessions: [SprintFocusSessionRecord]
    @Query private var sprints: [BoardSprintRecord]
    let onOpen: (RoutinaDeepLink) -> Void

    var body: some View {
        if let status = activeStatus {
            Button {
                onOpen(status.deepLink)
            } label: {
                SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 10) {
                        Image(systemName: status.systemImage)
                            .font(.subheadline.weight(.semibold))

                        Text(status.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(status.timeText(at: context.date))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .routinaGlassCard(cornerRadius: 10, tint: .teal, tintOpacity: 0.08, interactive: true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(.teal.opacity(0.35), lineWidth: 1)
                    )
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .routinaGlassPanel(cornerRadius: 0, tint: .teal, tintOpacity: 0.04)
            .accessibilityLabel("Open running timer for \(status.title)")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var activeStatus: HomePinnedFocusTimerStatus? {
        let taskStatus = activeTaskStatus
        let sprintStatus = activeSprintStatus

        switch (taskStatus, sprintStatus) {
        case let (.some(task), .some(sprint)):
            return task.startedAt >= sprint.startedAt ? task : sprint
        case let (.some(task), nil):
            return task
        case let (nil, .some(sprint)):
            return sprint
        case (nil, nil):
            return nil
        }
    }

    private var activeTaskStatus: HomePinnedFocusTimerStatus? {
        guard let session = focusSessions.first(where: { $0.state == .active && $0.startedAt != nil }),
              let startedAt = session.startedAt
        else {
            return nil
        }

        let taskTitle = tasks.first { $0.id == session.taskID }?.name
        return HomePinnedFocusTimerStatus(
            id: session.id,
            targetID: session.taskID,
            kind: .task,
            title: normalizedTitle(taskTitle, fallback: "Task focus"),
            startedAt: startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds
        )
    }

    private var activeSprintStatus: HomePinnedFocusTimerStatus? {
        guard let session = sprintFocusSessions.first(where: { $0.stoppedAt == nil }) else {
            return nil
        }

        let sprintTitle = sprints.first { $0.id == session.sprintID }?.title
        return HomePinnedFocusTimerStatus(
            id: session.id,
            targetID: session.sprintID,
            kind: .sprint,
            title: normalizedTitle(sprintTitle, fallback: "Sprint focus"),
            startedAt: session.startedAt,
            plannedDurationSeconds: 0
        )
    }

    private func normalizedTitle(_ title: String?, fallback: String) -> String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? fallback : trimmedTitle
    }
}

private struct HomePinnedFocusTimerStatus: Equatable {
    enum Kind: Equatable {
        case task
        case sprint
    }

    let id: UUID
    let targetID: UUID
    let kind: Kind
    let title: String
    let startedAt: Date
    let plannedDurationSeconds: TimeInterval

    var systemImage: String {
        switch kind {
        case .task:
            return "timer"
        case .sprint:
            return "flag.checkered"
        }
    }

    var deepLink: RoutinaDeepLink {
        switch kind {
        case .task:
            return .task(targetID)
        case .sprint:
            return .sprint(targetID)
        }
    }

    private var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    func timeText(at date: Date) -> String {
        if overtimeSeconds(at: date) > 0 {
            return "+\(FocusSessionFormatting.durationText(seconds: overtimeSeconds(at: date)))"
        }
        return FocusSessionFormatting.durationText(seconds: displaySeconds(at: date))
    }

    private func displaySeconds(at date: Date) -> TimeInterval {
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        guard !isCountUp else { return elapsed }
        return max(0, plannedDurationSeconds - elapsed)
    }

    private func overtimeSeconds(at date: Date) -> TimeInterval {
        guard !isCountUp else { return 0 }
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        return max(0, elapsed - plannedDurationSeconds)
    }
}
