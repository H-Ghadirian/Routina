import Foundation

enum TimelineRange: String, CaseIterable, Identifiable, Sendable, Equatable, Codable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case all = "All"
    var id: Self { self }
}

enum TimelineFilterType: String, CaseIterable, Identifiable, Sendable, Equatable, Codable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"
    case records = "Records"
    case focus = "Focus"
    case events = "Events"
    case emotions = "Emotions"
    case notes = "Notes"
    case places = "Places"
    case sleep = "Sleep"
    case away = "Away"
    case done = "Done"
    case missed = "Missed"
    case canceled = "Canceled"
    var id: Self { self }

    var title: String {
        switch self {
        case .records:
            return "Tracking"
        default:
            return rawValue
        }
    }

    static let timelinePigmentCases: [TimelineFilterType] = [
        .all,
        .routines,
        .todos,
        .records,
        .focus,
        .notes,
        .places,
        .emotions,
        .sleep,
        .away,
    ]

    var isTimelinePigmentCase: Bool {
        Self.timelinePigmentCases.contains(self)
    }

    static let contentTypeCases: [TimelineFilterType] = [
        .all,
        .routines,
        .todos,
        .records,
        .focus,
        .events,
        .emotions,
        .notes,
        .places,
        .sleep,
        .away,
    ]

    static let statusCases: [TimelineFilterType] = [
        .all,
        .done,
        .missed,
        .canceled,
    ]

    static func visibleCases(
        includingEventEmotion includeEventEmotion: Bool,
        includingPlaces includePlaces: Bool = true,
        includingNotes includeNotes: Bool = true,
        includingAway includeAway: Bool = true,
        includingSleep includeSleep: Bool = true
    ) -> [TimelineFilterType] {
        visibleCases(
            from: allCases,
            includingEventEmotion: includeEventEmotion,
            includingPlaces: includePlaces,
            includingNotes: includeNotes,
            includingAway: includeAway,
            includingSleep: includeSleep
        )
    }

    static func visibleContentTypeCases(
        includingEventEmotion includeEventEmotion: Bool,
        includingPlaces includePlaces: Bool = true,
        includingNotes includeNotes: Bool = true,
        includingAway includeAway: Bool = true,
        includingSleep includeSleep: Bool = true
    ) -> [TimelineFilterType] {
        visibleCases(
            from: contentTypeCases,
            includingEventEmotion: includeEventEmotion,
            includingPlaces: includePlaces,
            includingNotes: includeNotes,
            includingAway: includeAway,
            includingSleep: includeSleep
        )
    }

    static func visibleTimelinePigmentCases(
        includingEventEmotion includeEventEmotion: Bool,
        includingPlaces includePlaces: Bool = true,
        includingNotes includeNotes: Bool = true,
        includingAway includeAway: Bool = true,
        includingSleep includeSleep: Bool = true
    ) -> [TimelineFilterType] {
        visibleCases(
            from: timelinePigmentCases,
            includingEventEmotion: includeEventEmotion,
            includingPlaces: includePlaces,
            includingNotes: includeNotes,
            includingAway: includeAway,
            includingSleep: includeSleep
        )
    }

    static func visibleCases(
        from cases: [TimelineFilterType],
        includingEventEmotion includeEventEmotion: Bool,
        includingPlaces includePlaces: Bool = true,
        includingNotes includeNotes: Bool = true,
        includingAway includeAway: Bool = true,
        includingSleep includeSleep: Bool = true
    ) -> [TimelineFilterType] {
        cases.filter { type in
            (includeEventEmotion || !type.isEventOrEmotion)
                && (includePlaces || type != .places)
                && (includeNotes || type != .notes)
                && (includeAway || type != .away)
                && (includeSleep || type != .sleep)
        }
    }

    var isEventOrEmotion: Bool {
        self == .events || self == .emotions
    }

    var isStatusCase: Bool {
        Self.statusCases.contains(self) && self != .all
    }

    func normalized(
        includingEventEmotion includeEventEmotion: Bool,
        includingPlaces includePlaces: Bool = true,
        includingNotes includeNotes: Bool = true,
        includingAway includeAway: Bool = true,
        includingSleep includeSleep: Bool = true
    ) -> TimelineFilterType {
        guard includeEventEmotion || !isEventOrEmotion else { return .all }
        guard includePlaces || self != .places else { return .all }
        guard includeNotes || self != .notes else { return .all }
        guard includeAway || self != .away else { return .all }
        guard includeSleep || self != .sleep else { return .all }
        return self
    }
}

enum TimelineEntryType: Equatable {
    case task
    case event
    case emotion
    case note
    case focus
    case sleep
    case placeCheckIn
    case away
}

struct TimelineEntry: Identifiable, Equatable {
    let id: UUID
    let taskID: UUID?
    let timestamp: Date
    let startTimestamp: Date?
    let endTimestamp: Date?
    let taskName: String
    let taskEmoji: String
    let tags: [String]
    let hasImage: Bool
    let hasFileAttachment: Bool
    let hasVoiceNote: Bool
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let taskType: RoutineTaskType?
    let isOneOff: Bool
    let kind: RoutineLogKind
    let entryType: TimelineEntryType
    let durationSeconds: TimeInterval?
    let activityTitle: String?
    let searchableText: String

    init(
        id: UUID,
        taskID: UUID?,
        timestamp: Date,
        startTimestamp: Date? = nil,
        endTimestamp: Date? = nil,
        taskName: String,
        taskEmoji: String,
        tags: [String],
        hasImage: Bool = false,
        hasFileAttachment: Bool = false,
        hasVoiceNote: Bool = false,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        taskType: RoutineTaskType? = nil,
        isOneOff: Bool,
        kind: RoutineLogKind,
        entryType: TimelineEntryType = .task,
        durationSeconds: TimeInterval? = nil,
        activityTitle: String? = nil,
        searchableText: String? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.timestamp = timestamp
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.taskName = taskName
        self.taskEmoji = taskEmoji
        self.tags = tags
        self.hasImage = hasImage
        self.hasFileAttachment = hasFileAttachment
        self.hasVoiceNote = hasVoiceNote
        self.importance = importance
        self.urgency = urgency
        self.taskType = taskType
        self.isOneOff = isOneOff
        self.kind = kind
        self.entryType = entryType
        self.durationSeconds = durationSeconds
        self.activityTitle = activityTitle
        self.searchableText = searchableText ?? Self.defaultSearchableText(
            taskName: taskName,
            taskEmoji: taskEmoji,
            activityTitle: activityTitle
        )
    }

    private static func defaultSearchableText(
        taskName: String,
        taskEmoji: String,
        activityTitle: String?
    ) -> String {
        [taskName, taskEmoji, activityTitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var isSleep: Bool {
        entryType == .sleep
    }

    var isEmotion: Bool {
        entryType == .emotion
    }

    var isEvent: Bool {
        entryType == .event
    }

    var isNote: Bool {
        entryType == .note
    }

    var isStatusNote: Bool {
        isNote && RoutineTag.contains("Status", in: tags)
    }

    var isFocus: Bool {
        entryType == .focus
    }

    var isPlaceCheckIn: Bool {
        entryType == .placeCheckIn
    }

    var isAway: Bool {
        entryType == .away
    }

    var taskKindLabel: String {
        switch taskType {
        case .routine:
            return "Routine"
        case .todo:
            return "Todo"
        case .record:
            return "Tracking"
        case nil:
            return isOneOff ? "Todo" : "Routine"
        }
    }
}

enum TimelineEntryKindPresentation {
    static func label(for entry: TimelineEntry) -> String {
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
            return entry.taskKindLabel
        case .fulfilled:
            return "Fulfilled"
        case .canceled:
            return "Canceled"
        case .missed:
            return "Missed"
        }
    }
}

enum TimelineLogic {
    static func filteredEntries(
        logs: [RoutineLog],
        tasks: [RoutineTask],
        events: [RoutineEvent] = [],
        emotionLogs: [EmotionLog] = [],
        notes: [RoutineNote] = [],
        focusSessions: [FocusSession] = [],
        sprintFocusSessions: [SprintFocusSessionRecord] = [],
        boardSprints: [BoardSprintRecord] = [],
        sleepSessions: [SleepSession] = [],
        placeCheckInSessions: [PlaceCheckInSession] = [],
        awaySessions: [AwaySession] = [],
        fileAttachmentTaskIDs: Set<UUID> = [],
        noteAttachmentNoteIDs: Set<UUID> = [],
        range: TimelineRange,
        filterType: TimelineFilterType,
        mediaFilter: TaskMediaFilter = .all,
        now: Date,
        calendar: Calendar
        ) -> [TimelineEntry] {
        let lookup = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let resolvedLogs = logsIncludingLastDoneFallbacks(
            logs: logs,
            tasks: tasks,
            calendar: calendar
        )
        let cutoff: Date? = {
            switch range {
            case .today: return calendar.startOfDay(for: now)
            case .week: return calendar.date(byAdding: .day, value: -7, to: now)
            case .month: return calendar.date(byAdding: .month, value: -1, to: now)
            case .all: return nil
            }
        }()

        let logEntries = resolvedLogs.compactMap { log -> TimelineEntry? in
            guard let timestamp = log.timestamp else { return nil }
            guard log.kind != .fulfilled else { return nil }
            if let cutoff, timestamp < cutoff { return nil }

            let task = lookup[log.taskID]
            let taskType = task?.scheduleMode.taskType
            let hasImage = task?.hasImage ?? false
            let hasFileAttachment = fileAttachmentTaskIDs.contains(log.taskID)
            let hasVoiceNote = task?.hasVoiceNote ?? false

            guard HomeDisplayFilterSupport.matchesMediaFilter(
                mediaFilter,
                hasImage: hasImage,
                hasFileAttachment: hasFileAttachment,
                hasVoiceNote: hasVoiceNote
            ) else {
                return nil
            }

            switch filterType {
            case .all: break
            case .routines: if taskType != .routine { return nil }
            case .todos: if taskType != .todo { return nil }
            case .records: if taskType != .record { return nil }
            case .events: return nil
            case .emotions: return nil
            case .notes: return nil
            case .focus: return nil
            case .places: return nil
            case .sleep: return nil
            case .away: return nil
            case .done: if log.kind != .completed { return nil }
            case .missed: if log.kind != .missed { return nil }
            case .canceled: if log.kind != .canceled { return nil }
            }

            return TimelineEntry(
                id: log.id,
                taskID: log.taskID,
                timestamp: timestamp,
                taskName: task?.name ?? "Deleted Routine",
                taskEmoji: task?.emoji ?? "🗑️",
                tags: task?.tags ?? [],
                hasImage: hasImage,
                hasFileAttachment: hasFileAttachment,
                hasVoiceNote: hasVoiceNote,
                importance: task?.importance ?? .level2,
                urgency: task?.urgency ?? .level2,
                taskType: taskType,
                isOneOff: taskType == .todo,
                kind: log.kind
            )
        }

        let eventEntries = events.compactMap { event -> TimelineEntry? in
            guard filterType == .all || filterType == .events,
                  mediaFilter == .all
            else {
                return nil
            }

            let timestamp = event.startedAt ?? event.createdAt ?? event.updatedAt ?? Date.distantPast
            if let cutoff, timestamp < cutoff { return nil }

            return TimelineEntry(
                id: event.id,
                taskID: nil,
                timestamp: timestamp,
                startTimestamp: event.startedAt,
                endTimestamp: event.endedAt,
                taskName: event.displayTitle,
                taskEmoji: event.displayEmoji,
                tags: event.tags,
                isOneOff: false,
                kind: .completed,
                entryType: .event,
                searchableText: searchableText(for: event)
            )
        }

        let emotionEntries = emotionLogs.compactMap { emotion -> TimelineEntry? in
            guard filterType == .all || filterType == .emotions,
                  mediaFilter == .all
            else {
                return nil
            }

            let timestamp = emotion.createdAt ?? emotion.updatedAt ?? Date.distantPast
            if let cutoff, timestamp < cutoff { return nil }

            return TimelineEntry(
                id: emotion.id,
                taskID: nil,
                timestamp: timestamp,
                taskName: emotion.displayLabel.capitalized,
                taskEmoji: "◎",
                tags: [],
                isOneOff: false,
                kind: .completed,
                entryType: .emotion,
                activityTitle: "\(emotion.familiesDisplayTitle) · \(emotion.clampedIntensity)/5",
                searchableText: searchableText(for: emotion)
            )
        }

        let noteEntries = notes.compactMap { note -> TimelineEntry? in
            let timestamp = note.createdAt ?? note.updatedAt ?? Date.distantPast
            if let cutoff, timestamp < cutoff { return nil }

            let hasFileAttachment = noteAttachmentNoteIDs.contains(note.id)
            guard filterType == .all || filterType == .notes,
                  HomeDisplayFilterSupport.matchesMediaFilter(
                    mediaFilter,
                    hasImage: note.hasImage,
                    hasFileAttachment: hasFileAttachment,
                    hasVoiceNote: note.hasVoiceNote
                  )
            else {
                return nil
            }

            let isStatusNote = RoutineTag.contains("Status", in: note.tags)

            return TimelineEntry(
                id: note.id,
                taskID: nil,
                timestamp: timestamp,
                taskName: note.displayTitle,
                taskEmoji: isStatusNote ? "💬" : "📝",
                tags: note.tags,
                hasImage: note.hasImage,
                hasFileAttachment: hasFileAttachment,
                hasVoiceNote: note.hasVoiceNote,
                isOneOff: false,
                kind: .completed,
                entryType: .note,
                searchableText: searchableText(for: note)
            )
        }

        let focusEntries = focusSessions.compactMap { session -> TimelineEntry? in
            guard filterType == .all || filterType == .focus,
                  mediaFilter == .all,
                  session.state != .abandoned,
                  let startedAt = session.startedAt
            else {
                return nil
            }

            if let cutoff, startedAt < cutoff { return nil }

            let task = session.isTaskFocus ? lookup[session.taskID] : nil
            let title: String
            let emoji: String
            let tags: [String]
            let importance: RoutineTaskImportance
            let urgency: RoutineTaskUrgency
            let isOneOff: Bool
            let entryTaskID: UUID?

            if let tagName = session.focusTagName {
                title = "#\(tagName)"
                emoji = "⏱️"
                tags = [tagName]
                importance = .level2
                urgency = .level2
                isOneOff = false
                entryTaskID = nil
            } else if session.isUnassigned {
                title = "Unassigned focus"
                emoji = "⏱️"
                tags = []
                importance = .level2
                urgency = .level2
                isOneOff = false
                entryTaskID = nil
            } else {
                title = task?.name ?? "Deleted Routine"
                emoji = task?.emoji ?? "⏱️"
                tags = task?.tags ?? []
                importance = task?.importance ?? .level2
                urgency = task?.urgency ?? .level2
                isOneOff = task?.isOneOffTask ?? false
                entryTaskID = session.taskID
            }

            return TimelineEntry(
                id: session.id,
                taskID: entryTaskID,
                timestamp: startedAt,
                startTimestamp: startedAt,
                endTimestamp: session.finishedAt,
                taskName: title,
                taskEmoji: emoji,
                tags: tags,
                importance: importance,
                urgency: urgency,
                isOneOff: isOneOff,
                kind: .completed,
                entryType: .focus,
                durationSeconds: session.activeDurationSeconds(at: now),
                activityTitle: focusActivityTitle(for: session)
            )
        }

        let sprintLookup = Dictionary(
            boardSprints.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let sprintFocusEntries = sprintFocusSessions.compactMap { session -> TimelineEntry? in
            guard filterType == .all || filterType == .focus,
                  mediaFilter == .all
            else {
                return nil
            }

            let startedAt = session.startedAt
            if let cutoff, startedAt < cutoff { return nil }

            let sprintTitle = sprintLookup[session.sprintID]?.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title = if let sprintTitle, !sprintTitle.isEmpty {
                sprintTitle
            } else {
                "Board focus"
            }
            let stoppedAt = session.stoppedAt
            let duration = session.activeDurationSeconds(at: now)

            return TimelineEntry(
                id: session.id,
                taskID: nil,
                timestamp: startedAt,
                startTimestamp: startedAt,
                endTimestamp: stoppedAt,
                taskName: title,
                taskEmoji: "🎯",
                tags: [],
                isOneOff: false,
                kind: .completed,
                entryType: .focus,
                durationSeconds: duration,
                activityTitle: stoppedAt == nil ? "Active board focus" : "Board focus"
            )
        }

        let sleepEntries = sleepSessions.compactMap { session -> TimelineEntry? in
            guard filterType == .all || filterType == .sleep,
                  mediaFilter == .all,
                  let startedAt = session.startedAt
            else {
                return nil
            }

            let endedAt = session.endedAt
            let timestamp = endedAt ?? startedAt
            if let cutoff, timestamp < cutoff { return nil }

            return TimelineEntry(
                id: session.id,
                taskID: nil,
                timestamp: timestamp,
                startTimestamp: startedAt,
                endTimestamp: endedAt,
                taskName: "Sleep",
                taskEmoji: "🛌",
                tags: [],
                isOneOff: false,
                kind: .completed,
                entryType: .sleep,
                durationSeconds: session.durationSeconds(referenceDate: now)
            )
        }

        let placeEntries = placeCheckInSessions.compactMap { session -> TimelineEntry? in
            let hasImage = session.hasImage
            guard filterType == .all || filterType == .places,
                  HomeDisplayFilterSupport.matchesMediaFilter(
                    mediaFilter,
                    hasImage: hasImage,
                    hasFileAttachment: false
                  ),
                  let startedAt = session.startedAt
            else {
                return nil
            }

            let endedAt = session.endedAt
            let timestamp = endedAt ?? startedAt
            if let cutoff, timestamp < cutoff { return nil }

            return TimelineEntry(
                id: session.id,
                taskID: nil,
                timestamp: timestamp,
                startTimestamp: startedAt,
                endTimestamp: endedAt,
                taskName: session.displayPlaceName,
                taskEmoji: "📍",
                tags: session.activity.map { [$0.title] } ?? [],
                hasImage: hasImage,
                isOneOff: false,
                kind: .completed,
                entryType: .placeCheckIn,
                durationSeconds: session.durationSeconds(referenceDate: now),
                activityTitle: session.activity?.title
            )
        }

        let awayEntries = awaySessions.compactMap { session -> TimelineEntry? in
            guard filterType == .all || filterType == .away else {
                return nil
            }

            let startedAt = session.startedAt ?? session.createdAt ?? Date()
            let endedAt = session.finishedAt
            let timestamp = endedAt ?? startedAt

            if let cutoff, timestamp < cutoff {
                return nil
            }

            let statusTitle: String
            switch session.state {
            case .active:
                statusTitle = session.isCountUp ? "Active count-up away" : "Active away"
            case .completed:
                statusTitle = session.isCountUp ? "Completed count-up away" : "Completed away"
            case .endedEarly:
                statusTitle = "Ended early away"
            }

            let linkedTask = session.linkedTaskID.flatMap { lookup[$0] }
            let linkedTaskTitle = linkedTask?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let activityTitle = [statusTitle, linkedTaskTitle.map { "Linked to \($0)" }]
                .compactMap { $0 }
                .joined(separator: " · ")

            return TimelineEntry(
                id: session.id,
                taskID: nil,
                timestamp: timestamp,
                startTimestamp: startedAt,
                endTimestamp: endedAt,
                taskName: session.displayTitle,
                taskEmoji: linkedTask?.emoji ?? "🕒",
                tags: linkedTask?.tags ?? [],
                isOneOff: false,
                kind: .completed,
                entryType: .away,
                durationSeconds: session.durationSeconds(referenceDate: now),
                activityTitle: activityTitle,
                searchableText: searchableText(for: session, linkedTask: linkedTask)
            )
        }

        return logEntries
            + eventEntries
            + emotionEntries
            + noteEntries
            + focusEntries
            + sprintFocusEntries
            + sleepEntries
            + placeEntries
            + awayEntries
    }

    static func logsIncludingLastDoneFallbacks(
        logs: [RoutineLog],
        tasks: [RoutineTask],
        calendar: Calendar
    ) -> [RoutineLog] {
        var resolvedLogs = logs

        for task in tasks {
            guard let lastDone = task.lastDone else { continue }
            let hasCompletionLog = resolvedLogs.contains { log in
                guard log.taskID == task.id,
                      log.kind.resolvesDoneDate,
                      let timestamp = log.timestamp else {
                    return false
                }
                return calendar.isDate(timestamp, inSameDayAs: lastDone)
            }
            guard !hasCompletionLog else { continue }

            resolvedLogs.append(
                RoutineLog(
                    id: TimelineSyntheticLogID.completion(taskID: task.id, completedAt: lastDone),
                    timestamp: lastDone,
                    taskID: task.id,
                    kind: .completed
                )
            )
        }

        return resolvedLogs
    }

    private static func searchableText(for awaySession: AwaySession, linkedTask: RoutineTask?) -> String {
        [
            awaySession.displayTitle,
            awaySession.state == .active ? "Active away" : awaySession.state == .completed ? "Completed away" : "Ended early away",
            linkedTask?.name,
            linkedTask?.emoji,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    static func availableTags(from entries: [TimelineEntry]) -> [String] {
        RoutineTag.allTags(from: entries.map(\.tags))
    }

    static func matchesSelectedTag(_ selectedTag: String?, in tags: [String]) -> Bool {
        guard let selectedTag else { return true }
        return RoutineTag.contains(selectedTag, in: tags)
    }

    static func groupedByDay(
        entries: [TimelineEntry],
        calendar: Calendar
    ) -> [(date: Date, entries: [TimelineEntry])] {
        var grouped: [Date: [TimelineEntry]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.timestamp)
            grouped[day, default: []].append(entry)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map {
                (
                    date: $0.key,
                    entries: $0.value.sorted { lhs, rhs in
                        lhs.timestamp > rhs.timestamp
                    }
                )
            }
    }

    private static func searchableText(for note: RoutineNote) -> String {
        [
            note.displayTitle,
            note.title,
            note.body,
        ]
        .compactMap(RoutineNote.cleanedText)
        .joined(separator: "\n")
    }

    private static func searchableText(for event: RoutineEvent) -> String {
        [
            event.displayTitle,
            event.title,
            event.notes,
            event.tags.joined(separator: " "),
        ]
        .compactMap(RoutineEvent.cleanedText)
        .joined(separator: "\n")
    }

    private static func searchableText(for emotion: EmotionLog) -> String {
        [
            emotion.displayLabel,
            emotion.familiesDisplayTitle,
            emotion.reflection,
            emotion.bodyAreas.map(\.title).joined(separator: " "),
        ]
        .compactMap(EmotionLog.cleanedText)
        .joined(separator: "\n")
    }

    private static func focusActivityTitle(for session: FocusSession) -> String {
        switch session.state {
        case .active:
            return session.isPaused ? "Paused focus" : "Active focus"
        case .completed:
            return "Completed focus"
        case .abandoned:
            return "Abandoned focus"
        }
    }

    static func daySectionTitle(
        for date: Date,
        calendar: Calendar
    ) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        }
    }
}

enum TimelineSyntheticLogID {
    static func completion(taskID: UUID, completedAt: Date) -> UUID {
        let uuid = taskID.uuid
        let timestampBits = completedAt.timeIntervalSinceReferenceDate.bitPattern
        return UUID(uuid: (
            uuid.0 ^ byte(timestampBits, shift: 56),
            uuid.1 ^ byte(timestampBits, shift: 48),
            uuid.2 ^ byte(timestampBits, shift: 40),
            uuid.3 ^ byte(timestampBits, shift: 32),
            uuid.4 ^ byte(timestampBits, shift: 24),
            uuid.5 ^ byte(timestampBits, shift: 16),
            uuid.6 ^ byte(timestampBits, shift: 8),
            uuid.7 ^ byte(timestampBits, shift: 0),
            uuid.8 ^ byte(timestampBits, shift: 56),
            uuid.9 ^ byte(timestampBits, shift: 48),
            uuid.10 ^ byte(timestampBits, shift: 40),
            uuid.11 ^ byte(timestampBits, shift: 32),
            uuid.12 ^ byte(timestampBits, shift: 24),
            uuid.13 ^ byte(timestampBits, shift: 16),
            uuid.14 ^ byte(timestampBits, shift: 8),
            uuid.15 ^ byte(timestampBits, shift: 0)
        ))
    }

    private static func byte(_ value: UInt64, shift: Int) -> UInt8 {
        UInt8(truncatingIfNeeded: value >> UInt64(shift))
    }
}
