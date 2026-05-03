import ComposableArchitecture
import SwiftUI

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>
    let externalSearchText: Binding<String>?
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Environment(\.calendar) var calendar
    @AppStorage(
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue,
        store: SharedDefaults.app
    ) private var routineListSectioningModeRawValue: String = RoutineListSectioningMode.defaultValue.rawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) var showPersianDates = false
    @State private var localSearchText = ""
    @State var isCompactHeaderHidden = false
    @State var areTaskListModeActionsExpanded = false
    @State var areTopActionsExpanded = false
    @State var isQuickAddSheetPresented = false
    @State var isRefreshScheduled = false
    @State var relatedFilterTagSuggestionAnchor: String?

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
                .sheet(isPresented: $isQuickAddSheetPresented) {
                    QuickAddTaskSheet {
                        requestRefresh()
                    }
                }
        )
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

    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeStatusBadgeView(style: badgeStyle(for: task).map { HomeStatusBadgeStyle($0) })
    }

    func taskTypeBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeTaskTypeBadgeView(isTodo: task.isOneOffTask)
    }

    @ViewBuilder
    func emptyStateView(
        title: String,
        message: String,
        systemImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        HomeEmptyStateView(
            title: title,
            message: message,
            systemImage: systemImage,
            action: action
        )
    }

    func inlineEmptyStateRow(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        HomeInlineEmptyStateRowView(
            title: title,
            message: message,
            systemImage: systemImage
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
        guard areTaskListModeActionsExpanded || areTopActionsExpanded else { return }
        withAnimation(.snappy(duration: 0.2)) {
            areTaskListModeActionsExpanded = false
            areTopActionsExpanded = false
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
