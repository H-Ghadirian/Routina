import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \RoutineLog.timestamp, order: .reverse) private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]
    @Query private var fileAttachments: [RoutineAttachment]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]
    @Query(sort: \EmotionLog.createdAt, order: .reverse) private var emotionLogs: [EmotionLog]
    @Query(sort: \RoutineNote.createdAt, order: .reverse) private var notes: [RoutineNote]
    @Query private var noteAttachments: [RoutineNoteAttachment]
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query(sort: \SprintFocusSessionRecord.startedAt, order: .reverse) private var sprintFocusSessions: [SprintFocusSessionRecord]
    @Query(sort: \BoardSprintRecord.createdAt, order: .reverse) private var boardSprints: [BoardSprintRecord]
    @Query(sort: \SleepSession.startedAt, order: .reverse) private var sleepSessions: [SleepSession]
    @Query(sort: \AwaySession.startedAt, order: .reverse) private var awaySessions: [AwaySession]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var placeCheckInSessions: [PlaceCheckInSession]
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTimelineRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var timelineRowHiddenFieldsRawValue = ""
    @State private var relatedFilterTagSuggestionAnchor: String?
    @State private var selectedTimelineEntryID: UUID?

    var body: some View {
timelineRoot
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
        }
    }
    .sheet(item: deepLinkedEventPresentationBinding) { presentation in
        NavigationStack {
            deepLinkedEventDetail(eventID: presentation.id)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            store.send(.eventDeepLinkPresentationDismissed(presentation.id))
                        }
                    }
                }
        }
    }
.task {
    syncTimelineData()
    ensureTimelineSelection()
    routePendingDeepLinkedNote()
    routePendingDeepLinkedEvent()
}
.onChange(of: tasks) { _, _ in
    syncTimelineData()
}
.onChange(of: logs) { _, _ in
    syncTimelineData()
}
.onChange(of: focusSessionChangeToken) { _, _ in
    syncTimelineData()
}
.onChange(of: sprintFocusSessionChangeToken) { _, _ in
    syncTimelineData()
}
.onChange(of: boardSprintChangeToken) { _, _ in
    syncTimelineData()
}
    .onChange(of: sleepSessionChangeToken) { _, _ in
        syncTimelineData()
    }
    .onChange(of: awaySessionChangeToken) { _, _ in
        syncTimelineData()
    }
    .onChange(of: placeCheckInChangeToken) { _, _ in
        syncTimelineData()
    }
.onChange(of: fileAttachmentChangeToken) { _, _ in
    syncTimelineData()
}
.onChange(of: eventChangeToken) { _, _ in
    syncTimelineData()
}
.onChange(of: emotionLogChangeToken) { _, _ in
    syncTimelineData()
}
.onChange(of: noteChangeToken) { _, _ in
    syncTimelineData()
}
.onChange(of: noteAttachmentChangeToken) { _, _ in
    syncTimelineData()
}
.onChange(of: visibleTimelineEntryIDs) { _, _ in
    ensureTimelineSelection()
    routePendingDeepLinkedNote()
    routePendingDeepLinkedEvent()
}
.onChange(of: store.deepLinkedNoteID) { _, _ in
    routePendingDeepLinkedNote()
}
.onChange(of: store.deepLinkedEventID) { _, _ in
    routePendingDeepLinkedEvent()
}
    }

    @ViewBuilder
    private var timelineRoot: some View {
        if usesSidebarLayout {
            NavigationSplitView {
                timelineSidebarContent
                    .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 520)
            } detail: {
                timelineSidebarDetail
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack {
                content
                    .navigationTitle("Timeline")
                    .routinaTimelineNavigationTitleDisplayMode()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            filterSheetButton
                        }
                    }
                    .navigationDestination(for: UUID.self) { taskID in
                        timelineDetailDestination(taskID: taskID)
                    }
            }
        }
    }

    private var usesSidebarLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    private var visibleTimelineEntryIDs: [UUID] {
        groupedByDay.flatMap { $0.entries.map(\.id) }
    }

    private var latestTimelineEntryID: UUID? {
        groupedByDay.last?.entries.last?.id
    }

    private var invertedGroupedByDay: [TimelineFeature.TimelineSection] {
        groupedByDay.reversed().map { section in
            TimelineFeature.TimelineSection(
                date: section.date,
                entries: Array(section.entries.reversed())
            )
        }
    }

    private var sleepSessionChangeToken: [String] {
        sleepSessions.map { session in
            [
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: ":")
        }
    }

    private var focusSessionChangeToken: [String] {
        focusSessions.map { session in
            [
                session.id.uuidString,
                session.taskID.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.completedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.abandonedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.pausedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.accumulatedPausedSeconds.description,
            ].joined(separator: ":")
        }
    }

    private var sprintFocusSessionChangeToken: [String] {
        sprintFocusSessions.map { session in
            [
                session.id.uuidString,
                session.sprintID.uuidString,
                session.startedAt.timeIntervalSinceReferenceDate.description,
                session.stoppedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.pausedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.accumulatedPausedSeconds.description,
            ].joined(separator: ":")
        }
    }

    private var boardSprintChangeToken: [String] {
        boardSprints.map { sprint in
            [
                sprint.id.uuidString,
                sprint.title,
                sprint.statusRawValue,
                sprint.createdAt.timeIntervalSinceReferenceDate.description,
                sprint.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                sprint.finishedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: ":")
        }
    }

    private var awaySessionChangeToken: [String] {
        awaySessions.map { session in
            [
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.finishedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.state.rawValue,
            ].joined(separator: ":")
        }
    }

    private var fileAttachmentTaskIDs: Set<UUID> {
        Set(fileAttachments.map(\.taskID))
    }

    private var fileAttachmentChangeToken: [String] {
        fileAttachments.map { "\($0.id.uuidString):\($0.taskID.uuidString)" }.sorted()
    }

    private var noteAttachmentNoteIDs: Set<UUID> {
        Set(noteAttachments.map(\.noteID))
    }

    private var eventChangeToken: [String] {
        events.map { event in
            [
                event.id.uuidString,
                event.title ?? "",
                event.notes ?? "",
                event.emoji ?? "",
                event.tagsStorage,
                event.isAllDay.description,
                event.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                event.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                event.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: ":")
        }
    }

    private var emotionLogChangeToken: [String] {
        emotionLogs.map { emotion in
            [
                emotion.id.uuidString,
                emotion.familyRawValue,
                emotion.familyRawValuesStorage,
                emotion.label,
                emotion.labelsStorage,
                emotion.valence.description,
                emotion.arousal.description,
                emotion.intensity.description,
                emotion.bodyAreasStorage,
                emotion.reflection ?? "",
                emotion.createdAt?.timeIntervalSinceReferenceDate.description ?? "",
                emotion.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: ":")
        }
    }

    private var noteChangeToken: [String] {
        notes.map { note in
            [
                note.id.uuidString,
                note.title ?? "",
                note.body ?? "",
                note.tagsStorage,
                note.createdAt?.timeIntervalSinceReferenceDate.description ?? "",
                note.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
                note.imageData?.count.description ?? "",
                note.voiceNoteData?.count.description ?? "",
            ].joined(separator: ":")
        }
    }

    private var noteAttachmentChangeToken: [String] {
        noteAttachments.map { "\($0.id.uuidString):\($0.noteID.uuidString):\($0.fileName):\($0.data.count)" }.sorted()
    }

    private func syncTimelineData() {
        store.send(.setData(
            tasks: tasks,
            logs: logs,
            events: events,
            emotionLogs: emotionLogs,
            notes: notes,
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            boardSprints: boardSprints,
            sleepSessions: sleepSessions,
            placeCheckInSessions: placeCheckInSessions,
            awaySessions: awaySessions,
            fileAttachmentTaskIDs: fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: noteAttachmentNoteIDs
        ))
    }

    private var placeCheckInChangeToken: [String] {
        placeCheckInSessions.map { session in
            [
                session.id.uuidString,
                session.placeName,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.activityRawValue ?? "",
                session.imageData?.count.description ?? "",
            ].joined(separator: ":")
        }
    }

    private var selectedTimelineEntry: TimelineEntry? {
        groupedByDay
            .flatMap(\.entries)
            .first { $0.id == selectedTimelineEntryID }
    }

    private var deepLinkedNotePresentationBinding: Binding<TimelineNoteDeepLinkPresentation?> {
        Binding(
            get: {
                guard !usesSidebarLayout, let noteID = store.deepLinkedNoteID else { return nil }
                return TimelineNoteDeepLinkPresentation(id: noteID)
            },
            set: { presentation in
                if presentation == nil, let noteID = store.deepLinkedNoteID {
                    store.send(.noteDeepLinkPresentationDismissed(noteID))
                }
            }
        )
    }

    private var deepLinkedEventPresentationBinding: Binding<TimelineEventDeepLinkPresentation?> {
        Binding(
            get: {
                guard !usesSidebarLayout, let eventID = store.deepLinkedEventID else { return nil }
                return TimelineEventDeepLinkPresentation(id: eventID)
            },
            set: { presentation in
                if presentation == nil, let eventID = store.deepLinkedEventID {
                    store.send(.eventDeepLinkPresentationDismissed(eventID))
                }
            }
        )
    }

    private func ensureTimelineSelection() {
        selectedTimelineEntryID = TimelineSelectionSupport.resolvedSelection(
            currentSelection: selectedTimelineEntryID,
            visibleEntryIDs: visibleTimelineEntryIDs,
            usesSidebarLayout: usesSidebarLayout
        )
    }

    private func routePendingDeepLinkedNote() {
        guard usesSidebarLayout, let noteID = store.deepLinkedNoteID else { return }
        guard visibleTimelineEntryIDs.contains(noteID) else { return }
        selectedTimelineEntryID = noteID
        store.send(.noteDeepLinkPresentationDismissed(noteID))
    }

    private func routePendingDeepLinkedEvent() {
        guard usesSidebarLayout, let eventID = store.deepLinkedEventID else { return }
        guard visibleTimelineEntryIDs.contains(eventID) else { return }
        selectedTimelineEntryID = eventID
        store.send(.eventDeepLinkPresentationDismissed(eventID))
    }

    private var filterSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isFilterSheetPresented },
            set: { store.send(.setFilterSheet($0)) }
        )
    }

    private var selectedRangeBinding: Binding<TimelineRange> {
        Binding(
            get: { store.selectedRange },
            set: { store.send(.selectedRangeChanged($0)) }
        )
    }

    private var filterTypeBinding: Binding<TimelineFilterType> {
        Binding(
            get: { store.filterType },
            set: { store.send(.filterTypeChanged($0)) }
        )
    }

    private var mediaFilterBinding: Binding<TaskMediaFilter> {
        Binding(
            get: { store.mediaFilter },
            set: { store.send(.mediaFilterChanged($0)) }
        )
    }

    private var groupedByDay: [TimelineFeature.TimelineSection] {
        store.groupedEntries
    }

    private var availableTags: [String] {
        store.availableTags
    }

    private var filterPresentation: TimelineFilterPresentation {
        TimelineFilterPresentation(
            selectedTags: store.effectiveSelectedTags,
            excludedTags: store.excludedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            availableTags: availableTags,
            relatedTagRules: store.relatedTagRules
        )
    }

    private var suggestedRelatedFilterTags: [String] {
        filterPresentation.suggestedRelatedTags(suggestionAnchor: relatedFilterTagSuggestionAnchor)
    }

    private var availableExcludeTags: [String] {
        let baseEntries = TimelineLogic.filteredEntries(
            logs: store.logs,
            tasks: store.tasks,
            events: store.events,
            emotionLogs: store.emotionLogs,
            notes: store.notes,
            focusSessions: store.focusSessions,
            sprintFocusSessions: store.sprintFocusSessions,
            boardSprints: store.boardSprints,
            sleepSessions: store.sleepSessions,
            awaySessions: store.awaySessions,
            placeCheckInSessions: store.placeCheckInSessions,
            fileAttachmentTaskIDs: store.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: store.noteAttachmentNoteIDs,
            range: store.selectedRange,
            filterType: store.filterType,
            mediaFilter: store.mediaFilter,
            now: Date(),
            calendar: calendar
        ).filter { entry in
            HomeFeature.matchesImportanceUrgencyFilter(
                store.selectedImportanceUrgencyFilter,
                importance: entry.importance,
                urgency: entry.urgency
            )
        }

        return filterPresentation.availableExcludeTags(from: baseEntries)
    }

    private var tagRuleBindings: HomeTagRuleBindings {
        HomeTagRuleBindings(
            includeTagMatchMode: Binding(
                get: { store.includeTagMatchMode },
                set: { store.send(.includeTagMatchModeChanged($0)) }
            ),
            excludeTagMatchMode: Binding(
                get: { store.excludeTagMatchMode },
                set: { store.send(.excludeTagMatchModeChanged($0)) }
            )
        )
    }

    private var tagRuleData: HomeTagFilterData {
        filterPresentation.tagRuleData(
            suggestedRelatedTags: suggestedRelatedFilterTags,
            availableExcludeTags: availableExcludeTags
        )
    }

    private var tagRuleActions: HomeTagFilterActions {
        HomeTagFilterActions(
            onShowAllTags: {
                relatedFilterTagSuggestionAnchor = nil
                store.send(.selectedTagsChanged([]))
            },
            onToggleIncludedTag: toggleIncludedTag,
            onAddIncludedTag: addIncludedTag,
            onToggleExcludedTag: toggleExcludedTag
        )
    }

    private func isIncludedTagSelected(_ tag: String) -> Bool {
        filterPresentation.isIncludedTagSelected(tag)
    }

    private func toggleIncludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledIncludedTag(
            tag,
            currentSuggestionAnchor: relatedFilterTagSuggestionAnchor
        )
        relatedFilterTagSuggestionAnchor = mutation.suggestionAnchor
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func addIncludedTag(_ tag: String) {
        guard let mutation = filterPresentation.addedIncludedTag(
            tag,
            currentSuggestionAnchor: relatedFilterTagSuggestionAnchor
        ) else { return }
        relatedFilterTagSuggestionAnchor = mutation.suggestionAnchor
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func toggleExcludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledExcludedTag(tag)
        store.send(.selectedTagsChanged(mutation.selectedTags))
        store.send(.excludedTagsChanged(mutation.excludedTags))
    }

    private var hasActiveFilters: Bool {
        store.hasActiveFilters
    }

    private var hasAnyTimelineRecords: Bool {
        !logs.isEmpty
            || !events.isEmpty
            || !emotionLogs.isEmpty
            || !notes.isEmpty
            || !focusSessions.isEmpty
            || !sprintFocusSessions.isEmpty
            || !awaySessions.isEmpty
            || !sleepSessions.isEmpty
            || !placeCheckInSessions.isEmpty
    }

    private var hasActiveFilterChips: Bool {
        store.selectedRange != .all
            || (store.filterType != .all && !store.filterType.isTimelinePigmentCase)
            || !store.effectiveSelectedTags.isEmpty
            || !store.excludedTags.isEmpty
            || store.selectedImportanceUrgencyFilter != nil
            || store.mediaFilter != .all
    }

    private var timelinePigmentControl: some View {
        TimelinePigmentControl(selection: filterTypeBinding)
    }

    @ViewBuilder
    private var content: some View {
        if !hasAnyTimelineRecords {
            ContentUnavailableView(
                "No timeline entries yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed items, focus sessions, notes, place check-ins, emotions, away sessions, and sleep records will appear here in chronological order.")
            )
        } else {
            VStack(spacing: 0) {
                timelinePigmentControl
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, hasActiveFilterChips ? 0 : 8)

                if hasActiveFilterChips {
                    activeFilterChipBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
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

    private var activeFilterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Clear All") {
                    store.send(.clearFilters)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                if store.selectedRange != .all {
                    compactFilterChip(title: store.selectedRange.rawValue) {
                        store.send(.selectedRangeChanged(.all))
                    }
                }

                if store.filterType != .all && !store.filterType.isTimelinePigmentCase {
                    compactFilterChip(title: store.filterType.rawValue) {
                        store.send(.filterTypeChanged(.all))
                    }
                }

                ForEach(store.effectiveSelectedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "#\(tag)") {
                        var selected = store.effectiveSelectedTags
                        selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
                        store.send(.selectedTagsChanged(selected))
                    }
                }

                if let selectedImportanceUrgencyFilterLabel {
                    compactFilterChip(title: selectedImportanceUrgencyFilterLabel) {
                        store.send(.selectedImportanceUrgencyFilterChanged(nil))
                    }
                }

                ForEach(store.excludedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "not #\(tag)", tintColor: .red) {
                        store.send(.excludedTagsChanged(store.excludedTags.filter { $0 != tag }))
                    }
                }
            }
        }
    }

    private func compactFilterChip(
        title: String,
        tintColor: Color = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.medium))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: tintColor, tintOpacity: 0.12, interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var timelineList: some View {
        List {
            ForEach(invertedGroupedByDay, id: \.date) { section in
                Section {
                    ForEach(section.entries) { entry in
                        timelineRow(entry)
                            .id(entry.id)
                            .scaleEffect(x: 1, y: -1)
                    }
                } header: {
                    Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                        .scaleEffect(x: 1, y: -1)
                }
            }
        }
        .listStyle(.plain)
        .scaleEffect(x: 1, y: -1)
    }

    @ViewBuilder
    private var timelineSidebarContent: some View {
        VStack(spacing: 0) {
            timelinePigmentControl
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, hasActiveFilterChips ? 0 : 8)

            if hasActiveFilterChips {
                activeFilterChipBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }

                if !hasAnyTimelineRecords {
                    ContentUnavailableView(
                        "No timeline entries yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed items, focus sessions, notes, place check-ins, emotions, away sessions, and sleep records will appear here in chronological order.")
                    )
                } else if groupedByDay.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try a different time range or filter.")
                )
            } else {
                List(selection: $selectedTimelineEntryID) {
                    ForEach(invertedGroupedByDay, id: \.date) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                timelineRowContent(entry)
                                    .id(entry.id)
                                    .tag(entry.id)
                                    .scaleEffect(x: 1, y: -1)
                            }
                        } header: {
                            Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                                .scaleEffect(x: 1, y: -1)
                        }
                    }
                }
                .listStyle(.plain)
                .scaleEffect(x: 1, y: -1)
            }
        }
        .navigationTitle("Timeline")
        .routinaTimelineNavigationTitleDisplayMode()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                filterSheetButton
            }
        }
    }

    @ViewBuilder
    private var timelineSidebarDetail: some View {
        if let taskID = selectedTimelineEntry?.taskID {
            timelineDetailDestination(taskID: taskID)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isEmotion, let emotion = emotionLog(for: selectedTimelineEntry) {
            EmotionLogDetailView(emotion: emotion)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isEvent, let event = event(for: selectedTimelineEntry) {
            RoutineEventDetailView(event: event)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isNote, let note = note(for: selectedTimelineEntry) {
            RoutineNoteDetailView(
                note: note,
                attachments: noteAttachments(for: note),
                onDelete: {
                    if selectedTimelineEntryID == note.id {
                        selectedTimelineEntryID = nil
                    }
                }
            )
        } else if let selectedTimelineEntry,
                  selectedTimelineEntry.isPlaceCheckIn,
                  let session = placeCheckInSession(for: selectedTimelineEntry) {
            PlaceCheckInSessionDetailView(session: session)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isSleep {
            ContentUnavailableView(
                "Sleep record",
                systemImage: "bed.double.fill",
                description: Text(timelineSubtitle(for: selectedTimelineEntry))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isFocus {
            ContentUnavailableView(
                "Focus record",
                systemImage: "timer",
                description: Text(timelineSubtitle(for: selectedTimelineEntry))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let selectedTimelineEntry, selectedTimelineEntry.isPlaceCheckIn {
            ContentUnavailableView(
                "Place check-in not found",
                systemImage: "mappin.and.ellipse",
                description: Text("The selected place check-in is no longer available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Select a timeline entry",
                systemImage: "clock.arrow.circlepath",
                description: Text("Choose an item from the sidebar to see its detail.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var filterSheetButton: some View {
        Button {
            store.send(.setFilterSheet(true))
        } label: {
            Image(
                systemName: hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }

    private var timelineFiltersSheet: some View {
        NavigationStack {
            List {
                Section("Range") {
                    Picker("Range", selection: selectedRangeBinding) {
                        ForEach(TimelineRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if tasks.contains(where: { $0.isOneOffTask }) || !events.isEmpty || !notes.isEmpty || !focusSessions.isEmpty || !sprintFocusSessions.isEmpty || !sleepSessions.isEmpty || !awaySessions.isEmpty || !placeCheckInSessions.isEmpty {
                    Section("Type") {
                        Picker("Type", selection: filterTypeBinding) {
                            ForEach(TimelineFilterType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: Binding(
                        get: { store.selectedImportanceUrgencyFilter },
                        set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
                    ),
                    summary: importanceUrgencyFilterSummary
                )

                Section("Media") {
                    Picker("Media", selection: mediaFilterBinding) {
                        ForEach(TaskMediaFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                }

                HomeFiltersTagRulesSection(
                    bindings: tagRuleBindings,
                    data: tagRuleData,
                    actions: tagRuleActions,
                    labels: HomeTagFilterSectionLabels(
                        includedTitle: "Show items with",
                        includedPickerTitle: "Show items with",
                        excludedTitle: "Hide items with",
                        excludedPickerTitle: "Hide items with"
                    )
                )

                HomeFiltersClearSection(
                    hasActiveOptionalFilters: hasActiveFilters,
                    onClearOptionalFilters: { store.send(.clearFilters) }
                )
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        store.send(.setFilterSheet(false))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            let selected = store.effectiveSelectedTags.filter { RoutineTag.contains($0, in: newValue) }
            store.send(.selectedTagsChanged(selected))
        }
    }

    private var selectedImportanceUrgencyFilterLabel: String? {
        guard let filter = ImportanceUrgencyFilterCell.normalized(store.selectedImportanceUrgencyFilter) else {
            return nil
        }
        return "\(filter.importance.shortTitle)/\(filter.urgency.shortTitle)+"
    }

    private var importanceUrgencyFilterSummary: String {
        guard let filter = ImportanceUrgencyFilterCell.normalized(store.selectedImportanceUrgencyFilter) else {
            return "Showing done items across all importance and urgency levels."
        }
        return "Showing done items from tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    @ViewBuilder
    private func timelineRow(_ entry: TimelineEntry) -> some View {
        if let taskID = entry.taskID {
            NavigationLink(value: taskID) {
                timelineRowContent(entry)
            }
        } else if entry.isEmotion, let emotion = emotionLog(for: entry) {
            NavigationLink {
                EmotionLogDetailView(emotion: emotion)
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isEvent, let event = event(for: entry) {
            NavigationLink {
                RoutineEventDetailView(event: event)
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isNote, let note = note(for: entry) {
            NavigationLink {
                RoutineNoteDetailView(
                    note: note,
                    attachments: noteAttachments(for: note)
                )
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isPlaceCheckIn, let session = placeCheckInSession(for: entry) {
            NavigationLink {
                PlaceCheckInSessionDetailView(session: session)
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isSleep {
            Button {
                RoutinaDeepLinkDispatcher.open(.sleep(entry.id))
            } label: {
                timelineRowContent(entry)
            }
            .buttonStyle(.plain)
        } else {
            timelineRowContent(entry)
        }
    }

    private func timelineRowContent(_ entry: TimelineEntry) -> some View {
        HStack(spacing: 12) {
            if timelineRowVisibility.shows(.icon) {
                Text(entry.taskEmoji)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if timelineRowVisibility.shows(.subtitle) {
                    Text(timelineSubtitle(for: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if timelineRowVisibility.shows(.kindBadge) {
                Text(timelineKindLabel(for: entry))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .routinaGlassPill(tint: timelineKindColor(for: entry), tintOpacity: 0.15)
                    .foregroundStyle(timelineKindColor(for: entry))
            }
        }
        .padding(.vertical, 2)
    }

    private var timelineRowVisibility: HomeTimelineRowVisibility {
        HomeTimelineRowVisibility(storageRawValue: timelineRowHiddenFieldsRawValue)
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

    private func note(for entry: TimelineEntry) -> RoutineNote? {
        notes.first { $0.id == entry.id }
    }

    private func event(for entry: TimelineEntry) -> RoutineEvent? {
        events.first { $0.id == entry.id }
    }

    private func emotionLog(for entry: TimelineEntry) -> EmotionLog? {
        emotionLogs.first { $0.id == entry.id }
    }

    private func placeCheckInSession(for entry: TimelineEntry) -> PlaceCheckInSession? {
        placeCheckInSessions.first { $0.id == entry.id }
    }

    private func noteAttachments(for note: RoutineNote) -> [RoutineNoteAttachment] {
        noteAttachments
            .filter { $0.noteID == note.id }
            .sorted { $0.createdAt < $1.createdAt }
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
    private func deepLinkedEventDetail(eventID: UUID) -> some View {
        if let event = events.first(where: { $0.id == eventID }) {
            RoutineEventDetailView(event: event)
        } else {
            ContentUnavailableView(
                "Event not found",
                systemImage: "calendar",
                description: Text("The selected event is no longer available.")
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
        let defaultSelectedDate = (detailTask.isCompletedOneOff || detailTask.isCanceledOneOff)
            ? calendar.startOfDay(for: detailTask.lastDone ?? detailTask.canceledAt ?? now)
            : calendar.startOfDay(for: now)

        return TaskDetailFeature.State(
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
    }

}

private struct TimelineNoteDeepLinkPresentation: Identifiable, Equatable {
    let id: UUID
}

private struct TimelineEventDeepLinkPresentation: Identifiable, Equatable {
    let id: UUID
}
