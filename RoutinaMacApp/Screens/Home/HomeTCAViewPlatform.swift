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
            return store.taskListMode == .todos ? "Todos" : "Routines"
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
        case .routines:
            return "Refine the routine list by status, tag, and place. Changes apply to the sidebar immediately."
        case .todos:
            return "Refine the todo list by status, tag, and place. Changes apply to the sidebar immediately."
        }
    }

    func clearAllMacFilters() {
        if store.macSidebarMode == .timeline {
            store.send(.selectedTimelineRangeChanged(.all))
            store.send(.selectedTimelineFilterTypeChanged(.all))
            store.send(.selectedTimelineTagChanged(nil))
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
                TimelineLogic.matchesSelectedTag(store.selectedTimelineTag, in: entry.tags)
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
        TimelineLogic.availableTags(from: baseTimelineEntries)
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
                title: store.taskListMode == .todos ? "No matching todos" : "No matching routines",
                message: store.taskListMode == .todos
                    ? "Try a different place or switch back to all todos."
                    : "Try a different place or switch back to all routines.",
                systemImage: "magnifyingglass"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: macSidebarSelectionBinding) {
                let pinnedOffset = 0
                if !pinnedTasks.isEmpty {
                    Section("Pinned") {
                        ForEach(Array(pinnedTasks.enumerated()), id: \.element.id) { index, task in
                            routineNavigationRow(for: task, rowNumber: pinnedOffset + index + 1)
                        }
                        .onDelete { offsets in
                            deleteTasks(at: offsets, from: pinnedTasks)
                        }
                    }
                }

                let sectionOffset = pinnedTasks.count
                ForEach(sections) { section in
                    let sectionStart = sectionOffset + sections.prefix(while: { $0.id != section.id }).reduce(0) { $0 + $1.tasks.count }
                    Section(section.title) {
                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                            routineNavigationRow(for: task, rowNumber: sectionStart + index + 1)
                        }
                        .onDelete { offsets in
                            deleteTasks(at: offsets, from: section.tasks)
                        }
                    }
                }

                if !archivedTasks.isEmpty {
                    let archivedOffset = sectionOffset + sections.reduce(0) { $0 + $1.tasks.count }
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
        includeMarkDone: Bool
    ) -> some View {
        routineRow(for: task, rowNumber: rowNumber)
            .tag(MacSidebarSelection.task(task.taskID))
            .contentShape(Rectangle())
            .contextMenu {
                routineContextMenu(for: task, includeMarkDone: includeMarkDone)
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
        let sections = isAdding ? macAddFormSections : macEditFormSections

        return VStack(alignment: .leading, spacing: 0) {
            macSidebarHeader

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sections, id: \.self) { section in
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
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formSectionIcon(for section: String) -> String {
        switch section {
        case "Identity":           return "person.fill"
        case "Behavior":           return "repeat"
        case "Places":             return "mappin.fill"
        case "Importance & Urgency": return "flag.fill"
        case "Context":            return "tag.fill"
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
        var sections = ["Identity", "Behavior", "Places", "Importance & Urgency", "Context", "Notes"]
        if isStepBased { sections.append("Steps") }
        sections.append("Image")
        sections.append("Attachment")
        return sections
    }

    private var macEditFormSections: [String] {
        guard let detail = store.taskDetailState else { return [] }
        let scheduleMode = detail.editScheduleMode
        var sections = ["Identity", "Behavior", "Places", "Importance & Urgency", "Context", "Notes"]
        if scheduleMode == .fixedInterval || scheduleMode == .oneOff {
            sections.append("Steps")
        }
        sections.append("Image")
        sections.append("Attachment")
        sections.append("Danger Zone")
        return sections
    }

    var macSidebarHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            macSidebarModeStrip
            if isMacRoutinesMode {
                macTaskListModeStrip
            }
            if isMacRoutinesMode || isMacTimelineMode {
                macSearchPanel
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var macSidebarModeStrip: some View {
        HStack(spacing: 0) {
            ForEach(MacSidebarMode.allCases) { mode in
                Button {
                    macSidebarModeBinding.wrappedValue = mode
                } label: {
                    let isSelected = macSidebarModeBinding.wrappedValue == mode
                    let isAddTab = mode == .addTask
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected
                                ? (isAddTab ? Color.accentColor : Color.accentColor)
                                : Color.clear)

                        Image(systemName: macSidebarModeIcon(for: mode))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : (isAddTab ? Color.accentColor : Color.secondary))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(mode.rawValue)

                if mode == .settings {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 42)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var macTaskListModeStrip: some View {
        HStack(spacing: 8) {
            ForEach(HomeFeature.TaskListMode.allCases) { mode in
                Button {
                    store.send(.taskListModeChanged(mode))
                } label: {
                    Text(mode.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .foregroundStyle(store.taskListMode == mode ? Color.white : Color.primary)
                        .background(
                            Capsule()
                                .fill(store.taskListMode == mode ? Color.accentColor : Color.secondary.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func macSidebarModeIcon(for mode: MacSidebarMode) -> String {
        switch mode {
        case .routines: return "checklist"
        case .timeline: return "clock.arrow.circlepath"
        case .stats: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        case .addTask: return "plus"
        }
    }

    private var macSearchPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                platformSearchField(searchText: searchTextBinding)

                Button {
                    store.send(.setMacFilterDetailPresented(!store.isMacFilterDetailPresented))
                } label: {
                    Image(
                        systemName: macHasCustomFiltersApplied
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                    .font(.title3)
                    .foregroundStyle(
                        store.isMacFilterDetailPresented || macHasCustomFiltersApplied
                            ? Color.accentColor
                            : Color.secondary
                    )
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                store.isMacFilterDetailPresented
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.secondary.opacity(0.07)
                            )
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show filters")
            }

            if macHasCustomFiltersApplied {
                Button("Clear All Filters") {
                    clearAllMacFilters()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filters")
                            .font(.largeTitle.weight(.semibold))

                        Text(macFilterDetailDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if macHasCustomFiltersApplied {
                        Button("Clear All Filters") {
                            clearAllMacFilters()
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    }
                }

                macSidebarSectionCard {
                    filterPicker
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
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
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
                                        count: baseTimelineEntries.count,
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
        baseTimelineEntries.filter { entry in
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
        Group {
            if store.timelineLogs.isEmpty {
                emptyStateView(
                    title: "No completions yet",
                    message: "Completed routines and todos will appear here in chronological order.",
                    systemImage: "clock.arrow.circlepath"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groupedTimelineEntries.isEmpty {
                emptyStateView(
                    title: "No matching dones",
                    message: "Try a different search, time range, or done type.",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: macSidebarSelectionBinding) {
                    ForEach(Array(groupedTimelineEntries.enumerated()), id: \.element.date) { sectionIndex, section in
                        let sectionStart = groupedTimelineEntries.prefix(sectionIndex).reduce(0) { $0 + $1.entries.count }
                        Section(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar)) {
                            ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                                timelineSidebarRow(entry, rowNumber: sectionStart + index + 1)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
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

/// Separate View struct so SwiftUI gives it its own observation lifecycle.
/// Inline closures inside `NavigationSplitView.detail` on macOS can lose
/// observation tracking after several view swaps, causing state changes
/// (like toggling the filter panel) to stop updating the detail column.
struct MacDetailContainerView<FilterView: View>: View {
    let store: StoreOf<HomeFeature>
    let isTimelinePresented: Bool
    let isStatsPresented: Bool
    let isSettingsPresented: Bool
    let settingsStore: StoreOf<SettingsFeature>
    let statsStore: StoreOf<StatsFeature>?
    let selectedSettingsSection: SettingsMacSection
    let addRoutineStore: StoreOf<AddRoutineFeature>?
    @ViewBuilder let filterView: () -> FilterView

    var body: some View {
        WithPerceptionTracking {
            if store.isMacFilterDetailPresented {
                filterView()
            } else if let addRoutineStore {
                AddRoutineTCAView(store: addRoutineStore)
            } else if isStatsPresented, let statsStore {
                StatsViewWrapper(store: statsStore)
            } else if isStatsPresented {
                ContentUnavailableView(
                    "Stats unavailable",
                    systemImage: "chart.bar.xaxis",
                    description: Text("The stats store is not currently connected for this view.")
                )
            } else if isSettingsPresented {
                EmbeddedSettingsMacDetailView(
                    store: settingsStore,
                    section: selectedSettingsSection
                )
            } else if let detailStore = store.scope(
                state: \.taskDetailState,
                action: \.taskDetail
            ) {
                TaskDetailTCAView(store: detailStore)
            } else {
                ContentUnavailableView(
                    isTimelinePresented
                        ? "Select a done item or filters"
                        : (store.routineTasks.isEmpty ? "Add a task to get started" : "Select a task"),
                    systemImage: isTimelinePresented ? "clock.arrow.circlepath" : "sidebar.right",
                    description: Text(
                        isTimelinePresented
                            ? "Choose a completed routine or todo from the sidebar, or open filters beside search to refine the done history."
                            : (
                                store.routineTasks.isEmpty
                                    ? "Add a routine or to-do to see its details here."
                                    : "Choose a routine or to-do from the sidebar to see its details."
                            )
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct MacPlaceFilterOption: Equatable, Identifiable {
    enum Status: Equatable {
        case here
        case away(distanceMeters: Double)
        case unknown
    }

    let place: RoutinePlace
    let linkedRoutineCount: Int
    let status: Status

    var id: UUID { place.id }
    var coordinate: CLLocationCoordinate2D { placeCoordinate.clLocationCoordinate2D }

    var placeCoordinate: LocationCoordinate {
        LocationCoordinate(latitude: place.latitude, longitude: place.longitude)
    }

    var subtitle: String {
        let routineText = linkedRoutineCount == 1 ? "1 routine" : "\(linkedRoutineCount) routines"
        return "\(routineText) • \(Int(place.radiusMeters)) m radius"
    }
}

struct MacPlaceFilterDetailView: View {
    let options: [MacPlaceFilterOption]
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool
    let showAvailabilityToggle: Bool
    let currentLocation: LocationCoordinate?
    let manualPlaceFilterDescription: String
    let locationStatusText: String?
    let onManagePlaces: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Place Filter")
                        .font(.largeTitle.weight(.semibold))

                    Text("Choose a saved place from the list and filter the routine sidebar by that location.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                MacPlaceFilterPanel(
                    options: options,
                    selectedPlaceID: $selectedPlaceID,
                    hideUnavailableRoutines: $hideUnavailableRoutines,
                    showAvailabilityToggle: showAvailabilityToggle,
                    currentLocation: currentLocation,
                    manualPlaceFilterDescription: manualPlaceFilterDescription,
                    locationStatusText: locationStatusText,
                    onManagePlaces: onManagePlaces
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct MacPlaceFilterPanel: View {
    let options: [MacPlaceFilterOption]
    @Binding var selectedPlaceID: UUID?
    @Binding var hideUnavailableRoutines: Bool
    let showAvailabilityToggle: Bool
    let currentLocation: LocationCoordinate?
    let manualPlaceFilterDescription: String
    let locationStatusText: String?
    let onManagePlaces: () -> Void

    @State private var mapPosition: MapCameraPosition

    init(
        options: [MacPlaceFilterOption],
        selectedPlaceID: Binding<UUID?>,
        hideUnavailableRoutines: Binding<Bool>,
        showAvailabilityToggle: Bool,
        currentLocation: LocationCoordinate?,
        manualPlaceFilterDescription: String,
        locationStatusText: String?,
        onManagePlaces: @escaping () -> Void
    ) {
        self.options = options
        _selectedPlaceID = selectedPlaceID
        _hideUnavailableRoutines = hideUnavailableRoutines
        self.showAvailabilityToggle = showAvailabilityToggle
        self.currentLocation = currentLocation
        self.manualPlaceFilterDescription = manualPlaceFilterDescription
        self.locationStatusText = locationStatusText
        self.onManagePlaces = onManagePlaces
        _mapPosition = State(
            initialValue: Self.mapCameraPosition(
                options: options,
                selectedPlaceID: selectedPlaceID.wrappedValue,
                currentLocation: currentLocation
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelHeader
            panelContent
            panelFooter
        }
        .onAppear(perform: updateMapPosition)
        .onChange(of: selectedPlaceID) { _, _ in
            updateMapPosition()
        }
        .onChange(of: options) { _, _ in
            updateMapPosition()
        }
        .onChange(of: currentLocation) { _, _ in
            updateMapPosition()
        }
    }

    private var panelHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label("Places", systemImage: "location.viewfinder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if selectedPlaceID != nil {
                Button("Clear") {
                    selectedPlaceID = nil
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            }

            Button("Manage") {
                onManagePlaces()
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        if options.isEmpty {
            Text("Save places in Settings to filter routines with a map-based view here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(alignment: .top, spacing: 12) {
                placeListColumn

                Divider()
                    .padding(.vertical, 2)

                mapPreview
            }
            .frame(height: 340)
        }
    }

    @ViewBuilder
    private var panelFooter: some View {
        if showAvailabilityToggle {
            Toggle("Hide unavailable routines", isOn: $hideUnavailableRoutines)
                .toggleStyle(.switch)
                .font(.caption)
        }

        Text(manualPlaceFilterDescription)
            .font(.caption)
            .foregroundStyle(.secondary)

        if let locationStatusText {
            Text(locationStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var placeListColumn: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                allRoutinesRow

                ForEach(options) { option in
                    MacPlaceFilterRow(
                        option: option,
                        isSelected: selectedPlaceID == option.id
                    ) {
                        selectedPlaceID = option.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var allRoutinesRow: some View {
        Button {
            selectedPlaceID = nil
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedPlaceID == nil ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(
                                selectedPlaceID == nil
                                    ? Color.accentColor.opacity(0.16)
                                    : Color.secondary.opacity(0.10)
                            )
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("All routines")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Show every routine without filtering by place.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground(isSelected: selectedPlaceID == nil))
        }
        .buttonStyle(.plain)
    }

    private var mapPreview: some View {
        Map(position: $mapPosition) {
            ForEach(options) { option in
                MapCircle(
                    center: option.coordinate,
                    radius: option.place.radiusMeters
                )
                .foregroundStyle(circleColor(for: option))

                Annotation(option.place.displayName, coordinate: option.coordinate) {
                    Circle()
                        .fill(selectedPlaceID == option.id ? Color.accentColor : Color.white.opacity(0.92))
                        .overlay(
                            Circle()
                                .stroke(selectedPlaceID == option.id ? Color.white : Color.accentColor, lineWidth: 2)
                        )
                        .frame(width: selectedPlaceID == option.id ? 14 : 10, height: selectedPlaceID == option.id ? 14 : 10)
                        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                }
            }

            if let currentLocation {
                Annotation("Current Location", coordinate: currentLocation.clLocationCoordinate2D) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.18))
                            .frame(width: 20, height: 20)

                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .mapStyle(.standard)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Text(selectedPlaceMapTitle)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(10)
        }
        .frame(maxWidth: 280, maxHeight: .infinity)
    }

    private var selectedPlaceMapTitle: String {
        if let selectedPlaceID,
           let option = options.first(where: { $0.id == selectedPlaceID }) {
            return option.place.displayName
        }
        return "All saved places"
    }

    private func circleColor(for option: MacPlaceFilterOption) -> Color {
        selectedPlaceID == option.id ? Color.accentColor.opacity(0.22) : Color.accentColor.opacity(0.10)
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
    }

    private func updateMapPosition() {
        withAnimation(.snappy(duration: 0.3)) {
            mapPosition = Self.mapCameraPosition(
                options: options,
                selectedPlaceID: selectedPlaceID,
                currentLocation: currentLocation
            )
        }
    }

    private static func mapCameraPosition(
        options: [MacPlaceFilterOption],
        selectedPlaceID: UUID?,
        currentLocation: LocationCoordinate?
    ) -> MapCameraPosition {
        guard !options.isEmpty else {
            let fallbackRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
            return .region(fallbackRegion)
        }

        if let selectedPlaceID,
           let selectedOption = options.first(where: { $0.id == selectedPlaceID }) {
            return .region(region(focusingOn: selectedOption.place))
        }

        return .region(regionIncludingAllPlaces(options, currentLocation: currentLocation))
    }

    private static func region(focusingOn place: RoutinePlace) -> MKCoordinateRegion {
        let latitudeDelta = max(latitudeDelta(forMeters: place.radiusMeters * 4), 0.01)
        let longitudeDelta = max(
            longitudeDelta(forMeters: place.radiusMeters * 4, latitude: place.latitude),
            0.01
        )

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private static func regionIncludingAllPlaces(
        _ options: [MacPlaceFilterOption],
        currentLocation: LocationCoordinate?
    ) -> MKCoordinateRegion {
        var minLatitude = Double.greatestFiniteMagnitude
        var maxLatitude = -Double.greatestFiniteMagnitude
        var minLongitude = Double.greatestFiniteMagnitude
        var maxLongitude = -Double.greatestFiniteMagnitude

        for option in options {
            let latitudeInset = latitudeDelta(forMeters: option.place.radiusMeters * 1.8)
            let longitudeInset = longitudeDelta(
                forMeters: option.place.radiusMeters * 1.8,
                latitude: option.place.latitude
            )

            minLatitude = min(minLatitude, option.place.latitude - latitudeInset)
            maxLatitude = max(maxLatitude, option.place.latitude + latitudeInset)
            minLongitude = min(minLongitude, option.place.longitude - longitudeInset)
            maxLongitude = max(maxLongitude, option.place.longitude + longitudeInset)
        }

        if let currentLocation {
            minLatitude = min(minLatitude, currentLocation.latitude)
            maxLatitude = max(maxLatitude, currentLocation.latitude)
            minLongitude = min(minLongitude, currentLocation.longitude)
            maxLongitude = max(maxLongitude, currentLocation.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let latitudeDelta = max((maxLatitude - minLatitude) * 1.35, 0.02)
        let longitudeDelta = max((maxLongitude - minLongitude) * 1.35, 0.02)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    private static func latitudeDelta(forMeters meters: Double) -> Double {
        meters / 111_000
    }

    private static func longitudeDelta(forMeters meters: Double, latitude: Double) -> Double {
        let cosine = max(abs(cos(latitude * .pi / 180)), 0.2)
        return meters / (111_000 * cosine)
    }
}

struct MacPlaceFilterRow: View {
    let option: MacPlaceFilterOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(option.place.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        MacPlaceStatusBadge(status: option.status)
                    }

                    Text(option.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }
}

struct MacPlaceStatusBadge: View {
    let status: MacPlaceFilterOption.Status

    var body: some View {
        Text(labelText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }

    private var labelText: String {
        switch status {
        case .here:
            return "Here"
        case let .away(distanceMeters):
            if distanceMeters < 1_000 {
                return "\(Int(distanceMeters.rounded())) m away"
            }
            return String(format: "%.1f km", distanceMeters / 1_000)
        case .unknown:
            return "Unknown"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .here:
            return .green
        case .away:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .here:
            return Color.green.opacity(0.15)
        case .away:
            return Color.orange.opacity(0.16)
        case .unknown:
            return Color.secondary.opacity(0.12)
        }
    }
}

struct MacToolbarIconButton: NSViewRepresentable {
    let title: String
    let systemImage: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let button = NSButton(
            image: NSImage(systemSymbolName: systemImage, accessibilityDescription: title) ?? NSImage(),
            target: context.coordinator,
            action: #selector(Coordinator.performAction)
        )
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.toolTip = title
        button.contentTintColor = .labelColor
        button.setButtonType(.momentaryPushIn)
        return button
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let button = nsView as? NSButton else {
            return
        }

        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        button.toolTip = title
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        private let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

struct MacToolbarStatusBadge: NSViewRepresentable {
    let title: String
    let systemImage: String
    let tintColor: NSColor

    func makeNSView(context: Context) -> NSView {
        let imageView = NSImageView()
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        imageView.contentTintColor = tintColor

        let textField = NSTextField(labelWithString: title)
        textField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        textField.textColor = tintColor
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.setContentHuggingPriority(.required, for: .horizontal)

        let stackView = NSStackView(views: [imageView, textField])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 5
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        update(stackView: stackView, imageView: imageView, textField: textField)
        return stackView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let stackView = nsView as? NSStackView,
              stackView.views.count == 2,
              let imageView = stackView.views[0] as? NSImageView,
              let textField = stackView.views[1] as? NSTextField
        else {
            return
        }

        update(stackView: stackView, imageView: imageView, textField: textField)
    }

    private func update(stackView: NSStackView, imageView: NSImageView, textField: NSTextField) {
        imageView.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        imageView.toolTip = title
        imageView.contentTintColor = tintColor
        textField.stringValue = title
        textField.textColor = tintColor
        stackView.toolTip = title
    }
}
