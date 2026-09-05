import SwiftUI

extension HomeTCAView {
    var timelineEntries: [TimelineEntry] {
        macTimelinePresentation.filteredEntries
    }

    var timelineSourceTasks: [RoutineTask] {
        HomeTaskSupport.timelineTasksIncludingSelectedDetail(
            tasks: store.routineTasks,
            detailTask: store.taskDetailState?.task
        )
    }

    var timelineSourceLogs: [RoutineLog] {
        HomeTaskSupport.timelineLogsIncludingSelectedDetailFallback(
            timelineLogs: store.timelineLogs,
            detailTask: store.taskDetailState?.task,
            detailLogs: store.taskDetailState?.logs,
            calendar: calendar
        )
    }

    private var baseTimelineEntries: [TimelineEntry] {
        macTimelinePresentation.baseEntries
    }

    private var macTimelinePresentation: HomeMacTimelinePresentation {
        let signature = HomeMacTimelinePresentationSignature(
            dataRevision: store.routineDisplaysRevision,
            filterType: effectiveMacTimelineFilterType,
            statusFilter: store.selectedTimelineStatusFilter,
            mediaFilter: store.selectedTimelineMediaFilter,
            selectedTags: store.selectedTimelineTags,
            includeTagMatchMode: store.selectedTimelineIncludeTagMatchMode,
            selectedFlags: macSharedSelectedFlags,
            includeFlagMatchMode: macSharedIncludeFlagMatchMode,
            excludedFlags: macSharedExcludedFlags,
            excludeFlagMatchMode: macSharedExcludeFlagMatchMode,
            excludedTags: store.selectedTimelineExcludedTags,
            excludeTagMatchMode: store.selectedTimelineExcludeTagMatchMode,
            importanceUrgencyFilter: store.selectedTimelineImportanceUrgencyFilter,
            pressureFilter: store.selectedTimelinePressureFilter,
            thinkingNeededFilter: store.selectedTimelineThinkingNeededFilter,
            estimationFilter: store.selectedTimelineEstimationFilter,
            taskLadderReferenceDay: calendar.startOfDay(for: Date()),
            searchText: macSearchPresentationText.trimmingCharacters(in: .whitespacesAndNewlines),
            showsEventsAndEmotions: areMacEventEmotionActionsEnabled,
            showsPlaces: isPlacesEnabled,
            showsNotes: isNotesEnabled,
            showsAway: isAwayEnabled,
            showsSleep: includesMacSleepTimelineFilters,
            flagRules: store.flagRules,
            fileAttachmentTaskIDs: store.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: isNotesEnabled ? noteAttachmentNoteIDs : [],
            focusActionLogCount: focusSessionActionLogs.count,
            latestFocusActionLogTimestamp: focusSessionActionLogs.first?.timestamp,
            calendarIdentifier: calendar.identifier,
            calendarTimeZoneIdentifier: calendar.timeZone.identifier,
            calendarFirstWeekday: calendar.firstWeekday,
            calendarMinimumDaysInFirstWeek: calendar.minimumDaysInFirstWeek
        )

        return macTimelinePresentationCache.presentation(for: signature) {
            buildMacTimelinePresentation()
        }
    }

    var macTimelineRowNumbersByEntryID: [UUID: Int] {
        macTimelinePresentation.rowNumbersByEntryID
    }

    private func buildMacTimelinePresentation() -> HomeMacTimelinePresentation {
        let tasks = timelineSourceTasks
        let logs = timelineSourceLogs
        let now = Date()
        let visibleNotes = isNotesEnabled ? notes : []
        let visiblePlaces = isPlacesEnabled ? placeCheckInSessions : []
        let visibleAwaySessions = isAwayEnabled ? awaySessions : []
        let visibleSleepSessions = includesMacSleepTimelineFilters ? sleepSessions : []
        let visibleEvents = areMacEventEmotionActionsEnabled ? events : []
        let visibleEmotionLogs = areMacEventEmotionActionsEnabled ? emotionLogs : []
        let visibleNoteAttachmentIDs = isNotesEnabled ? noteAttachmentNoteIDs : []
        let focusSessionEvents = FocusSessionActionEvent.events(from: focusSessionActionLogs)

        let unfilteredBaseEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            events: visibleEvents,
            emotionLogs: visibleEmotionLogs,
            notes: visibleNotes,
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            focusSessionEvents: focusSessionEvents,
            boardSprints: boardSprints,
            sleepSessions: visibleSleepSessions,
            placeCheckInSessions: visiblePlaces,
            awaySessions: visibleAwaySessions,
            fileAttachmentTaskIDs: store.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: visibleNoteAttachmentIDs,
            range: .all,
            filterType: effectiveMacTimelineFilterType,
            statusFilter: store.selectedTimelineStatusFilter,
            mediaFilter: store.selectedTimelineMediaFilter,
            now: now,
            calendar: calendar
        )
        let availableFlags = TimelineLogic.availableFlags(from: unfilteredBaseEntries)
        let selectedFlags = macSharedSelectedFlags.filter {
            RoutineFlag.contains($0, in: availableFlags)
        }
        let excludedFlags = macSharedExcludedFlags.filter {
            RoutineFlag.contains($0, in: availableFlags)
        }
        let baseEntries = TimelineLogic.entriesVisibleForFlags(
            unfilteredBaseEntries,
            selectedFlags: selectedFlags,
            includeFlagMatchMode: macSharedIncludeFlagMatchMode,
            excludedFlags: excludedFlags,
            excludeFlagMatchMode: macSharedExcludeFlagMatchMode,
            rules: store.flagRules
        )
        let filteredEntries =
            baseEntries
            .filter { entry in
                matchesMacSharedTaskLadderFilters(entry)
                    && HomeFeature.matchesSelectedTags(
                        store.selectedTimelineTags,
                        mode: store.selectedTimelineIncludeTagMatchMode,
                        in: entry.tags
                    )
                    && HomeFeature.matchesExcludedTags(
                        store.selectedTimelineExcludedTags,
                        mode: store.selectedTimelineExcludeTagMatchMode,
                        in: entry.tags
                    )
            }
            .filter(matchesTimelineSearch)
        let allUnfilteredEntries = TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            events: visibleEvents,
            emotionLogs: visibleEmotionLogs,
            notes: visibleNotes,
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            focusSessionEvents: focusSessionEvents,
            boardSprints: boardSprints,
            sleepSessions: visibleSleepSessions,
            placeCheckInSessions: visiblePlaces,
            awaySessions: visibleAwaySessions,
            fileAttachmentTaskIDs: store.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: visibleNoteAttachmentIDs,
            range: .all,
            filterType: .all,
            mediaFilter: .all,
            now: now,
            calendar: calendar
        )
        let unfilteredEntries = TimelineLogic.entriesVisibleForFlags(
            allUnfilteredEntries,
            selectedFlags: [],
            includeFlagMatchMode: .all,
            rules: store.flagRules
        )

        let groupedFilteredEntries = TimelineLogic.groupedByDay(
            entries: filteredEntries,
            calendar: calendar
        )
        let rowNumbersByEntryID = TimelineLogic.rowNumbersByEntryID(
            groupedEntries: groupedFilteredEntries
        )

        return HomeMacTimelinePresentation(
            baseEntries: baseEntries,
            filteredEntries: filteredEntries,
            unfilteredEntries: unfilteredEntries,
            availableFlags: availableFlags,
            groupedFilteredEntries: groupedFilteredEntries,
            rowNumbersByEntryID: rowNumbersByEntryID
        )
    }

    var effectiveMacTimelineFilterType: TimelineFilterType {
        store.selectedTimelineFilterType.normalized(
            includingEventEmotion: areMacEventEmotionActionsEnabled,
            includingPlaces: isPlacesEnabled,
            includingNotes: isNotesEnabled,
            includingAway: isAwayEnabled,
            includingSleep: includesMacSleepTimelineFilters
        )
    }

    var includesMacSleepTimelineFilters: Bool {
        isAwayEnabled && isStatsSleepTabEnabled
    }

    var availableTimelineTags: [String] {
        TimelineLogic.availableTags(
            from: filteredTimelineEntriesForTagging
        )
    }

    var availableTimelineFlags: [String] {
        macTimelinePresentation.availableFlags
    }

    var filteredTimelineEntriesForTagging: [TimelineEntry] {
        baseTimelineEntries.filter(matchesMacSharedTaskLadderFilters)
    }

    var availableTimelineExcludeTags: [String] {
        availableTimelineTags.filter { tag in
            !store.selectedTimelineTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
    }

    var suggestedRelatedTimelineTags: [String] {
        let selectedTags = store.selectedTimelineTags
        guard !selectedTags.isEmpty else { return [] }
        let suggestionSource = relatedTimelineTagSuggestionAnchor.map { [$0] } ?? Array(selectedTags)
        return RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: store.relatedTagRules,
            availableTags: availableTimelineTags
        )
    }

    var groupedTimelineEntries: [(date: Date, entries: [TimelineEntry])] {
        macTimelinePresentation.groupedFilteredEntries
    }

    var plannerTimelineEntries: [TimelineEntry] {
        timelineEntries
    }

    var groupedPlannerTimelineEntries: [(date: Date, entries: [TimelineEntry])] {
        macTimelinePresentation.groupedFilteredEntries
    }

    var plannerTimelineEntryCount: Int {
        unfilteredPlannerTimelineEntries.count
    }

    var macHasActiveTimelineFilters: Bool {
        effectiveMacTimelineFilterType != .all
            || store.selectedTimelineStatusFilter != .all
            || !store.selectedTimelineTags.isEmpty
            || !macSharedSelectedFlags.isEmpty
            || !macSharedExcludedFlags.isEmpty
            || store.selectedTimelineImportanceUrgencyFilter != nil
            || store.selectedTimelinePressureFilter != nil
            || store.selectedTimelineThinkingNeededFilter != nil
            || store.selectedTimelineEstimationFilter != .all
            || store.selectedTimelineMediaFilter != .all
            || !store.selectedTimelineExcludedTags.isEmpty
    }

    var macPlannerTimelineFilterNoticeTitle: String? {
        guard macHasActiveTimelineFilters else { return nil }
        guard
            let newestUnfilteredEntry =
                unfilteredPlannerTimelineEntries
                .filter(matchesTimelineSearch)
                .max(by: { $0.timestamp < $1.timestamp })
        else {
            return "Timeline filters active"
        }

        guard
            let newestFilteredEntry = plannerTimelineEntries.max(
                by: { $0.timestamp < $1.timestamp }
            )
        else {
            return "Newer activity hidden by filters"
        }

        return newestUnfilteredEntry.timestamp > newestFilteredEntry.timestamp
            ? "Newer activity hidden by filters"
            : "Timeline filters active"
    }

    func hasTimelineSearchResult(for searchText: String) -> Bool {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }

        return baseTimelineEntries.contains { entry in
            matchesTimelineSearch(entry, searchText: trimmedSearch)
        }
            || unfilteredPlannerTimelineEntries.contains { entry in
                matchesTimelineSearch(entry, searchText: trimmedSearch)
            }
    }

    private var unfilteredPlannerTimelineEntries: [TimelineEntry] {
        macTimelinePresentation.unfilteredEntries
    }

    var selectedMacTimelineEntry: TimelineEntry? {
        selectedMacTimelineSelection.entry
    }

    var selectedMacTimelineSelection: MacTimelineSelection {
        guard case let .timelineEntry(entryID) = store.macSidebarSelection else {
            return .empty
        }

        let entry = timelineEntries.first { $0.id == entryID }
        let note = selectedTimelineNote(for: entry, fallbackID: entryID)
        let attachments = note.map(selectedTimelineNoteAttachments) ?? []
        let emotion = entry.flatMap { entry in
            entry.isEmotion ? emotionLogs.first { $0.id == entry.id } : nil
        }
        let event = entry.flatMap { entry in
            entry.isEvent ? events.first { $0.id == entry.id } : nil
        }
        let placeCheckInSession = entry.flatMap { entry in
            entry.isPlaceCheckIn ? placeCheckInSessions.first { $0.id == entry.id } : nil
        }
        let awaySession = entry.flatMap { entry in
            entry.isAway ? awaySessions.first { $0.id == entry.id } : nil
        }

        return MacTimelineSelection(
            entry: entry,
            emotion: emotion,
            event: event,
            note: note,
            noteAttachments: attachments,
            placeCheckInSession: placeCheckInSession,
            awaySession: awaySession
        )
    }

    var selectedMacTimelineNote: RoutineNote? {
        selectedMacTimelineSelection.note
    }

    var selectedMacTimelineEmotion: EmotionLog? {
        selectedMacTimelineSelection.emotion
    }

    var selectedMacTimelineEvent: RoutineEvent? {
        selectedMacTimelineSelection.event
    }

    var selectedMacTimelineNoteAttachments: [RoutineNoteAttachment] {
        selectedMacTimelineSelection.noteAttachments
    }

    var selectedMacTimelinePlaceCheckInSession: PlaceCheckInSession? {
        selectedMacTimelineSelection.placeCheckInSession
    }

    var selectedMacTimelineAwaySession: AwaySession? {
        selectedMacTimelineSelection.awaySession
    }

    private func selectedTimelineNote(
        for entry: TimelineEntry?,
        fallbackID: UUID
    ) -> RoutineNote? {
        if let entry, entry.isNote {
            return notes.first { $0.id == entry.id }
        }

        return notes.first { $0.id == fallbackID }
    }

    private func selectedTimelineNoteAttachments(
        for note: RoutineNote
    ) -> [RoutineNoteAttachment] {
        noteAttachments
            .filter { $0.noteID == note.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func openTimelineEntry(_ entry: TimelineEntry) {
        if entry.isSleep {
            openSleepInPlanner(entry.id)
            return
        }
        if entry.isAway, awaySessions.contains(where: { $0.id == entry.id }) {
            isEventEditorPresented = false
            isEmotionLogEditorPresented = false
            isNoteEditorPresented = false
            selectedNoteID = nil
            store.send(.macSidebarSelectionChanged(.timelineEntry(entry.id)))
            store.send(.setSelectedTask(nil))
            return
        }

        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        selectedNoteID = entry.isNote ? entry.id : nil
        store.send(.macSidebarSelectionChanged(.timelineEntry(entry.id)))
        store.send(.setSelectedTask(entry.taskID))
    }

    func openPlannerTimelineEntry(_ entry: TimelineEntry) {
        if let taskID = entry.taskID,
            timelineSourceTasks.contains(where: { $0.id == taskID })
        {
            openDayPlanTaskDetails(taskID)
            return
        }

        if entry.isSleep {
            dayPlanDisplayMode = .calendar
            openSleepInPlanner(entry.id)
            return
        }

        if entry.isNote {
            openSavedNote(entry.id)
            return
        }

        if entry.isEvent {
            openSavedEvent(entry.id)
            return
        }

        if entry.isEmotion {
            openSavedEmotion(entry.id)
            return
        }

        openTimelineEntryInSidebar(entry)
    }

    private func openTimelineEntryInSidebar(_ entry: TimelineEntry) {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        selectedNoteID = entry.isNote ? entry.id : nil
        searchTextBinding.wrappedValue = ""
        store.send(.setAddRoutineSheet(false))
        store.send(.setMacFilterDetailPresented(false))
        store.send(.macSidebarModeChanged(.timeline))
        store.send(.macSidebarSelectionChanged(.timelineEntry(entry.id)))
        store.send(.setSelectedTask(entry.taskID))
        macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: entry.id)
    }

    func handlePendingSleepPlannerDeepLink(_ sleepID: UUID?) {
        guard let sleepID else { return }
        openSleepInPlanner(sleepID)
    }

    func openSleepInPlanner(_ sleepID: UUID) {
        guard let session = sleepSessions.first(where: { $0.id == sleepID }) else {
            store.send(.sleepPlannerDeepLinkHandled(sleepID))
            return
        }

        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        selectedNoteID = nil
        dayPlanUnplannedCompletedFilterDate = nil
        macHomeDetailMode = .planner
        taskDetailPanePlacement = nil
        store.send(.setSelectedTask(nil))
        store.send(.macSidebarModeChanged(.routines))
        dayPlanPlanner.focusSleepSession(session, calendar: calendar, context: modelContext)
        store.send(.sleepPlannerDeepLinkHandled(sleepID))
    }

    func openTimelineInSidebar() {
        isEventEditorPresented = false
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        selectedNoteID = nil
        dayPlanUnplannedCompletedFilterDate = nil
        macHomeDetailMode = .planner
        dayPlanDisplayMode = .list
        taskDetailPanePlacement = nil
        store.send(.macSidebarModeChanged(.routines))
        store.send(.setSelectedTask(nil))
        validateSelectedTimelineTag()
        macTimelineSidebarScrollRequest = nil
    }
}
