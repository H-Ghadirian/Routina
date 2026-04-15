import ComposableArchitecture
import MapKit
import SwiftUI

private enum HomeSidebarSizing {
    static let minWidth: CGFloat = 320
    static let idealWidth: CGFloat = 380
    static let maxWidth: CGFloat = 520
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
    private typealias MacSidebarMode = HomeFeature.MacSidebarMode
    private typealias MacSidebarSelection = HomeFeature.MacSidebarSelection

    @ToolbarContentBuilder
    var homeToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            macDoneCountToolbarItem
            macCanceledCountToolbarItem
            macRoutineCountToolbarItem
            macTodoCountToolbarItem
        }
    }

    var platformNavigationContent: some View {
        NavigationSplitView {
            WithPerceptionTracking {
                macSidebarContent
            }
        } detail: {
            MacDetailContainerView(
                store: store,
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
            }
            .navigationTitle(macSidebarNavigationTitle)
            .environment(\.addEditFormCoordinator, addEditFormCoordinator)
        }
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
                }
            }
    }

    var searchPlaceholderText: String {
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

    private var macAvailableFilters: [RoutineListFilter] {
        [.all, .due, .doneToday]
    }

    var macPlaceFilterOptions: [MacPlaceFilterOption] {
        let linkedRoutineCounts = store.routineTasks.reduce(into: [UUID: Int]()) { partialResult, task in
            guard let placeID = task.placeID else { return }
            partialResult[placeID, default: 0] += 1
        }

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
                status: status
            )
        }
    }

    var isMacTimelineMode: Bool { store.macSidebarMode == .timeline }
    var isMacStatsMode: Bool    { store.macSidebarMode == .stats }
    var isMacSettingsMode: Bool { store.macSidebarMode == .settings }
    var isMacRoutinesMode: Bool { store.macSidebarMode == .routines }
    var isMacAddTaskMode: Bool  { store.macSidebarMode == .addTask }

    var macSidebarNavigationTitle: String {
        switch store.macSidebarMode {
        case .routines:
            switch store.taskListMode {
            case .all:
                return "All"
            case .routines:
                return "Routines"
            case .todos:
                return "Todos"
            }
        case .timeline:
            return "Dones"
        case .stats:
            return "Stats"
        case .settings:
            return "Settings"
        case .addTask:
            return "Add Task"
        }
    }
    var currentSelectedSettingsSection: SettingsMacSection { store.selectedSettingsSection ?? .notifications }

    var macHasCustomFiltersApplied: Bool {
        if store.macSidebarMode == .timeline {
            return store.selectedTimelineRange != .all
                || store.selectedTimelineFilterType != .all
                || store.selectedTimelineTag != nil
                || store.selectedTimelineImportanceUrgencyFilter != nil
                || !store.selectedTimelineExcludedTags.isEmpty
        }
        if store.macSidebarMode == .stats { return false }
        return store.selectedFilter != .all || hasActiveOptionalFilters
    }

    var macExcludeTagsForCurrentMode: Binding<Set<String>> {
        Binding(
            get: { store.excludedTags },
            set: { store.send(.excludedTagsChanged($0)) }
        )
    }

    var macFilterDetailDescription: String {
        switch store.taskListMode {
        case .all:
            return "Refine the combined list by status, importance, urgency, tag, and place. Changes apply to the sidebar immediately."
        case .routines:
            return "Refine the routine list by status, importance, urgency, tag, and place. Changes apply to the sidebar immediately."
        case .todos:
            return "Refine the todo list by status, importance, urgency, tag, and place. Changes apply to the sidebar immediately."
        }
    }

    func clearAllMacFilters() {
        if store.macSidebarMode == .timeline {
            store.send(.selectedTimelineRangeChanged(.all))
            store.send(.selectedTimelineFilterTypeChanged(.all))
            store.send(.selectedTimelineTagChanged(nil))
            store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
            store.send(.selectedTimelineExcludedTagsChanged([]))
        } else {
            store.send(.selectedFilterChanged(.all))
            store.send(.clearOptionalFilters)
        }
    }

    var timelineEntries: [TimelineEntry] {
        baseTimelineEntries
            .filter { entry in
                HomeFeature.matchesImportanceUrgencyFilter(
                    store.selectedTimelineImportanceUrgencyFilter,
                    importance: entry.importance,
                    urgency: entry.urgency
                )
                    && TimelineLogic.matchesSelectedTag(store.selectedTimelineTag, in: entry.tags)
                    && !store.selectedTimelineExcludedTags.contains { RoutineTag.contains($0, in: entry.tags) }
            }
            .filter(matchesTimelineSearch)
    }

    private var baseTimelineEntries: [TimelineEntry] {
        TimelineLogic.filteredEntries(
            logs: store.timelineLogs,
            tasks: store.routineTasks,
            range: store.selectedTimelineRange,
            filterType: store.selectedTimelineFilterType,
            now: Date(),
            calendar: calendar
        )
    }

    var availableTimelineTags: [String] {
        TimelineLogic.availableTags(
            from: filteredTimelineEntriesForTagging
        )
    }

    private var filteredTimelineEntriesForTagging: [TimelineEntry] {
        baseTimelineEntries.filter { entry in
            HomeFeature.matchesImportanceUrgencyFilter(
                store.selectedTimelineImportanceUrgencyFilter,
                importance: entry.importance,
                urgency: entry.urgency
            )
        }
    }

    var availableTimelineExcludeTags: [String] {
        let availableTags = availableTimelineTags.filter { tag in
            store.selectedTimelineTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
        }
        return availableTags
    }

    var groupedTimelineEntries: [(date: Date, entries: [TimelineEntry])] {
        TimelineLogic.groupedByDay(entries: timelineEntries, calendar: calendar)
    }

    private var macSidebarModeBinding: Binding<MacSidebarMode> {
        Binding(
            get: { store.macSidebarMode },
            set: { mode in
                switch mode {
                case .routines:  showRoutinesInSidebar()
                case .timeline:  openTimelineInSidebar()
                case .stats:     openStatsInSidebar()
                case .settings:  openSettingsInSidebar()
                case .addTask:   openAddTask()
                }
            }
        )
    }

    private var macSidebarSelectionBinding: Binding<MacSidebarSelection?> {
        Binding(
            get: { store.macSidebarSelection },
            set: { selection in
                switch selection {
                case let .task(taskID):
                    store.send(.macSidebarSelectionChanged(.task(taskID)))
                case let .timelineEntry(entryID):
                    // Resolve task from @Query-backed timelineEntries then send separately
                    store.send(.macSidebarSelectionChanged(.timelineEntry(entryID)))
                    let taskID = timelineEntries.first(where: { $0.id == entryID })?.taskID
                    store.send(.setSelectedTask(taskID))
                case nil:
                    store.send(.macSidebarSelectionChanged(nil))
                }
            }
        )
    }

    private func openTimelineEntry(_ entry: TimelineEntry) {
        store.send(.macSidebarSelectionChanged(.timelineEntry(entry.id)))
        store.send(.setSelectedTask(entry.taskID))
    }

    private func showRoutinesInSidebar() {
        store.send(.macSidebarModeChanged(.routines))
    }

    private func openTimelineInSidebar() {
        store.send(.macSidebarModeChanged(.timeline))
        validateSelectedTimelineTag()
    }

    private func openStatsInSidebar() {
        store.send(.macSidebarModeChanged(.stats))
    }

    private func openSettingsInSidebar() {
        store.send(.macSidebarModeChanged(.settings))
        settingsStore.send(.onAppear)
    }

    func openSettingsPlacesInSidebar() {
        store.send(.selectedSettingsSectionChanged(.places))
        store.send(.macSidebarModeChanged(.settings))
        settingsStore.send(.onAppear)
    }

    func timelineSidebarRow(_ entry: TimelineEntry, rowNumber: Int) -> some View {
        Button {
            openTimelineEntry(entry)
        } label: {
            HStack(spacing: 12) {
                Text("\(rowNumber)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .frame(width: 18, alignment: .trailing)

                Text(entry.taskEmoji)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.taskName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    Text(entry.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(entry.isOneOff ? "Todo" : "Routine")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(entry.isOneOff
                                ? Color.purple.opacity(0.15)
                                : Color.accentColor.opacity(0.15)
                            )
                    )
                    .foregroundStyle(entry.isOneOff ? .purple : .accentColor)
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .tag(MacSidebarSelection.timelineEntry(entry.id))
        .contentShape(Rectangle())
    }

    private func matchesTimelineSearch(_ entry: TimelineEntry) -> Bool {
        let trimmedSearch = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return entry.taskName.localizedCaseInsensitiveContains(trimmedSearch)
            || entry.taskEmoji.localizedCaseInsensitiveContains(trimmedSearch)
            || (entry.isOneOff
                ? "todo".localizedCaseInsensitiveContains(trimmedSearch)
                : "routine".localizedCaseInsensitiveContains(trimmedSearch))
    }

    func validateSelectedTimelineTag() {
        guard let tag = store.selectedTimelineTag else { return }
        if !RoutineTag.contains(tag, in: availableTimelineTags) {
            store.send(.selectedTimelineTagChanged(nil))
        }
        store.send(
            .selectedTimelineExcludedTagsChanged(
                store.selectedTimelineExcludedTags.filter { RoutineTag.contains($0, in: availableTimelineExcludeTags) }
            )
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
        if !availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Include Tag")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            tagFilterButton(title: "All Tags", isSelected: store.selectedTag == nil) {
                                store.send(.selectedTagChanged(nil))
                            }

                            ForEach(availableTags, id: \.self) { tag in
                                tagFilterButton(
                                    title: "#\(tag)",
                                    isSelected: store.selectedTag.map { RoutineTag.contains($0, in: [tag]) } ?? false
                                ) {
                                    store.send(.selectedTagChanged(tag))
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Exclude Tags")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableExcludeTags, id: \.self) { tag in
                                let isExcluded = store.excludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                                tagFilterButton(
                                    title: "#\(tag)",
                                    isSelected: isExcluded,
                                    selectedColor: .red
                                ) {
                                    if isExcluded {
                                        store.send(.excludedTagsChanged(store.excludedTags.filter { $0 != tag }))
                                    } else {
                                        var newTags = store.excludedTags
                                        newTags.insert(tag)
                                        store.send(.excludedTagsChanged(newTags))
                                        if store.selectedTag.map({ RoutineTag.contains($0, in: [tag]) }) == true {
                                            store.send(.selectedTagChanged(nil))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !store.excludedTags.isEmpty {
                        Text("Hiding tasks tagged: \(store.excludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Select tags to hide tasks that have them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var platformCompactHomeHeader: some View {
        EmptyView()
    }

    @ViewBuilder
    func platformListOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
        let pinnedTasks = filteredPinnedTasks(
            activeRoutineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays
        )
        let sections = groupedRoutineSections(from: (routineDisplays + awayRoutineDisplays).filter { !$0.isPinned })
        let archivedTasks = filteredArchivedTasks(archivedRoutineDisplays, includePinned: false)

        if pinnedTasks.isEmpty && sections.isEmpty && archivedTasks.isEmpty {
            emptyStateView(
                title: emptyTaskListTitle,
                message: emptyTaskListMessage,
                systemImage: "magnifyingglass"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: macSidebarSelectionBinding) {
                let pinnedOffset = 0
                if !pinnedTasks.isEmpty {
                    let pinnedContext = ManualMoveContext(
                        sectionKey: pinnedManualOrderSectionKey,
                        orderedTaskIDs: pinnedTasks.map(\.taskID)
                    )
                    Section("Pinned") {
                        ForEach(Array(pinnedTasks.enumerated()), id: \.element.id) { index, task in
                            routineNavigationRow(
                                for: task,
                                rowNumber: pinnedOffset + index + 1,
                                moveContext: pinnedContext
                            )
                        }
                        .onDelete { offsets in
                            deleteTasks(at: offsets, from: pinnedTasks)
                        }
                    }
                }

                let sectionOffset = pinnedTasks.count
                ForEach(sections) { section in
                    let sectionStart = sectionOffset + sections.prefix(while: { $0.id != section.id }).reduce(0) { $0 + $1.tasks.count }
                    let sectionContext = ManualMoveContext(
                        sectionKey: section.tasks.first.map { regularManualOrderSectionKey(for: $0) } ?? "onTrack",
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                    Section(section.title) {
                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                            routineNavigationRow(
                                for: task,
                                rowNumber: sectionStart + index + 1,
                                moveContext: sectionContext
                            )
                        }
                        .onDelete { offsets in
                            deleteTasks(at: offsets, from: section.tasks)
                        }
                    }
                }

                if !archivedTasks.isEmpty {
                    let archivedOffset = sectionOffset + sections.reduce(0) { $0 + $1.tasks.count }
                    let archivedContext = ManualMoveContext(
                        sectionKey: archivedManualOrderSectionKey,
                        orderedTaskIDs: archivedTasks.map(\.taskID)
                    )
                    Section("Archived") {
                        ForEach(Array(archivedTasks.enumerated()), id: \.element.id) { index, task in
                            routineNavigationRow(
                                for: task,
                                rowNumber: archivedOffset + index + 1,
                                moveContext: archivedContext
                            )
                        }
                        .onDelete { offsets in
                            deleteTasks(at: offsets, from: archivedTasks)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationDestination(for: UUID.self) { taskID in
                taskDetailDestination(taskID: taskID)
            }
        }
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
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.name)
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    statusBadge(for: task)
                }

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
        .padding(.horizontal, task.color != .none ? 8 : 0)
        .background(
            task.color.swiftUIColor.map { color in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
            }
        )
    }

    func platformDeleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        let ids = offsets.compactMap { sectionTasks[$0].taskID }
        store.send(.deleteTasksTapped(ids))
    }

    func platformOpenTask(_ taskID: UUID) {
        store.send(.macSidebarSelectionChanged(.task(taskID)))
    }

    func platformDeleteTask(_ taskID: UUID) {
        store.send(.deleteTasksTapped([taskID]))
    }

    func platformRoutineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool,
        moveContext: ManualMoveContext?
    ) -> some View {
        routineRow(for: task, rowNumber: rowNumber)
            .tag(MacSidebarSelection.task(task.taskID))
            .contentShape(Rectangle())
            .contextMenu {
                routineContextMenu(
                    for: task,
                    includeMarkDone: includeMarkDone,
                    moveContext: moveContext
                )
            }
    }

    @ViewBuilder
    func platformPinMenuItem(for task: HomeFeature.RoutineDisplay) -> some View {
        Button {
            store.send(task.isPinned ? .unpinTask(task.taskID) : .pinTask(task.taskID))
        } label: {
            Label(
                task.isPinned ? "Unpin from Top" : "Pin to Top",
                systemImage: task.isPinned ? "pin.slash" : "pin"
            )
        }
    }

    @ViewBuilder
    func platformDeleteMenuItem(for task: HomeFeature.RoutineDisplay) -> some View {
        Button(role: .destructive) {
            deleteTask(task.taskID)
        } label: {
            Label("Delete", systemImage: "trash")
        }
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

    @ViewBuilder
    private var macSidebarContent: some View {
        Group {
            if isMacAddTaskMode || store.taskDetailState?.isEditSheetPresented == true {
                macFormSectionNav
            } else if isMacRoutinesMode && store.routineTasks.isEmpty {
                VStack(spacing: 0) {
                    macSidebarHeader
                    Divider()
                    emptyStateView(
                        title: "No tasks yet",
                        message: "Add a routine or to-do, and the sidebar will organize what needs attention for you.",
                        systemImage: "checklist"
                    ) {
                        openAddTask()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 0) {
                    macSidebarHeader

                    Divider()

                    if isMacTimelineMode {
                        macTimelineSidebarView
                    } else if isMacStatsMode {
                        macStatsSidebarView
                    } else if isMacSettingsMode {
                        macSettingsSidebarView
                    } else {
                        listOfSortedTasksView(
                            routineDisplays: store.routineDisplays,
                            awayRoutineDisplays: store.awayRoutineDisplays,
                            archivedRoutineDisplays: store.archivedRoutineDisplays
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .navigationTitle("Routina")
        .toolbar { homeToolbarContent }
        .routinaHomeSidebarColumnWidth()
    }

    private var macFormSectionNav: some View {
        let isAdding = isMacAddTaskMode
        let available = isAdding ? macAddFormSections : macEditFormSections
        return HomeMacFormSectionNavView(
            availableSections: available,
            coordinator: addEditFormCoordinator,
            draggedSection: $draggedSection
        ) {
            macSidebarHeader
        }
    }

    private var macAddFormSections: [String] {
        let scheduleMode = store.addRoutineState?.scheduleMode ?? .fixedInterval
        let isStepBased = scheduleMode == .fixedInterval || scheduleMode == .oneOff
        var sections = ["Identity", "Behavior", "Places", "Importance & Urgency", "Tags", "Linked tasks", "Link URL", "Notes"]
        if isStepBased { sections.append("Steps") }
        sections.append("Image")
        sections.append("Attachment")
        return sections
    }

    private var macEditFormSections: [String] {
        guard let detail = store.taskDetailState else { return [] }
        let scheduleMode = detail.editScheduleMode
        var sections = ["Identity", "Behavior", "Places", "Importance & Urgency", "Tags", "Linked tasks", "Link URL", "Notes"]
        if scheduleMode == .fixedInterval || scheduleMode == .oneOff {
            sections.append("Steps")
        }
        sections.append("Image")
        sections.append("Attachment")
        sections.append("Danger Zone")
        return sections
    }

    var macSidebarHeader: some View {
        HomeMacSidebarHeaderView(
            selectedSidebarMode: macSidebarModeBinding,
            selectedTaskListMode: store.taskListMode,
            isRoutinesMode: isMacRoutinesMode,
            isTimelineMode: isMacTimelineMode,
            onSelectTaskListMode: { mode in
                store.send(.taskListModeChanged(mode))
            }
        ) {
            macSearchPanel
        }
    }

    private var emptyTaskListTitle: String {
        switch store.taskListMode {
        case .all:
            return "No matching tasks"
        case .routines:
            return "No matching routines"
        case .todos:
            return "No matching todos"
        }
    }

    private var emptyTaskListMessage: String {
        switch store.taskListMode {
        case .all:
            return "Try a different place or clear a few filters."
        case .routines:
            return "Try a different place or switch back to all routines."
        case .todos:
            return "Try a different place or switch back to all todos."
        }
    }

    private var macSearchPanel: some View {
        HomeMacSearchPanelView(
            hasCustomFiltersApplied: macHasCustomFiltersApplied,
            isFilterDetailPresented: store.isMacFilterDetailPresented,
            onToggleFilters: {
                store.send(.setMacFilterDetailPresented(!store.isMacFilterDetailPresented))
            },
            onClearFilters: {
                clearAllMacFilters()
            }
        ) {
            platformSearchField(searchText: searchTextBinding)
        }
    }

    @ViewBuilder
    var macActiveFiltersDetailView: some View {
        if isMacTimelineMode {
            macTimelineFiltersDetailView
        } else {
            macFiltersDetailView
        }
    }

    private var macFiltersDetailView: some View {
        HomeMacFilterDetailContainerView(
            title: "Filters",
            description: macFilterDetailDescription,
            clearButtonTitle: "Clear All Filters",
            showsClearButton: macHasCustomFiltersApplied,
            onClear: { clearAllMacFilters() }
        ) {
            HomeMacRoutineFiltersDetailView(
                availableFilters: macAvailableFilters,
                selectedFilter: Binding(
                    get: { store.selectedFilter },
                    set: { store.send(.selectedFilterChanged($0)) }
                ),
                selectedImportanceUrgencyFilter: Binding(
                    get: { store.selectedImportanceUrgencyFilter },
                    set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
                ),
                importanceUrgencySummary: importanceUrgencyFilterSummary,
                showsTagSection: !availableTags.isEmpty,
                showsPlaceSection: hasPlaceAwareContent
            ) {
                tagFilterBar
            } placeSectionContent: {
                MacPlaceFilterPanel(
                    options: macPlaceFilterOptions,
                    selectedPlaceID: manualPlaceFilterBinding,
                    hideUnavailableRoutines: hideUnavailableRoutinesBinding,
                    showAvailabilityToggle: hasPlaceLinkedRoutines && store.locationSnapshot.authorizationStatus.isAuthorized,
                    currentLocation: store.locationSnapshot.coordinate,
                    manualPlaceFilterDescription: manualPlaceFilterDescription,
                    locationStatusText: hasPlaceLinkedRoutines ? locationStatusText : nil,
                    onManagePlaces: { openSettingsPlacesInSidebar() }
                )
            }
        }
    }

    private var macTimelineFiltersDetailView: some View {
        HomeMacTimelineFilterDetailContainerView(
            showsClearButton: macHasCustomFiltersApplied,
            onClear: { clearAllMacFilters() },
            onAvailableTagsChange: { validateSelectedTimelineTag() },
            availableTags: availableTimelineTags
        ) {
            HomeMacTimelineFiltersDetailView(
                selectedRange: Binding(
                    get: { store.selectedTimelineRange },
                    set: { store.send(.selectedTimelineRangeChanged($0)) }
                ),
                selectedType: Binding(
                    get: { store.selectedTimelineFilterType },
                    set: { store.send(.selectedTimelineFilterTypeChanged($0)) }
                ),
                selectedImportanceUrgencyFilter: Binding(
                    get: { store.selectedTimelineImportanceUrgencyFilter },
                    set: { store.send(.selectedTimelineImportanceUrgencyFilterChanged($0)) }
                ),
                showsTypeSection: store.routineTasks.contains(where: \.isOneOffTask),
                importanceUrgencySummary: timelineImportanceUrgencySummary,
                allTagsCount: filteredTimelineEntriesForTagging.count,
                availableTags: availableTimelineTags,
                availableExcludeTags: availableTimelineExcludeTags,
                selectedTag: store.selectedTimelineTag,
                selectedExcludedTags: store.selectedTimelineExcludedTags,
                tagSelectionSummary: timelineTagSelectionSummary,
                excludedTagSummary: timelineExcludedTagSummary,
                tagCount: { tag in
                    timelineTagCount(for: tag)
                },
                onSelectTag: { tag in
                    store.send(.selectedTimelineTagChanged(tag))
                },
                onToggleExcludedTag: { tag in
                    if store.selectedTimelineExcludedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
                        store.send(.selectedTimelineExcludedTagsChanged(store.selectedTimelineExcludedTags.filter { $0 != tag }))
                    } else {
                        var newTags = store.selectedTimelineExcludedTags
                        newTags.insert(tag)
                        store.send(.selectedTimelineExcludedTagsChanged(newTags))
                        if store.selectedTimelineTag.map({ RoutineTag.contains($0, in: [tag]) }) == true {
                            store.send(.selectedTimelineTagChanged(nil))
                        }
                    }
                }
            )
        }
    }

    var macStatsSidebarView: some View {
        HomeMacStatsSidebarView(
            selectedTaskTypeFilter: statsStore?.taskTypeFilter ?? .all,
            onSelectTaskTypeFilter: { filter in
                statsStore?.send(.taskTypeFilterChanged(filter))
            },
            selectedRange: statsStore?.selectedRange ?? .week,
            onSelectRange: { range in
                statsStore?.send(.selectedRangeChanged(range))
            },
            selectedImportanceUrgencyFilter: Binding(
                get: { statsStore?.selectedImportanceUrgencyFilter },
                set: { statsStore?.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            importanceUrgencySummary: statsImportanceUrgencySummary,
            allTags: statsAllTags,
            tagSummaries: statsTagSummaries,
            taskCountForSelectedTypeFilter: statsTaskCountForSelectedTypeFilter,
            selectedTag: selectedStatsTag,
            onSelectTag: { tag in
                statsStore?.send(.selectedTagChanged(tag))
            },
            selectedExcludedTags: selectedStatsExcludedTags,
            availableExcludeTags: statsAvailableExcludeTags,
            excludedTagSummary: statsExcludedTagSummary,
            tagSelectionSummary: statsTagSelectionSummary,
            tagCount: { tag in
                statsTagCount(for: tag)
            },
            onToggleExcludedTag: { tag in
                if selectedStatsExcludedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
                    statsStore?.send(.excludedTagsChanged(selectedStatsExcludedTags.filter { $0 != tag }))
                } else {
                    var newTags = selectedStatsExcludedTags
                    newTags.insert(tag)
                    statsStore?.send(.excludedTagsChanged(newTags))
                    if selectedStatsTag.map({ RoutineTag.contains($0, in: [tag]) }) == true {
                        statsStore?.send(.selectedTagChanged(nil))
                    }
                }
            }
        )
    }

    private var statsAllTags: [String] {
        if let statsStore {
            return statsStore.availableTags
        }

        var seen = Set<String>()
        var result: [String] = []
        for task in store.routineTasks {
            for tag in task.tags where !seen.contains(tag) {
                seen.insert(tag)
                result.append(tag)
            }
        }
        return result.sorted()
    }

    private var statsTagSummaries: [RoutineTagSummary] {
        if let statsStore {
            let filteredTasks = statsStore.tasks.filter { task in
                switch statsStore.taskTypeFilter {
                case .all:
                    return true
                case .routines:
                    return !task.isOneOffTask
                case .todos:
                    return task.isOneOffTask
                }
            }.filter { task in
                HomeFeature.matchesImportanceUrgencyFilter(
                    statsStore.selectedImportanceUrgencyFilter,
                    importance: task.importance,
                    urgency: task.urgency
                )
            }
            return RoutineTag.summaries(from: filteredTasks)
        }

        return RoutineTag.summaries(from: store.routineTasks)
    }

    private var statsTaskCountForSelectedTypeFilter: Int {
        if let statsStore {
            return statsStore.tasks.filter { task in
                switch statsStore.taskTypeFilter {
                case .all:
                    return true
                case .routines:
                    return !task.isOneOffTask
                case .todos:
                    return task.isOneOffTask
                }
            }.filter { task in
                HomeFeature.matchesImportanceUrgencyFilter(
                    statsStore.selectedImportanceUrgencyFilter,
                    importance: task.importance,
                    urgency: task.urgency
                )
            }.count
        }

        return store.routineTasks.count
    }

    private var selectedStatsTag: String? {
        statsStore?.selectedTag
    }

    private var selectedStatsExcludedTags: Set<String> {
        statsStore?.excludedTags ?? []
    }

    private var statsTagSelectionSummary: String {
        if let selectedStatsTag {
            let matchingCount = statsTagSummaries.first(where: { $0.name == selectedStatsTag })?.linkedRoutineCount ?? 0
            return "#\(selectedStatsTag) across \(matchingCount) \(matchingCount == 1 ? "routine" : "routines")"
        }

        let tagCount = statsTagSummaries.count
        return "\(tagCount) \(tagCount == 1 ? "tag" : "tags") available"
    }

    private var statsAvailableExcludeTags: [String] {
        statsAllTags.filter { tag in
            selectedStatsTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
        }
    }

    private var statsExcludedTagSummary: String {
        if !selectedStatsExcludedTags.isEmpty {
            return "Hiding tasks tagged: \(selectedStatsExcludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }

        return "Select tags to hide tasks that have them."
    }

    private var timelineImportanceUrgencySummary: String {
        guard let filter = store.selectedTimelineImportanceUrgencyFilter else {
            return "Choose a cell to show done items from tasks that meet or exceed that importance and urgency."
        }
        return "Showing done items from tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    private var statsImportanceUrgencySummary: String {
        guard let filter = statsStore?.selectedImportanceUrgencyFilter else {
            return "Choose a cell to show stats only for tasks that meet or exceed that importance and urgency."
        }
        return "Showing stats for tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    private var timelineTagSelectionSummary: String {
        if let selectedTimelineTag = store.selectedTimelineTag {
            let matchingCount = timelineTagCount(for: selectedTimelineTag)
            return "#\(selectedTimelineTag) across \(matchingCount) \(matchingCount == 1 ? "item" : "items")"
        }

        let tagCount = availableTimelineTags.count
        return "\(tagCount) \(tagCount == 1 ? "tag" : "tags") available"
    }

    private var timelineExcludedTagSummary: String {
        if !store.selectedTimelineExcludedTags.isEmpty {
            return "Hiding items tagged: \(store.selectedTimelineExcludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }

        return "Select tags to hide done items that have them."
    }

    private func statsTagCount(for tag: String) -> Int {
        statsTagSummaries.first(where: { RoutineTag.contains(tag, in: [$0.name]) })?.linkedRoutineCount ?? 0
    }

    private func timelineTagCount(for tag: String) -> Int {
        filteredTimelineEntriesForTagging.filter { entry in
            RoutineTag.contains(tag, in: entry.tags)
        }.count
    }

    var macSettingsSidebarView: some View {
        HomeMacSettingsSidebarView(
            store: settingsStore,
            selectedSection: currentSelectedSettingsSection,
            onSelectSection: { section in
                store.send(.selectedSettingsSectionChanged(section))
            }
        )
    }

    var macTimelineSidebarView: some View {
        HomeMacTimelineSidebarView(
            timelineLogCount: store.timelineLogs.count,
            groupedEntries: groupedTimelineEntries,
            selection: macSidebarSelectionBinding,
            sectionTitle: { date in
                TimelineLogic.daySectionTitle(for: date, calendar: calendar)
            }
        ) { entry, rowNumber in
            timelineSidebarRow(entry, rowNumber: rowNumber)
        }
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
}

struct HomeMacView: View {
    let appStore: StoreOf<AppFeature>
    let store: StoreOf<HomeFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let statsStore: StoreOf<StatsFeature>

    var body: some View {
        HomeTCAView(
            store: store,
            settingsStore: settingsStore,
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
    }
}
