import ComposableArchitecture
import SwiftData
import SwiftUI

private struct TimelineDataSnapshot {
    var tasks: [RoutineTask] = []
    var logs: [RoutineLog] = []
    var fileAttachments: [RoutineAttachment] = []
    var events: [RoutineEvent] = []
    var emotionLogs: [EmotionLog] = []
    var notes: [RoutineNote] = []
    var noteAttachments: [RoutineNoteAttachment] = []
    var focusSessions: [FocusSession] = []
    var sprintFocusSessions: [SprintFocusSessionRecord] = []
    var boardSprints: [BoardSprintRecord] = []
    var sleepSessions: [SleepSession] = []
    var awaySessions: [AwaySession] = []
    var placeCheckInSessions: [PlaceCheckInSession] = []

    @MainActor
    static func fetch(from context: ModelContext) throws -> Self {
        Self(
            tasks: try context.fetch(FetchDescriptor<RoutineTask>()),
            logs: try context.fetch(FetchDescriptor<RoutineLog>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )),
            fileAttachments: try context.fetch(FetchDescriptor<RoutineAttachment>()),
            events: try context.fetch(FetchDescriptor<RoutineEvent>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            emotionLogs: try context.fetch(FetchDescriptor<EmotionLog>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )),
            notes: try context.fetch(FetchDescriptor<RoutineNote>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )),
            noteAttachments: try context.fetch(FetchDescriptor<RoutineNoteAttachment>()),
            focusSessions: try context.fetch(FetchDescriptor<FocusSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            sprintFocusSessions: try context.fetch(FetchDescriptor<SprintFocusSessionRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            boardSprints: try context.fetch(FetchDescriptor<BoardSprintRecord>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )),
            sleepSessions: try context.fetch(FetchDescriptor<SleepSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            awaySessions: try context.fetch(FetchDescriptor<AwaySession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            placeCheckInSessions: try context.fetch(FetchDescriptor<PlaceCheckInSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            ))
        )
    }
}

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var dataSnapshot = TimelineDataSnapshot()
    @State private var hasDeferredDataSnapshotRefresh = false
    @State private var deferredDataSnapshotRefreshTask: Task<Void, Never>?
    @State private var relatedFilterTagSuggestionAnchor: String?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacTimelineQuickFiltersVisible.rawValue,
        store: SharedDefaults.app
    ) private var areMacTimelineQuickFiltersVisible = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTimelineRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var timelineRowHiddenFieldsRawValue = ""
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingStatsSleepTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isStatsSleepTabEnabled = false
    @State private var editingAwaySession: AwaySession?

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
    private var events: [RoutineEvent] { dataSnapshot.events }
    private var emotionLogs: [EmotionLog] { dataSnapshot.emotionLogs }
    private var notes: [RoutineNote] { dataSnapshot.notes }
    private var noteAttachments: [RoutineNoteAttachment] { dataSnapshot.noteAttachments }
    private var focusSessions: [FocusSession] { dataSnapshot.focusSessions }
    private var sprintFocusSessions: [SprintFocusSessionRecord] { dataSnapshot.sprintFocusSessions }
    private var boardSprints: [BoardSprintRecord] { dataSnapshot.boardSprints }
    private var sleepSessions: [SleepSession] { dataSnapshot.sleepSessions }
    private var awaySessions: [AwaySession] { dataSnapshot.awaySessions }
    private var placeCheckInSessions: [PlaceCheckInSession] { dataSnapshot.placeCheckInSessions }

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
        store.send(.setData(
            tasks: tasks,
            logs: logs,
            events: events,
            emotionLogs: emotionLogs,
            notes: isNotesEnabled ? notes : [],
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
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
            get: { effectiveFilterType },
            set: {
                store.send(.filterTypeChanged(
                    $0.normalized(
                        includingEventEmotion: areMacEventEmotionActionsEnabled,
                        includingPlaces: isPlacesEnabled,
                        includingNotes: isNotesEnabled,
                        includingAway: isAwayEnabled,
                        includingSleep: includesSleepTimelineFilters
                    )
                ))
            }
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

    private var latestTimelineEntryID: UUID? {
        groupedByDay.first?.entries.first?.id
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
        filterPresentation.availableExcludeTags()
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
        store.selectedRange != .all
            || effectiveFilterType != .all
            || !store.effectiveSelectedTags.isEmpty
            || !store.excludedTags.isEmpty
            || store.selectedImportanceUrgencyFilter != nil
            || store.mediaFilter != .all
    }

    private var effectiveFilterType: TimelineFilterType {
        store.filterType.normalized(
            includingEventEmotion: areMacEventEmotionActionsEnabled,
            includingPlaces: isPlacesEnabled,
            includingNotes: isNotesEnabled,
            includingAway: isAwayEnabled,
            includingSleep: includesSleepTimelineFilters
        )
    }

    private var includesSleepTimelineFilters: Bool {
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

    private var showsTypeFilterSection: Bool {
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
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Range",
                        options: TimelineRange.allCases,
                        selection: selectedRangeBinding
                    ) { range in
                        Text(range.rawValue)
                    }
                }

                if showsTypeFilterSection {
                    Section("Type") {
                        RoutinaGlassSegmentedControl(
                            accessibilityLabel: "Type",
                            options: TimelineFilterType.visibleCases(
                                includingEventEmotion: areMacEventEmotionActionsEnabled,
                                includingPlaces: isPlacesEnabled,
                                includingNotes: isNotesEnabled,
                                includingAway: isAwayEnabled,
                                includingSleep: includesSleepTimelineFilters
                            ),
                            selection: filterTypeBinding
                        ) { type in
                            Text(type.title)
                        }
                    }
                }

                Section("Media") {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Media",
                        options: TaskMediaFilter.allCases,
                        selection: mediaFilterBinding,
                        minimumSegmentWidth: 92
                    ) { filter in
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }

                if !availableTags.isEmpty {
                    Section("Tag Rules") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Show items with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                RoutinaGlassSegmentedControl(
                                    accessibilityLabel: "Show items with",
                                    options: RoutineTagMatchMode.allCases,
                                    selection: Binding(
                                        get: { store.includeTagMatchMode },
                                        set: { store.send(.includeTagMatchModeChanged($0)) }
                                    ),
                                    fillsAvailableWidth: true
                                ) { mode in
                                    Text(mode.rawValue)
                                }
                                .frame(maxWidth: 180)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if store.effectiveSelectedTags.isEmpty {
                                        timelineTagButton(title: "All Tags", isSelected: true) {
                                            relatedFilterTagSuggestionAnchor = nil
                                            store.send(.selectedTagsChanged([]))
                                        }
                                    } else {
                                        ForEach(store.effectiveSelectedTags.sorted(), id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: true) {
                                                toggleIncludedTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if !suggestedRelatedFilterTags.isEmpty {
                                Text("Suggested")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggestedRelatedFilterTags, id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: false) {
                                                addIncludedTag(tag)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }

                            Text("Add more")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableTags.filter { !isIncludedTagSelected($0) }, id: \.self) { tag in
                                        timelineTagButton(title: "#\(tag)", isSelected: false) {
                                            toggleIncludedTag(tag)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Hide items with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                RoutinaGlassSegmentedControl(
                                    accessibilityLabel: "Hide items with",
                                    options: RoutineTagMatchMode.allCases,
                                    selection: Binding(
                                        get: { store.excludeTagMatchMode },
                                        set: { store.send(.excludeTagMatchModeChanged($0)) }
                                    ),
                                    fillsAvailableWidth: true
                                ) { mode in
                                    Text(mode.rawValue)
                                }
                                .frame(maxWidth: 180)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if store.excludedTags.isEmpty {
                                        Text("No hidden tags")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(store.excludedTags.sorted(), id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: true, selectedColor: .red) {
                                                toggleExcludedTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if !availableExcludeTags.isEmpty {
                                Text("Add tags to hide")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(availableExcludeTags.filter { tag in
                                            !store.excludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                                        }, id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: false, selectedColor: .red) {
                                                toggleExcludedTag(tag)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }

                if hasActiveFilters {
                    Section {
                        Button("Clear Filters") {
                            store.send(.clearFilters)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        store.send(.setFilterSheet(false))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            store.send(.selectedTagsChanged(store.effectiveSelectedTags.filter { RoutineTag.contains($0, in: newValue) }))
        }
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
        } else if entry.isAway, let session = awaySession(for: entry) {
            Button {
                editingAwaySession = session
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
                    .routinaScrollingPillFill(
                        tint: timelineKindColor(for: entry),
                        tintOpacity: 0.15
                    )
                    .foregroundStyle(timelineKindColor(for: entry))
            }
        }
        .padding(.vertical, 2)
    }

    private var timelineRowVisibility: HomeTimelineRowVisibility {
        HomeTimelineRowVisibility(storageRawValue: timelineRowHiddenFieldsRawValue)
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
        guard isPlacesEnabled else { return nil }
        return placeCheckInSessions.first { $0.id == entry.id }
    }

    private func awaySession(for entry: TimelineEntry) -> AwaySession? {
        awaySessions.first { $0.id == entry.id }
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

    private func timelineTagButton(
        title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .routinaGlassPill(
                    tint: isSelected ? selectedColor : .secondary,
                    tintOpacity: isSelected ? 0.16 : 0.10,
                    interactive: true
                )
                .foregroundStyle(isSelected ? selectedColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct TimelineNoteDeepLinkPresentation: Identifiable, Equatable {
    let id: UUID
}
