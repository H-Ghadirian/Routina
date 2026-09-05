import ComposableArchitecture
import SwiftData
import SwiftUI

extension HomeTCAView {
    var fileAttachmentChangeToken: [String] {
        fileAttachments.map { "\($0.id.uuidString):\($0.taskID.uuidString)" }.sorted()
    }

    func syncFileAttachmentTaskIDs() {
        store.send(.fileAttachmentTaskIDsChanged(Set(fileAttachments.map(\.taskID))))
    }

    func validateMacEventEmotionFilterVisibility() {
        validateMacTimelineFilterVisibility()
    }

    func validateMacTimelineFilterVisibility() {
        let normalized = store.selectedTimelineFilterType.normalized(
            includingEventEmotion: areMacEventEmotionActionsEnabled,
            includingPlaces: isPlacesEnabled,
            includingNotes: isNotesEnabled,
            includingAway: isAwayEnabled,
            includingSleep: includesMacSleepTimelineFilters
        )
        if normalized != store.selectedTimelineFilterType {
            store.send(.selectedTimelineFilterTypeChanged(normalized))
        }
    }

    func openFocusTimerTarget(_ deepLink: RoutinaDeepLink?) {
        RoutinaMacWindowRouter.shared.openHomeAndActivate()

        guard let deepLink else { return }

        isRestoringMacNavigationHistory = true
        switch deepLink {
        case .task:
            macHomeDetailMode = .details
            taskDetailPanePlacement = nil
        case .sprint:
            macHomeDetailMode = MacHomeDetailMode.board.visibleSurfaceMode
            taskDetailPanePlacement = nil
        case .sleep:
            macHomeDetailMode = .planner
            taskDetailPanePlacement = nil
        case .goal, .note, .event:
            break
        }

        openActiveFocusTarget(deepLink)

        Task { @MainActor in
            await Task.yield()
            isRestoringMacNavigationHistory = false
            macNavigationHistory.replaceCurrent(macNavigationSnapshot)
        }
    }

    @ViewBuilder
    var detailContent: some View {
        if let detailStore = self.store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                onOpenEventDetails: openSavedEvent,
                onTagFilterSelected: { store.send(.taskDetailTagFilterTapped($0)) },
                sidebarLocation: macTaskSourceListSidebarLocation(detailStore.task.id),
                onLocateInSidebar: scrollSelectedTaskInMacSidebar
            )
        } else if let selectedNote {
            RoutineNoteDetailView(
                note: selectedNote,
                attachments: noteAttachments(for: selectedNote),
                onEdit: { openEditNote(selectedNote.id) },
                onDelete: { closeDeletedNote(selectedNote.id) }
            )
        } else {
            ContentUnavailableView(
                "Select a task",
                systemImage: "checklist",
                description: Text("Choose a repeating or one-time task from the sidebar to see its schedule, logs, and actions.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedNote: RoutineNote? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    var editingNote: RoutineNote? {
        guard let editingNoteID else { return nil }
        return notes.first { $0.id == editingNoteID }
    }

    func noteAttachments(for note: RoutineNote) -> [RoutineNoteAttachment] {
        noteAttachments
            .filter { $0.noteID == note.id }
            .sorted { $0.createdAt < $1.createdAt }
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
        get {
            settingsStore.appearance.routineListSectioningMode
        }
        nonmutating set {
            settingsStore.send(.routineListSectioningModeChanged(newValue))
        }
    }

    var taskRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: taskRowHiddenFieldsRawValue)
    }

    var timelineRowVisibility: HomeTimelineRowVisibility {
        HomeTimelineRowVisibility(storageRawValue: timelineRowHiddenFieldsRawValue)
    }

    var isMacSearchSidebarRevealActive: Bool {
        macSearchSidebarRevealSnapshot != nil
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
            Label("\(store.doneStats.totalCount) done", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Label("\(store.doneStats.canceledTotalCount) canceled", systemImage: "xmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Label("\(store.doneStats.missedTotalCount) missed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)

            Label("\(store.homeToolbarRoutineCount) repeating", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Label("\(store.homeToolbarTodoCount) one-time", systemImage: "checkmark.circle")
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

    func routineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        platformRoutineRow(for: task, rowNumber: rowNumber)
    }

    func routineRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>
    ) -> some View {
        platformRoutineRow(
            for: task,
            rowNumber: rowNumber,
            metadataPresenter: metadataPresenter
        )
    }

    @ViewBuilder
    func taskDetailDestination(taskID: UUID) -> some View {
        if store.selectedTaskID == taskID,
            let detailStore = self.store.scope(
                state: \.taskDetailState,
                action: \.taskDetail
            )
        {
            TaskDetailTCAView(
                store: detailStore,
                onOpenEventDetails: openSavedEvent,
                onTagFilterSelected: { store.send(.taskDetailTagFilterTapped($0)) },
                sidebarLocation: macTaskSourceListSidebarLocation(detailStore.task.id),
                onLocateInSidebar: scrollSelectedTaskInMacSidebar
            )
        } else if store.routineTasks.contains(where: { $0.id == taskID }) {
            HomeLoadingStateView(
                title: "Opening Task",
                message: "Loading task details and recent activity.",
                systemImage: "checklist",
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

    @ViewBuilder
    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        statusBadge(for: task, metadataPresenter: routineMetadataPresenter)
    }

    @ViewBuilder
    func statusBadge(
        for task: HomeFeature.RoutineDisplay,
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>
    ) -> some View {
        HomeStatusBadgeView(
            style: taskListStatusBadgeStyle(for: task, metadataPresenter: metadataPresenter)
        )
    }

    func taskListStatusBadgeStyle(
        for task: HomeFeature.RoutineDisplay,
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>
    ) -> HomeStatusBadgeStyle? {
        if store.taskListMode == .todos,
            task.isOneOffTask,
            !task.isCompletedOneOff,
            !task.isCanceledOneOff,
            !task.isInProgress,
            !task.hasActiveRelationshipBlocker,
            task.todoState != .blocked
        {
            return nil
        }

        return metadataPresenter.badgeStyle(for: task).map(HomeStatusBadgeStyle.init)
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
                .routinaIf(isSelected) { view in
                    view.routinaGlassPill(tint: .accentColor, tintOpacity: 0.16, interactive: true)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
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
