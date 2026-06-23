import SwiftUI

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
            notes: notes,
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            boardSprints: boardSprints,
            sleepSessions: sleepSessions,
            placeCheckInSessions: isPlacesEnabled ? placeCheckInSessions : [],
            awaySessions: awaySessions,
            fileAttachmentTaskIDs: store.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: noteAttachmentNoteIDs,
            range: store.selectedTimelineRange,
            filterType: effectiveMacTimelineFilterType,
            mediaFilter: store.selectedTimelineMediaFilter,
            now: Date(),
            calendar: calendar
        )
    }

    private var effectiveMacTimelineFilterType: TimelineFilterType {
        store.selectedTimelineFilterType.normalized(
            includingEventEmotion: areMacEventEmotionActionsEnabled,
            includingPlaces: isPlacesEnabled
        )
    }

    var availableTimelineTags: [String] {
        TimelineLogic.availableTags(
            from: filteredTimelineEntriesForTagging
        )
    }

    private var filteredTimelineEntriesForTagging: [TimelineEntry] {
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

    var selectedMacTimelineEntry: TimelineEntry? {
        guard case let .timelineEntry(entryID) = store.macSidebarSelection else {
            return nil
        }
        return timelineEntries.first { $0.id == entryID }
    }

    var selectedMacTimelineNote: RoutineNote? {
        if let selectedMacTimelineEntry, selectedMacTimelineEntry.isNote {
            return notes.first { $0.id == selectedMacTimelineEntry.id }
        }

        guard case let .timelineEntry(noteID) = store.macSidebarSelection else { return nil }
        return notes.first { $0.id == noteID }
    }

    var selectedMacTimelineEmotion: EmotionLog? {
        guard let selectedMacTimelineEntry, selectedMacTimelineEntry.isEmotion else {
            return nil
        }
        return emotionLogs.first { $0.id == selectedMacTimelineEntry.id }
    }

    var selectedMacTimelineEvent: RoutineEvent? {
        guard let selectedMacTimelineEntry, selectedMacTimelineEntry.isEvent else {
            return nil
        }
        return events.first { $0.id == selectedMacTimelineEntry.id }
    }

    var selectedMacTimelineNoteAttachments: [RoutineNoteAttachment] {
        guard let selectedMacTimelineNote else { return [] }
        return noteAttachments
            .filter { $0.noteID == selectedMacTimelineNote.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var selectedMacTimelinePlaceCheckInSession: PlaceCheckInSession? {
        guard let selectedMacTimelineEntry, selectedMacTimelineEntry.isPlaceCheckIn else {
            return nil
        }
        return placeCheckInSessions.first { $0.id == selectedMacTimelineEntry.id }
    }

    var selectedMacTimelineAwaySession: AwaySession? {
        guard let selectedMacTimelineEntry, selectedMacTimelineEntry.isAway else {
            return nil
        }
        return awaySessions.first { $0.id == selectedMacTimelineEntry.id }
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
        guard let latestEntry = timelineEntries.last else {
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
        return entry.searchableText.localizedCaseInsensitiveContains(trimmedSearch)
            || timelineKindLabel(for: entry).localizedCaseInsensitiveContains(trimmedSearch)
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

    var timelineImportanceUrgencySummary: String {
        guard let filter = ImportanceUrgencyFilterCell.normalized(store.selectedTimelineImportanceUrgencyFilter) else {
            return "Showing done items across all importance and urgency levels."
        }
        return "Showing done items from tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    var timelineTagSelectionSummary: String {
        if !store.selectedTimelineTags.isEmpty {
            return "\(store.selectedTimelineIncludeTagMatchMode.rawValue) of \(store.selectedTimelineTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }

        let tagCount = availableTimelineTags.count
        return "\(tagCount) \(tagCount == 1 ? "tag" : "tags") available"
    }

    var timelineExcludedTagSummary: String {
        if !store.selectedTimelineExcludedTags.isEmpty {
            return "Hiding items tagged: \(store.selectedTimelineExcludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
        }

        return "Select tags to hide done items that have them."
    }

    var macActiveTimelineFiltersSummary: String? {
        var labels: [String] = []

        if store.selectedTimelineRange != .all {
            labels.append(store.selectedTimelineRange.rawValue)
        }

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

    private func timelineTagCount(for tag: String) -> Int {
        filteredTimelineEntriesForTagging.filter { entry in
            RoutineTag.contains(tag, in: entry.tags)
        }.count
    }

    private func timelineTagColor(for tag: String) -> Color? {
        Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: store.tagColors))
    }

    var macTimelineFiltersDetailView: some View {
        HomeMacTimelineFilterDetailContainerView(
            title: macFilterDetailTitle,
            showsTitle: false,
            onAvailableTagsChange: { validateSelectedTimelineTag() },
            availableTags: availableTimelineTags
        ) {
            HomeMacTimelineFiltersDetailView(
                selectedRange: Binding(
                    get: { store.selectedTimelineRange },
                    set: { store.send(.selectedTimelineRangeChanged($0)) }
                ),
                selectedType: Binding(
                    get: { effectiveMacTimelineFilterType },
                    set: {
                        store.send(.selectedTimelineFilterTypeChanged(
                            $0.normalized(
                                includingEventEmotion: areMacEventEmotionActionsEnabled,
                                includingPlaces: isPlacesEnabled
                            )
                        ))
                    }
                ),
                selectedImportanceUrgencyFilter: Binding(
                    get: { store.selectedTimelineImportanceUrgencyFilter },
                    set: { store.send(.selectedTimelineImportanceUrgencyFilterChanged($0)) }
                ),
                selectedMediaFilter: Binding(
                    get: { store.selectedTimelineMediaFilter },
                    set: { store.send(.selectedTimelineMediaFilterChanged($0)) }
                ),
                timelineRowVisibility: timelineRowVisibility,
                showsTypeSection: showsMacTimelineTypeFilterSection,
                importanceUrgencySummary: timelineImportanceUrgencySummary,
                allTagsCount: filteredTimelineEntriesForTagging.count,
                availableTags: availableTimelineTags,
                suggestedRelatedTags: suggestedRelatedTimelineTags,
                availableExcludeTags: availableTimelineExcludeTags,
                selectedTags: store.selectedTimelineTags,
                includeTagMatchMode: store.selectedTimelineIncludeTagMatchMode,
                excludeTagMatchMode: store.selectedTimelineExcludeTagMatchMode,
                selectedExcludedTags: store.selectedTimelineExcludedTags,
                tagSelectionSummary: timelineTagSelectionSummary,
                excludedTagSummary: timelineExcludedTagSummary,
                tagCount: { tag in
                    timelineTagCount(for: tag)
                },
                tagColor: { tag in
                    timelineTagColor(for: tag)
                },
                onSelectTags: { tags in
                    relatedTimelineTagSuggestionAnchor = tags.sorted().last
                    store.send(.selectedTimelineTagsChanged(tags))
                },
                onIncludeTagMatchModeChange: { mode in
                    store.send(.selectedTimelineIncludeTagMatchModeChanged(mode))
                },
                onSelectSuggestedTag: { tag in
                    var selected = store.selectedTimelineTags
                    selected.insert(tag)
                    store.send(.selectedTimelineTagsChanged(selected))
                },
                onExcludeTagMatchModeChange: { mode in
                    store.send(.selectedTimelineExcludeTagMatchModeChanged(mode))
                },
                onToggleExcludedTag: { tag in
                    if store.selectedTimelineExcludedTags.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
                        store.send(.selectedTimelineExcludedTagsChanged(store.selectedTimelineExcludedTags.filter { $0 != tag }))
                    } else {
                        var newTags = store.selectedTimelineExcludedTags
                        newTags.insert(tag)
                        store.send(.selectedTimelineExcludedTagsChanged(newTags))
                        store.send(.selectedTimelineTagsChanged(store.selectedTimelineTags.filter { !RoutineTag.contains($0, in: [tag]) }))
                    }
                },
                onTimelineRowFieldVisibilityChanged: { field, isVisible in
                    settingsStore.send(.timelineRowFieldVisibilityChanged(field, isVisible))
                },
                includesEventEmotionFilters: areMacEventEmotionActionsEnabled,
                includesPlaceFilters: isPlacesEnabled
            )
        }
    }

    private var showsMacTimelineTypeFilterSection: Bool {
        store.routineTasks.contains(where: \.isOneOffTask)
            || (areMacEventEmotionActionsEnabled && (!events.isEmpty || !emotionLogs.isEmpty))
            || !notes.isEmpty
            || !focusSessions.isEmpty
            || !sprintFocusSessions.isEmpty
            || !sleepSessions.isEmpty
            || !awaySessions.isEmpty
            || (isPlacesEnabled && !placeCheckInSessions.isEmpty)
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
                                    includingPlaces: isPlacesEnabled
                                )
                            ))
                        }
                    ),
                    includesEventEmotion: areMacEventEmotionActionsEnabled,
                    includesPlaces: isPlacesEnabled
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            HomeMacTimelineSidebarView(
                timelineEntryCount: store.timelineLogs.count + events.count + emotionLogs.count + notes.count + focusSessions.count + sprintFocusSessions.count + sleepSessions.count + awaySessions.count + (isPlacesEnabled ? placeCheckInSessions.count : 0),
                groupedEntries: groupedTimelineEntries,
                presentationID: macTimelineSidebarPresentationID,
                isActive: isMacTimelineMode && !store.isMacFilterDetailPresented,
                allowsFallbackSelection: !store.isMacFilterDetailPresented,
                showsPlaces: isPlacesEnabled,
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
