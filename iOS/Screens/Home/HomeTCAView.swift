import ComposableArchitecture
import SwiftData
import SwiftUI

private struct HomeTaskListPresentationRefreshToken: Equatable {
    let isActive: Bool
    let displayRevision: UInt
    let filters: HomeTaskFiltersState
    let taskListMode: HomeTaskListMode
    let hideUnavailableRoutines: Bool
    let searchText: String
    let sectioningMode: RoutineListSectioningMode
    let flagRules: [RoutineFlagRule]
    let referenceDay: Date
}

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>
    let timelineStore: StoreOf<TimelineFeature>?
    let backlogStore: StoreOf<BacklogFeature>?
    let taskRankingStore: StoreOf<TaskRankingFeature>?
    let externalSearchText: Binding<String>?
    let isActive: Bool
    @Environment(\.calendar) var calendar
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage(
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue,
        store: SharedDefaults.app
    ) private var routineListSectioningModeRawValue: String = RoutineListSectioningMode.defaultValue.rawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) var showPersianDates = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingHomeTaskListModeTabsVisible.rawValue,
        store: SharedDefaults.app
    ) var areHomeTaskListModeTabsVisible = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) var isGoalsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) var isAwayEnabled = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var taskRowHiddenFieldsRawValue = ""
    @AppStorage(
        IOSFirstTaskExperience.completionDefaultsKey,
        store: SharedDefaults.app
    ) var hasCompletedFirstTaskExperience = true
    @State private var localSearchText = ""
    @State var isManualCloudRefreshInProgress = false
    @State var manualCloudRefreshStatusText = ""
    @State var isCompactHeaderHidden = false
    @State var areTaskListModeActionsExpanded = false
    @State var isRefreshScheduled = false
    @State var hasDeferredRoutineUpdateRefresh = false
    @State var deferredRoutineUpdateRefreshTask: Task<Void, Never>?
    @State var needsRefreshWhenActive = false
    @State var relatedFilterTagSuggestionAnchor: String?
    @State var planningDateTaskID: UUID?
    @State var planningDateDraft = Date()
    @State var taskListPresentation = HomeTaskListPresentation<HomeFeature.RoutineDisplay>(
        sections: [],
        hiddenUnavailableTaskCount: 0,
        emptyState: nil
    )
    @State var taskListPresentationRevision: UInt = 0
    @State var searchTaskCreationText: String?
    @State var activeFocusPresentation: ActiveFocusControlPresentation?

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
        self.externalSearchText = searchText
        self.isActive = isActive
    }

    var body: some View {
        homeContent
    }

    private var homeContent: some View {
        applyHomeRefreshObservers(
            to: applyPlatformHomeObservers(
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
            .sheet(isPresented: planningDatePickerPresentedBinding) {
                TaskPlanningDatePickerSheet(
                    date: $planningDateDraft,
                    onCancel: dismissPlanningDatePicker,
                    onSave: savePlanningDatePicker
                )
            }
            .sheet(item: $activeFocusPresentation) { presentation in
                ActiveFocusControlSheet(
                    presentation: presentation,
                    onOpenTask: { taskID in
                        activeFocusPresentation = nil
                        openTask(taskID)
                    }
                )
            }
            .task(id: taskListPresentationRefreshToken) {
                guard isActive else { return }
                await refreshTaskListPresentation()
            }
            .onChange(of: store.routineTasks.isEmpty, initial: true) { _, isEmpty in
                guard
                    IOSFirstTaskExperience.shouldComplete(
                        taskCount: isEmpty ? 0 : store.routineTasks.count,
                        hasCompleted: hasCompletedFirstTaskExperience
                    )
                else {
                    return
                }
                hasCompletedFirstTaskExperience = true
            }
        )
    }

    private var taskListPresentationRefreshToken: HomeTaskListPresentationRefreshToken {
        HomeTaskListPresentationRefreshToken(
            isActive: isActive,
            displayRevision: store.taskListPresentationRevision,
            filters: store.taskFilters,
            taskListMode: store.taskListMode,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            searchText: searchTextBinding.wrappedValue,
            sectioningMode: routineListSectioningMode,
            flagRules: store.flagRules,
            referenceDay: calendar.startOfDay(for: Date())
        )
    }

    private func refreshTaskListPresentation() async {
        let request = HomeIOSPresentationSnapshotRequest(
            filteringConfiguration: taskListFilteringConfiguration(),
            taskListMode: store.taskListMode,
            routineDisplays: store.routineDisplays,
            awayRoutineDisplays: store.awayRoutineDisplays,
            archivedRoutineDisplays: store.archivedRoutineDisplays,
            hideUnavailableRoutines: store.hideUnavailableRoutines,
            showArchivedTasks: store.showArchivedTasks
        )

        let result: HomeIOSPresentationSnapshotResult?
        if request.requiresMainActorBuild {
            result = request.build()
        } else {
            let detachedRequest = request.preparedForDetachedBuild()
            let buildTask = Task.detached(priority: .userInitiated) {
                detachedRequest.build()
            }
            result = await withTaskCancellationHandler {
                await buildTask.value
            } onCancel: {
                buildTask.cancel()
            }
        }

        guard !Task.isCancelled, let result else { return }
        taskListPresentation = result.presentation
        searchTaskCreationText = result.searchTaskCreationText
        taskListPresentationRevision &+= 1
    }

    func refreshFileAttachmentTaskIDs() {
        do {
            let attachments = try modelContext.fetch(FetchDescriptor<RoutineAttachment>())
            store.send(.fileAttachmentTaskIDsChanged(Set(attachments.map(\.taskID))))
        } catch {
            assertionFailure("Unable to refresh Home attachment data: \(error)")
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
                description: Text("Choose a repeating or one-time task from the sidebar to see its schedule, logs, and actions.")
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

    var smartAddSeedText: String {
        searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var routineListSectioningMode: RoutineListSectioningMode {
        get {
            RoutineListSectioningMode.preferenceValue(rawValue: routineListSectioningModeRawValue)
        }
        nonmutating set {
            routineListSectioningModeRawValue = newValue.availableValue.rawValue
        }
    }

    var taskRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: taskRowHiddenFieldsRawValue)
    }

    var selectedTaskBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedTaskID },
            set: { store.send(.setSelectedTask($0)) }
        )
    }

    var timelineRangePicker: some View {
        platformTimelineRangePicker
    }

    var timelineTypePicker: some View {
        platformTimelineTypePicker
    }

    var overallDoneCountSummary: some View {
        HStack(spacing: 12) {
            Label("\(store.doneStats.totalCount) done", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Label("\(store.doneStats.canceledTotalCount) canceled", systemImage: "xmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Label("\(store.doneStats.missedTotalCount) missed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)

            Label("\(store.routineTasks.filter { !$0.isOneOffTask }.count) repeating", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Label(
                "\(store.routineTasks.filter { $0.isOneOffTask && !$0.isCompletedOneOff && !$0.isCanceledOneOff }.count) one-time",
                systemImage: "checkmark.circle"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    var tagFilterBar: some View {
        platformTagFilterBar
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

    func routineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int?) -> some View {
        platformRoutineRow(for: task, rowNumber: rowNumber)
    }

    @ViewBuilder
    func taskDetailDestination(taskID: UUID) -> some View {
        if store.selectedTaskID == taskID,
            let detailStore = self.store.scope(
                state: \.taskDetailState,
                action: \.taskDetail
            )
        {
            TaskDetailTCAView(store: detailStore)
        } else if store.routineTasks.contains(where: { $0.id == taskID }) {
            HomeLoadingStateView(
                title: "Opening Task",
                message: "Loading task details and recent activity.",
                systemImage: "checklist.checked",
                showsSkeleton: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                openTask(taskID)
            }
        } else {
            ContentUnavailableView(
                "Task not found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected task is no longer available.")
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

    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeStatusBadgeView(style: badgeStyle(for: task).map(HomeStatusBadgeStyle.init))
    }

    func taskTypeBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeTaskTypeBadgeView(taskType: task.scheduleMode.taskType)
    }

    @ViewBuilder
    func emptyStateView(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String = "Add Task",
        action: (() -> Void)? = nil
    ) -> some View {
        HomeEmptyStateView(
            title: title,
            message: message,
            systemImage: systemImage,
            actionTitle: actionTitle,
            action: action
        )
    }

    func inlineEmptyStateRow(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String = "Add Task",
        action: (() -> Void)? = nil
    ) -> some View {
        HomeInlineEmptyStateRowView(
            title: title,
            message: message,
            systemImage: systemImage,
            actionTitle: actionTitle,
            action: action
        )
    }

    func handleCompactHeaderScroll(oldOffset: CGFloat, newOffset: CGFloat) {
        let delta = newOffset - oldOffset

        if abs(delta) > 2 {
            collapseExpandedToolbarActions()
        }

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

    func collapseExpandedToolbarActions() {
        guard areTaskListModeActionsExpanded else { return }
        withAnimation(.snappy(duration: 0.2)) {
            areTaskListModeActionsExpanded = false
        }
    }
}

extension HomeFeature.TaskListMode {
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
