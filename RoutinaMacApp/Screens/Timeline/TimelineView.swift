import ComposableArchitecture
import SwiftData
import SwiftUI

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>
    @Environment(\.calendar) var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var dataSnapshot = TimelineDataSnapshot()
    @State private var hasDeferredDataSnapshotRefresh = false
    @State private var deferredDataSnapshotRefreshTask: Task<Void, Never>?
    @State var relatedFilterTagSuggestionAnchor: String?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacTimelineQuickFiltersVisible.rawValue,
        store: SharedDefaults.app
    ) var areMacTimelineQuickFiltersVisible = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTimelineRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) var timelineRowHiddenFieldsRawValue = ""
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) var areMacEventEmotionActionsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsSleepTabEnabled.rawValue,
        store: SharedDefaults.app
    ) var isStatsSleepTabEnabled = false
    @State var editingAwaySession: AwaySession?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("")
                .routinaTimelineNavigationTitleDisplayMode()
                .toolbar {
                    RoutinaMacFocusTimerToolbarItem()

                    ToolbarItem(placement: .primaryAction) {
                        filterSheetButton
                    }
                }
                .navigationDestination(for: UUID.self) { taskID in
                    timelineDetailDestination(taskID: taskID)
                }
                .sheet(isPresented: filterSheetBinding) {
                    timelineFiltersSheet
                }
                .sheet(item: deepLinkedNotePresentationBinding) { presentation in
                    NavigationStack {
                        deepLinkedNoteDetail(noteID: presentation.id)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        store.send(.noteDeepLinkPresentationDismissed(presentation.id))
                                    }
                                }
                            }
                            .frame(minWidth: 560, minHeight: 420)
                    }
                }
                .sheet(item: $editingAwaySession) { session in
                    AwaySessionEditSheet(session: session)
                        .id(session.id)
                        .frame(minWidth: 460, minHeight: 440)
                }
        }
        .task {
            refreshTimelineDataSnapshot()
            validateEventEmotionFilterVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            requestTimelineDataSnapshotRefresh()
        }
        .onChange(of: isPlacesEnabled) { _, _ in
            syncTimelineData()
            validateTimelineFilterVisibility()
        }
        .onChange(of: isNotesEnabled) { _, _ in
            syncTimelineData()
            validateTimelineFilterVisibility()
            guard !isNotesEnabled, let noteID = store.deepLinkedNoteID else { return }
            store.send(.noteDeepLinkPresentationDismissed(noteID))
        }
        .onChange(of: isAwayEnabled) { _, _ in
            syncTimelineData()
            validateTimelineFilterVisibility()
            if !isAwayEnabled {
                editingAwaySession = nil
            }
        }
        .onChange(of: areMacEventEmotionActionsEnabled) { _, _ in
            syncTimelineData()
            validateTimelineFilterVisibility()
        }
        .onChange(of: isStatsSleepTabEnabled) { _, _ in
            syncTimelineData()
            validateTimelineFilterVisibility()
        }
        .onChange(of: store.filterType) { _, _ in
            validateTimelineFilterVisibility()
        }
        .onDisappear {
            deferredDataSnapshotRefreshTask?.cancel()
            deferredDataSnapshotRefreshTask = nil
        }
    }

    private var fileAttachmentTaskIDs: Set<UUID> {
        Set(fileAttachments.map(\.taskID))
    }

    private var tasks: [RoutineTask] { dataSnapshot.tasks }
    private var logs: [RoutineLog] { dataSnapshot.logs }
    private var fileAttachments: [RoutineAttachment] { dataSnapshot.fileAttachments }
    var events: [RoutineEvent] {
        areMacEventEmotionActionsEnabled ? dataSnapshot.events : []
    }
    var emotionLogs: [EmotionLog] {
        areMacEventEmotionActionsEnabled ? dataSnapshot.emotionLogs : []
    }
    var notes: [RoutineNote] { dataSnapshot.notes }
    var noteAttachments: [RoutineNoteAttachment] { dataSnapshot.noteAttachments }
    private var focusSessions: [FocusSession] { dataSnapshot.focusSessions }
    private var sprintFocusSessions: [SprintFocusSessionRecord] { dataSnapshot.sprintFocusSessions }
    private var focusSessionEvents: [FocusSessionActionEvent] { dataSnapshot.focusSessionEvents }
    private var boardSprints: [BoardSprintRecord] { dataSnapshot.boardSprints }
    private var sleepSessions: [SleepSession] {
        includesSleepTimelineFilters ? dataSnapshot.sleepSessions : []
    }
    var awaySessions: [AwaySession] { dataSnapshot.awaySessions }
    var placeCheckInSessions: [PlaceCheckInSession] { dataSnapshot.placeCheckInSessions }

    private var noteAttachmentNoteIDs: Set<UUID> {
        Set(noteAttachments.map(\.noteID))
    }

    private var deepLinkedNotePresentationBinding: Binding<TimelineNoteDeepLinkPresentation?> {
        Binding(
            get: {
                guard isNotesEnabled, let noteID = store.deepLinkedNoteID else { return nil }
                return TimelineNoteDeepLinkPresentation(id: noteID)
            },
            set: { presentation in
                if presentation == nil, let noteID = store.deepLinkedNoteID {
                    store.send(.noteDeepLinkPresentationDismissed(noteID))
                }
            }
        )
    }

    private func syncTimelineData() {
        store.send(
            .setData(
                tasks: tasks,
                logs: logs,
                events: events,
                emotionLogs: emotionLogs,
                notes: isNotesEnabled ? notes : [],
                focusSessions: focusSessions,
                sprintFocusSessions: sprintFocusSessions,
                focusSessionEvents: focusSessionEvents,
                boardSprints: boardSprints,
                sleepSessions: sleepSessions,
                placeCheckInSessions: isPlacesEnabled ? placeCheckInSessions : [],
                awaySessions: isAwayEnabled ? awaySessions : [],
                fileAttachmentTaskIDs: fileAttachmentTaskIDs,
                noteAttachmentNoteIDs: isNotesEnabled ? noteAttachmentNoteIDs : []
            ))
    }

    private func requestTimelineDataSnapshotRefresh() {
        guard !RoutinaMacScrollInteractionGate.isScrollActive else {
            hasDeferredDataSnapshotRefresh = true
            scheduleDeferredTimelineDataSnapshotRefresh()
            return
        }
        refreshTimelineDataSnapshot()
    }

    private func scheduleDeferredTimelineDataSnapshotRefresh() {
        guard deferredDataSnapshotRefreshTask == nil else { return }
        deferredDataSnapshotRefreshTask = Task { @MainActor in
            try? await Task.sleep(
                for: .milliseconds(RoutinaMacScrollInteractionGate.quietRetryDelayMilliseconds)
            )
            guard !Task.isCancelled else { return }
            deferredDataSnapshotRefreshTask = nil
            guard hasDeferredDataSnapshotRefresh else { return }
            requestTimelineDataSnapshotRefresh()
        }
    }

    private func refreshTimelineDataSnapshot() {
        do {
            dataSnapshot = try TimelineDataSnapshot.fetch(from: modelContext)
            hasDeferredDataSnapshotRefresh = false
            deferredDataSnapshotRefreshTask?.cancel()
            deferredDataSnapshotRefreshTask = nil
            syncTimelineData()
        } catch {
            assertionFailure("Unable to refresh Timeline data: \(error)")
        }
    }

    var hasActiveFilters: Bool {
        store.selectedRange != .all
            || effectiveFilterType != .all
            || !store.effectiveSelectedTags.isEmpty
            || !store.excludedTags.isEmpty
            || store.selectedImportanceUrgencyFilter != nil
            || store.mediaFilter != .all
    }

    var effectiveFilterType: TimelineFilterType {
        store.filterType.normalized(
            includingEventEmotion: areMacEventEmotionActionsEnabled,
            includingPlaces: isPlacesEnabled,
            includingNotes: isNotesEnabled,
            includingAway: isAwayEnabled,
            includingSleep: includesSleepTimelineFilters
        )
    }

    var includesSleepTimelineFilters: Bool {
        isAwayEnabled && isStatsSleepTabEnabled
    }

    private var hasAnyTimelineRecords: Bool {
        !logs.isEmpty
            || tasks.contains { $0.lastDone != nil }
            || !events.isEmpty
            || !emotionLogs.isEmpty
            || (isNotesEnabled && !notes.isEmpty)
            || !focusSessions.isEmpty
            || !sprintFocusSessions.isEmpty
            || (includesSleepTimelineFilters && !sleepSessions.isEmpty)
            || (isAwayEnabled && !awaySessions.isEmpty)
            || (isPlacesEnabled && !placeCheckInSessions.isEmpty)
    }

    private var timelineEmptyDescription: String {
        var items = ["Completed items", "focus sessions"]
        if isNotesEnabled {
            items.append("notes")
        }
        if isPlacesEnabled {
            items.append("place check-ins")
        }
        items.append("emotions")
        if isAwayEnabled {
            items.append("away sessions")
        }
        items.append("sleep records")
        return "\(items.joined(separator: ", ")) will appear here newest first."
    }

    var showsTypeFilterSection: Bool {
        tasks.contains(where: { $0.isOneOffTask })
            || (areMacEventEmotionActionsEnabled && (!events.isEmpty || !emotionLogs.isEmpty))
            || (isNotesEnabled && !notes.isEmpty)
            || !focusSessions.isEmpty
            || !sprintFocusSessions.isEmpty
            || (includesSleepTimelineFilters && !sleepSessions.isEmpty)
            || (isAwayEnabled && !awaySessions.isEmpty)
            || (isPlacesEnabled && !placeCheckInSessions.isEmpty)
    }

    private func validateEventEmotionFilterVisibility() {
        validateTimelineFilterVisibility()
    }

    private func validateTimelineFilterVisibility() {
        let normalized = store.filterType.normalized(
            includingEventEmotion: areMacEventEmotionActionsEnabled,
            includingPlaces: isPlacesEnabled,
            includingNotes: isNotesEnabled,
            includingAway: isAwayEnabled,
            includingSleep: includesSleepTimelineFilters
        )
        if normalized != store.filterType {
            store.send(.filterTypeChanged(normalized))
        }
    }

    private var timelinePigmentControl: some View {
        TimelinePigmentControl(
            selection: filterTypeBinding,
            includesEventEmotion: areMacEventEmotionActionsEnabled,
            includesPlaces: isPlacesEnabled,
            includesNotes: isNotesEnabled,
            includesAway: isAwayEnabled,
            includesSleep: includesSleepTimelineFilters
        )
    }

    @ViewBuilder
    private var content: some View {
        if !hasAnyTimelineRecords {
            ContentUnavailableView(
                "No timeline entries yet",
                systemImage: "clock.arrow.circlepath",
                description: Text(timelineEmptyDescription)
            )
        } else {
            VStack(spacing: 0) {
                if areMacTimelineQuickFiltersVisible {
                    timelinePigmentControl
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }

                if groupedByDay.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different time range or filter.")
                    )
                } else {
                    timelineList
                }
            }
        }
    }

    private var timelineList: some View {
        List {
            ForEach(groupedByDay, id: \.date) { section in
                Section {
                    ForEach(section.entries) { entry in
                        timelineRow(entry)
                            .id(entry.id)
                    }
                } header: {
                    Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func deepLinkedNoteDetail(noteID: UUID) -> some View {
        if let note = notes.first(where: { $0.id == noteID }) {
            RoutineNoteDetailView(
                note: note,
                attachments: noteAttachments(for: note),
                onDelete: { store.send(.noteDeepLinkPresentationDismissed(noteID)) }
            )
        } else {
            ContentUnavailableView(
                "Note not found",
                systemImage: "note.text",
                description: Text("The selected note is no longer available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func timelineDetailDestination(taskID: UUID) -> some View {
        if let task = tasks.first(where: { $0.id == taskID }) {
            TaskDetailTCAView(
                store: Store(
                    initialState: makeTaskDetailState(for: task)
                ) {
                    TaskDetailFeature()
                }
            )
        } else {
            ContentUnavailableView(
                "Task not found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected task is no longer available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func makeTaskDetailState(for task: RoutineTask) -> TaskDetailFeature.State {
        let detailTask = task.detachedCopy()
        let now = Date()
        let defaultSelectedDate =
            (detailTask.isCompletedOneOff || detailTask.isCanceledOneOff)
            ? calendar.startOfDay(for: detailTask.lastDone ?? detailTask.canceledAt ?? now)
            : calendar.startOfDay(for: now)

        var state = TaskDetailFeature.State(
            task: detailTask,
            logs: [],
            selectedDate: defaultSelectedDate,
            daysSinceLastRoutine: RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailTask.lastDone,
                referenceDate: now
            ),
            overdueDays: detailTask.isArchived()
                ? 0
                : RoutineDateMath.overdueDays(for: detailTask, referenceDate: now, calendar: calendar),
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        )
        state.refreshChecklistItemsCache()
        return state
    }

}

private struct TimelineNoteDeepLinkPresentation: Identifiable, Equatable {
    let id: UUID
}
