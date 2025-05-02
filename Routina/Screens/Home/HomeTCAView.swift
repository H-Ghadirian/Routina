import Combine
import ComposableArchitecture
import CoreData
import MapKit
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    enum IOSTaskListMode: String, CaseIterable, Identifiable {
        case routines = "Routines"
        case todos = "Todos"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .routines:
                return "repeat"
            case .todos:
                return "checklist"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .routines:
                return "Show routines"
            case .todos:
                return "Show todos"
            }
        }
    }

    struct RoutineListSection: Identifiable {
        let title: String
        var tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

    let store: StoreOf<HomeFeature>
#if os(macOS)
    let settingsStore: StoreOf<SettingsFeature>
#endif
    let externalSearchText: Binding<String>?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) var calendar
    @Query(sort: \RoutineLog.timestamp, order: .reverse) var timelineLogs: [RoutineLog]
    @AppStorage(
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue,
        store: SharedDefaults.app
    ) private var routineListSectioningModeRawValue: String = RoutineListSectioningMode.defaultValue.rawValue
    @State private var localSearchText = ""
    @State var selectedFilter: RoutineListFilter = .all
    @State var iosTaskListMode: IOSTaskListMode = .routines
    @State var selectedTag: String?
    @State var excludedTags: Set<String> = []
    @State var selectedManualPlaceFilterID: UUID?
    @State private var tabFilterManager = TabFilterStateManager()
    @State var isFilterSheetPresented = false
    @State var isCompactHeaderHidden = false
    @State private var isRefreshScheduled = false
    @State var selectedTimelineRange: TimelineRange = .all
    @State var selectedTimelineFilterType: TimelineFilterType = .all
    @State var selectedTimelineTag: String?
#if os(macOS)
    @State var macSidebarSelection: MacSidebarSelection?
    @State var macSidebarMode: MacSidebarMode = .routines
    @State var macTaskListMode: MacTaskListMode = .routines
    @State var selectedSettingsSection: SettingsMacSection? = .notifications
    @State var addEditFormCoordinator = AddEditFormCoordinator()
    @State var statsSelectedRange: DoneChartRange = .week
    @State var statsSelectedTag: String? = nil
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
        applyPlatformHomeObservers(
            to: applyAddRoutinePresentation(
                to: applyPlatformDeleteConfirmation(
                    to: applyPlatformRefresh(
                        to: applyPlatformSearchExperience(
                            to: platformNavigationContent,
                            searchText: searchTextBinding
                        )
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
                let placeStillExists = places.contains { place in
                    place.id == selectedManualPlaceFilterID
                }
                if !placeStillExists {
                    self.selectedManualPlaceFilterID = nil
                }
            }
    }

    @ViewBuilder
    var detailContent: some View {
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

    var addRoutineSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isAddRoutineSheetPresented },
            set: { store.send(.setAddRoutineSheet($0)) }
        )
    }

    var searchTextBinding: Binding<String> {
        if let externalSearchText {
            externalSearchText
        } else {
            $localSearchText
        }
    }

    var routineListSectioningMode: RoutineListSectioningMode {
        RoutineListSectioningMode(rawValue: routineListSectioningModeRawValue) ?? .defaultValue
    }

    var selectedTaskBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedTaskID },
            set: { store.send(.setSelectedTask($0)) }
        )
    }

    @ViewBuilder
    var addRoutineSheetContent: some View {
        if let addRoutineStore = self.store.scope(
            state: \.addRoutineState,
            action: \.addRoutineSheet
        ) {
            AddRoutineTCAView(store: addRoutineStore)
        }
    }

    var timelineRangePicker: some View {
        platformTimelineRangePicker
    }

    var timelineTypePicker: some View {
        platformTimelineTypePicker
    }

    var overallDoneCountSummary: some View {
        HStack(spacing: 12) {
            Label("\(store.doneStats.totalCount) dones", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Label("\(store.routineTasks.filter { !$0.isOneOffTask }.count) routines", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Label("\(store.routineTasks.filter { $0.isOneOffTask && !$0.isCompletedOneOff }.count) todos", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    var tagFilterBar: some View {
        platformTagFilterBar
    }

    func sharedTaskSections(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> (sections: [RoutineListSection], awayTasks: [HomeFeature.RoutineDisplay], archivedTasks: [HomeFeature.RoutineDisplay]) {
        (
            groupedRoutineSections(from: routineDisplays),
            filteredAwayTasks(awayRoutineDisplays),
            filteredArchivedTasks(archivedRoutineDisplays)
        )
    }

    func listOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
        platformListOfSortedTasksView(
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays
        )
    }

    var compactHomeHeader: some View {
        platformCompactHomeHeader
    }

    var filterSheetButton: some View {
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
    var activeFilterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedTag {
                    compactFilterChip(title: "#\(selectedTag)") {
                        self.selectedTag = nil
                    }
                }

                ForEach(excludedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "not #\(tag)", tintColor: .red) {
                        excludedTags.remove(tag)
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

    func compactFilterChip(
        title: String,
        systemImage: String? = nil,
        tintColor: Color = .secondary,
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
            .foregroundStyle(tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tintColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    var hideUnavailableRoutinesBinding: Binding<Bool> {
        Binding(
            get: { store.hideUnavailableRoutines },
            set: { store.send(.hideUnavailableRoutinesChanged($0)) }
        )
    }

    var manualPlaceFilterBinding: Binding<UUID?> {
        Binding(
            get: { selectedManualPlaceFilterID },
            set: { selectedManualPlaceFilterID = $0 }
        )
    }

    var sortedRoutinePlaces: [RoutinePlace] {
        store.routinePlaces.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var selectedPlaceName: String? {
        guard let selectedManualPlaceFilterID else { return nil }
        return store.routinePlaces.first(where: { $0.id == selectedManualPlaceFilterID })?.displayName
    }

    var activeOptionalFilterCount: Int {
        var count = 0

        if selectedTag != nil {
            count += 1
        }
        count += excludedTags.count
        if selectedManualPlaceFilterID != nil {
            count += 1
        }
        if store.hideUnavailableRoutines {
            count += 1
        }

        return count
    }

    var hasActiveOptionalFilters: Bool {
        activeOptionalFilterCount > 0
    }

    var hasSavedPlaces: Bool {
        !sortedRoutinePlaces.isEmpty
    }

    var hasPlaceLinkedRoutines: Bool {
        store.routineTasks.contains { $0.placeID != nil }
    }

    var hasPlaceAwareContent: Bool {
        hasSavedPlaces || hasPlaceLinkedRoutines
    }

    func saveFilterSnapshot(for tabKey: String) {
        tabFilterManager.save(
            TabFilterStateManager.Snapshot(
                selectedTag: selectedTag,
                excludedTags: excludedTags,
                selectedFilter: selectedFilter,
                selectedManualPlaceFilterID: selectedManualPlaceFilterID
            ),
            for: tabKey
        )
    }

    func restoreFilterSnapshot(for tabKey: String) {
        let snapshot = tabFilterManager.snapshot(for: tabKey)
        selectedTag = snapshot.selectedTag
        excludedTags = snapshot.excludedTags
        selectedFilter = snapshot.selectedFilter
        selectedManualPlaceFilterID = snapshot.selectedManualPlaceFilterID

        if !tabFilterManager.hasSnapshot(for: tabKey), store.hideUnavailableRoutines {
            store.send(.hideUnavailableRoutinesChanged(false))
        }
    }

    func clearOptionalFilters() {
        selectedTag = nil
        excludedTags = []
        selectedManualPlaceFilterID = nil

        if store.hideUnavailableRoutines {
            store.send(.hideUnavailableRoutinesChanged(false))
        }
    }

    var manualPlaceFilterDescription: String {
        guard let selectedManualPlaceFilterID,
              let place = store.routinePlaces.first(where: { $0.id == selectedManualPlaceFilterID })
        else {
            return "Choose a saved place to show only routines linked to that place."
        }
        return "Showing only routines linked to \(place.displayName)."
    }

    var placeFilterSectionDescription: String {
        if hasSavedPlaces {
            return manualPlaceFilterDescription
        }
        return "Save a place in Settings, then link it to a routine to filter by place here."
    }

    var locationStatusText: String {
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

    func routineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        platformRoutineRow(for: task, rowNumber: rowNumber)
    }

    @ViewBuilder
    func routineDetailDestination(taskID: UUID) -> some View {
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

    func deleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        platformDeleteTasks(at: offsets, from: sectionTasks)
    }

    func openTask(_ taskID: UUID) {
        platformOpenTask(taskID)
    }

    func deleteTask(_ taskID: UUID) {
        platformDeleteTask(taskID)
    }

    func routineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool = true
    ) -> some View {
        platformRoutineNavigationRow(for: task, rowNumber: rowNumber, includeMarkDone: includeMarkDone)
    }

    @ViewBuilder
    func routineContextMenu(
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

        platformPinMenuItem(for: task)
        platformDeleteMenuItem(for: task)
    }

    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        let style = badgeStyle(for: task)

        return HStack(spacing: 4) {
            Image(systemName: style.systemImage)
                .imageScale(.small)

            Text(style.title)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
        .foregroundStyle(style.foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(style.backgroundColor, in: Capsule())
    }

    func tagFilterButton(
        title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? selectedColor : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? selectedColor.opacity(0.16) : Color.secondary.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func emptyStateView(
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

    func inlineEmptyStateRow(
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

    var iOSAvailableFilters: [RoutineListFilter] {
        [.all, .due, .doneToday]
    }

    var availableTags: [String] {
        HomeFeature.availableTags(from: allRoutineDisplays.filter(matchesCurrentTaskListMode))
    }

    /// Tags available for exclusion — scoped to tasks that already match the selected include tag.
    var availableExcludeTags: [String] {
        let base = allRoutineDisplays.filter(matchesCurrentTaskListMode).filter { task in
            HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
        }
        return HomeFeature.availableTags(from: base).filter { tag in
            // Don't offer the include tag itself as an exclude option
            selectedTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
        }
    }

    func handleCompactHeaderScroll(oldOffset: CGFloat, newOffset: CGFloat) {
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
        let all = (activeDisplays + awayDisplays + archivedDisplays).filter(matchesCurrentTaskListMode)
        let allAvailableTags = HomeFeature.availableTags(from: all)

        if let selectedTag, !RoutineTag.contains(selectedTag, in: allAvailableTags) {
            self.selectedTag = nil
        }

        // Prune excluded tags to only those still present in the include-scoped pool
        excludedTags = excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }
    }

    @ViewBuilder
    func iosTaskListModeButton(_ mode: IOSTaskListMode) -> some View {
        let isSelected = iosTaskListMode == mode

        Button {
            iosTaskListMode = mode
        } label: {
            Image(systemName: mode.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
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
