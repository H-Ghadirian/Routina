import ComposableArchitecture
import MapKit
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

    var filterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(macAvailableFilters) { filter in
                    Button {
                        store.send(.selectedFilterChanged(filter))
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(
                                store.selectedFilter == filter ? Color.white : Color.primary
                            )
                            .background(
                                Capsule()
                                    .fill(
                                        store.selectedFilter == filter
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.10)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
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

    func macSidebarSectionCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.quaternary.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
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
        let sections = addEditFormCoordinator.orderedSections(available: available)

        return VStack(alignment: .leading, spacing: 0) {
            macSidebarHeader

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sections, id: \.self) { section in
                        let isMovable = section != "Identity"
                        Button {
                            addEditFormCoordinator.scrollTarget = section
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.12))
                                    Image(systemName: formSectionIcon(for: section))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .frame(width: 32, height: 32)

                                Text(section)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer(minLength: 0)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.secondary.opacity(0.6))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.secondary.opacity(0.07))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .opacity(draggedSection == section ? 0.4 : 1)
                        .if(isMovable) { view in
                            view
                                .draggable(section) {
                                    formSectionDragPreview(for: section)
                                }
                                .contextMenu {
                                    formSectionContextMenu(for: section, available: available)
                                }
                        }
                        .if(isMovable) { view in
                            view.onDrop(of: [.text], delegate: SectionDropDelegate(
                                item: section,
                                coordinator: addEditFormCoordinator,
                                draggedSection: $draggedSection,
                                available: available
                            ))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formSectionDragPreview(for section: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: formSectionIcon(for: section))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(section)
                .font(.body.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .onAppear { draggedSection = section }
    }

    @ViewBuilder
    private func formSectionContextMenu(for section: String, available: [String]) -> some View {
        let ordered = addEditFormCoordinator.orderedSections(available: available)
        let movableOrdered = ordered.filter { $0 != "Identity" }
        let isFirst = movableOrdered.first == section
        let isLast = movableOrdered.last == section

        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                addEditFormCoordinator.moveUp(section)
            }
        } label: {
            Label("Move Up", systemImage: "arrow.up")
        }
        .disabled(isFirst)

        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                addEditFormCoordinator.moveDown(section)
            }
        } label: {
            Label("Move Down", systemImage: "arrow.down")
        }
        .disabled(isLast)
    }

    private func formSectionIcon(for section: String) -> String {
        switch section {
        case "Identity":           return "person.fill"
        case "Behavior":           return "repeat"
        case "Places":             return "mappin.and.ellipse"
        case "Importance & Urgency": return "flag.fill"
        case "Tags":               return "tag.fill"
        case "Linked tasks":       return "link"
        case "Link URL":           return "globe"
        case "Notes":              return "note.text"
        case "Steps":              return "list.number"
        case "Image":              return "photo.fill"
        case "Attachment":         return "paperclip"
        case "Danger Zone":        return "exclamationmark.triangle.fill"
        default:                   return "circle.fill"
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
                macSidebarSectionCard {
                    filterPicker
                }

                macSidebarSectionCard(title: "Importance & Urgency") {
                    macImportanceUrgencyMatrix
                }

                if !availableTags.isEmpty {
                    macSidebarSectionCard {
                        tagFilterBar
                    }
                }

                if hasPlaceAwareContent {
                    macSidebarSectionCard {
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
    }

    private var macImportanceUrgencyMatrix: some View {
        HomeMacImportanceUrgencyMatrixView(
            selectedFilter: Binding(
                get: { store.selectedImportanceUrgencyFilter },
                set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            summaryText: importanceUrgencyFilterSummary
        )
    }

    private var macTimelineFiltersDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Done Filters")
                            .font(.largeTitle.weight(.semibold))

                        Text("Refine the done history in the sidebar by date range and type. Search applies to done entries while Timeline is open.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if macHasCustomFiltersApplied {
                        Button("Clear Filters") {
                            clearAllMacFilters()
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                }

                macSidebarSectionCard(title: "Range") {
                    timelineRangePicker
                }

                if store.routineTasks.contains(where: \.isOneOffTask) {
                    macSidebarSectionCard(title: "Type") {
                        timelineTypePicker
                    }
                }

                macSidebarSectionCard(title: "Importance & Urgency") {
                    Button(store.selectedTimelineImportanceUrgencyFilter == nil ? "All levels selected" : "Show all levels") {
                        store.send(.selectedTimelineImportanceUrgencyFilterChanged(nil))
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.selectedTimelineImportanceUrgencyFilter == nil ? Color.accentColor : Color.primary)

                    ImportanceUrgencyMatrixPicker(
                        selectedFilter: Binding(
                            get: { store.selectedTimelineImportanceUrgencyFilter },
                            set: { store.send(.selectedTimelineImportanceUrgencyFilterChanged($0)) }
                        )
                    )
                    .frame(maxWidth: 420, alignment: .leading)

                    Text(timelineImportanceUrgencySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !availableTimelineTags.isEmpty {
                    macSidebarSectionCard(title: "Tags") {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Include Tag")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)

                                Text(timelineTagSelectionSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)

                                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                                    statsTagChip(
                                        title: "All Tags",
                                        count: filteredTimelineEntriesForTagging.count,
                                        systemImage: "tag.slash.fill",
                                        isSelected: store.selectedTimelineTag == nil
                                    ) {
                                        store.send(.selectedTimelineTagChanged(nil))
                                    }

                                    ForEach(availableTimelineTags, id: \.self) { tag in
                                        statsTagChip(
                                            title: "#\(tag)",
                                            count: timelineTagCount(for: tag),
                                            systemImage: "tag.fill",
                                            isSelected: store.selectedTimelineTag.map { RoutineTag.contains($0, in: [tag]) } ?? false
                                        ) {
                                            store.send(.selectedTimelineTagChanged(tag))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !availableTimelineExcludeTags.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Exclude Tags")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)

                                    Text(timelineExcludedTagSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)

                                    WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                                        ForEach(availableTimelineExcludeTags, id: \.self) { tag in
                                            let isExcluded = store.selectedTimelineExcludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                                            statsTagChip(
                                                title: "#\(tag)",
                                                count: timelineTagCount(for: tag),
                                                systemImage: "tag.slash.fill",
                                                isSelected: isExcluded,
                                                selectedColor: .red
                                            ) {
                                                if isExcluded {
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
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
            .onChange(of: availableTimelineTags) { _, _ in
                validateSelectedTimelineTag()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    var macStatsSidebarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Show")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(StatsTaskTypeFilter.allCases) { filter in
                            statsTaskTypeChip(filter)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Time Range")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(DoneChartRange.allCases) { range in
                            statsRangeChip(range)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Importance & Urgency")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    Button(statsStore?.selectedImportanceUrgencyFilter == nil ? "All levels selected" : "Show all levels") {
                        statsStore?.send(.selectedImportanceUrgencyFilterChanged(nil))
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statsStore?.selectedImportanceUrgencyFilter == nil ? Color.accentColor : Color.primary)
                    .padding(.horizontal, 4)

                    ImportanceUrgencyMatrixPicker(
                        selectedFilter: Binding(
                            get: { statsStore?.selectedImportanceUrgencyFilter },
                            set: { statsStore?.send(.selectedImportanceUrgencyFilterChanged($0)) }
                        )
                    )
                    .frame(maxWidth: 420, alignment: .leading)
                    .padding(.horizontal, 4)

                    Text(statsImportanceUrgencySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }

                if !statsAllTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Filter by Tag")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        Text(statsTagSelectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                            statsTagChip(
                                title: "All Tags",
                                count: statsTaskCountForSelectedTypeFilter,
                                systemImage: "tag.slash.fill",
                                isSelected: selectedStatsTag == nil
                            ) {
                                statsStore?.send(.selectedTagChanged(nil))
                            }

                            ForEach(statsTagSummaries) { summary in
                                statsTagChip(
                                    title: "#\(summary.name)",
                                    count: summary.linkedRoutineCount,
                                    systemImage: "tag.fill",
                                    isSelected: selectedStatsTag == summary.name
                                ) {
                                    statsStore?.send(.selectedTagChanged(summary.name))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exclude Tags")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        Text(statsExcludedTagSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                            ForEach(statsAvailableExcludeTags, id: \.self) { tag in
                                let isExcluded = selectedStatsExcludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                                statsTagChip(
                                    title: "#\(tag)",
                                    count: statsTagCount(for: tag),
                                    systemImage: "tag.slash.fill",
                                    isSelected: isExcluded,
                                    selectedColor: .red
                                ) {
                                    if isExcluded {
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
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var selectedStatsTaskTypeFilter: StatsTaskTypeFilter {
        statsStore?.taskTypeFilter ?? .all
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

    private var selectedStatsRange: DoneChartRange {
        statsStore?.selectedRange ?? .week
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

    @ViewBuilder
    private func statsTaskTypeChip(_ filter: StatsTaskTypeFilter) -> some View {
        Button {
            statsStore?.send(.taskTypeFilterChanged(filter))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statsTaskTypeIcon(for: filter))
                    .font(.caption.weight(.semibold))

                Text(filter.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedStatsTaskTypeFilter == filter ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedStatsTaskTypeFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selectedStatsTaskTypeFilter == filter ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statsTaskTypeIcon(for filter: StatsTaskTypeFilter) -> String {
        switch filter {
        case .all: return "square.grid.2x2"
        case .routines: return "repeat"
        case .todos: return "checklist"
        }
    }

    @ViewBuilder
    private func statsRangeChip(_ range: DoneChartRange) -> some View {
        Button {
            statsStore?.send(.selectedRangeChanged(range))
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statsRangeIcon(for: range))
                    .font(.caption.weight(.semibold))

                Text(range.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedStatsRange == range ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedStatsRange == range ? Color.accentColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selectedStatsRange == range ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statsRangeIcon(for range: DoneChartRange) -> String {
        switch range {
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        case .year: return "calendar.badge.plus"
        }
    }

    @ViewBuilder
    private func statsTagChip(
        title: String,
        count: Int,
        systemImage: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))

                Text(title)
                    .font(.caption.weight(.semibold))

                Text(count.formatted())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.18) : Color.primary.opacity(0.08))
                    )
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? selectedColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? selectedColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    var macSettingsSidebarView: some View {
        List {
            ForEach(SettingsMacSection.allCases) { section in
                Button {
                    store.send(.selectedSettingsSectionChanged(section))
                } label: {
                    SettingsMacSidebarRow(
                        section: section,
                        store: settingsStore
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(store.selectedSettingsSection == section ? Color.accentColor.opacity(0.9) : Color.clear)
                        .padding(.vertical, 2)
                )
            }
        }
        .listStyle(.sidebar)
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

// MARK: - Drag-and-drop delegate for sidebar section reordering

private struct SectionDropDelegate: DropDelegate {
    let item: String
    let coordinator: AddEditFormCoordinator
    @Binding var draggedSection: String?
    let available: [String]

    func performDrop(info: DropInfo) -> Bool {
        draggedSection = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedSection, dragged != item else { return }
        // Work within the movable order (excludes Identity)
        let order = coordinator.sectionOrder
        guard let fromIndex = order.firstIndex(of: dragged),
              let toIndex = order.firstIndex(of: item) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            coordinator.sectionOrder.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggedSection != nil
    }
}
