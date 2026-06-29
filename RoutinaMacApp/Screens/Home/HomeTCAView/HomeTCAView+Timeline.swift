import SwiftUI

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
        baseTimelineEntries
            .filter { entry in
                HomeFeature.matchesImportanceUrgencyFilter(
                    store.selectedTimelineImportanceUrgencyFilter,
                    importance: entry.importance,
                    urgency: entry.urgency
                )
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
    }

    private var baseTimelineEntries: [TimelineEntry] {
        TimelineLogic.filteredEntries(
            logs: store.timelineLogs,
            tasks: store.routineTasks,
            events: events,
            emotionLogs: emotionLogs,
            notes: isNotesEnabled ? notes : [],
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            boardSprints: boardSprints,
            sleepSessions: sleepSessions,
            placeCheckInSessions: isPlacesEnabled ? placeCheckInSessions : [],
            awaySessions: isAwayEnabled ? awaySessions : [],
            fileAttachmentTaskIDs: store.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: isNotesEnabled ? noteAttachmentNoteIDs : [],
            range: .all,
            filterType: effectiveMacTimelineFilterType,
            mediaFilter: store.selectedTimelineMediaFilter,
            now: Date(),
            calendar: calendar
        )
    }

    private var effectiveMacTimelineFilterType: TimelineFilterType {
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

    var filteredTimelineEntriesForTagging: [TimelineEntry] {
        baseTimelineEntries.filter { entry in
            HomeFeature.matchesImportanceUrgencyFilter(
                store.selectedTimelineImportanceUrgencyFilter,
                importance: entry.importance,
                urgency: entry.urgency
            )
        }
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
        TimelineLogic.groupedByDay(entries: timelineEntries, calendar: calendar)
    }

    var plannerTimelineEntries: [TimelineEntry] {
        basePlannerTimelineEntries
            .filter(matchesTimelineSearch)
    }

    var groupedPlannerTimelineEntries: [(date: Date, entries: [TimelineEntry])] {
        TimelineLogic.groupedByDay(entries: plannerTimelineEntries, calendar: calendar)
    }

    var plannerTimelineEntryCount: Int {
        basePlannerTimelineEntries.count
    }

    func hasTimelineSearchResult(for searchText: String) -> Bool {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }

        return baseTimelineEntries.contains { entry in
            matchesTimelineSearch(entry, searchText: trimmedSearch)
        } || basePlannerTimelineEntries.contains { entry in
            matchesTimelineSearch(entry, searchText: trimmedSearch)
        }
    }

    private var basePlannerTimelineEntries: [TimelineEntry] {
        TimelineLogic.filteredEntries(
            logs: store.timelineLogs,
            tasks: store.routineTasks,
            events: events,
            emotionLogs: emotionLogs,
            notes: isNotesEnabled ? notes : [],
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            boardSprints: boardSprints,
            sleepSessions: sleepSessions,
            placeCheckInSessions: isPlacesEnabled ? placeCheckInSessions : [],
            awaySessions: isAwayEnabled ? awaySessions : [],
            fileAttachmentTaskIDs: store.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: isNotesEnabled ? noteAttachmentNoteIDs : [],
            range: .all,
            filterType: .all,
            mediaFilter: .all,
            now: Date(),
            calendar: calendar
        )
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
           store.routineTasks.contains(where: { $0.id == taskID }) {
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
        store.send(.macSidebarModeChanged(.timeline))
        validateSelectedTimelineTag()
        macTimelineSidebarScrollRequest = nil
        guard macTimelineSidebarPositionedPresentationID != macTimelineSidebarPresentationID else {
            return
        }
        guard let latestEntry = groupedTimelineEntries.first?.entries.first else {
            return
        }
        selectedNoteID = latestEntry.isNote ? latestEntry.id : nil
        store.send(.macSidebarSelectionChanged(.timelineEntry(latestEntry.id)))
        store.send(.setSelectedTask(latestEntry.taskID))
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
                        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)
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
                        .routinaGlassPill(tint: timelineKindColor(for: entry), tintOpacity: 0.15)
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
        let trimmedSearch = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return matchesTimelineSearch(entry, searchText: trimmedSearch)
    }

    private func matchesTimelineSearch(_ entry: TimelineEntry, searchText: String) -> Bool {
        return entry.searchableText.localizedCaseInsensitiveContains(searchText)
            || timelineKindLabel(for: entry).localizedCaseInsensitiveContains(searchText)
    }

    func validateSelectedTimelineTag() {
        let selected = store.selectedTimelineTags.filter { RoutineTag.contains($0, in: availableTimelineTags) }
        store.send(.selectedTimelineTagsChanged(selected))
        store.send(
            .selectedTimelineExcludedTagsChanged(
                store.selectedTimelineExcludedTags.filter { RoutineTag.contains($0, in: availableTimelineExcludeTags) }
            )
        )
    }

    var macActiveTimelineFiltersSummary: String? {
        var labels: [String] = []

        if effectiveMacTimelineFilterType != .all {
            labels.append(effectiveMacTimelineFilterType.rawValue)
        }

        if let filter = store.selectedTimelineImportanceUrgencyFilter {
            labels.append("\(filter.importance.shortTitle)/\(filter.urgency.shortTitle)+")
        }

        if store.selectedTimelineMediaFilter != .all {
            labels.append(store.selectedTimelineMediaFilter.title)
        }

        if !store.selectedTimelineTags.isEmpty {
            labels.append("\(store.selectedTimelineIncludeTagMatchMode.rawValue) \(store.selectedTimelineTags.count) tags")
        }

        if !store.selectedTimelineExcludedTags.isEmpty {
            if store.selectedTimelineExcludedTags.count == 1, let tag = store.selectedTimelineExcludedTags.first {
                labels.append("not #\(tag)")
            } else {
                labels.append("not \(store.selectedTimelineExcludedTags.count) tags")
            }
        }

        let summary = summarizedFilterLabels(from: labels, maxVisibleCount: 4)
        return summaryWithResultCount(summary, resultCount: timelineEntries.count)
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
        store.routineTasks.contains(where: \.isOneOffTask)
            || (areMacEventEmotionActionsEnabled && (!events.isEmpty || !emotionLogs.isEmpty))
            || (isNotesEnabled && !notes.isEmpty)
            || !focusSessions.isEmpty
            || !sprintFocusSessions.isEmpty
            || (includesMacSleepTimelineFilters && !sleepSessions.isEmpty)
            || (isAwayEnabled && !awaySessions.isEmpty)
            || (isPlacesEnabled && !placeCheckInSessions.isEmpty)
    }

    var macPlannerTimelineListView: some View {
        HomeMacPlannerTimelineListView(
            timelineEntryCount: plannerTimelineEntryCount,
            groupedEntries: groupedPlannerTimelineEntries,
            showsPlaces: isPlacesEnabled,
            showsNotes: isNotesEnabled,
            showsAway: isAwayEnabled,
            sectionTitle: { date in
                TimelineLogic.daySectionTitle(for: date, calendar: calendar)
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
                timelineEntryCount: store.timelineLogs.count + events.count + emotionLogs.count + (isNotesEnabled ? notes.count : 0) + focusSessions.count + sprintFocusSessions.count + sleepSessions.count + (isAwayEnabled ? awaySessions.count : 0) + (isPlacesEnabled ? placeCheckInSessions.count : 0),
                groupedEntries: groupedTimelineEntries,
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
                        .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)
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
                        .routinaGlassPill(tint: timelineKindColor(for: entry), tintOpacity: 0.15)
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
        if entry.isSleep {
            return "Sleep"
        }
        if entry.isAway {
            return "Away"
        }
        if entry.isEmotion {
            return "Emotion"
        }
        if entry.isEvent {
            return "Event"
        }
        if entry.isStatusNote {
            return "Status"
        }
        if entry.isNote {
            return "Note"
        }
        if entry.isFocus {
            return "Focus"
        }
        if entry.isPlaceCheckIn {
            return "Place"
        }

        switch entry.kind {
        case .completed:
            return entry.isOneOff ? "Todo" : "Routine"
        case .canceled:
            return "Canceled"
        case .missed:
            return "Missed"
        }
    }

    private func timelineKindColor(for entry: TimelineEntry) -> Color {
        if entry.isSleep {
            return .indigo
        }
        if entry.isAway {
            return .mint
        }
        if entry.isEmotion {
            return .pink
        }
        if entry.isEvent {
            return .teal
        }
        if entry.isStatusNote {
            return .mint
        }
        if entry.isNote {
            return .blue
        }
        if entry.isFocus {
            return .cyan
        }
        if entry.isPlaceCheckIn {
            return .teal
        }

        switch entry.kind {
        case .completed:
            return entry.isOneOff ? .purple : .accentColor
        case .canceled:
            return .orange
        case .missed:
            return .yellow
        }
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
