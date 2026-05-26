import ComposableArchitecture
import SwiftData
import SwiftUI

enum MacHomeDetailMode: String, CaseIterable, Identifiable {
    case details = "Details"
    case planner = "Planner"
    case board = "Board"
    case places = "Places"

    var id: Self { self }
}

struct MacSidebarTaskScrollRequest: Equatable {
    enum Anchor: Equatable {
        case center
        case minimalReveal
    }

    let taskID: UUID
    let anchor: Anchor
    private let token = UUID()

    init(taskID: UUID, anchor: Anchor = .center) {
        self.taskID = taskID
        self.anchor = anchor
    }
}

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let goalsStore: StoreOf<GoalsFeature>
    let statsStore: StoreOf<StatsFeature>?
    @State var addEditFormCoordinator = AddEditFormCoordinator()
    let externalSearchText: Binding<String>?
    @Environment(\.calendar) var calendar
    @Environment(\.modelContext) var modelContext
    @AppStorage(
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue,
        store: SharedDefaults.app
    ) private var routineListSectioningModeRawValue: String = RoutineListSectioningMode.defaultValue.rawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) var showPersianDates = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var taskRowHiddenFieldsRawValue = ""
    @AppStorage("macTodoBoardCompactCards", store: SharedDefaults.app)
    var isMacTodoBoardCompactCards = false
    @AppStorage("macBoardTicketInspectorPresented", store: SharedDefaults.app)
    var isMacBoardTicketInspectorPresented = true
    @AppStorage(
        UserDefaultBoolValueKey.appSettingDailyRoutinesSectionCollapsed.rawValue,
        store: SharedDefaults.app
    ) var isDailyRoutinesSectionCollapsed = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingArchivedRoutinesSectionCollapsed.rawValue,
        store: SharedDefaults.app
    ) var isArchivedSectionCollapsed = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingCollapsedTagTaskListSections.rawValue,
        store: SharedDefaults.app
    ) var collapsedTagTaskListSectionIDsStorage = ""
    @State private var localSearchText = ""
    @State var isCompactHeaderHidden = false
    @State var isQuickAddSheetPresented = false
    @State var isEmotionLogEditorPresented = false
    @State var isNoteEditorPresented = false
    @State var selectedNoteID: UUID?
    @State var isRefreshScheduled = false
    @State var relatedFilterTagSuggestionAnchor: String?
    @State var relatedTimelineTagSuggestionAnchor: String?
    @State var relatedStatsTagSuggestionAnchor: String?
    @State var draggedSection: FormSection?
    @State var macHomeDetailMode: MacHomeDetailMode = .details
    @State var macNavigationHistory = HomeMacNavigationHistory()
    @State var isRestoringMacNavigationHistory = false
    @StateObject var dayPlanPlanner = DayPlanPlannerState()
    @State var dayPlanUnplannedCompletedFilterDate: Date?
    @State var macSidebarTaskScrollRequest: MacSidebarTaskScrollRequest?
    @State var isFinishedSprintsExpanded = false
    @State var placeCheckInMapActivity: PlaceCheckInActivity?
    @State var placeCheckInSelectedPlaceID: UUID?
    @State var placeCheckInSelectedHistoryMarkerID: PlaceCheckInHistoryMapMarker.ID?
    @FocusState var isSprintCreationFieldFocused: Bool
    @FocusState var isBacklogCreationFieldFocused: Bool
    @FocusState var isSprintRenameFieldFocused: Bool
    @FocusState var isMacTaskSourceListFocused: Bool
    @Query(sort: \FocusSession.startedAt, order: .reverse) var focusSessions: [FocusSession]
    @Query(sort: \SleepSession.startedAt, order: .reverse) var sleepSessions: [SleepSession]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) var placeCheckInSessions: [PlaceCheckInSession]
    @Query private var fileAttachments: [RoutineAttachment]
    @Query(sort: \EmotionLog.createdAt, order: .reverse) var emotionLogs: [EmotionLog]
    @Query(sort: \RoutineNote.createdAt, order: .reverse) var notes: [RoutineNote]
    @Query var noteAttachments: [RoutineNoteAttachment]

    init(
        store: StoreOf<HomeFeature>,
        settingsStore: StoreOf<SettingsFeature>,
        goalsStore: StoreOf<GoalsFeature>,
        statsStore: StoreOf<StatsFeature>? = nil,
        searchText: Binding<String>? = nil
    ) {
        self.store = store
        self.settingsStore = settingsStore
        self.goalsStore = goalsStore
        self.statsStore = statsStore
        self.externalSearchText = searchText
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
                .task {
                    syncFileAttachmentTaskIDs()
                }
                .onChange(of: fileAttachmentChangeToken) { _, _ in
                    syncFileAttachmentTaskIDs()
                }
        )
    }

    private var fileAttachmentChangeToken: [String] {
        fileAttachments.map { "\($0.id.uuidString):\($0.taskID.uuidString)" }.sorted()
    }

    private func syncFileAttachmentTaskIDs() {
        store.send(.fileAttachmentTaskIDsChanged(Set(fileAttachments.map(\.taskID))))
    }

    @ViewBuilder
    var detailContent: some View {
        if let detailStore = self.store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(store: detailStore)
        } else if let selectedNote {
            RoutineNoteDetailView(
                note: selectedNote,
                attachments: noteAttachments(for: selectedNote)
            )
        } else {
            ContentUnavailableView(
                "Select a task",
                systemImage: "checklist",
                description: Text("Choose a routine or to-do from the sidebar to see its schedule, logs, and actions.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedNote: RoutineNote? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    private func noteAttachments(for note: RoutineNote) -> [RoutineNoteAttachment] {
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
            RoutineListSectioningMode(rawValue: routineListSectioningModeRawValue) ?? .defaultValue
        }
        nonmutating set {
            routineListSectioningModeRawValue = newValue.rawValue
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

    @ViewBuilder
    func taskDetailDestination(taskID: UUID) -> some View {
        if store.selectedTaskID == taskID,
           let detailStore = self.store.scope(
               state: \.taskDetailState,
               action: \.taskDetail
        ) {
            TaskDetailTCAView(store: detailStore)
        } else if store.routineTasks.contains(where: { $0.id == taskID }) {
            HomeLoadingStateView(
                title: "Opening Routine",
                message: "Loading routine details and recent activity.",
                systemImage: "checklist",
                showsSkeleton: false
            )
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

    @ViewBuilder
    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        if store.taskListMode == .todos,
           task.isOneOffTask,
           !task.isCompletedOneOff,
           !task.isCanceledOneOff,
           !task.isInProgress {
            EmptyView()
        } else {
            HomeStatusBadgeView(style: HomeStatusBadgeStyle(badgeStyle(for: task)))
        }
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
