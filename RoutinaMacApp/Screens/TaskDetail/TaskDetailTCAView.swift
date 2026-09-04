import SwiftUI
import ComposableArchitecture
import SwiftData

struct TaskDetailSidebarLocation: Equatable {
    let titles: [String]

    var accessibilityValue: String {
        titles.joined(separator: ", ")
    }
}

struct TaskDetailDoneOccurrenceContext {
    let date: Date
    let occurrence: DayPlanDoneTaskOccurrence
}

struct TaskDetailTCAView: View {
    enum Presentation {
        case fullDetail
        case companionPane

        var showsEditingEntryPoints: Bool {
            self == .fullDetail
        }
    }

    let store: StoreOf<TaskDetailFeature>
    var showsPrincipalToolbarTitle = true
    let allowsTitlePlannerDrag: Bool
    let presentation: Presentation
    let onExpandCompanion: (() -> Void)?
    let onCloseCompanion: (() -> Void)?
    let onMinimizeFullscreen: (() -> Void)?
    let onCloseFullscreen: (() -> Void)?
    let externalBlockingFocusTitle: String?
    let onOpenEventDetails: ((UUID) -> Void)?
    let onTagFilterSelected: ((String) -> Void)?
    let sidebarLocation: TaskDetailSidebarLocation?
    let onLocateInSidebar: (() -> Void)?
    let doneOccurrenceContext: TaskDetailDoneOccurrenceContext?
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \FocusSession.startedAt, order: .reverse) var focusSessions: [FocusSession]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) var events: [RoutineEvent]
    @State var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State var isShowingAllLogs = false
    @State var isRoutineLogsExpanded = false
    @State var isCommentComposerVisible = false
    @State var isTimeControlRevealed = false
    @State var isTodoStateControlRevealed = false
    @State var isChecklistSectionRevealed = false
    @State var inlineEditSections: [FormSection] = []
    @State var isTimeSectionExpanded = false
    @State var timeEditing = TaskDetailTimeEditingState()
    @State var taskTimeEntryHours = 0
    @State var taskTimeEntryMinutes = 25
    @State var taskTimeEntryResetToken = 0
    @State var isEditEmojiPickerPresented = false
    @State var attachmentTempURL: URL?
    @State var fileToSave: AttachmentItem?
    @State var isRelationshipGraphPresented = false
    @State var isExistingTaskLinkerPresented = false
    @State var selectedLinkedEventPresentation: TaskDetailLinkedEventPresentation?
    @State var isCalendarExpanded = false
    @State var referenceDate = Date()
    @State var activeBlockingTask: RoutineTask?
    @State var sprintBlockingFocusTitle: String?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) var showPersianDates = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingTaskSharingEnabled.rawValue,
        store: SharedDefaults.app
    ) var isTaskSharingEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingTaskRelationshipVisualizerEnabled.rawValue,
        store: SharedDefaults.app
    ) var isTaskRelationshipVisualizerEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) var areMacEventEmotionActionsEnabled = false
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll

    init(
        store: StoreOf<TaskDetailFeature>,
        showsPrincipalToolbarTitle: Bool = true,
        allowsTitlePlannerDrag: Bool = false,
        presentation: Presentation = .fullDetail,
        onExpandCompanion: (() -> Void)? = nil,
        onCloseCompanion: (() -> Void)? = nil,
        onMinimizeFullscreen: (() -> Void)? = nil,
        onCloseFullscreen: (() -> Void)? = nil,
        blockingFocusTitle: String? = nil,
        onOpenEventDetails: ((UUID) -> Void)? = nil,
        onTagFilterSelected: ((String) -> Void)? = nil,
        sidebarLocation: TaskDetailSidebarLocation? = nil,
        onLocateInSidebar: (() -> Void)? = nil,
        doneOccurrenceContext: TaskDetailDoneOccurrenceContext? = nil
    ) {
        self.store = store
        self.showsPrincipalToolbarTitle = showsPrincipalToolbarTitle
        self.allowsTitlePlannerDrag = allowsTitlePlannerDrag
        self.presentation = presentation
        self.onExpandCompanion = onExpandCompanion
        self.onCloseCompanion = onCloseCompanion
        self.onMinimizeFullscreen = onMinimizeFullscreen
        self.onCloseFullscreen = onCloseFullscreen
        self.externalBlockingFocusTitle = blockingFocusTitle
        self.onOpenEventDetails = onOpenEventDetails
        self.onTagFilterSelected = onTagFilterSelected
        self.sidebarLocation = sidebarLocation
        self.onLocateInSidebar = onLocateInSidebar
        self.doneOccurrenceContext = doneOccurrenceContext

        let taskID = store.task.id
        _focusSessions = Query(
            filter: #Predicate<FocusSession> { session in
                session.taskID == taskID
                    || (session.completedAt == nil && session.abandonedAt == nil)
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    var body: some View {
        detailBody
            .routinaInlineTitleDisplayMode()
            .toolbar {
                TaskDetailToolbarContent(
                    store: store,
                    showsPrincipalToolbarTitle: showsPrincipalToolbarTitle,
                    isInlineEditPresented: isInlineEditPresented
                )
            }
            .routinaPlatformEditPresentation(
                isPresented: presentationRouting.editSheet,
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions,
                canSaveCurrentEdit: canSaveCurrentEdit
            )
            .sheet(isPresented: $isEditEmojiPickerPresented) {
                EmojiPickerSheet(
                    selectedEmoji: presentationRouting.editRoutineEmoji,
                    emojis: allEmojiOptions
                )
            }
            .sheet(isPresented: $isRelationshipGraphPresented) {
                TaskRelationshipGraphSheet(
                    centerTask: store.task,
                    relationships: store.resolvedRelationships,
                    statusColor: TaskDetailPresentation.statusColor(for:),
                    onSelectTask: { taskID in
                        isRelationshipGraphPresented = false
                        store.send(.openLinkedTask(taskID))
                    }
                )
            }
            .sheet(isPresented: $isExistingTaskLinkerPresented) {
                existingTaskLinkerSheet
            }
            .sheet(item: $selectedLinkedEventPresentation) { presentation in
                linkedEventDetailSheet(eventID: presentation.id)
            }
            .sheet(item: $timeEditing.editingLog) { log in
                TaskDetailLogTimeSpentSheet(
                    minutes: $timeEditing.editingMinutes,
                    title: "Time Spent",
                    message: "Record the actual time for this completion.",
                    showsClearButton: log.actualDurationMinutes != nil,
                    onClear: {
                        store.send(.updateLogDuration(log.id, nil))
                        timeEditing.dismissLog()
                    },
                    onCancel: {
                        timeEditing.dismissLog()
                    },
                    onSave: {
                        store.send(.updateLogDuration(log.id, timeEditing.editingMinutes))
                        timeEditing.dismissLog()
                    }
                )
            }
            .sheet(isPresented: $timeEditing.isEditingTaskTimeSpent) {
                TaskDetailLogTimeSpentSheet(
                    minutes: $timeEditing.editingMinutes,
                    title: "Actual Time Spent",
                    message: "Set the total actual time for this task.",
                    showsClearButton: store.task.actualDurationMinutes != nil,
                    onClear: {
                        store.send(.updateTaskDuration(nil))
                        timeEditing.dismissTask()
                    },
                    onCancel: {
                        timeEditing.dismissTask()
                    },
                    onSave: {
                        store.send(.updateTaskDuration(timeEditing.editingMinutes))
                        timeEditing.dismissTask()
                    }
                )
            }
            .task {
                await refreshFocusBlockingContext()
            }
            .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
                Task {
                    await refreshFocusBlockingContext()
                }
            }
            .taskDetailDeleteConfirmationAlert(store: store)
            .taskDetailUndoCompletionConfirmationAlert(store: store, mode: .undoOnly)
            .taskDetailManualCompletionConfirmationDialog(store: store)
            .onAppear {
                referenceDate = Date()
                displayedMonthStart = Calendar.current.startOfMonth(for: store.resolvedSelectedDate)
                syncAvailableEvents()
                collapseDefaultSections()
            }
            .onChange(of: availableEventCandidates) { _, _ in
                syncAvailableEvents()
            }
            .onChange(of: areMacEventEmotionActionsEnabled) { _, isEnabled in
                guard !isEnabled else { return }
                selectedLinkedEventPresentation = nil
                inlineEditSections.removeAll { $0 == .events }
            }
            .onChange(of: isGoalsTabEnabled) { _, isEnabled in
                guard !isEnabled else { return }
                inlineEditSections.removeAll { $0 == .goals }
            }
            .onChange(of: store.task.id) { _, _ in
                referenceDate = Date()
                activeBlockingTask = nil
                isCommentComposerVisible = false
                isExistingTaskLinkerPresented = false
                resetRevealedOptionalControls()
                syncAvailableEvents()
                Task {
                    await refreshFocusBlockingContext()
                }
                collapseDefaultSections()
                displayedMonthStart = Calendar.current.startOfMonth(for: store.resolvedSelectedDate)
            }
            .onChange(of: store.shouldDismissAfterDelete) { _, shouldDismiss in
                guard shouldDismiss else { return }
                dismiss()
                store.send(.deleteDismissHandled)
            }
            .onChange(of: store.resolvedSelectedDate) { _, newValue in
                displayedMonthStart = Calendar.current.startOfMonth(for: newValue)
            }
            .onChange(of: store.task.actualDurationMinutes) { _, _ in
                isTimeControlRevealed = false
            }
            .onChange(of: store.task.todoStateRawValue) { _, newValue in
                if newValue != nil {
                    isTodoStateControlRevealed = false
                }
            }
            .routinaAttachmentShareSheet(url: $attachmentTempURL)
            .fileExporter(
                isPresented: TaskDetailAttachmentExportPresentation.isPresentedBinding(fileToSave: $fileToSave),
                document: fileToSave.map { RoutineAttachmentFileDocument(data: $0.data) },
                contentType: .data,
                defaultFilename: fileToSave?.fileName
            ) { _ in
                fileToSave = nil
            }
    }

    @ViewBuilder
    var detailBody: some View {
        if isInlineEditPresented {
            TaskDetailEditRoutineContent(
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions,
                canSaveCurrentEdit: canSaveCurrentEdit,
                automaticPathTitles: editAutomaticPathTitles,
                focusSessionCount: focusSessionCountForTask
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if store.task.isOneOffTask {
            todoDetailContent
                .background { taskColorBackground }
        } else {
            taskDetailContent
                .background { taskColorBackground }
        }
    }

    @ViewBuilder
    var taskColorBackground: some View {
        if let color = store.task.color.swiftUIColor {
            color.opacity(0.07).ignoresSafeArea()
        }
    }

}
