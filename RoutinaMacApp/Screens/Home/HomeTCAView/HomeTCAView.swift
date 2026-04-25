import Combine
import ComposableArchitecture
import CoreData
import MapKit
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    struct RoutineListSection: Identifiable {
        let title: String
        var tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

    struct ManualMoveContext: Equatable {
        let sectionKey: String
        let orderedTaskIDs: [UUID]
    }

    let store: StoreOf<HomeFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let statsStore: StoreOf<StatsFeature>?
    @State var addEditFormCoordinator = AddEditFormCoordinator()
    let externalSearchText: Binding<String>?
    @Environment(\.calendar) var calendar
    @AppStorage(
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue,
        store: SharedDefaults.app
    ) private var routineListSectioningModeRawValue: String = RoutineListSectioningMode.defaultValue.rawValue
    @AppStorage("macTodoBoardCompactCards", store: SharedDefaults.app)
    var isMacTodoBoardCompactCards = false
    @State private var localSearchText = ""
    @State var isCompactHeaderHidden = false
    @State private var isRefreshScheduled = false
    @State var relatedFilterTagSuggestionAnchor: String?
    @State var relatedTimelineTagSuggestionAnchor: String?
    @State var relatedStatsTagSuggestionAnchor: String?
    @State var draggedSection: FormSection?
    @State var isBoardTaskDetailSheetPresented = false
    @FocusState var isSprintCreationFieldFocused: Bool
    @FocusState var isSprintRenameFieldFocused: Bool

    init(
        store: StoreOf<HomeFeature>,
        settingsStore: StoreOf<SettingsFeature>,
        statsStore: StoreOf<StatsFeature>? = nil,
        searchText: Binding<String>? = nil
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.statsStore = statsStore
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
            .sheet(isPresented: isFilterSheetPresentedBinding) {
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
    }

    @ViewBuilder
    var detailContent: some View {
        if let detailStore = self.store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(store: detailStore)
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

    var sidebarRowNumberMinWidth: CGFloat { 28 }

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

            Label("\(store.doneStats.canceledTotalCount) cancels", systemImage: "xmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Label("\(store.routineTasks.filter { !$0.isOneOffTask }.count) routines", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Label("\(store.routineTasks.filter { $0.isOneOffTask && !$0.isCompletedOneOff && !$0.isCanceledOneOff }.count) todos", systemImage: "checkmark.circle")
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
            store.send(.isFilterSheetPresentedChanged(true))
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
        HomeActiveFilterChipBar(
            taskListViewMode: store.taskListViewMode,
            selectedTags: store.selectedTags,
            excludedTags: store.excludedTags,
            selectedPlaceName: selectedPlaceName,
            selectedImportanceUrgencyFilterLabel: homeFilterPresentation.selectedImportanceUrgencyFilterLabel,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            onClearAll: { store.send(.clearOptionalFilters) },
            onClearTaskListViewMode: { store.send(.taskListViewModeChanged(.all)) },
            onRemoveIncludedTag: { tag in
                var selected = store.selectedTags
                selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
                store.send(.selectedTagsChanged(selected))
            },
            onRemoveExcludedTag: { tag in
                store.send(.excludedTagsChanged(store.excludedTags.filter { $0 != tag }))
            },
            onClearPlace: {
                store.send(.selectedManualPlaceFilterIDChanged(nil))
            },
            onClearImportanceUrgency: {
                store.send(.selectedImportanceUrgencyFilterChanged(nil))
            },
            onShowUnavailableRoutines: {
                store.send(.hideUnavailableRoutinesChanged(false))
            }
        )
    }

    var homeFilterPresentation: HomeFilterPresentation {
        HomeFilterPresentation(
            taskListKind: store.taskListMode.filterTaskListKind,
            selectedFilter: store.selectedFilter,
            taskListViewMode: store.taskListViewMode,
            selectedTodoStateFilter: store.selectedTodoStateFilter,
            selectedTags: store.selectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            excludedTags: store.excludedTags,
            selectedPlaceName: selectedPlaceName,
            hasSelectedPlaceFilter: store.selectedManualPlaceFilterID != nil,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            hasSavedPlaces: hasSavedPlaces,
            awayRoutineCount: store.awayRoutineDisplays.count,
            locationAuthorizationStatus: store.locationSnapshot.authorizationStatus
        )
    }

    var hideUnavailableRoutinesBinding: Binding<Bool> {
        Binding(
            get: { store.hideUnavailableRoutines },
            set: { store.send(.hideUnavailableRoutinesChanged($0)) }
        )
    }

    var isFilterSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: { store.isFilterSheetPresented },
            set: { store.send(.isFilterSheetPresentedChanged($0)) }
        )
    }

    var manualPlaceFilterBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedManualPlaceFilterID },
            set: { store.send(.selectedManualPlaceFilterIDChanged($0)) }
        )
    }

    var homeFilterBindings: HomeFilterBindings {
        HomeFilterBindings(
            taskListViewMode: Binding(
                get: { store.taskListViewMode },
                set: { store.send(.taskListViewModeChanged($0)) }
            ),
            selectedFilter: Binding(
                get: { store.selectedFilter },
                set: { store.send(.selectedFilterChanged($0)) }
            ),
            selectedTodoStateFilter: Binding(
                get: { store.selectedTodoStateFilter },
                set: { store.send(.selectedTodoStateFilterChanged($0)) }
            ),
            selectedImportanceUrgencyFilter: Binding(
                get: { store.selectedImportanceUrgencyFilter },
                set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            includeTagMatchMode: Binding(
                get: { store.includeTagMatchMode },
                set: { store.send(.includeTagMatchModeChanged($0)) }
            ),
            excludeTagMatchMode: Binding(
                get: { store.excludeTagMatchMode },
                set: { store.send(.excludeTagMatchModeChanged($0)) }
            ),
            selectedPlaceID: manualPlaceFilterBinding,
            hideUnavailableRoutines: hideUnavailableRoutinesBinding
        )
    }

    var sortedRoutinePlaces: [RoutinePlace] {
        store.routinePlaces.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var selectedPlaceName: String? {
        guard let id = store.selectedManualPlaceFilterID else { return nil }
        return store.routinePlaces.first(where: { $0.id == id })?.displayName
    }

    var activeOptionalFilterCount: Int {
        homeFilterPresentation.activeOptionalFilterCount
    }

    var hasActiveOptionalFilters: Bool {
        homeFilterPresentation.hasActiveOptionalFilters
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

    var manualPlaceFilterDescription: String {
        homeFilterPresentation.manualPlaceFilterDescription
    }

    var placeFilterSectionDescription: String {
        homeFilterPresentation.placeFilterSectionDescription
    }

    var placeFilterPluralNoun: String {
        homeFilterPresentation.placeFilterPluralNoun
    }

    var selectedImportanceUrgencyFilterLabel: String? {
        homeFilterPresentation.selectedImportanceUrgencyFilterLabel
    }

    var importanceUrgencyFilterSummary: String {
        homeFilterPresentation.importanceUrgencyFilterSummary
    }

    var locationStatusText: String {
        homeFilterPresentation.locationStatusText
    }

    func routineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        platformRoutineRow(for: task, rowNumber: rowNumber)
    }

    @ViewBuilder
    func taskDetailDestination(taskID: UUID) -> some View {
        if store.selectedTaskID == taskID,
           let detailStore = self.store.scope(
               state: \.taskDetailState,
               action: \.taskDetail
           ) {
            TaskDetailTCAView(store: detailStore)
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
        includeMarkDone: Bool = true,
        moveContext: ManualMoveContext? = nil
    ) -> some View {
        platformRoutineNavigationRow(
            for: task,
            rowNumber: rowNumber,
            includeMarkDone: includeMarkDone,
            moveContext: moveContext
        )
    }

    @ViewBuilder
    func routineContextMenu(
        for task: HomeFeature.RoutineDisplay,
        includeMarkDone: Bool,
        moveContext: ManualMoveContext? = nil
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
        } else if task.isCompletedOneOff || task.isCanceledOneOff {
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
                    store.send(.notTodayTask(task.taskID))
                } label: {
                    Label("Not today!", systemImage: "moon.zzz")
                }

                Button {
                    store.send(.pauseTask(task.taskID))
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
            }
        }

        if let moveContext,
           let currentIndex = moveContext.orderedTaskIDs.firstIndex(of: task.taskID) {
            Divider()

            Button {
                store.send(
                    .moveTaskInSection(
                        taskID: task.taskID,
                        sectionKey: moveContext.sectionKey,
                        orderedTaskIDs: moveContext.orderedTaskIDs,
                        direction: .top
                    )
                )
            } label: {
                Label("Move to Top", systemImage: "arrow.up.to.line")
            }
            .disabled(currentIndex == 0)

            Button {
                store.send(
                    .moveTaskInSection(
                        taskID: task.taskID,
                        sectionKey: moveContext.sectionKey,
                        orderedTaskIDs: moveContext.orderedTaskIDs,
                        direction: .up
                    )
                )
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(currentIndex == 0)

            Button {
                store.send(
                    .moveTaskInSection(
                        taskID: task.taskID,
                        sectionKey: moveContext.sectionKey,
                        orderedTaskIDs: moveContext.orderedTaskIDs,
                        direction: .down
                    )
                )
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(currentIndex == moveContext.orderedTaskIDs.count - 1)

            Button {
                store.send(
                    .moveTaskInSection(
                        taskID: task.taskID,
                        sectionKey: moveContext.sectionKey,
                        orderedTaskIDs: moveContext.orderedTaskIDs,
                        direction: .bottom
                    )
                )
            } label: {
                Label("Move to Bottom", systemImage: "arrow.down.to.line")
            }
            .disabled(currentIndex == moveContext.orderedTaskIDs.count - 1)
        }

        platformPinMenuItem(for: task)
        platformDeleteMenuItem(for: task)
    }

    @ViewBuilder
    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        if store.taskListMode == .todos,
           task.isOneOffTask,
           !task.isCompletedOneOff,
           !task.isCanceledOneOff,
           !task.isInProgress {
            EmptyView()
        } else {
            let style = badgeStyle(for: task)

            HStack(spacing: 4) {
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

    private var allRoutineDisplays: [HomeFeature.RoutineDisplay] {
        store.routineDisplays + store.awayRoutineDisplays + store.archivedRoutineDisplays
    }

    var iOSAvailableFilters: [RoutineListFilter] {
        [.all, .due, .doneToday]
    }

    var availableTags: [String] {
        tagSummaries.map(\.name)
    }

    var tagSummaries: [RoutineTagSummary] {
        HomeFeature.tagSummaries(from: allRoutineDisplays.filter(matchesCurrentTaskListMode))
    }

    var allTagTaskCount: Int {
        allRoutineDisplays.filter(matchesCurrentTaskListMode).count
    }

    /// Tags available for exclusion — scoped to tasks that already match the selected include tag.
    var availableExcludeTags: [String] {
        availableExcludeTagSummaries.map(\.name)
    }

    var availableExcludeTagSummaries: [RoutineTagSummary] {
        let base = allRoutineDisplays.filter(matchesCurrentTaskListMode).filter { task in
            HomeFeature.matchesSelectedTags(
                store.selectedTags,
                mode: store.includeTagMatchMode,
                in: task.tags
            )
        }
        return HomeFeature.tagSummaries(from: base).filter { summary in
            // Don't offer the include tag itself as an exclude option
            !store.selectedTags.contains { RoutineTag.contains($0, in: [summary.name]) }
        }
    }

    var homeTagFilterData: HomeTagFilterData {
        HomeTagFilterData(
            selectedTags: store.selectedTags,
            excludedTags: store.excludedTags,
            tagSummaries: tagSummaries,
            allTagTaskCount: allTagTaskCount,
            suggestedRelatedTags: suggestedRelatedFilterTags,
            availableExcludeTagSummaries: availableExcludeTagSummaries
        )
    }

    var homeTagFilterActions: HomeTagFilterActions {
        HomeTagFilterActions(
            onShowAllTags: {
                relatedFilterTagSuggestionAnchor = nil
                store.send(.selectedTagsChanged([]))
            },
            onToggleIncludedTag: toggleIncludedTag,
            onAddIncludedTag: addIncludedTag,
            onToggleExcludedTag: toggleExcludedTag
        )
    }

    var suggestedRelatedFilterTags: [String] {
        let selectedTags = store.selectedTags
        guard !selectedTags.isEmpty else { return [] }
        let suggestionSource = relatedFilterTagSuggestionAnchor.map { [$0] } ?? Array(selectedTags)
        return RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: store.relatedTagRules,
            availableTags: availableTags
        )
    }

    func toggleIncludedTag(_ tag: String) {
        var selected = store.selectedTags
        if selected.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            selected.insert(tag)
            relatedFilterTagSuggestionAnchor = tag
        }
        store.send(.selectedTagsChanged(selected))
        if selected.isEmpty {
            relatedFilterTagSuggestionAnchor = nil
        }
    }

    func addIncludedTag(_ tag: String) {
        guard !homeTagFilterData.isIncludedTagSelected(tag) else { return }
        var selected = store.selectedTags
        selected.insert(tag)
        store.send(.selectedTagsChanged(selected))
    }

    func toggleExcludedTag(_ tag: String) {
        var excluded = store.excludedTags
        if excluded.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            excluded = excluded.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            excluded.insert(tag)
            var selected = store.selectedTags
            selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
            store.send(.selectedTagsChanged(selected))
        }
        store.send(.excludedTagsChanged(excluded))
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

    @ViewBuilder
    func iosTaskListModeButton(_ mode: HomeFeature.TaskListMode) -> some View {
        let isSelected = store.taskListMode == mode

        Button {
            store.send(.taskListModeChanged(mode))
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

private extension HomeFeature.TaskListMode {
    var filterTaskListKind: HomeFilterTaskListKind {
        switch self {
        case .all:
            return .all
        case .routines:
            return .routines
        case .todos:
            return .todos
        }
    }
}
