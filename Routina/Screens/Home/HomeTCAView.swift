import Combine
import ComposableArchitecture
import CoreData
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    private enum RoutineListFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case due = "Due"
        case doneToday = "Done Today"

        var id: String { rawValue }
    }

    private struct RoutineListSection: Identifiable {
        let title: String
        let tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

    let store: StoreOf<HomeFeature>
    private let externalSearchText: Binding<String>?
    @Environment(\.modelContext) private var modelContext
    @State private var localSearchText = ""
    @State private var selectedFilter: RoutineListFilter = .all
    @State private var selectedTag: String?
    @State private var selectedManualPlaceFilterID: UUID?
    @State private var isFilterSheetPresented = false
    @State private var isCompactHeaderHidden = false
    @State private var isRefreshScheduled = false

    init(
        store: StoreOf<HomeFeature>,
        searchText: Binding<String>? = nil
    ) {
        self.store = store
        self.externalSearchText = searchText
    }

    var body: some View {
        WithPerceptionTracking {
            homeContent
        }
    }

    private var homeContent: some View {
        applyPlatformDeleteConfirmation(
            to: applyPlatformRefresh(
                to: applyPlatformSearchExperience(
                    to: navigationContent,
                    searchText: searchTextBinding
                )
            )
        )
            .sheet(isPresented: addRoutineSheetBinding) {
                addRoutineSheetContent
            }
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
            }
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
                if !places.contains(where: { $0.id == selectedManualPlaceFilterID }) {
                    self.selectedManualPlaceFilterID = nil
                }
            }
    }

    private var navigationContent: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
    }

    @ViewBuilder
    private var sidebarContent: some View {
#if os(macOS)
        VStack(spacing: 12) {
            if store.routineTasks.isEmpty {
                emptyStateView(
                    title: "No routines yet",
                    message: "Start with one recurring task, and the sidebar will organize what needs attention for you.",
                    systemImage: "checklist"
                ) {
                    store.send(.setAddRoutineSheet(true))
                }
            } else {
                platformSearchField(searchText: searchTextBinding)
                filterPicker
                tagFilterBar
                locationFilterPanel
                overallDoneCountSummary

                listOfSortedTasksView(
                    routineDisplays: store.routineDisplays,
                    awayRoutineDisplays: store.awayRoutineDisplays,
                    archivedRoutineDisplays: store.archivedRoutineDisplays
                )
            }
        }
        .navigationTitle("Routina")
        .toolbar { homeToolbarContent }
        .routinaHomeSidebarColumnWidth()
#else
        Group {
            if store.routineTasks.isEmpty {
                emptyStateView(
                    title: "No routines yet",
                    message: "Start with one recurring task, and the home list will organize what needs attention for you.",
                    systemImage: "checklist"
                ) {
                    store.send(.setAddRoutineSheet(true))
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
        ToolbarItemGroup(placement: .primaryAction) {
            platformRefreshButton
#if !os(macOS)
            filterSheetButton
#endif
            Button {
                store.send(.setAddRoutineSheet(true))
            } label: {
                Label("Add Routine", systemImage: "plus")
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let detailStore = self.store.scope(
            state: \.routineDetailState,
            action: \.routineDetail
        ) {
            RoutineDetailTCAView(store: detailStore)
        } else {
            ContentUnavailableView(
                "Select a routine",
                systemImage: "checklist.checked",
                description: Text("Choose a routine from the sidebar to see its schedule, logs, and actions.")
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

    private var filterPicker: some View {
        Picker("Routine Filter", selection: $selectedFilter) {
            ForEach(RoutineListFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var overallDoneCountSummary: some View {
        HStack(spacing: 8) {
            Label("\(store.doneStats.totalCount) total dones", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Spacer(minLength: 0)

            Text(summaryCountText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var tagFilterBar: some View {
        if !availableTags.isEmpty {
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
            .padding(.top, -2)
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
                List(selection: selectedTaskBinding) {
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Filter By Place")
                        .font(.subheadline.weight(.semibold))

                    Picker(
                        "Place Filter",
                        selection: Binding(
                            get: { selectedManualPlaceFilterID },
                            set: { selectedManualPlaceFilterID = $0 }
                        )
                    ) {
                        Text("All routines").tag(Optional<UUID>.none)
                        ForEach(store.routinePlaces.sorted { lhs, rhs in
                            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                        }) { place in
                            Text(place.displayName).tag(Optional(place.id))
                        }
                    }
                    .pickerStyle(.menu)

                    Text(manualPlaceFilterDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .padding(.horizontal)
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
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowIconBackgroundColor(for: task))
                Text(task.emoji)
                    .font(.title3)
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

                Text(rowMetadataText(for: task))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
#else
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)

                statusBadge(for: task)

                Text(rowMetadataText(for: task))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
                (includePinned || !task.isPinned)
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
            || (task.placeName?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || RoutineTag.matchesQuery(trimmedSearch, in: task.tags)
    }

    private func matchesFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .due:
            return !task.isDoneToday && (urgencyLevel(for: task) > 0 || isYellowUrgency(task))
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
        NavigationLink(value: task.taskID) {
            routineRow(for: task)
        }
        .contentShape(Rectangle())
        .contextMenu {
            routineContextMenu(for: task, includeMarkDone: includeMarkDone)
        }
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

    private func rowMetadataText(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isPaused {
            return "\(cadenceDescription(for: task)) • \(doneCountDescription(for: task.doneCount)) • \(pauseDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
        }
        return "\(cadenceDescription(for: task)) • \(doneCountDescription(for: task.doneCount)) • \(completionDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
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
        let interval = task.interval
        if interval == 1 { return "Daily" }
        if interval % 30 == 0 {
            let months = interval / 30
            return months == 1 ? "Monthly" : "Every \(months) months"
        }
        if interval % 7 == 0 {
            let weeks = interval / 7
            return weeks == 1 ? "Weekly" : "Every \(weeks) weeks"
        }
        return "Every \(interval) days"
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
                Button("Add Routine", action: action)
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

    private var summaryCountText: String {
        let activeCount = store.routineDisplays.count
        let awayCount = store.awayRoutineDisplays.count
        let archivedCount = store.archivedRoutineDisplays.count

        if awayCount == 0 && archivedCount == 0 {
            return activeCount == 1 ? "1 active task" : "\(activeCount) active tasks"
        }

        if archivedCount == 0 {
            return "\(activeCount) active • \(awayCount) away"
        }

        return "\(activeCount) active • \(awayCount) away • \(archivedCount) archived"
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
