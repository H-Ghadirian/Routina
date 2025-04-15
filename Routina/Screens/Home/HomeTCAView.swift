import Combine
import ComposableArchitecture
import CoreData
import MapKit
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    private enum RoutineListFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case due = "Due"
        case todos = "Todos"
        case doneToday = "Done Today"

        var id: String { rawValue }
    }

    private struct RoutineListSection: Identifiable {
        let title: String
        let tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

#if os(macOS)
    private enum MacSidebarSelection: Hashable {
        case task(UUID)
        case timelineEntry(UUID)
    }

    private enum MacSidebarMode: String, CaseIterable, Identifiable {
        case routines = "Routines"
        case timeline = "Timeline"
        case stats = "Stats"
        case settings = "Settings"

        var id: Self { self }
    }
#endif

    let store: StoreOf<HomeFeature>
#if os(macOS)
    let settingsStore: StoreOf<SettingsFeature>
#endif
    private let externalSearchText: Binding<String>?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Query(sort: \RoutineLog.timestamp, order: .reverse) private var timelineLogs: [RoutineLog]
    @State private var localSearchText = ""
    @State private var selectedFilter: RoutineListFilter = .all
    @State private var selectedTag: String?
    @State private var selectedManualPlaceFilterID: UUID?
    @State private var isFilterSheetPresented = false
    @State private var isCompactHeaderHidden = false
    @State private var isRefreshScheduled = false
    @State private var selectedTimelineRange: TimelineRange = .week
    @State private var selectedTimelineFilterType: TimelineFilterType = .all
    @State private var selectedTimelineTag: String?
#if os(macOS)
    @State private var macSidebarSelection: MacSidebarSelection?
    @State private var macSidebarMode: MacSidebarMode = .routines
    @State private var selectedSettingsSection: SettingsMacSection? = .notifications
#endif

    init(
        store: StoreOf<HomeFeature>,
        searchText: Binding<String>? = nil
    ) {
        self.store = store
#if os(macOS)
        self.settingsStore = Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
#endif
        self.externalSearchText = searchText
    }

    var body: some View {
        WithPerceptionTracking {
            homeContent
        }
    }

    private var homeContent: some View {
        applyAddRoutinePresentation(
            to: applyPlatformDeleteConfirmation(
                to: applyPlatformRefresh(
                    to: applyPlatformSearchExperience(
                        to: navigationContent,
                        searchText: searchTextBinding
                    )
                )
            )
        )
            .sheet(isPresented: $isFilterSheetPresented) {
                homeFiltersSheet
            }
            .onAppear {
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .routineDidUpdate)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
#if os(macOS)
                settingsStore.send(.onAppBecameActive)
#endif
            }
#if os(macOS)
            .onReceive(
                NotificationCenter.default.publisher(for: CloudKitSyncDiagnostics.didUpdateNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                settingsStore.send(.cloudDiagnosticsUpdated)
            }
#endif
            .onChange(of: store.routineDisplays) { _, displays in
                validateSelectedTag(
                    activeDisplays: displays,
                    awayDisplays: store.awayRoutineDisplays,
                    archivedDisplays: store.archivedRoutineDisplays
                )
            }
            .onChange(of: store.awayRoutineDisplays) { _, displays in
                validateSelectedTag(
                    activeDisplays: store.routineDisplays,
                    awayDisplays: displays,
                    archivedDisplays: store.archivedRoutineDisplays
                )
            }
            .onChange(of: store.archivedRoutineDisplays) { _, displays in
                validateSelectedTag(
                    activeDisplays: store.routineDisplays,
                    awayDisplays: store.awayRoutineDisplays,
                    archivedDisplays: displays
                )
            }
            .onChange(of: store.routinePlaces) { _, places in
                guard let selectedManualPlaceFilterID else { return }
                let placeStillExists = places.contains { place in
                    place.id == selectedManualPlaceFilterID
                }
                if !placeStillExists {
                    self.selectedManualPlaceFilterID = nil
                }
            }
#if os(macOS)
            .onChange(of: store.selectedTaskID) { _, selectedTaskID in
                guard macSidebarMode == .routines else { return }
                macSidebarSelection = selectedTaskID.map(MacSidebarSelection.task)
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenRoutinesInSidebar)) { _ in
                showRoutinesInSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenTimelineInSidebar)) { _ in
                openTimelineInSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routinaMacOpenStatsInSidebar)) { _ in
                openStatsInSidebar()
            }
            .onChange(of: macSidebarMode) { _, mode in
                if mode == .settings {
                    settingsStore.send(.onAppear)
                }
            }
#endif
    }

    private var navigationContent: some View {
        NavigationSplitView {
            WithPerceptionTracking {
                sidebarContent
            }
        } detail: {
#if os(macOS)
            MacDetailContainerView(
                store: store,
                isTimelinePresented: macSidebarMode == .timeline,
                isStatsPresented: macSidebarMode == .stats,
                isSettingsPresented: macSidebarMode == .settings,
                settingsStore: settingsStore,
                selectedSettingsSection: selectedSettingsSection ?? .notifications,
                addRoutineStore: self.store.scope(
                    state: \.addRoutineState,
                    action: \.addRoutineSheet
                )
            ) {
                macActiveFiltersDetailView
            }
#else
            WithPerceptionTracking {
                detailContent
            }
#endif
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
#if os(macOS)
        VStack(spacing: 12) {
            if macSidebarMode == .routines && store.routineTasks.isEmpty {
                emptyStateView(
                    title: "No tasks yet",
                    message: "Add a routine or to-do, and the sidebar will organize what needs attention for you.",
                    systemImage: "checklist"
                ) {
                    openAddTask()
                }
            } else {
                VStack(spacing: 0) {
                    macSidebarHeader

                    Divider()

                    if macSidebarMode == .timeline {
                        macTimelineSidebarView
                    } else if macSidebarMode == .stats {
                        macStatsSidebarView
                    } else if macSidebarMode == .settings {
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
#else
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
#endif
    }

    @ToolbarContentBuilder
    private var homeToolbarContent: some ToolbarContent {
#if os(macOS)
        ToolbarItemGroup(placement: .automatic) {
        }
#endif

        ToolbarItemGroup(placement: .primaryAction) {
            platformRefreshButton
#if !os(macOS)
            filterSheetButton
            Button {
                openAddTask()
            } label: {
                Label("Add Task", systemImage: "plus")
            }
#else
            MacToolbarIconButton(title: "Add Task", systemImage: "plus") {
                openAddTask()
            }
#endif
        }
    }

#if os(macOS)
    private var macSidebarHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            macSidebarModeStrip
            if macSidebarMode == .routines || macSidebarMode == .timeline {
                macSearchPanel
            }
            if macSidebarMode == .timeline {
                overallDoneCountSummary
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                macSidebarMode == mode
                                    ? Color.accentColor
                                    : Color.clear
                            )

                        Image(systemName: macSidebarModeIcon(for: mode))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(
                                macSidebarMode == mode
                                    ? Color.white
                                    : Color.secondary
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(mode.rawValue)
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

    private func macSidebarModeIcon(for mode: MacSidebarMode) -> String {
        switch mode {
        case .routines:
            return "checklist"
        case .timeline:
            return "clock.arrow.circlepath"
        case .stats:
            return "chart.bar.xaxis"
        case .settings:
            return "gearshape"
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

    private var macHasCustomFiltersApplied: Bool {
        if macSidebarMode == .timeline {
            return selectedTimelineRange != .week
                || selectedTimelineFilterType != .all
                || selectedTimelineTag != nil
        }
        if macSidebarMode == .stats {
            return false
        }
        return selectedFilter != .all || hasActiveOptionalFilters
    }

    private func clearAllMacFilters() {
        if macSidebarMode == .timeline {
            selectedTimelineRange = .week
            selectedTimelineFilterType = .all
            selectedTimelineTag = nil
        } else {
            selectedFilter = .all
            clearOptionalFilters()
        }
    }

    @ViewBuilder
    private var macActiveFiltersDetailView: some View {
        if macSidebarMode == .timeline {
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

                        Text("Refine the routine list by status, tag, and place. Changes apply to the sidebar immediately.")
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
            .frame(maxWidth: 860, alignment: .leading)
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
                        timelineTagFilterBar
                    }
                }
            }
            .onChange(of: availableTimelineTags) { _, _ in
                validateSelectedTimelineTag()
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func macSidebarSectionCard<Content: View>(
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
#endif

    @ViewBuilder
    private var detailContent: some View {
        if let detailStore = self.store.scope(
            state: \.routineDetailState,
            action: \.routineDetail
        ) {
            RoutineDetailTCAView(store: detailStore)
        } else {
            ContentUnavailableView(
                "Select a task",
                systemImage: "checklist.checked",
                description: Text("Choose a routine or to-do from the sidebar to see its schedule, logs, and actions.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var addRoutineSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isAddRoutineSheetPresented },
            set: { store.send(.setAddRoutineSheet($0)) }
        )
    }

    private var searchTextBinding: Binding<String> {
        if let externalSearchText {
            externalSearchText
        } else {
            $localSearchText
        }
    }

    var searchPlaceholderText: String {
#if os(macOS)
        macSidebarMode == .timeline ? "Search dones" : "Search routines and todos"
#else
        "Search routines and todos"
#endif
    }

    private var selectedTaskBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedTaskID },
            set: { store.send(.setSelectedTask($0)) }
        )
    }

    @ViewBuilder
    private var addRoutineSheetContent: some View {
        if let addRoutineStore = self.store.scope(
            state: \.addRoutineState,
            action: \.addRoutineSheet
        ) {
            AddRoutineTCAView(store: addRoutineStore)
        }
    }

    @ViewBuilder
    private func applyAddRoutinePresentation<Content: View>(to content: Content) -> some View {
#if os(macOS)
        content
#else
        content.sheet(isPresented: addRoutineSheetBinding) {
            addRoutineSheetContent
        }
#endif
    }

    private func openAddTask() {
#if os(macOS)
        macSidebarMode = .routines
        macSidebarSelection = nil
        store.send(.setMacFilterDetailPresented(false))
#endif
        store.send(.setAddRoutineSheet(true))
    }

    private var filterPicker: some View {
#if os(macOS)
        VStack(alignment: .leading, spacing: 8) {
            Text("Show")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(RoutineListFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .foregroundStyle(
                                selectedFilter == filter ? Color.white : Color.primary
                            )
                            .background(
                                Capsule()
                                    .fill(
                                        selectedFilter == filter
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.10)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
#else
        Picker("Routine Filter", selection: $selectedFilter) {
            ForEach(RoutineListFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 4)
#endif
    }

    private var timelineRangePicker: some View {
        Picker("Range", selection: $selectedTimelineRange) {
            ForEach(TimelineRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
#if os(macOS)
        .pickerStyle(.segmented)
#endif
    }

    private var timelineTypePicker: some View {
        Picker("Type", selection: $selectedTimelineFilterType) {
            ForEach(TimelineFilterType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
#if os(macOS)
        .pickerStyle(.segmented)
#endif
    }

    private var overallDoneCountSummary: some View {
        HStack(spacing: 8) {
            Label("\(store.doneStats.totalCount) total dones", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        }
    }

    @ViewBuilder
    private var tagFilterBar: some View {
        if !availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
#if os(macOS)
                Text("Tags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
#endif

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
#if !os(macOS)
                    .padding(.horizontal)
#endif
                }
            }
#if !os(macOS)
            .padding(.top, -2)
#endif
        }
    }

    private func sortedTasks(_ routineDisplays: [HomeFeature.RoutineDisplay]) -> [HomeFeature.RoutineDisplay] {
        routineDisplays.sorted(by: regularTaskSort)
    }

    private func regularTaskSort(
        _ task1: HomeFeature.RoutineDisplay,
        _ task2: HomeFeature.RoutineDisplay
    ) -> Bool {
        let overdueDays1 = overdueDays(for: task1)
        let overdueDays2 = overdueDays(for: task2)

        if overdueDays1 != overdueDays2 {
            return overdueDays1 > overdueDays2
        }

        let urgency1 = urgencyLevel(for: task1)
        let urgency2 = urgencyLevel(for: task2)
        if urgency1 != urgency2 {
            return urgency1 > urgency2
        }

        return task1.name.localizedCaseInsensitiveCompare(task2.name) == .orderedAscending
    }

    private func archivedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        let lhsDate = lhs.pausedAt ?? lhs.lastDone ?? .distantPast
        let rhsDate = rhs.pausedAt ?? rhs.lastDone ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func pinnedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        let lhsDate = lhs.pinnedAt ?? .distantPast
        let rhsDate = rhs.pinnedAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        if lhs.isPaused != rhs.isPaused {
            return !lhs.isPaused && rhs.isPaused
        }
        return lhs.isPaused && rhs.isPaused ? archivedTaskSort(lhs, rhs) : regularTaskSort(lhs, rhs)
    }

    private func urgencyLevel(for task: HomeFeature.RoutineDisplay) -> Int {
        let dueIn = dueInDays(for: task)

        if dueIn < 0 { return 3 }
        if dueIn == 0 { return 2 }
        if dueIn == 1 { return 1 }
        return 0
    }

    private func listOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
#if os(macOS)
        let pinnedTasks = filteredPinnedTasks(
            activeRoutineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays
        )
        let sections = groupedRoutineSections(from: (routineDisplays + awayRoutineDisplays).filter { !$0.isPinned })
        let archivedTasks = filteredArchivedTasks(archivedRoutineDisplays, includePinned: false)
#else
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
                title: "No matching routines",
                message: "Try a different search or switch back to another filter.",
                systemImage: "magnifyingglass"
            )
        }()
#endif
        return Group {
#if os(macOS)
            if pinnedTasks.isEmpty && sections.isEmpty && archivedTasks.isEmpty {
                emptyStateView(
                    title: "No matching routines",
                    message: "Try a different place or switch back to all routines.",
                    systemImage: "magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: macSidebarSelectionBinding) {
                    if !pinnedTasks.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedTasks) { task in
                                routineNavigationRow(for: task)
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: pinnedTasks)
                            }
                        }
                    }

                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.tasks) { task in
                                routineNavigationRow(for: task)
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: section.tasks)
                            }
                        }
                    }

                    if !archivedTasks.isEmpty {
                        Section("Archived") {
                            ForEach(archivedTasks) { task in
                                routineNavigationRow(for: task)
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: archivedTasks)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationDestination(for: UUID.self) { taskID in
                    routineDetailDestination(taskID: taskID)
                }
            }
#else
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
                            Section(section.title) {
                                ForEach(section.tasks) { task in
                                    routineNavigationRow(for: task)
                                }
                                .onDelete { offsets in
                                    deleteTasks(at: offsets, from: section.tasks)
                                }
                            }
                        }

#if !os(macOS)
                        if !store.hideUnavailableRoutines && !awayTasks.isEmpty {
                            Section("Not Here Right Now") {
                                ForEach(awayTasks) { task in
                                    routineNavigationRow(for: task, includeMarkDone: false)
                                }
                                .onDelete { offsets in
                                    deleteTasks(at: offsets, from: awayTasks)
                                }
                            }
                        }
#endif

                        if !archivedTasks.isEmpty {
                            Section("Archived") {
                                ForEach(archivedTasks) { task in
                                    routineNavigationRow(for: task)
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
#endif
        }
    }

#if os(macOS)
    private var timelineEntries: [TimelineEntry] {
        baseTimelineEntries
            .filter { entry in
                TimelineLogic.matchesSelectedTag(selectedTimelineTag, in: entry.tags)
            }
            .filter(matchesTimelineSearch)
    }

    private var baseTimelineEntries: [TimelineEntry] {
        TimelineLogic.filteredEntries(
            logs: timelineLogs,
            tasks: store.routineTasks,
            range: selectedTimelineRange,
            filterType: selectedTimelineFilterType,
            now: Date(),
            calendar: calendar
        )
    }

    private var availableTimelineTags: [String] {
        TimelineLogic.availableTags(from: baseTimelineEntries)
    }

    private var groupedTimelineEntries: [(date: Date, entries: [TimelineEntry])] {
        TimelineLogic.groupedByDay(entries: timelineEntries, calendar: calendar)
    }

    private var macStatsSidebarView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stats", systemImage: "chart.bar.xaxis")
                .font(.title3.weight(.semibold))

            Text("Use the navigator above to switch sections. Stats is shown in the right panel.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
    }

    private var macSettingsSidebarView: some View {
        List {
            ForEach(SettingsMacSection.allCases) { section in
                Button {
                    selectedSettingsSection = section
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
                        .fill(
                            selectedSettingsSection == section
                                ? Color.accentColor.opacity(0.9)
                                : Color.clear
                        )
                        .padding(.vertical, 2)
                )
            }
        }
        .listStyle(.sidebar)
    }

    private var macTimelineSidebarView: some View {
        Group {
            if timelineLogs.isEmpty {
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
                    ForEach(groupedTimelineEntries, id: \.date) { section in
                        Section(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar)) {
                            ForEach(section.entries) { entry in
                                timelineSidebarRow(entry)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
#endif

    @ViewBuilder
    private var compactHomeHeader: some View {
#if os(macOS)
        EmptyView()
#else
        VStack(alignment: .leading, spacing: 10) {
            activeFilterChipBar
        }
#endif
    }

    private var filterSheetButton: some View {
        Button {
            isFilterSheetPresented = true
        } label: {
            Image(
                systemName: hasActiveOptionalFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveOptionalFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }

    @ViewBuilder
    private var activeFilterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedTag {
                    compactFilterChip(title: "#\(selectedTag)") {
                        self.selectedTag = nil
                    }
                }

                if let selectedPlaceName {
                    compactFilterChip(title: selectedPlaceName, systemImage: "mappin.and.ellipse") {
                        selectedManualPlaceFilterID = nil
                    }
                }

                if store.hideUnavailableRoutines {
                    compactFilterChip(title: "Away hidden", systemImage: "location.slash") {
                        store.send(.hideUnavailableRoutinesChanged(false))
                    }
                }

                if activeOptionalFilterCount > 1 {
                    Button("Clear All") {
                        clearOptionalFilters()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private func compactFilterChip(
        title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }

                Text(title)
                    .font(.caption.weight(.medium))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var locationFilterPanel: some View {
        if hasPlaceAwareContent {
            Group {
#if os(macOS)
                EmptyView()
#else
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
#endif
            }
#if !os(macOS)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .padding(.horizontal)
#endif
        }
    }

    private var hideUnavailableRoutinesBinding: Binding<Bool> {
        Binding(
            get: { store.hideUnavailableRoutines },
            set: { store.send(.hideUnavailableRoutinesChanged($0)) }
        )
    }

    private var manualPlaceFilterBinding: Binding<UUID?> {
        Binding(
            get: { selectedManualPlaceFilterID },
            set: { selectedManualPlaceFilterID = $0 }
        )
    }

    private var sortedRoutinePlaces: [RoutinePlace] {
        store.routinePlaces.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

#if os(macOS)
    private var macPlaceFilterOptions: [MacPlaceFilterOption] {
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
#endif

    private var selectedPlaceName: String? {
        guard let selectedManualPlaceFilterID else { return nil }
        return store.routinePlaces.first(where: { $0.id == selectedManualPlaceFilterID })?.displayName
    }

    private var activeOptionalFilterCount: Int {
        var count = 0

        if selectedTag != nil {
            count += 1
        }
        if selectedManualPlaceFilterID != nil {
            count += 1
        }
        if store.hideUnavailableRoutines {
            count += 1
        }

        return count
    }

    private var hasActiveOptionalFilters: Bool {
        activeOptionalFilterCount > 0
    }

    private var hasSavedPlaces: Bool {
        !sortedRoutinePlaces.isEmpty
    }

    private var hasPlaceLinkedRoutines: Bool {
        store.routineTasks.contains { $0.placeID != nil }
    }

    private var hasPlaceAwareContent: Bool {
        hasSavedPlaces || hasPlaceLinkedRoutines
    }

    @ViewBuilder
    private var homeFiltersSheet: some View {
#if os(macOS)
        EmptyView()
#else
        NavigationStack {
            List {
                Section("Status") {
                    Picker("Show routines", selection: $selectedFilter) {
                        ForEach(RoutineListFilter.allCases) { filter in
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
#endif
    }

    private func clearOptionalFilters() {
        selectedTag = nil
        selectedManualPlaceFilterID = nil

        if store.hideUnavailableRoutines {
            store.send(.hideUnavailableRoutinesChanged(false))
        }
    }

    private var manualPlaceFilterDescription: String {
        guard let selectedManualPlaceFilterID,
              let place = store.routinePlaces.first(where: { $0.id == selectedManualPlaceFilterID })
        else {
            return "Choose a saved place to show only routines linked to that place."
        }
        return "Showing only routines linked to \(place.displayName)."
    }

    private var placeFilterSectionDescription: String {
        if hasSavedPlaces {
            return manualPlaceFilterDescription
        }
        return "Save a place in Settings, then link it to a routine to filter by place here."
    }

    private var locationStatusText: String {
        switch store.locationSnapshot.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if store.awayRoutineDisplays.isEmpty {
                return "All place-linked routines are currently available."
            }
            if store.hideUnavailableRoutines {
                return "\(store.awayRoutineDisplays.count) routines are hidden because you are away from their saved place."
            }
            return "\(store.awayRoutineDisplays.count) routines are away from their saved place and shown below."
        case .notDetermined:
            return "Allow location access to automatically separate place-based routines. Until then they stay visible."
        case .disabled:
            return "Location services are disabled on this device, so place-based routines stay visible."
        case .restricted, .denied:
            return "Location access is off, so place-based routines stay visible."
        }
    }

    private func filteredAwayTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        sortedTasks(routineDisplays).filter { task in
            matchesSearch(task)
                && matchesFilter(task)
                && matchesManualPlaceFilter(task)
                && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
        }
    }

    private func routineRow(for task: HomeFeature.RoutineDisplay) -> some View {
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
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
#if os(macOS)
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
#else
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
#endif

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

    @ViewBuilder
    private func routineDetailDestination(taskID: UUID) -> some View {
        if store.selectedTaskID == taskID,
           let detailStore = self.store.scope(
               state: \.routineDetailState,
               action: \.routineDetail
           ) {
            RoutineDetailTCAView(store: detailStore)
        } else if store.routineTasks.contains(where: { $0.id == taskID }) {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    openTask(taskID)
                }
        } else {
            ContentUnavailableView(
                "Routine not found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected routine is no longer available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func groupedRoutineSections(
        from routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [RoutineListSection] {
        let filtered = filteredTasks(routineDisplays)

        let overdue = filtered.filter { overdueDays(for: $0) > 0 }
        let dueSoon = filtered.filter {
            !($0.isDoneToday) &&
            overdueDays(for: $0) == 0 &&
            (urgencyLevel(for: $0) > 0 || isYellowUrgency($0))
        }
        let onTrack = filtered.filter {
            !($0.isDoneToday) &&
            overdueDays(for: $0) == 0 &&
            urgencyLevel(for: $0) == 0 &&
            !isYellowUrgency($0)
        }
        let doneToday = filtered.filter(\.isDoneToday)

        return [
            RoutineListSection(title: "Overdue", tasks: overdue),
            RoutineListSection(title: "Due Soon", tasks: dueSoon),
            RoutineListSection(title: "On Track", tasks: onTrack),
            RoutineListSection(title: "Done Today", tasks: doneToday)
        ]
        .filter { !$0.tasks.isEmpty }
    }

    private func deleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        let ids = offsets.compactMap { sectionTasks[$0].taskID }
#if os(macOS)
        store.send(.deleteTasksTapped(ids))
#else
        if let selectedTaskID = store.selectedTaskID, ids.contains(selectedTaskID) {
            store.send(.setSelectedTask(nil))
        }
        store.send(.deleteTasks(ids))
#endif
    }

    private func openTask(_ taskID: UUID) {
#if os(macOS)
        macSidebarMode = .routines
        macSidebarSelection = .task(taskID)
#endif
        store.send(.setSelectedTask(taskID))
    }

    private func deleteTask(_ taskID: UUID) {
#if os(macOS)
        store.send(.deleteTasksTapped([taskID]))
#else
        if store.selectedTaskID == taskID {
            store.send(.setSelectedTask(nil))
        }
        store.send(.deleteTasks([taskID]))
#endif
    }

#if os(macOS)
    private var macSidebarModeBinding: Binding<MacSidebarMode> {
        Binding(
            get: { macSidebarMode },
            set: { mode in
                switch mode {
                case .routines:
                    showRoutinesInSidebar()
                case .timeline:
                    openTimelineInSidebar()
                case .stats:
                    openStatsInSidebar()
                case .settings:
                    openSettingsInSidebar()
                }
            }
        )
    }

    private var macSidebarSelectionBinding: Binding<MacSidebarSelection?> {
        Binding(
            get: { macSidebarSelection },
            set: { selection in
                macSidebarSelection = selection
                switch selection {
                case let .task(taskID):
                    macSidebarMode = .routines
                    if store.isAddRoutineSheetPresented {
                        store.send(.setAddRoutineSheet(false))
                    }
                    store.send(.setSelectedTask(taskID))
                case let .timelineEntry(entryID):
                    macSidebarMode = .timeline
                    if store.isAddRoutineSheetPresented {
                        store.send(.setAddRoutineSheet(false))
                    }
                    store.send(.setMacFilterDetailPresented(false))
                    if let taskID = timelineEntries.first(where: { $0.id == entryID })?.taskID {
                        store.send(.setSelectedTask(taskID))
                    } else {
                        store.send(.setSelectedTask(nil))
                    }
                case nil:
                    if macSidebarMode == .routines {
                        store.send(.setSelectedTask(nil))
                    }
                }
            }
        )
    }

    private func openTimelineEntry(_ entry: TimelineEntry) {
        macSidebarMode = .timeline
        macSidebarSelection = .timelineEntry(entry.id)
        if store.isAddRoutineSheetPresented {
            store.send(.setAddRoutineSheet(false))
        }
        store.send(.setMacFilterDetailPresented(false))
        if let taskID = entry.taskID {
            store.send(.setSelectedTask(taskID))
        } else {
            store.send(.setSelectedTask(nil))
        }
    }

    private func showRoutinesInSidebar() {
        macSidebarMode = .routines
        macSidebarSelection = store.selectedTaskID.map(MacSidebarSelection.task)
        store.send(.setMacFilterDetailPresented(false))
    }

    private func openTimelineInSidebar() {
        macSidebarMode = .timeline
        validateSelectedTimelineTag()
        macSidebarSelection = nil
        if store.isAddRoutineSheetPresented {
            store.send(.setAddRoutineSheet(false))
        }
        store.send(.setMacFilterDetailPresented(false))
        store.send(.setSelectedTask(nil))
    }

    private func openStatsInSidebar() {
        macSidebarMode = .stats
        macSidebarSelection = nil
        if store.isAddRoutineSheetPresented {
            store.send(.setAddRoutineSheet(false))
        }
        store.send(.setMacFilterDetailPresented(false))
        store.send(.setSelectedTask(nil))
    }

    private func openSettingsInSidebar() {
        macSidebarMode = .settings
        macSidebarSelection = nil
        if store.isAddRoutineSheetPresented {
            store.send(.setAddRoutineSheet(false))
        }
        if selectedSettingsSection == nil {
            selectedSettingsSection = .notifications
        }
        store.send(.setMacFilterDetailPresented(false))
        store.send(.setSelectedTask(nil))
        settingsStore.send(.onAppear)
    }

    private func openSettingsPlacesInSidebar() {
        selectedSettingsSection = .places
        openSettingsInSidebar()
    }

    private func timelineSidebarRow(_ entry: TimelineEntry) -> some View {
        Button {
            openTimelineEntry(entry)
        } label: {
            HStack(spacing: 12) {
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

    @ViewBuilder
    private var timelineTagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tagFilterButton(title: "All Tags", isSelected: selectedTimelineTag == nil) {
                    selectedTimelineTag = nil
                }

                ForEach(availableTimelineTags, id: \.self) { tag in
                    tagFilterButton(
                        title: "#\(tag)",
                        isSelected: selectedTimelineTag.map { RoutineTag.contains($0, in: [tag]) } ?? false
                    ) {
                        selectedTimelineTag = tag
                    }
                }
            }
        }
    }

    private func validateSelectedTimelineTag() {
        guard let selectedTimelineTag else { return }
        if !RoutineTag.contains(selectedTimelineTag, in: availableTimelineTags) {
            self.selectedTimelineTag = nil
        }
    }

#endif
    private func urgencyColor(for task: HomeFeature.RoutineDisplay) -> Color {
        if task.isPaused {
            return .teal
        }
        if case .away = task.locationAvailability {
            return .blue
        }
        if task.isInProgress {
            return .orange
        }
        if task.isOneOffTask {
            return task.isCompletedOneOff ? .green : .blue
        }
        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return .orange
        }
        if task.recurrenceRule.isFixedCalendar {
            let urgency = urgencyLevel(for: task)
            switch urgency {
            case 3:
                return .red
            case 2, 1:
                return .orange
            default:
                return .green
            }
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    private func rowIconBackgroundColor(for task: HomeFeature.RoutineDisplay) -> Color {
        urgencyColor(for: task).opacity(task.isDoneToday ? 0.22 : 0.14)
    }

    private func isYellowUrgency(_ task: HomeFeature.RoutineDisplay) -> Bool {
        if task.isOneOffTask {
            return false
        }
        if task.isInProgress
            || task.scheduleMode == .derivedFromChecklist
            || (task.scheduleMode == .fixedIntervalChecklist && task.completedChecklistItemCount > 0) {
            return false
        }
        if task.recurrenceRule.isFixedCalendar {
            return dueInDays(for: task) == 1
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    private func daysSinceLastRoutine(_ task: HomeFeature.RoutineDisplay) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(from: task.lastDone, referenceDate: Date())
    }

    private func daysSinceScheduleAnchor(_ task: HomeFeature.RoutineDisplay) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(
            from: task.scheduleAnchor ?? task.lastDone,
            referenceDate: Date()
        )
    }

    private func filteredTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        sortedTasks(routineDisplays).filter { task in
            matchesSearch(task)
                && matchesFilter(task)
                && matchesManualPlaceFilter(task)
                && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
        }
    }

    private func filteredArchivedTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay],
        includePinned: Bool = true
    ) -> [HomeFeature.RoutineDisplay] {
        routineDisplays
            .filter { task in
                !task.isCompletedOneOff
                    && (includePinned || !task.isPinned)
                    && matchesSearch(task)
                    && matchesManualPlaceFilter(task)
                    && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
            }
            .sorted(by: archivedTaskSort)
    }

    private func filteredPinnedTasks(
        activeRoutineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        let activePinned = sortedTasks(activeRoutineDisplays + awayRoutineDisplays).filter { task in
            task.isPinned
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesManualPlaceFilter(task)
                && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
        }
        let archivedPinned = filteredArchivedTasks(archivedRoutineDisplays).filter(\.isPinned)

        return (activePinned + archivedPinned).sorted(by: pinnedTaskSort)
    }

    private func matchesSearch(_ task: HomeFeature.RoutineDisplay) -> Bool {
        let trimmedSearch = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return task.name.localizedCaseInsensitiveContains(trimmedSearch)
            || task.emoji.localizedCaseInsensitiveContains(trimmedSearch)
            || (task.notes?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || (task.placeName?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || RoutineTag.matchesQuery(trimmedSearch, in: task.tags)
    }

    private func matchesFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .due:
            return !task.isDoneToday && (urgencyLevel(for: task) > 0 || isYellowUrgency(task))
        case .todos:
            return task.isOneOffTask
        case .doneToday:
            return task.isDoneToday
        }
    }

    private func matchesManualPlaceFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        guard let selectedManualPlaceFilterID else { return true }
        return task.placeID == selectedManualPlaceFilterID
    }

    private func dueInDays(for task: HomeFeature.RoutineDisplay) -> Int {
        task.daysUntilDue
    }

    private func overdueDays(for task: HomeFeature.RoutineDisplay) -> Int {
        max(-dueInDays(for: task), 0)
    }

    private func routineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        includeMarkDone: Bool = true
    ) -> some View {
#if os(macOS)
        // Use .tag() instead of NavigationLink so the List selection binding
        // drives the sidebar highlight without NavigationLink hijacking the
        // NavigationSplitView detail column.
        routineRow(for: task)
            .tag(MacSidebarSelection.task(task.taskID))
            .contentShape(Rectangle())
            .contextMenu {
                routineContextMenu(for: task, includeMarkDone: includeMarkDone)
            }
#else
        NavigationLink(value: task.taskID) {
            routineRow(for: task)
        }
        .contentShape(Rectangle())
        .contextMenu {
            routineContextMenu(for: task, includeMarkDone: includeMarkDone)
        }
#endif
    }

    @ViewBuilder
    private func routineContextMenu(
        for task: HomeFeature.RoutineDisplay,
        includeMarkDone: Bool
    ) -> some View {
        Button {
            openTask(task.taskID)
        } label: {
            Label("Open", systemImage: "arrow.right.circle")
        }

        if task.isPaused {
            Button {
                store.send(.resumeTask(task.taskID))
            } label: {
                Label("Resume", systemImage: "play.circle")
            }
        } else if task.isCompletedOneOff {
            EmptyView()
        } else {
            if includeMarkDone {
                Button {
                    store.send(.markTaskDone(task.taskID))
                } label: {
                    Label(markDoneLabel(for: task), systemImage: "checkmark.circle")
                }
                .disabled(isMarkDoneDisabled(task))
            }

            if !task.isOneOffTask {
                Button {
                    store.send(.pauseTask(task.taskID))
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
            }
        }

#if os(macOS)
        Button {
            store.send(task.isPinned ? .unpinTask(task.taskID) : .pinTask(task.taskID))
        } label: {
            Label(
                task.isPinned ? "Unpin from Top" : "Pin to Top",
                systemImage: task.isPinned ? "pin.slash" : "pin"
            )
        }
#endif

        Button(role: .destructive) {
            deleteTask(task.taskID)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func rowMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        if task.isOneOffTask {
            let items = todoRowMetadataItems(for: task)
            return items.isEmpty ? nil : items.joined(separator: " • ")
        }

        if task.isPaused {
            return "\(cadenceDescription(for: task)) • \(doneCountDescription(for: task.doneCount)) • \(pauseDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
        }
        return "\(cadenceDescription(for: task)) • \(doneCountDescription(for: task.doneCount)) • \(completionDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
    }

    private func todoRowMetadataItems(for task: HomeFeature.RoutineDisplay) -> [String] {
        var items: [String] = []

        if let deadlineText = conciseDeadlineText(for: task) {
            items.append(deadlineText)
        }

        if task.isPaused {
            items.append(pauseDescription(for: task))
        } else if task.isCompletedOneOff || task.isInProgress {
            items.append(completionDescription(for: task))
        }

        if let stepText = conciseTodoStepText(for: task) {
            items.append(stepText)
        }

        if let placeText = concisePlaceMetadataText(for: task) {
            items.append(placeText)
        }

        return items
    }

    private func pauseDescription(for task: HomeFeature.RoutineDisplay) -> String {
        guard let pausedAt = task.pausedAt else { return "Paused" }
        let elapsedDays = RoutineDateMath.elapsedDaysSinceLastDone(from: pausedAt, referenceDate: Date())
        if elapsedDays == 0 { return "Paused today" }
        if elapsedDays == 1 { return "Paused yesterday" }
        return "Paused \(elapsedDays) days ago"
    }

    private func doneCountDescription(for count: Int) -> String {
        count == 1 ? "1 done" : "\(count) dones"
    }

    private func cadenceDescription(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isOneOffTask {
            return "One-off todo"
        }
        if task.scheduleMode == .derivedFromChecklist {
            return "Checklist-driven"
        }
        return task.recurrenceRule.displayText()
    }

    private func completionDescription(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isOneOffTask {
            if task.isInProgress {
                let totalSteps = max(task.steps.count, 1)
                return "Step \(task.completedStepCount + 1) of \(totalSteps)"
            }
            guard task.lastDone != nil else { return "Not completed yet" }

            let elapsedDays = daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Completed today" }
            if elapsedDays == 1 { return "Completed yesterday" }
            return "Completed \(elapsedDays) days ago"
        }
        if task.scheduleMode == .derivedFromChecklist {
            if task.isDoneToday && overdueDays(for: task) == 0 {
                return "Updated today"
            }
            guard task.lastDone != nil else { return "Never updated" }

            let elapsedDays = daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Updated today" }
            if elapsedDays == 1 { return "Updated yesterday" }
            return "Updated \(elapsedDays) days ago"
        }
        if task.scheduleMode == .fixedIntervalChecklist && task.completedChecklistItemCount > 0 {
            return "Checklist \(task.completedChecklistItemCount) of \(max(task.checklistItemCount, 1))"
        }
        if task.isInProgress {
            let totalSteps = max(task.steps.count, 1)
            return "Step \(task.completedStepCount + 1) of \(totalSteps)"
        }
        guard task.lastDone != nil else { return "Never completed" }

        let elapsedDays = daysSinceLastRoutine(task)
        if elapsedDays == 0 { return "Completed today" }
        if elapsedDays == 1 { return "Completed yesterday" }
        return "Completed \(elapsedDays) days ago"
    }

    private func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        let style = badgeStyle(for: task)

        return Label(style.title, systemImage: style.systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(2)
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.backgroundColor, in: Capsule())
    }

    private func tagFilterButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private func badgeStyle(
        for task: HomeFeature.RoutineDisplay
    ) -> (title: String, systemImage: String, foregroundColor: Color, backgroundColor: Color) {
        if task.isPaused {
            return ("Paused", "pause.circle.fill", .teal, Color.teal.opacity(0.16))
        }
        if case .away = task.locationAvailability {
            return ("Away", "location.slash.fill", .blue, Color.blue.opacity(0.14))
        }
        if task.isInProgress {
            return ("Step \(task.completedStepCount + 1)/\(max(task.steps.count, 1))", "list.number", .orange, Color.orange.opacity(0.16))
        }
        if task.isOneOffTask {
            if task.isCompletedOneOff {
                return ("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            return ("To Do", "circle", .blue, Color.blue.opacity(0.12))
        }
        let dueIn = dueInDays(for: task)

        if task.scheduleMode == .derivedFromChecklist {
            if dueIn < 0 {
                return ("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
            }
            if dueIn == 0 {
                return ("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
            }
            if task.isDoneToday {
                return ("Updated", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            if dueIn == 1 {
                return ("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
            }
            return ("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
        }

        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return (
                "\(task.completedChecklistItemCount)/\(max(task.checklistItemCount, 1)) done",
                "checklist.checked",
                .orange,
                Color.orange.opacity(0.16)
            )
        }

        if task.isDoneToday {
            return ("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
        }

        if dueIn < 0 {
            return ("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
        }
        if dueIn == 0 {
            return ("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
        }
        if dueIn == 1 {
            return ("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
        }
        if isYellowUrgency(task) {
            return ("\(dueIn)d left", "calendar.badge.clock", .orange, Color.orange.opacity(0.12))
        }

        return ("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
    }

    private func stepMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        if task.scheduleMode == .derivedFromChecklist {
            if let nextDueChecklistItemTitle = task.nextDueChecklistItemTitle {
                if task.dueChecklistItemCount > 1 {
                    return " • Due: \(nextDueChecklistItemTitle) +\(task.dueChecklistItemCount - 1)"
                }
                return " • Due: \(nextDueChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            return totalItems == 0 ? "" : " • \(totalItems) \(totalItems == 1 ? "item" : "items")"
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            if let nextPendingChecklistItemTitle = task.nextPendingChecklistItemTitle,
               task.completedChecklistItemCount < task.checklistItemCount {
                return " • Next: \(nextPendingChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            if totalItems == 0 { return "" }
            return " • Checklist \(task.completedChecklistItemCount)/\(totalItems)"
        }
        guard !task.steps.isEmpty else { return "" }
        if let nextStepTitle = task.nextStepTitle {
            return " • Next: \(nextStepTitle)"
        }
        let totalSteps = task.steps.count
        return " • \(totalSteps) \(totalSteps == 1 ? "step" : "steps")"
    }

    private func conciseTodoStepText(for task: HomeFeature.RoutineDisplay) -> String? {
        guard !task.steps.isEmpty else { return nil }
        if task.isCompletedOneOff { return nil }
        if let nextStepTitle = task.nextStepTitle {
            return "Next: \(nextStepTitle)"
        }
        if task.steps.count > 1 {
            return "\(task.steps.count) steps"
        }
        return nil
    }

    private func conciseDeadlineText(for task: HomeFeature.RoutineDisplay) -> String? {
        guard task.isOneOffTask, let dueDate = task.dueDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Due today"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Due tomorrow"
        }
        if dueDate < Date() {
            let days = max(
                abs(calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: dueDate),
                    to: calendar.startOfDay(for: Date())
                ).day ?? 0),
                1
            )
            return "Overdue \(days)d"
        }
        return "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func markDoneLabel(for task: HomeFeature.RoutineDisplay) -> String {
        if task.scheduleMode == .derivedFromChecklist {
            if task.dueChecklistItemCount == 0 {
                return "No Due Items"
            }
            if task.dueChecklistItemCount == 1 {
                return "Buy Due Item"
            }
            return "Buy Due Items"
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            return "Checklist"
        }
        return task.steps.isEmpty ? "Mark Done" : "Complete Next Step"
    }

    private func isMarkDoneDisabled(_ task: HomeFeature.RoutineDisplay) -> Bool {
        if task.isOneOffTask {
            return task.isCompletedOneOff || task.isPaused
        }
        if task.scheduleMode == .derivedFromChecklist {
            return task.isPaused || task.dueChecklistItemCount == 0
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            return true
        }
        if task.recurrenceRule.isFixedCalendar,
           let dueDate = task.dueDate,
           dueDate > Date() {
            return true
        }
        return task.isDoneToday || task.isPaused
    }

    private func placeMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        switch task.locationAvailability {
        case .unrestricted:
            return ""
        case let .available(placeName):
            return " • At \(placeName)"
        case let .away(placeName, _):
            return " • Away from \(placeName)"
        case let .unknown(placeName):
            return " • \(placeName) task"
        }
    }

    private func concisePlaceMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        switch task.locationAvailability {
        case .unrestricted:
            return nil
        case let .available(placeName):
            return "At \(placeName)"
        case let .away(placeName, _):
            return "Away from \(placeName)"
        case let .unknown(placeName):
            return placeName
        }
    }

    @ViewBuilder
    private func emptyStateView(
        title: String,
        message: String,
        systemImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let action {
                Button("Add Task", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func inlineEmptyStateRow(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 40)
    }

    @MainActor
    func performManualRefresh() async {
        if modelContext.hasChanges {
            try? modelContext.save()
        }

        if let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier {
            try? await CloudKitDirectPullService.pullLatestIntoLocalStore(
                containerIdentifier: containerIdentifier,
                modelContext: modelContext
            )
        }

        requestRefresh()

        // CloudKit imports are asynchronous; do a second pass shortly after manual refresh.
        try? await Task.sleep(for: .seconds(2))
        requestRefresh()
    }

    private var allRoutineDisplays: [HomeFeature.RoutineDisplay] {
        store.routineDisplays + store.awayRoutineDisplays + store.archivedRoutineDisplays
    }

    private var availableTags: [String] {
        HomeFeature.availableTags(from: allRoutineDisplays)
    }

    private func handleCompactHeaderScroll(oldOffset: CGFloat, newOffset: CGFloat) {
        let delta = newOffset - oldOffset

        if newOffset <= 12 {
            if isCompactHeaderHidden {
                isCompactHeaderHidden = false
            }
            return
        }

        if delta > 10, !isCompactHeaderHidden {
            isCompactHeaderHidden = true
        } else if delta < -10, isCompactHeaderHidden {
            isCompactHeaderHidden = false
        }
    }

    private func validateSelectedTag(
        activeDisplays: [HomeFeature.RoutineDisplay],
        awayDisplays: [HomeFeature.RoutineDisplay],
        archivedDisplays: [HomeFeature.RoutineDisplay]
    ) {
        guard let selectedTag else { return }
        let availableTags = HomeFeature.availableTags(from: activeDisplays + awayDisplays + archivedDisplays)
        if !RoutineTag.contains(selectedTag, in: availableTags) {
            self.selectedTag = nil
        }
    }

    @MainActor
    private func requestRefresh() {
        guard !isRefreshScheduled else { return }
        isRefreshScheduled = true

        Task { @MainActor in
            defer { isRefreshScheduled = false }
            await Task.yield()
            store.send(.onAppear)
        }
    }
}

#if os(macOS)
/// Separate View struct so SwiftUI gives it its own observation lifecycle.
/// Inline closures inside `NavigationSplitView.detail` on macOS can lose
/// observation tracking after several view swaps, causing state changes
/// (like toggling the filter panel) to stop updating the detail column.
private struct MacDetailContainerView<FilterView: View>: View {
    let store: StoreOf<HomeFeature>
    let isTimelinePresented: Bool
    let isStatsPresented: Bool
    let isSettingsPresented: Bool
    let settingsStore: StoreOf<SettingsFeature>
    let selectedSettingsSection: SettingsMacSection
    let addRoutineStore: StoreOf<AddRoutineFeature>?
    @ViewBuilder let filterView: () -> FilterView

    var body: some View {
        WithPerceptionTracking {
            if store.isMacFilterDetailPresented {
                filterView()
            } else if let addRoutineStore {
                AddRoutineTCAView(store: addRoutineStore)
            } else if isStatsPresented {
                StatsView()
            } else if isSettingsPresented {
                EmbeddedSettingsMacDetailView(
                    store: settingsStore,
                    section: selectedSettingsSection
                )
            } else if let detailStore = store.scope(
                state: \.routineDetailState,
                action: \.routineDetail
            ) {
                RoutineDetailTCAView(store: detailStore)
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
#endif

#if os(macOS)
private struct MacPlaceFilterOption: Equatable, Identifiable {
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

private struct MacPlaceFilterDetailView: View {
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
            .frame(maxWidth: 860, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct MacPlaceFilterPanel: View {
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

private struct MacPlaceFilterRow: View {
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

private struct MacPlaceStatusBadge: View {
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
#endif
