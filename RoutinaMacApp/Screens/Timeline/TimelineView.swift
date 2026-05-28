import ComposableArchitecture
import SwiftData
import SwiftUI

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RoutineLog.timestamp, order: .reverse) private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]
    @Query private var fileAttachments: [RoutineAttachment]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]
    @Query(sort: \EmotionLog.createdAt, order: .reverse) private var emotionLogs: [EmotionLog]
    @Query(sort: \RoutineNote.createdAt, order: .reverse) private var notes: [RoutineNote]
    @Query private var noteAttachments: [RoutineNoteAttachment]
    @Query(sort: \SleepSession.startedAt, order: .reverse) private var sleepSessions: [SleepSession]
    @Query(sort: \PlaceCheckInSession.startedAt, order: .reverse) private var placeCheckInSessions: [PlaceCheckInSession]
    @State private var relatedFilterTagSuggestionAnchor: String?

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
            }
            .frame(minWidth: 560, minHeight: 420)
        }
}
.task {
    syncTimelineData()
}
.onChange(of: tasks) { _, _ in
    syncTimelineData()
}
.onChange(of: logs) { _, _ in
    syncTimelineData()
}
.onChange(of: sleepSessionChangeToken) { _, _ in
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

    private var deepLinkedNotePresentationBinding: Binding<TimelineNoteDeepLinkPresentation?> {
        Binding(
            get: {
                guard let noteID = store.deepLinkedNoteID else { return nil }
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
            notes: notes,
            sleepSessions: sleepSessions,
            placeCheckInSessions: placeCheckInSessions,
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
        store.hasActiveFilters
    }

    @ViewBuilder
    private var content: some View {
        if logs.isEmpty && notes.isEmpty && sleepSessions.isEmpty && placeCheckInSessions.isEmpty {
            ContentUnavailableView(
                "No timeline entries yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed items, notes, place check-ins, and sleep records will appear here in chronological order.")
            )
        } else {
            VStack(spacing: 0) {
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
                    Picker("Range", selection: selectedRangeBinding) {
                        ForEach(TimelineRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if tasks.contains(where: { $0.isOneOffTask }) || !events.isEmpty || !notes.isEmpty || !sleepSessions.isEmpty || !placeCheckInSessions.isEmpty {
                    Section("Type") {
                        Picker("Type", selection: filterTypeBinding) {
                            ForEach(TimelineFilterType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                Section("Media") {
                    Picker("Media", selection: mediaFilterBinding) {
                        ForEach(TaskMediaFilter.allCases) { filter in
                            Label(filter.title, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if !availableTags.isEmpty {
                    Section("Tag Rules") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Show items with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Picker("Show items with", selection: Binding(
                                    get: { store.includeTagMatchMode },
                                    set: { store.send(.includeTagMatchModeChanged($0)) }
                                )) {
                                    ForEach(RoutineTagMatchMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
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
                                Picker("Hide items with", selection: Binding(
                                    get: { store.excludeTagMatchMode },
                                    set: { store.send(.excludeTagMatchModeChanged($0)) }
                                )) {
                                    ForEach(RoutineTagMatchMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
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
                RoutineNoteDetailView(note: note, attachments: noteAttachments(for: note))
            } label: {
                timelineRowContent(entry)
            }
        } else if entry.isPlaceCheckIn, let session = placeCheckInSession(for: entry) {
            NavigationLink {
                PlaceCheckInSessionDetailView(session: session)
            } label: {
                timelineRowContent(entry)
            }
        } else {
            timelineRowContent(entry)
        }
    }

    private func timelineRowContent(_ entry: TimelineEntry) -> some View {
        HStack(spacing: 12) {
            Text(entry.taskEmoji)
                .font(.title2)
                .frame(width: 36, height: 36)
                .routinaGlassCard(cornerRadius: 8, tint: .secondary, tintOpacity: 0.06)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.taskName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(timelineSubtitle(for: entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(timelineKindLabel(for: entry))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .routinaGlassPill(tint: timelineKindColor(for: entry), tintOpacity: 0.15)
                .foregroundStyle(timelineKindColor(for: entry))
        }
        .padding(.vertical, 2)
    }

    private func timelineKindLabel(for entry: TimelineEntry) -> String {
        if entry.isSleep {
            return "Sleep"
        }
        if entry.isEmotion {
            return "Emotion"
        }
        if entry.isEvent {
            return "Event"
        }
        if entry.isNote {
            return "Note"
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
        if entry.isEmotion {
            return .pink
        }
        if entry.isEvent {
            return .teal
        }
        if entry.isNote {
            return .blue
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
            RoutineNoteDetailView(note: note, attachments: noteAttachments(for: note))
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
