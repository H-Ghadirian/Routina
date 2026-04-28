import ComposableArchitecture
import SwiftUI

private struct WrappingHStack: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spacing = currentRowWidth == 0 ? 0 : horizontalSpacing

            if currentRowWidth + spacing + size.width > maxWidth, currentRowWidth > 0 {
                totalHeight += currentRowHeight + verticalSpacing
                maxRowWidth = max(maxRowWidth, currentRowWidth)
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth += spacing + size.width
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        maxRowWidth = max(maxRowWidth, currentRowWidth)
        totalHeight += currentRowHeight

        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedX = x == bounds.minX ? x : x + horizontalSpacing

            if proposedX + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            } else if x > bounds.minX {
                x += horizontalSpacing
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

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
        ToolbarItemGroup(placement: .topBarLeading) {
            if areTaskListModeActionsExpanded {
                iosTaskListModeButton(.all)
                iosTaskListModeButton(.routines)
                iosTaskListModeButton(.todos)
            }
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    areTaskListModeActionsExpanded.toggle()
                    if areTaskListModeActionsExpanded {
                        areTopActionsExpanded = false
                    }
                }
            } label: {
                Label(
                    areTaskListModeActionsExpanded ? "Collapse Task List Modes" : "Expand Task List Modes",
                    systemImage: areTaskListModeActionsExpanded ? "chevron.left.circle" : store.taskListMode.systemImage
                )
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            platformRefreshButton
            if areTopActionsExpanded {
                filterSheetButton
                calendarTaskImportButton
                Button {
                    collapseExpandedToolbarActions()
                    openAddTask()
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }
            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    areTopActionsExpanded.toggle()
                    if areTopActionsExpanded {
                        areTaskListModeActionsExpanded = false
                    }
                }
            } label: {
                Label(
                    areTopActionsExpanded ? "Collapse Actions" : "Expand Actions",
                    systemImage: areTopActionsExpanded ? "chevron.right.circle" : "ellipsis.circle"
                )
            }
        }
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("Place Filtering", systemImage: "location.viewfinder")
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 0)

                    if store.locationSnapshot.authorizationStatus.isAuthorized {
                        Toggle("Hide unavailable", isOn: hideUnavailableRoutinesBinding)
                            .labelsHidden()
                    }
                }

                Picker("Place Filter", selection: manualPlaceFilterBinding) {
                    Text(placeFilterAllTitle).tag(Optional<UUID>.none)
                    ForEach(sortedRoutinePlaces) { place in
                        Text(place.displayName).tag(Optional(place.id))
                    }
                }
                .pickerStyle(.menu)

                Text(manualPlaceFilterDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(locationStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .padding(.horizontal)
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

        VStack(spacing: 0) {
            if !isCompactHeaderHidden && hasActiveOptionalFilters {
                compactHomeHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let emptyState = presentation.emptyState {
                inlineEmptyStateRow(
                    title: emptyState.title,
                    message: emptyState.message,
                    systemImage: emptyState.systemImage
                )
            } else {
                List(selection: selectedTaskBinding) {
                    ForEach(presentation.sections) { section in
                        Section(section.title) {
                            ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                                routineNavigationRow(
                                    for: task,
                                    rowNumber: section.rowNumber(forTaskAt: index),
                                    includeMarkDone: section.includeMarkDone,
                                    moveContext: section.moveContext
                                )
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: section.tasks)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(geometry.contentOffset.y + geometry.contentInsets.top, 0)
                } action: { oldOffset, newOffset in
                    handleCompactHeaderScroll(oldOffset: oldOffset, newOffset: newOffset)
                }
                .navigationDestination(for: UUID.self) { taskID in
                    taskDetailDestination(taskID: taskID)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.25), value: isCompactHeaderHidden)
    }

    func platformRoutineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        let metadataText = rowMetadataText(for: task)

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowIconBackgroundColor(for: task))
                Text(task.emoji)
                    .font(.title3)
                if task.hasImage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "photo.fill")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .padding(4)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(2)
                }
            }
            .frame(width: 40, height: 40)
            .overlay(alignment: .topLeading) {
                Text("\(rowNumber)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .offset(x: -10, y: -8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)

                HStack(spacing: 6) {
                    if store.taskListMode == .all {
                        taskTypeBadge(for: task)
                    }
                    statusBadge(for: task)
                }

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !task.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(task.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .foregroundStyle(tagColor(for: tag) ?? .secondary)
                                .lineLimit(1)
                        }
                    }
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, task.color != .none ? 8 : 0)
        .background(
            task.color.swiftUIColor.map { color in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.12))
            }
        )
    }

    private func tagColor(for tag: String) -> Color? {
        Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: store.tagColors))
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
        .contentShape(Rectangle())
        .contextMenu {
            routineContextMenu(for: task, includeMarkDone: includeMarkDone, moveContext: moveContext)
        }
    }

    @ViewBuilder
    private var iosSidebarContent: some View {
        Group {
            if store.routineTasks.isEmpty {
                emptyStateView(
                    title: "No tasks yet",
                    message: "Add a routine or to-do, and the home list will organize what needs attention for you.",
                    systemImage: "checklist"
                ) {
                    openAddTask()
                }
            } else {
                listOfSortedTasksView(
                    routineDisplays: store.routineDisplays,
                    awayRoutineDisplays: store.awayRoutineDisplays,
                    archivedRoutineDisplays: store.archivedRoutineDisplays
                )
            }
        }
        .navigationTitle(homeNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { homeToolbarContent }
        .routinaHomeSidebarColumnWidth()
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
