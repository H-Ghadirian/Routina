import SwiftUI

@MainActor
final class HomeMacTimelinePresentationCache: ObservableObject {
    private var cachedSignature: HomeMacTimelinePresentationSignature?
    private var cachedPresentation: HomeMacTimelinePresentation?

    func presentation(
        for signature: HomeMacTimelinePresentationSignature,
        build: () -> HomeMacTimelinePresentation
    ) -> HomeMacTimelinePresentation {
        if cachedSignature == signature, let cachedPresentation {
            return cachedPresentation
        }
#if os(macOS)
        if RoutinaMacScrollInteractionGate.isScrollActive, let cachedPresentation {
            return cachedPresentation
        }
#endif

        let presentation = build()
        cachedSignature = signature
        cachedPresentation = presentation
        return presentation
    }

    func invalidate() {
        cachedSignature = nil
    }
}

struct HomeMacTimelinePresentationSignature: Equatable {
    let dataRevision: Int
    let filterType: TimelineFilterType
    let statusFilter: TimelineStatusFilter
    let mediaFilter: TaskMediaFilter
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let selectedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludedFlags: Set<String>
    let excludeFlagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let importanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let pressureFilter: RoutineTaskPressure?
    let thinkingNeededFilter: RoutineTaskThinkingNeeded?
    let estimationFilter: TaskEstimationFilter
    let taskLadderReferenceDay: Date
    let searchText: String
    let showsEventsAndEmotions: Bool
    let showsPlaces: Bool
    let showsNotes: Bool
    let showsAway: Bool
    let showsSleep: Bool
    let flagRules: [RoutineFlagRule]
    let fileAttachmentTaskIDs: Set<UUID>
    let noteAttachmentNoteIDs: Set<UUID>
    let focusActionLogCount: Int
    let latestFocusActionLogTimestamp: Date?
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZoneIdentifier: String
    let calendarFirstWeekday: Int
    let calendarMinimumDaysInFirstWeek: Int
}

struct HomeMacTimelinePresentation {
    let baseEntries: [TimelineEntry]
    let filteredEntries: [TimelineEntry]
    let unfilteredEntries: [TimelineEntry]
    let availableFlags: [String]
    let groupedFilteredEntries: [(date: Date, entries: [TimelineEntry])]
    let rowNumbersByEntryID: [UUID: Int]
}

struct MacTimelineSelection {
    static var empty: MacTimelineSelection {
        MacTimelineSelection(
            entry: nil,
            emotion: nil,
            event: nil,
            note: nil,
            noteAttachments: [],
            placeCheckInSession: nil,
            awaySession: nil
        )
    }

    var entry: TimelineEntry?
    var emotion: EmotionLog?
    var event: RoutineEvent?
    var note: RoutineNote?
    var noteAttachments: [RoutineNoteAttachment]
    var placeCheckInSession: PlaceCheckInSession?
    var awaySession: AwaySession?
}

extension HomeTCAView {
    var timelineEntries: [TimelineEntry] {
        macTimelinePresentation.filteredEntries
    }

    private var timelineSourceTasks: [RoutineTask] {
        HomeTaskSupport.timelineTasksIncludingSelectedDetail(
            tasks: store.routineTasks,
            detailTask: store.taskDetailState?.task
        )
    }

    private var timelineSourceLogs: [RoutineLog] {
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
        let filteredEntries = baseEntries
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
        guard let newestUnfilteredEntry = unfilteredPlannerTimelineEntries
            .filter(matchesTimelineSearch)
            .max(by: { $0.timestamp < $1.timestamp })
        else {
            return "Timeline filters active"
        }

        guard let newestFilteredEntry = plannerTimelineEntries.max(by: { $0.timestamp < $1.timestamp }) else {
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
        } || unfilteredPlannerTimelineEntries.contains { entry in
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

    private func openTimelineEntry(_ entry: TimelineEntry) {
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

    private func openPlannerTimelineEntry(_ entry: TimelineEntry) {
        if let taskID = entry.taskID,
           timelineSourceTasks.contains(where: { $0.id == taskID }) {
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

    func timelineSidebarRow(_ entry: TimelineEntry, rowNumber: Int) -> some View {
        let rowVisibility = timelineRowVisibility

        return Button {
            openTimelineEntry(entry)
        } label: {
            HStack(spacing: 12) {
                if rowVisibility.shows(.rowNumber) {
                    Text("\(rowNumber)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: sidebarRowNumberMinWidth, alignment: .trailing)
                }

                if rowVisibility.shows(.icon) {
                    Text(entry.taskEmoji)
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .routinaScrollingRoundedFill(
                            cornerRadius: 8,
                            tint: .secondary,
                            tintOpacity: 0.06
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.taskName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if rowVisibility.shows(.subtitle) {
                        Text(timelineSubtitle(for: entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                if rowVisibility.shows(.kindBadge) {
                    Text(timelineKindLabel(for: entry))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .routinaScrollingPillFill(
                            tint: timelineKindColor(for: entry),
                            tintOpacity: 0.15
                        )
                        .foregroundStyle(timelineKindColor(for: entry))
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .tag(HomeFeature.MacSidebarSelection.timelineEntry(entry.id))
        .contentShape(Rectangle())
    }

    private func matchesTimelineSearch(_ entry: TimelineEntry) -> Bool {
        let trimmedSearch = macSearchPresentationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return matchesTimelineSearch(entry, searchText: trimmedSearch)
    }

    private func matchesTimelineSearch(_ entry: TimelineEntry, searchText: String) -> Bool {
        return entry.searchableText.localizedCaseInsensitiveContains(searchText)
            || timelineKindLabel(for: entry).localizedCaseInsensitiveContains(searchText)
    }

    func validateSelectedTimelineTag() {
        let selectedFlags = store.selectedTimelineFlags.filter {
            RoutineFlag.contains($0, in: availableTimelineFlags)
        }
        store.send(.selectedTimelineFlagsChanged(selectedFlags))
        let selected = store.selectedTimelineTags.filter { RoutineTag.contains($0, in: availableTimelineTags) }
        store.send(.selectedTimelineTagsChanged(selected))
        store.send(
            .selectedTimelineExcludedTagsChanged(
                store.selectedTimelineExcludedTags.filter { RoutineTag.contains($0, in: availableTimelineExcludeTags) }
            )
        )
    }

    var macActiveTimelineFiltersSummary: String? {
        guard macHasActiveTimelineFilters else { return nil }

        var labels: [String] = []

        if effectiveMacTimelineFilterType != .all {
            labels.append(effectiveMacTimelineFilterType.title)
        }

        if store.selectedTimelineStatusFilter != .all {
            labels.append(store.selectedTimelineStatusFilter.title)
        }

        if let filter = store.selectedTimelineImportanceUrgencyFilter {
            if let importance = filter.minimumImportance {
                labels.append("Importance \(importance.title)+")
            }
            if let urgency = filter.minimumUrgency {
                labels.append("Urgency \(urgency.title)+")
            }
        }

        if let pressure = store.selectedTimelinePressureFilter {
            labels.append("Pressure \(pressure.title)+")
        }

        if let thinking = store.selectedTimelineThinkingNeededFilter {
            labels.append("Thinking \(thinking.title)")
        }

        if store.selectedTimelineEstimationFilter != .all {
            labels.append("Estimated time: \(store.selectedTimelineEstimationFilter.title)")
        }

        if store.selectedTimelineMediaFilter != .all {
            labels.append(store.selectedTimelineMediaFilter.title)
        }

        if !store.selectedTimelineTags.isEmpty {
            labels.append("\(store.selectedTimelineIncludeTagMatchMode.rawValue) \(store.selectedTimelineTags.count) tags")
        }

        if !macSharedSelectedFlags.isEmpty {
            labels.append("\(macSharedIncludeFlagMatchMode.rawValue) \(macSharedSelectedFlags.count) flags")
        }

        if !macSharedExcludedFlags.isEmpty {
            labels.append("not \(macSharedExcludedFlags.count) flags")
        }

        if !store.selectedTimelineExcludedTags.isEmpty {
            if let excludedTagsSummary = macTimelineExcludedTagsSummary {
                labels.append(excludedTagsSummary)
            }
        }

        let summary = summarizedFilterLabels(from: labels, maxVisibleCount: 4)
        return summaryWithResultCount(summary, resultCount: timelineEntries.count)
    }

    private var macTimelineExcludedTagsSummary: String? {
        let tags = store.selectedTimelineExcludedTags.sorted()
        guard !tags.isEmpty else { return nil }
        if tags.count == 1, let tag = tags.first {
            return "not #\(tag)"
        }
        if tags.count <= 6 {
            return "not \(tags.map { "#\($0)" }.joined(separator: ", "))"
        }

        let visibleTags = tags.prefix(4).map { "#\($0)" }.joined(separator: ", ")
        return "not \(visibleTags) +\(tags.count - 4) tags"
    }

    private func matchesMacSharedTaskLadderFilters(_ entry: TimelineEntry) -> Bool {
        let hasActiveFilter = store.selectedTimelineImportanceUrgencyFilter != nil
            || store.selectedTimelinePressureFilter != nil
            || store.selectedTimelineThinkingNeededFilter != nil
            || store.selectedTimelineEstimationFilter != .all
        guard hasActiveFilter else { return true }
        guard entry.hasTaskLadderValues else { return false }

        return HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
            store.selectedTimelineImportanceUrgencyFilter,
            importance: entry.currentImportance,
            urgency: entry.currentUrgency
        )
            && HomeDisplayFilterSupport.matchesMinimumPressureFilter(
                store.selectedTimelinePressureFilter,
                pressure: entry.currentPressure
            )
            && HomeDisplayFilterSupport.matchesThinkingNeededFilter(
                store.selectedTimelineThinkingNeededFilter,
                thinkingNeeded: entry.thinkingNeeded
            )
            && HomeDisplayFilterSupport.matchesEstimationFilter(
                store.selectedTimelineEstimationFilter,
                estimatedDurationMinutes: entry.estimatedDurationMinutes
            )
    }

    var macTimelineFiltersDetailView: some View {
        HomeMacFilterDetailContainerView(
            title: macFilterDetailTitle,
            showsTitle: false
        ) {
            macTimelineFiltersDetailContent
        }
    }

    var macTimelineFiltersDetailContent: some View {
        HomeMacTimelineFiltersDetailView(
            selectedType: Binding(
                get: { effectiveMacTimelineFilterType },
                set: {
                    store.send(.selectedTimelineFilterTypeChanged(
                        $0.normalized(
                            includingEventEmotion: areMacEventEmotionActionsEnabled,
                            includingPlaces: isPlacesEnabled,
                            includingNotes: isNotesEnabled,
                            includingAway: isAwayEnabled,
                            includingSleep: includesMacSleepTimelineFilters
                        )
                    ))
                }
            ),
            selectedStatus: Binding(
                get: { store.selectedTimelineStatusFilter },
                set: { store.send(.selectedTimelineStatusFilterChanged($0)) }
            ),
            selectedMediaFilter: Binding(
                get: { store.selectedTimelineMediaFilter },
                set: { store.send(.selectedTimelineMediaFilterChanged($0)) }
            ),
            timelineRowVisibility: timelineRowVisibility,
            showsTypeSection: showsMacTimelineTypeFilterSection,
            onTimelineRowFieldVisibilityChanged: { field, isVisible in
                settingsStore.send(.timelineRowFieldVisibilityChanged(field, isVisible))
            },
            includesEventEmotionFilters: areMacEventEmotionActionsEnabled,
            includesPlaceFilters: isPlacesEnabled,
            includesNoteFilters: isNotesEnabled,
            includesAwayFilters: isAwayEnabled,
            includesSleepFilters: includesMacSleepTimelineFilters
        )
    }

    private var showsMacTimelineTypeFilterSection: Bool {
        timelineSourceTasks.contains(where: \.isOneOffTask)
            || (areMacEventEmotionActionsEnabled && (!events.isEmpty || !emotionLogs.isEmpty))
            || (isNotesEnabled && !notes.isEmpty)
            || !focusSessions.isEmpty
            || !sprintFocusSessions.isEmpty
            || (includesMacSleepTimelineFilters && !sleepSessions.isEmpty)
            || (isAwayEnabled && !awaySessions.isEmpty)
            || (isPlacesEnabled && !placeCheckInSessions.isEmpty)
    }

    func macPlannerTimelineListView(dateJumpRequest: DayPlanTimelineDateJumpRequest?) -> some View {
        HomeMacPlannerTimelineListView(
            timelineEntryCount: plannerTimelineEntryCount,
            groupedEntries: groupedPlannerTimelineEntries,
            rowNumbersByEntryID: macTimelinePresentation.rowNumbersByEntryID,
            activeFiltersTitle: macPlannerTimelineFilterNoticeTitle,
            activeFiltersSummary: macActiveTimelineFiltersSummary,
            showsPlaces: isPlacesEnabled,
            showsNotes: isNotesEnabled,
            showsAway: isAwayEnabled,
            dateJumpRequest: dateJumpRequest,
            calendar: calendar,
            sectionTitle: { date in
                TimelineLogic.daySectionTitle(for: date, calendar: calendar)
            },
            onClearFilters: {
                clearAllMacTimelineFilters()
            }
        ) { entry, rowNumber in
            plannerTimelineRow(entry, rowNumber: rowNumber)
        }
    }

    var macTimelineSidebarView: some View {
        VStack(spacing: 0) {
            if areMacTimelineQuickFiltersVisible {
                TimelinePigmentControl(
                    selection: Binding(
                        get: { effectiveMacTimelineFilterType },
                        set: {
                            store.send(.selectedTimelineFilterTypeChanged(
                                $0.normalized(
                                    includingEventEmotion: areMacEventEmotionActionsEnabled,
                                    includingPlaces: isPlacesEnabled,
                                    includingNotes: isNotesEnabled,
                                    includingAway: isAwayEnabled,
                                    includingSleep: includesMacSleepTimelineFilters
                                )
                            ))
                        }
                    ),
                    includesEventEmotion: areMacEventEmotionActionsEnabled,
                    includesPlaces: isPlacesEnabled,
                    includesNotes: isNotesEnabled,
                    includesAway: isAwayEnabled,
                    includesSleep: includesMacSleepTimelineFilters
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            HomeMacTimelineSidebarView(
                timelineEntryCount: timelineSourceLogs.count + (areMacEventEmotionActionsEnabled ? events.count + emotionLogs.count : 0) + (isNotesEnabled ? notes.count : 0) + focusSessions.count + sprintFocusSessions.count + (includesMacSleepTimelineFilters ? sleepSessions.count : 0) + (isAwayEnabled ? awaySessions.count : 0) + (isPlacesEnabled ? placeCheckInSessions.count : 0),
                groupedEntries: groupedTimelineEntries,
                rowNumbersByEntryID: macTimelinePresentation.rowNumbersByEntryID,
                presentationID: macTimelineSidebarPresentationID,
                isActive: isMacTimelineMode,
                allowsFallbackSelection: !store.isMacFilterDetailPresented,
                showsPlaces: isPlacesEnabled,
                showsNotes: isNotesEnabled,
                showsAway: isAwayEnabled,
                positionedPresentationID: $macTimelineSidebarPositionedPresentationID,
                selection: macSidebarSelectionBinding,
                scrollRequest: $macTimelineSidebarScrollRequest,
                sectionTitle: { date in
                    TimelineLogic.daySectionTitle(for: date, calendar: calendar)
                }
            ) { entry, rowNumber in
                timelineSidebarRow(entry, rowNumber: rowNumber)
            }
        }
    }

    func plannerTimelineRow(_ entry: TimelineEntry, rowNumber: Int) -> some View {
        let rowVisibility = timelineRowVisibility

        return Button {
            openPlannerTimelineEntry(entry)
        } label: {
            HStack(spacing: 14) {
                if rowVisibility.shows(.rowNumber) {
                    Text("\(rowNumber)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: sidebarRowNumberMinWidth, alignment: .trailing)
                }

                if rowVisibility.shows(.icon) {
                    Text(entry.taskEmoji)
                        .font(.title2)
                        .frame(width: 38, height: 38)
                        .routinaScrollingRoundedFill(
                            cornerRadius: 8,
                            tint: .secondary,
                            tintOpacity: 0.06
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.taskName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if rowVisibility.shows(.subtitle) {
                        Text(timelineSubtitle(for: entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if rowVisibility.shows(.kindBadge) {
                    Text(timelineKindLabel(for: entry))
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .routinaScrollingPillFill(
                            tint: timelineKindColor(for: entry),
                            tintOpacity: 0.15
                        )
                        .foregroundStyle(timelineKindColor(for: entry))
                }
            }
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func timelineKindLabel(for entry: TimelineEntry) -> String {
        TimelineEntryKindPresentation.label(for: entry)
    }

    private func timelineKindColor(for entry: TimelineEntry) -> Color {
        TimelineEntryKindPresentation.tint(for: entry).color
    }

    private func timelineSubtitle(for entry: TimelineEntry) -> String {
        if entry.isSleep {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let endedAt = entry.endTimestamp ?? entry.timestamp
            let range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            if let durationSeconds = entry.durationSeconds {
                return "\(range) · \(SleepSessionFormatting.durationText(seconds: durationSeconds))"
            }
            return range
        }

        if entry.isAway {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let range: String
            if let endedAt = entry.endTimestamp {
                range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            } else {
                range = "Since \(startedAt.formatted(date: .omitted, time: .shortened))"
            }
            let duration = entry.durationSeconds.map { AwaySessionFormatting.durationText(seconds: $0) }
            return [range, duration, entry.activityTitle].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isPlaceCheckIn {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let range: String
            if let endedAt = entry.endTimestamp {
                range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            } else {
                range = "Since \(startedAt.formatted(date: .omitted, time: .shortened))"
            }
            let duration = entry.durationSeconds.map { PlaceCheckInFormatting.durationText(seconds: $0) }
            return [range, duration, entry.activityTitle].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isEmotion {
            return [
                entry.timestamp.formatted(date: .omitted, time: .shortened),
                entry.activityTitle,
            ].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isEvent {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            guard let endedAt = entry.endTimestamp, endedAt > startedAt else {
                return startedAt.formatted(date: .omitted, time: .shortened)
            }
            if calendar.isDate(startedAt, inSameDayAs: endedAt) {
                return "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            }
            return RoutineEventDateFormatting.text(
                startedAt: startedAt,
                endedAt: endedAt,
                isAllDay: calendar.startOfDay(for: startedAt) == startedAt,
                calendar: calendar
            )
        }

        if entry.isNote {
            let mediaSummary = RoutineNoteMediaSummary.text(
                hasImage: entry.hasImage,
                hasFileAttachment: entry.hasFileAttachment,
                hasVoiceNote: entry.hasVoiceNote
            )
            return [
                entry.timestamp.formatted(date: .omitted, time: .shortened),
                mediaSummary
            ].compactMap(\.self).joined(separator: " · ")
        }

        if entry.isFocus {
            let startedAt = entry.startTimestamp ?? entry.timestamp
            let range: String
            if let endedAt = entry.endTimestamp {
                range = "\(startedAt.formatted(date: .omitted, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
            } else {
                range = "Since \(startedAt.formatted(date: .omitted, time: .shortened))"
            }
            let duration = entry.durationSeconds.map { FocusSessionFormatting.compactDurationText(seconds: $0) }
            return [range, duration, entry.activityTitle].compactMap(\.self).joined(separator: " · ")
        }

        return entry.timestamp.formatted(date: .omitted, time: .shortened)
    }

    private var noteAttachmentNoteIDs: Set<UUID> {
        Set(noteAttachments.map(\.noteID))
    }
}
