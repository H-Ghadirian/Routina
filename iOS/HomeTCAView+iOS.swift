import ComposableArchitecture
import SwiftUI

extension View {
    func routinaHomeSidebarColumnWidth() -> some View {
        self
    }
}

extension HomeTCAView {
    @ToolbarContentBuilder
    var homeToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            iosTaskListModeButton(.routines)
            iosTaskListModeButton(.todos)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            platformRefreshButton
            filterSheetButton
            Button {
                openAddTask()
            } label: {
                Label("Add Task", systemImage: "plus")
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
            await performManualRefresh()
        }
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        EmptyView()
    }

    func applyPlatformHomeObservers<Content: View>(to view: Content) -> some View {
        view.onChange(of: iosTaskListMode) { _, mode in
            guard let selectedTaskID = store.selectedTaskID,
                  let task = store.routineTasks.first(where: { $0.id == selectedTaskID })
            else {
                return
            }

            let shouldKeepSelection = mode == .todos ? task.isOneOffTask : !task.isOneOffTask
            if !shouldKeepSelection {
                store.send(.setSelectedTask(nil))
            }
        }
    }

    var searchPlaceholderText: String {
        switch iosTaskListMode {
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
        Picker("Routine Filter", selection: $selectedFilter) {
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
                    Text("All routines").tag(Optional<UUID>.none)
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
        NavigationStack {
            List {
                Section("Status") {
                    Picker("Show routines", selection: $selectedFilter) {
                        ForEach(iOSAvailableFilters) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if !availableTags.isEmpty {
                    Section("Tags") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                tagFilterButton(title: "All Tags", isSelected: selectedTag == nil) {
                                    selectedTag = nil
                                }

                                ForEach(availableTags, id: \.self) { tag in
                                    tagFilterButton(
                                        title: "#\(tag)",
                                        isSelected: selectedTag.map { RoutineTag.contains($0, in: [tag]) } ?? false
                                    ) {
                                        selectedTag = tag
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Place") {
                    if hasSavedPlaces {
                        Picker("Show routines", selection: manualPlaceFilterBinding) {
                            Text("All routines").tag(Optional<UUID>.none)
                            ForEach(sortedRoutinePlaces) { place in
                                Text(place.displayName).tag(Optional(place.id))
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        Text("No saved places yet")
                            .foregroundStyle(.secondary)
                    }

                    if hasPlaceLinkedRoutines && store.locationSnapshot.authorizationStatus.isAuthorized {
                        Toggle("Hide unavailable routines", isOn: hideUnavailableRoutinesBinding)
                    }

                    Text(placeFilterSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if hasPlaceLinkedRoutines {
                        Text(locationStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if hasActiveOptionalFilters {
                    Section {
                        Button("Clear Filters") {
                            clearOptionalFilters()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isFilterSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func matchesCurrentTaskListMode(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch iosTaskListMode {
        case .routines:
            return !task.isOneOffTask
        case .todos:
            return task.isOneOffTask
        }
    }

    var platformTimelineRangePicker: some View {
        Picker("Range", selection: $selectedTimelineRange) {
            ForEach(TimelineRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
    }

    var platformTimelineTypePicker: some View {
        Picker("Type", selection: $selectedTimelineFilterType) {
            ForEach(TimelineFilterType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
    }

    @ViewBuilder
    var platformTagFilterBar: some View {
        if !availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        tagFilterButton(title: "All Tags", isSelected: selectedTag == nil) {
                            selectedTag = nil
                        }

                        ForEach(availableTags, id: \.self) { tag in
                            tagFilterButton(
                                title: "#\(tag)",
                                isSelected: selectedTag.map { RoutineTag.contains($0, in: [tag]) } ?? false
                            ) {
                                selectedTag = tag
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, -2)
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
        let sections = groupedRoutineSections(from: routineDisplays)
        let awayTasks = filteredAwayTasks(awayRoutineDisplays)
        let archivedTasks = filteredArchivedTasks(archivedRoutineDisplays)
        let inlineEmptyState: (title: String, message: String, systemImage: String)? = {
            guard sections.isEmpty && archivedTasks.isEmpty && (store.hideUnavailableRoutines || awayTasks.isEmpty)
            else {
                return nil
            }

            if store.hideUnavailableRoutines && !awayTasks.isEmpty {
                return (
                    title: "No routines available here",
                    message: "\(awayTasks.count) routines are hidden because you are away from their saved place.",
                    systemImage: "location.slash"
                )
            }

            return (
                title: iosTaskListMode == .todos ? "No matching todos" : "No matching routines",
                message: "Try a different search or switch back to another filter.",
                systemImage: "magnifyingglass"
            )
        }()

        VStack(spacing: 0) {
            if !isCompactHeaderHidden && hasActiveOptionalFilters {
                compactHomeHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let inlineEmptyState {
                inlineEmptyStateRow(
                    title: inlineEmptyState.title,
                    message: inlineEmptyState.message,
                    systemImage: inlineEmptyState.systemImage
                )
            } else {
                List(selection: selectedTaskBinding) {
                    ForEach(sections) { section in
                        let sectionStart = sections.prefix(while: { $0.id != section.id }).reduce(0) { $0 + $1.tasks.count }
                        Section(section.title) {
                            ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                                routineNavigationRow(for: task, rowNumber: sectionStart + index + 1)
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: section.tasks)
                            }
                        }
                    }

                    if !store.hideUnavailableRoutines && !awayTasks.isEmpty {
                        let awayOffset = sections.reduce(0) { $0 + $1.tasks.count }
                        Section("Not Here Right Now") {
                            ForEach(Array(awayTasks.enumerated()), id: \.element.id) { index, task in
                                routineNavigationRow(for: task, rowNumber: awayOffset + index + 1, includeMarkDone: false)
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: awayTasks)
                            }
                        }
                    }

                    if !archivedTasks.isEmpty {
                        let archivedOffset = sections.reduce(0) { $0 + $1.tasks.count } + (store.hideUnavailableRoutines ? 0 : awayTasks.count)
                        Section("Archived") {
                            ForEach(Array(archivedTasks.enumerated()), id: \.element.id) { index, task in
                                routineNavigationRow(for: task, rowNumber: archivedOffset + index + 1)
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: archivedTasks)
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
                    routineDetailDestination(taskID: taskID)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.25), value: isCompactHeaderHidden)
    }

    func platformRoutineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        let metadataText = rowMetadataText(for: task)

        return HStack(alignment: .center, spacing: 12) {
            Text("\(rowNumber)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .frame(width: 18, alignment: .trailing)

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
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)

                statusBadge(for: task)

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !task.tags.isEmpty {
                    Text(task.tags.map { "#\($0)" }.joined(separator: "  "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
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
        includeMarkDone: Bool
    ) -> some View {
        NavigationLink(value: task.taskID) {
            routineRow(for: task, rowNumber: rowNumber)
        }
        .contentShape(Rectangle())
        .contextMenu {
            routineContextMenu(for: task, includeMarkDone: includeMarkDone)
        }
    }

    @ViewBuilder
    func platformPinMenuItem(for task: HomeFeature.RoutineDisplay) -> some View {
        EmptyView()
    }

    @ViewBuilder
    func platformDeleteMenuItem(for task: HomeFeature.RoutineDisplay) -> some View {
        Button(role: .destructive) {
            deleteTask(task.taskID)
        } label: {
            Label("Delete", systemImage: "trash")
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
        .navigationTitle("Routina")
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
