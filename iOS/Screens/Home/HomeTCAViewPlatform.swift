import Combine
import ComposableArchitecture
import Foundation
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
            return "One-time"
        case .routines:
            return "Repeating"
        }
    }

    @ToolbarContentBuilder
    var homeToolbarContent: some ToolbarContent {
        HomeIOSHomeToolbarContent(
            taskListMode: store.taskListMode,
            areTaskListModeActionsExpanded: areTaskListModeActionsExpanded,
            showTaskListModeActions: areHomeTaskListModeTabsVisible,
            hasActiveOptionalFilters: hasActiveOptionalFilters,
            onSelectTaskListMode: { mode in
                store.send(.taskListModeChanged(mode))
                collapseExpandedToolbarActions()
            },
            onToggleTaskListModeActions: {
                withAnimation(.snappy(duration: 0.2)) {
                    areTaskListModeActionsExpanded.toggle()
                }
            },
            onShowFilters: {
                collapseExpandedToolbarActions()
                store.send(.isFilterSheetPresentedChanged(true))
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
        view
            .safeAreaInset(edge: .top) {
                if isManualCloudRefreshInProgress {
                    HomeManualCloudRefreshProgressBanner(
                        statusText: manualCloudRefreshStatusText
                    )
                }
            }
            .refreshable {
                await performManualCloudRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: CloudKitSyncDiagnostics.didUpdateNotification
                )
            ) { _ in
                updateManualCloudRefreshStatus()
            }
            .alert(
                "Couldn't Refresh from iCloud",
                isPresented: Binding(
                    get: { store.manualRefreshErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.manualRefreshErrorDismissed)
                        }
                    }
                )
            ) {
                Button("Try Again") {
                    Task { @MainActor in
                        await performManualCloudRefresh()
                    }
                }
                Button("OK", role: .cancel) {
                    store.send(.manualRefreshErrorDismissed)
                }
            } message: {
                Text(store.manualRefreshErrorMessage ?? "")
            }
    }

    @MainActor
    func performManualCloudRefresh() async {
        guard !isManualCloudRefreshInProgress else { return }

        isManualCloudRefreshInProgress = true
        manualCloudRefreshStatusText = "Checking iCloud for updates…"
        defer {
            isManualCloudRefreshInProgress = false
            manualCloudRefreshStatusText = ""
        }

        await store.send(.manualRefreshRequested).finish()
    }

    func updateManualCloudRefreshStatus() {
        guard isManualCloudRefreshInProgress else { return }

        let message = CloudKitSyncDiagnostics.snapshot().manualRefreshDisplayMessage
        if !message.isEmpty {
            manualCloudRefreshStatusText = message
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
            return "Search repeating tasks"
        case .todos:
            return "Search one-time tasks"
        }
    }

    @ViewBuilder
    func applyAddRoutinePresentation<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: addRoutineSheetBinding) {
                addRoutineSheetContent
            }
    }

    func openAddTask() {
        store.send(.setSmartAddTaskSheet(true))
    }

    var filterPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Task Filter",
            options: iOSAvailableFilters,
            selection: Binding(
                get: { store.selectedFilter },
                set: { store.send(.selectedFilterChanged($0)) }
            ),
            fillsAvailableWidth: true
        ) { filter in
            Text(filter.title)
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    @ViewBuilder
    var locationFilterPanel: some View {
        if isPlacesEnabled && hasPlaceAwareContent {
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
            flagData: homeFlagFilterData,
            actions: homeFiltersSheetActions,
            tagPicker: {
                homeTagFilterPicker
            },
            tagSuggestions: {
                homeTagFilterData.tagSummaries.map(\.name)
            }
        )
    }

    private var homeTagFilterPicker: some View {
        HomeTagFilterPickerSheet(
            data: homeTagFilterData,
            bindings: homeFilterBindings.tagRules,
            actions: homeTagFilterActions
        )
    }

    var homeFiltersSheetConfiguration: HomeFiltersSheetConfiguration {
        HomeFiltersSheetConfiguration(
            taskListMode: store.taskListMode,
            availableFilters: iOSAvailableFilters,
            isGoalsEnabled: isGoalsEnabled,
            place: HomeFiltersPlaceConfiguration(
                sortedRoutinePlaces: isPlacesEnabled ? sortedRoutinePlaces : [],
                hasSavedPlaces: isPlacesEnabled && hasSavedPlaces,
                hasPlaceLinkedRoutines: isPlacesEnabled && hasPlaceLinkedRoutines,
                isPlacesEnabled: isPlacesEnabled,
                isLocationAuthorized: store.locationSnapshot.authorizationStatus.isAuthorized,
                placeFilterPluralNoun: placeFilterPluralNoun,
                placeFilterAllTitle: placeFilterAllTitle,
                placeFilterSectionDescription: placeFilterSectionDescription,
                locationStatusText: locationStatusText
            ),
            hasActiveOptionalFilters: hasActiveOptionalFilters
        )
    }

    var homeFiltersSheetActions: HomeFiltersSheetActions {
        HomeFiltersSheetActions(
            flagActions: homeFlagFilterActions,
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
            return task.scheduleMode.taskType == .routine
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
        TimelinePigmentControl(selection: Binding(
            get: {
                store.selectedTimelineFilterType.normalized(
                    includingEventEmotion: true,
                    includingPlaces: isPlacesEnabled,
                    includingNotes: isNotesEnabled,
                    includingAway: isAwayEnabled
                )
            },
            set: {
                store.send(.selectedTimelineFilterTypeChanged(
                    $0.normalized(
                        includingEventEmotion: true,
                        includingPlaces: isPlacesEnabled,
                        includingNotes: isNotesEnabled,
                        includingAway: isAwayEnabled
                    )
                ))
            }
        ), includesPlaces: isPlacesEnabled, includesNotes: isNotesEnabled, includesAway: isAwayEnabled)
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
        HomeIOSTaskListView(
            presentation: taskListPresentation,
            presentationRevision: taskListPresentationRevision,
            selectedTaskID: selectedTaskBinding,
            isCompactHeaderHidden: isCompactHeaderHidden,
            hasActiveOptionalFilters: hasActiveOptionalFilters,
            isTaskSearchActive: !searchTextBinding.wrappedValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        ) {
            compactHomeHeader
        } emptyRowContent: { emptyState in
            inlineEmptyStateRow(
                title: emptyState.title,
                message: emptyState.message,
                systemImage: emptyState.systemImage,
                actionTitle: "Create Task",
                action: searchTaskCreationText == nil ? nil : { openAddTask() }
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
        } workspaceNavigationContent: {
            homeWorkspaceNavigationSection
        }
    }

    func platformRoutineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int?) -> some View {
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
        rowNumber: Int?,
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
            isEmpty: showsLoadedEmptyTaskList,
            navigationTitle: homeNavigationTitle
        ) {
            emptyHomeContent
        } taskListContent: {
            if showsInitialTaskLoading {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            HomePinnedFocusTimerBanner(taskNamesByID: store.taskNamesByID) { presentation in
                activeFocusPresentation = presentation
            }
        }
    }

    @ViewBuilder
    private var emptyHomeContent: some View {
        if showsHomeWorkspaceNavigation,
           timelineStore != nil,
           backlogStore != nil,
           taskRankingStore != nil {
            List {
                Section {
                    inlineEmptyStateRow(
                        title: "No tasks yet",
                        message: "Add a repeating or one-time task, and the home list will organize what needs attention for you.",
                        systemImage: "checklist",
                        actionTitle: "Add New Task",
                        action: openAddTask
                    )
                }

                homeWorkspaceNavigationSection
            }
            .listStyle(.insetGrouped)
        } else {
            emptyStateView(
                title: "No tasks yet",
                message: "Add a repeating or one-time task, and the home list will organize what needs attention for you.",
                systemImage: "checklist",
                actionTitle: "Add New Task",
                action: openAddTask
            )
        }
    }

    private var showsHomeWorkspaceNavigation: Bool {
        externalSearchText == nil
    }

    @ViewBuilder
    private var homeWorkspaceNavigationSection: some View {
        if showsHomeWorkspaceNavigation,
           let timelineStore,
           let backlogStore,
           let taskRankingStore {
            HomeIOSWorkspaceNavigationSection(
                backlogStore: backlogStore,
                timelineStore: timelineStore,
                taskRankingStore: taskRankingStore
            )
        }
    }
}

private struct HomeManualCloudRefreshProgressBanner: View {
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView()
                .progressViewStyle(.linear)
                .accessibilityLabel("Receiving iCloud data")
                .accessibilityValue(statusText)
            Text(statusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

struct HomeIOSView: View {
    let store: StoreOf<HomeFeature>
    private let timelineStore: StoreOf<TimelineFeature>?
    private let backlogStore: StoreOf<BacklogFeature>?
    private let taskRankingStore: StoreOf<TaskRankingFeature>?
    private let searchText: Binding<String>?
    private let isActive: Bool

    init(
        store: StoreOf<HomeFeature>,
        timelineStore: StoreOf<TimelineFeature>? = nil,
        backlogStore: StoreOf<BacklogFeature>? = nil,
        taskRankingStore: StoreOf<TaskRankingFeature>? = nil,
        searchText: Binding<String>? = nil,
        isActive: Bool = true
    ) {
        self.store = store
        self.timelineStore = timelineStore
        self.backlogStore = backlogStore
        self.taskRankingStore = taskRankingStore
        self.searchText = searchText
        self.isActive = isActive
    }

    var body: some View {
        HomeTCAView(
            store: store,
            timelineStore: timelineStore,
            backlogStore: backlogStore,
            taskRankingStore: taskRankingStore,
            searchText: searchText,
            isActive: isActive
        )
    }
}

struct ActiveFocusControlPresentation: Identifiable, Equatable {
    let id: UUID
    let kind: FocusSessionKind
}

struct ActiveFocusControlSheet: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        },
        sort: \FocusSession.startedAt,
        order: .reverse
    ) private var focusSessions: [FocusSession]
    @Query(
        filter: #Predicate<SprintFocusSessionRecord> { session in
            session.stoppedAt == nil
        },
        sort: \SprintFocusSessionRecord.startedAt,
        order: .reverse
    ) private var sprintFocusSessions: [SprintFocusSessionRecord]
    @Query private var tasks: [RoutineTask]
    @Query private var sprints: [BoardSprintRecord]
    @State private var isPerformingAction = false
    @State private var actionErrorMessage: String?

    let presentation: ActiveFocusControlPresentation
    let onOpenTask: (UUID) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if let status = activeStatus {
                    ScrollView {
                        activeContent(status)
                            .padding(20)
                    }
                } else {
                    ContentUnavailableView(
                        "Focus Ended",
                        systemImage: "checkmark.circle",
                        description: Text("This timer is no longer active on this iPhone.")
                    )
                }
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isPerformingAction)
        .alert(
            "Couldn’t Update Focus",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        actionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                actionErrorMessage = nil
            }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    private func activeContent(_ status: ActiveFocusControlStatus) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Label(status.kindTitle, systemImage: status.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)

                Text(status.title)
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Text(status.timeText(at: context.date))
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(status.stateText(at: context.date))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            focusActionButtons(status)

            if let taskID = status.taskID {
                Button {
                    dismiss()
                    onOpenTask(taskID)
                } label: {
                    Label("Open Task", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isPerformingAction)
            }

            Text("Finish saves the focused time in history. Abandon ends the timer without keeping it as completed Focus history.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func focusActionButtons(_ status: ActiveFocusControlStatus) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                pauseResumeButton(status)
                finishButton
            }

            VStack(spacing: 10) {
                pauseResumeButton(status)
                finishButton
            }
        }

        Button(role: .destructive) {
            performAction(dismissesOnSuccess: true) {
                try FocusSessionSupport.abandonFocus(
                    sessionID: presentation.id,
                    kind: presentation.kind,
                    context: modelContext
                )
            }
        } label: {
            Label("Abandon", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isPerformingAction)
    }

    private func pauseResumeButton(_ status: ActiveFocusControlStatus) -> some View {
        Button {
            performAction(dismissesOnSuccess: false) {
                if status.isPaused {
                    return try FocusSessionSupport.resumeFocus(
                        sessionID: presentation.id,
                        kind: presentation.kind,
                        calendar: calendar,
                        context: modelContext
                    )
                }
                return try FocusSessionSupport.pauseFocus(
                    sessionID: presentation.id,
                    kind: presentation.kind,
                    calendar: calendar,
                    context: modelContext
                )
            }
        } label: {
            Label(
                status.isPaused ? "Resume" : "Pause",
                systemImage: status.isPaused ? "play.circle.fill" : "pause.circle.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.teal)
        .controlSize(.large)
        .disabled(isPerformingAction)
    }

    private var finishButton: some View {
        Button {
            performAction(dismissesOnSuccess: true) {
                try FocusSessionSupport.finishFocus(
                    sessionID: presentation.id,
                    kind: presentation.kind,
                    context: modelContext,
                    calendar: calendar
                )
            }
        } label: {
            Label("Finish", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .controlSize(.large)
        .disabled(isPerformingAction)
    }

    private var activeStatus: ActiveFocusControlStatus? {
        switch presentation.kind {
        case .task, .tag, .unassigned:
            guard let session = focusSessions.first(where: { $0.id == presentation.id }) else {
                return nil
            }

            let task = session.isTaskFocus
                ? tasks.first(where: { $0.id == session.taskID })
                : nil
            let title: String
            if let tagTitle = session.focusTagTitle {
                title = tagTitle
            } else if session.isUnassigned {
                title = "Unassigned focus"
            } else {
                title = normalizedTitle(task?.name, fallback: "Task focus")
            }

            return ActiveFocusControlStatus(
                title: title,
                kind: presentation.kind,
                taskID: session.isTaskFocus ? session.taskID : nil,
                startedAt: session.startedAt ?? .now,
                plannedDurationSeconds: session.plannedDurationSeconds,
                pausedAt: session.pausedAt,
                accumulatedPausedSeconds: session.accumulatedPausedSeconds
            )

        case .sprint:
            guard let session = sprintFocusSessions.first(where: { $0.id == presentation.id }) else {
                return nil
            }
            let sprintTitle = sprints.first(where: { $0.id == session.sprintID })?.title
            return ActiveFocusControlStatus(
                title: normalizedTitle(sprintTitle, fallback: "Sprint focus"),
                kind: .sprint,
                taskID: nil,
                startedAt: session.startedAt,
                plannedDurationSeconds: 0,
                pausedAt: session.pausedAt,
                accumulatedPausedSeconds: session.accumulatedPausedSeconds
            )
        }
    }

    private func performAction(
        dismissesOnSuccess: Bool,
        action: () throws -> Bool
    ) {
        guard !isPerformingAction else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }

        do {
            guard try action() else {
                actionErrorMessage = "The timer changed on another device. Close this screen and try again after iCloud finishes syncing."
                return
            }
            if dismissesOnSuccess {
                dismiss()
            }
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func normalizedTitle(_ title: String?, fallback: String) -> String {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedTitle.isEmpty ? fallback : trimmedTitle
    }
}

private struct ActiveFocusControlStatus {
    let title: String
    let kind: FocusSessionKind
    let taskID: UUID?
    let startedAt: Date
    let plannedDurationSeconds: TimeInterval
    let pausedAt: Date?
    let accumulatedPausedSeconds: TimeInterval

    var isPaused: Bool {
        pausedAt != nil
    }

    var kindTitle: String {
        switch kind {
        case .task:
            return "Task Focus"
        case .tag:
            return "Tag Focus"
        case .sprint:
            return "Sprint Focus"
        case .unassigned:
            return "Focus"
        }
    }

    var systemImage: String {
        switch kind {
        case .task:
            return "timer"
        case .tag:
            return "tag.fill"
        case .sprint:
            return "flag.checkered"
        case .unassigned:
            return "stopwatch"
        }
    }

    func timeText(at date: Date) -> String {
        if overtimeSeconds(at: date) > 0 {
            return "+\(FocusSessionFormatting.durationText(seconds: overtimeSeconds(at: date)))"
        }
        return FocusSessionFormatting.durationText(seconds: displaySeconds(at: date))
    }

    func stateText(at date: Date) -> String {
        if isPaused {
            return "Paused"
        }
        if overtimeSeconds(at: date) > 0 {
            return "Overtime"
        }
        return plannedDurationSeconds > 0 ? "Remaining" : "Elapsed"
    }

    private func displaySeconds(at date: Date) -> TimeInterval {
        let elapsed = elapsedSeconds(at: date)
        guard plannedDurationSeconds > 0 else { return elapsed }
        return max(0, plannedDurationSeconds - elapsed)
    }

    private func overtimeSeconds(at date: Date) -> TimeInterval {
        guard plannedDurationSeconds > 0 else { return 0 }
        return max(0, elapsedSeconds(at: date) - plannedDurationSeconds)
    }

    private func elapsedSeconds(at date: Date) -> TimeInterval {
        let endDate = pausedAt ?? date
        return max(0, endDate.timeIntervalSince(startedAt) - max(0, accumulatedPausedSeconds))
    }
}

private struct HomePinnedFocusTimerBanner: View {
    @Query(
        filter: #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        },
        sort: \FocusSession.startedAt,
        order: .reverse
    ) private var focusSessions: [FocusSession]
    @Query(
        filter: #Predicate<SprintFocusSessionRecord> { session in
            session.stoppedAt == nil
        },
        sort: \SprintFocusSessionRecord.startedAt,
        order: .reverse
    ) private var sprintFocusSessions: [SprintFocusSessionRecord]
    @Query private var sprints: [BoardSprintRecord]
    let taskNamesByID: [UUID: String]
    let onOpen: (ActiveFocusControlPresentation) -> Void

    var body: some View {
        if let status = activeStatus {
            Button {
                onOpen(status.presentation)
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

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .accessibilityLabel("Open \(status.isPaused ? "paused" : "running") timer for \(status.title)")
            .accessibilityHint("Shows Focus controls")
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

        let taskTitle = session.isTaskFocus ? taskNamesByID[session.taskID] : nil
        let kind: HomePinnedFocusTimerStatus.Kind
        let title: String
        if let tagTitle = session.focusTagTitle {
            kind = .tag
            title = tagTitle
        } else if session.isUnassigned {
            kind = .unassigned
            title = "Unassigned focus"
        } else {
            kind = .task
            title = normalizedTitle(taskTitle, fallback: "Task focus")
        }

        return HomePinnedFocusTimerStatus(
            id: session.id,
            kind: kind,
            title: title,
            startedAt: startedAt,
            plannedDurationSeconds: session.plannedDurationSeconds,
            pausedAt: session.pausedAt,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds
        )
    }

    private var activeSprintStatus: HomePinnedFocusTimerStatus? {
        guard let session = sprintFocusSessions.first(where: { $0.stoppedAt == nil }) else {
            return nil
        }

        let sprintTitle = sprints.first { $0.id == session.sprintID }?.title
        return HomePinnedFocusTimerStatus(
            id: session.id,
            kind: .sprint,
            title: normalizedTitle(sprintTitle, fallback: "Sprint focus"),
            startedAt: session.startedAt,
            plannedDurationSeconds: 0,
            pausedAt: session.pausedAt,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds
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
        case tag
        case sprint
        case unassigned
    }

    let id: UUID
    let kind: Kind
    let title: String
    let startedAt: Date
    let plannedDurationSeconds: TimeInterval
    let pausedAt: Date?
    let accumulatedPausedSeconds: TimeInterval

    var presentation: ActiveFocusControlPresentation {
        ActiveFocusControlPresentation(id: id, kind: focusKind)
    }

    var systemImage: String {
        if isPaused {
            return "pause.circle.fill"
        }

        switch kind {
        case .task:
            return "timer"
        case .tag:
            return "tag.fill"
        case .sprint:
            return "flag.checkered"
        case .unassigned:
            return "stopwatch"
        }
    }

    private var focusKind: FocusSessionKind {
        switch kind {
        case .task:
            return .task
        case .tag:
            return .tag
        case .sprint:
            return .sprint
        case .unassigned:
            return .unassigned
        }
    }

    private var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    var isPaused: Bool {
        pausedAt != nil
    }

    func timeText(at date: Date) -> String {
        if overtimeSeconds(at: date) > 0 {
            return "+\(FocusSessionFormatting.durationText(seconds: overtimeSeconds(at: date)))"
        }
        return FocusSessionFormatting.durationText(seconds: displaySeconds(at: date))
    }

    private func displaySeconds(at date: Date) -> TimeInterval {
        let elapsed = elapsedSeconds(at: date)
        guard !isCountUp else { return elapsed }
        return max(0, plannedDurationSeconds - elapsed)
    }

    private func overtimeSeconds(at date: Date) -> TimeInterval {
        guard !isCountUp else { return 0 }
        let elapsed = elapsedSeconds(at: date)
        return max(0, elapsed - plannedDurationSeconds)
    }

    private func elapsedSeconds(at date: Date) -> TimeInterval {
        let endDate = pausedAt ?? date
        return max(0, endDate.timeIntervalSince(startedAt) - max(0, accumulatedPausedSeconds))
    }
}
