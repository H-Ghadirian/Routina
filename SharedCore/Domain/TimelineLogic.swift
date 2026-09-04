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
        case .routines:
            return "Repeating"
        case .todos:
            return "One-time"
        default:
            return rawValue
        }
    }

    static let timelinePigmentCases: [TimelineFilterType] = [
        .all,
        .routines,
        .todos,
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

enum TimelineStatusFilter: String, CaseIterable, Identifiable, Sendable, Equatable, Codable {
    case all = "All"
    case done = "Done"
    case missed = "Missed"
    case canceled = "Canceled"

    var id: Self { self }
    var title: String { rawValue }

    init(legacyFilterType: TimelineFilterType) {
        switch legacyFilterType {
        case .done:
            self = .done
        case .missed:
            self = .missed
        case .canceled:
            self = .canceled
        default:
            self = .all
        }
    }

    func matches(kind: RoutineLogKind, entryType: TimelineEntryType) -> Bool {
        switch self {
        case .all:
            return true
        case .done:
            return entryType == .task && kind == .completed
        case .missed:
            return entryType == .task && kind == .missed
        case .canceled:
            return entryType == .task && kind == .canceled
        }
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
    let flags: [String]
    let hasImage: Bool
    let hasFileAttachment: Bool
    let hasVoiceNote: Bool
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let currentImportance: RoutineTaskImportance
    let currentUrgency: RoutineTaskUrgency
    let currentPressure: RoutineTaskPressure
    let thinkingNeeded: RoutineTaskThinkingNeeded
    let estimatedDurationMinutes: Int?
    let hasTaskLadderValues: Bool
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
        flags: [String] = [],
        hasImage: Bool = false,
        hasFileAttachment: Bool = false,
        hasVoiceNote: Bool = false,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        currentImportance: RoutineTaskImportance? = nil,
        currentUrgency: RoutineTaskUrgency? = nil,
        currentPressure: RoutineTaskPressure = .none,
        thinkingNeeded: RoutineTaskThinkingNeeded = .none,
        estimatedDurationMinutes: Int? = nil,
        hasTaskLadderValues: Bool = false,
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
        self.flags = flags
        self.hasImage = hasImage
        self.hasFileAttachment = hasFileAttachment
        self.hasVoiceNote = hasVoiceNote
        self.importance = importance
        self.urgency = urgency
        self.currentImportance = currentImportance ?? importance
        self.currentUrgency = currentUrgency ?? urgency
        self.currentPressure = currentPressure
        self.thinkingNeeded = thinkingNeeded
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.hasTaskLadderValues = hasTaskLadderValues
        self.taskType = taskType
        self.isOneOff = isOneOff
        self.kind = kind
        self.entryType = entryType
        self.durationSeconds = durationSeconds
        self.activityTitle = activityTitle
        self.searchableText =
            searchableText
            ?? Self.defaultSearchableText(
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
            return "Repeating task"
        case .todo:
            return "One-time task"
        case nil:
            return isOneOff ? "One-time task" : "Repeating task"
        }
    }
}

enum TimelineEntryKindTint: Equatable {
    case accent
    case blue
    case cyan
    case green
    case indigo
    case mint
    case orange
    case pink
    case purple
    case teal
    case yellow
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

    static func tint(for entry: TimelineEntry) -> TimelineEntryKindTint {
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
            switch entry.taskType {
            case .todo:
                return .purple
            case .routine:
                return .accent
            case nil:
                return entry.isOneOff ? .purple : .accent
            }
        case .fulfilled:
            return .green
        case .canceled:
            return .orange
        case .missed:
            return .yellow
        }
    }
}

enum TimelineLogic {
    static func rowNumbersByEntryID(
        groupedEntries: [(date: Date, entries: [TimelineEntry])]
    ) -> [UUID: Int] {
        var rowNumbers: [UUID: Int] = [:]
        rowNumbers.reserveCapacity(groupedEntries.reduce(into: 0) { $0 += $1.entries.count })

        var rowNumber = 1
        for section in groupedEntries {
            for entry in section.entries {
                rowNumbers[entry.id] = rowNumber
                rowNumber += 1
            }
        }
        return rowNumbers
    }

    static func filteredEntries(
        logs: [RoutineLog],
        tasks: [RoutineTask],
        events: [RoutineEvent] = [],
        emotionLogs: [EmotionLog] = [],
        notes: [RoutineNote] = [],
        focusSessions: [FocusSession] = [],
        sprintFocusSessions: [SprintFocusSessionRecord] = [],
        focusSessionEvents: [FocusSessionActionEvent] = [],
        boardSprints: [BoardSprintRecord] = [],
        sleepSessions: [SleepSession] = [],
        placeCheckInSessions: [PlaceCheckInSession] = [],
        awaySessions: [AwaySession] = [],
        fileAttachmentTaskIDs: Set<UUID> = [],
        noteAttachmentNoteIDs: Set<UUID> = [],
        range: TimelineRange,
        filterType: TimelineFilterType,
        statusFilter: TimelineStatusFilter = .all,
        mediaFilter: TaskMediaFilter = .all,
        now: Date,
        calendar: Calendar
    ) -> [TimelineEntry] {
        let contentFilterType = filterType.isStatusCase ? TimelineFilterType.all : filterType
        let effectiveStatusFilter =
            statusFilter == .all
            ? TimelineStatusFilter(legacyFilterType: filterType)
            : statusFilter
        let lookup = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let currentTaskLadderValuesByTaskID = Dictionary(
            tasks.map { task in
                (
                    task.id,
                    RoutineTaskTemporalWeightResolver.effectiveWeights(
                        for: task,
                        referenceDate: now,
                        calendar: calendar
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
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
            let currentTaskLadderValues = currentTaskLadderValuesByTaskID[log.taskID]

            guard
                HomeDisplayFilterSupport.matchesMediaFilter(
                    mediaFilter,
                    hasImage: hasImage,
                    hasFileAttachment: hasFileAttachment,
                    hasVoiceNote: hasVoiceNote
                )
            else {
                return nil
            }

            switch contentFilterType {
            case .all: break
            case .routines: if taskType != .routine { return nil }
            case .todos: if taskType != .todo { return nil }
            case .events: return nil
            case .emotions: return nil
            case .notes: return nil
            case .focus: return nil
            case .places: return nil
            case .sleep: return nil
            case .away: return nil
            case .done, .missed, .canceled:
                break
            }

            return TimelineEntry(
                id: log.id,
                taskID: log.taskID,
                timestamp: timestamp,
                taskName: task?.name ?? "Deleted Routine",
                taskEmoji: task?.emoji ?? "🗑️",
                tags: task?.tags ?? [],
                flags: task?.flags ?? [],
                hasImage: hasImage,
                hasFileAttachment: hasFileAttachment,
                hasVoiceNote: hasVoiceNote,
                importance: task?.importance ?? .level2,
                urgency: task?.urgency ?? .level2,
                currentImportance: currentTaskLadderValues?.importance,
                currentUrgency: currentTaskLadderValues?.urgency,
                currentPressure: currentTaskLadderValues?.pressure ?? .none,
                thinkingNeeded: task?.thinkingNeeded ?? .none,
                estimatedDurationMinutes: task?.estimatedDurationMinutes,
                hasTaskLadderValues: task != nil,
                taskType: taskType,
                isOneOff: taskType == .todo,
                kind: log.kind
            )
        }

        let eventEntries = events.compactMap { event -> TimelineEntry? in
            guard contentFilterType == .all || contentFilterType == .events,
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
            guard contentFilterType == .all || contentFilterType == .emotions,
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
            guard contentFilterType == .all || contentFilterType == .notes,
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

        let focusEventsBySessionID = FocusActivityIntervalResolver.eventsBySessionID(
            focusSessionEvents
        )
        let focusEntries = focusSessions.flatMap { session -> [TimelineEntry] in
            guard contentFilterType == .all || contentFilterType == .focus,
                mediaFilter == .all,
                session.state != .abandoned,
                let startedAt = session.startedAt
            else {
                return []
            }

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

            let currentTaskLadderValues = task.flatMap { currentTaskLadderValuesByTaskID[$0.id] }
            let intervals = FocusActivityIntervalResolver.intervals(
                for: session,
                events: focusEventsBySessionID[session.id] ?? [],
                referenceDate: now
            )
            var daySlices = FocusActivityIntervalResolver.daySlices(
                for: intervals,
                calendar: calendar
            )
            if daySlices.isEmpty,
                session.state == .active,
                startedAt <= now {
                daySlices = [
                    FocusActivityDaySlice(
                        sessionID: session.id,
                        day: calendar.startOfDay(for: startedAt),
                        startedAt: startedAt,
                        endedAt: startedAt,
                        isOngoing: !session.isPaused
                    )
                ]
            }
            let firstDay = daySlices.first?.day
            let slicesByDay = Dictionary(grouping: daySlices, by: \FocusActivityDaySlice.day)

            return slicesByDay.keys.sorted().compactMap { day in
                guard let slices = slicesByDay[day]?.sorted(by: { $0.startedAt < $1.startedAt }),
                    let firstSlice = slices.first,
                    let lastSlice = slices.last
                else {
                    return nil
                }
                if let cutoff, day < cutoff { return nil }
                let duration = slices.reduce(0) { $0 + $1.durationSeconds }
                let isOngoing = slices.contains(where: \FocusActivityDaySlice.isOngoing)

                return TimelineEntry(
                    id: FocusActivityIntervalResolver.timelineEntryID(
                        sessionID: session.id,
                        day: day,
                        usesOriginalSessionID: day == firstDay
                    ),
                    taskID: entryTaskID,
                    timestamp: firstSlice.startedAt,
                    startTimestamp: firstSlice.startedAt,
                    endTimestamp: isOngoing ? nil : lastSlice.endedAt,
                    taskName: title,
                    taskEmoji: emoji,
                    tags: tags,
                    flags: task?.flags ?? [],
                    importance: importance,
                    urgency: urgency,
                    currentImportance: currentTaskLadderValues?.importance,
                    currentUrgency: currentTaskLadderValues?.urgency,
                    currentPressure: currentTaskLadderValues?.pressure ?? .none,
                    thinkingNeeded: task?.thinkingNeeded ?? .none,
                    estimatedDurationMinutes: task?.estimatedDurationMinutes,
                    hasTaskLadderValues: task != nil,
                    isOneOff: isOneOff,
                    kind: .completed,
                    entryType: .focus,
                    durationSeconds: duration,
                    activityTitle: focusActivityTitle(for: session)
                )
            }
        }

        let sprintLookup = Dictionary(
            boardSprints.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let sprintFocusEntries = sprintFocusSessions.flatMap { session -> [TimelineEntry] in
            guard contentFilterType == .all || contentFilterType == .focus,
                mediaFilter == .all
            else {
                return []
            }

            let startedAt = session.startedAt
            let sprintTitle = sprintLookup[session.sprintID]?.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let title =
                if let sprintTitle, !sprintTitle.isEmpty {
                    sprintTitle
                } else {
                    "Board focus"
                }
            let stoppedAt = session.stoppedAt
            let intervals = FocusActivityIntervalResolver.intervals(
                for: session,
                events: focusEventsBySessionID[session.id] ?? [],
                referenceDate: now
            )
            var daySlices = FocusActivityIntervalResolver.daySlices(
                for: intervals,
                calendar: calendar
            )
            if daySlices.isEmpty,
                session.isActive,
                startedAt <= now {
                daySlices = [
                    FocusActivityDaySlice(
                        sessionID: session.id,
                        day: calendar.startOfDay(for: startedAt),
                        startedAt: startedAt,
                        endedAt: startedAt,
                        isOngoing: !session.isPaused
                    )
                ]
            }
            let firstDay = daySlices.first?.day
            let slicesByDay = Dictionary(grouping: daySlices, by: \FocusActivityDaySlice.day)

            return slicesByDay.keys.sorted().compactMap { day in
                guard let slices = slicesByDay[day]?.sorted(by: { $0.startedAt < $1.startedAt }),
                    let firstSlice = slices.first,
                    let lastSlice = slices.last
                else {
                    return nil
                }
                if let cutoff, day < cutoff { return nil }
                let duration = slices.reduce(0) { $0 + $1.durationSeconds }
                let isOngoing = slices.contains(where: \FocusActivityDaySlice.isOngoing)

                return TimelineEntry(
                    id: FocusActivityIntervalResolver.timelineEntryID(
                        sessionID: session.id,
                        day: day,
                        usesOriginalSessionID: day == firstDay
                    ),
                    taskID: nil,
                    timestamp: firstSlice.startedAt,
                    startTimestamp: firstSlice.startedAt,
                    endTimestamp: isOngoing ? nil : lastSlice.endedAt,
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
        }

        let sleepEntries = sleepSessions.compactMap { session -> TimelineEntry? in
            guard contentFilterType == .all || contentFilterType == .sleep,
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
            guard contentFilterType == .all || contentFilterType == .places,
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
            guard contentFilterType == .all || contentFilterType == .away else {
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

        return
            (logEntries
            + eventEntries
            + emotionEntries
            + noteEntries
            + focusEntries
            + sprintFocusEntries
            + sleepEntries
            + placeEntries
            + awayEntries)
            .filter {
                effectiveStatusFilter.matches(kind: $0.kind, entryType: $0.entryType)
            }
    }

    static func logsIncludingLastDoneFallbacks(
        logs: [RoutineLog],
        tasks: [RoutineTask],
        calendar: Calendar
    ) -> [RoutineLog] {
        var resolvedLogs = logs
        resolvedLogs.reserveCapacity(logs.count + tasks.count)

        var completionDaysByTaskID: [UUID: Set<Date>] = [:]
        completionDaysByTaskID.reserveCapacity(tasks.count)
        for log in logs {
            guard log.kind.resolvesDoneDate,
                let timestamp = log.timestamp
            else {
                continue
            }
            completionDaysByTaskID[log.taskID, default: []].insert(
                calendar.startOfDay(for: timestamp)
            )
        }

        for task in tasks {
            guard let lastDone = task.lastDone else { continue }
            let completionDay = calendar.startOfDay(for: lastDone)
            guard completionDaysByTaskID[task.id]?.contains(completionDay) != true else {
                continue
            }

            resolvedLogs.append(
                RoutineLog(
                    id: TimelineSyntheticLogID.completion(taskID: task.id, completedAt: lastDone),
                    timestamp: lastDone,
                    taskID: task.id,
                    kind: .completed
                )
            )
            completionDaysByTaskID[task.id, default: []].insert(completionDay)
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

    static func availableFlags(from entries: [TimelineEntry]) -> [String] {
        RoutineFlag.allFlags(from: entries.map(\.flags))
    }

    /// Applies Timeline-specific Flag behavior at an explicit presentation
    /// refresh boundary. With no Flag filter, configured entries stay hidden.
    /// Selecting Flags is deliberate recovery and therefore reveals matching
    /// entries even when one of their Flags normally hides them from Timeline.
    static func entriesVisibleForFlags(
        _ entries: [TimelineEntry],
        selectedFlags: Set<String>,
        includeFlagMatchMode: RoutineTagMatchMode,
        excludedFlags: Set<String> = [],
        excludeFlagMatchMode: RoutineTagMatchMode = .any,
        rules: [RoutineFlagRule]
    ) -> [TimelineEntry] {
        let includedEntries: [TimelineEntry]
        if selectedFlags.isEmpty {
            includedEntries = entries.filter {
                !RoutineFlagRules.hidesFromTimeline(flags: $0.flags, rules: rules)
            }
        } else {
            includedEntries = entries.filter {
                HomeDisplayFilterSupport.matchesSelectedFlags(
                    selectedFlags,
                    mode: includeFlagMatchMode,
                    in: $0.flags
                )
            }
        }

        return includedEntries.filter {
            HomeDisplayFilterSupport.matchesExcludedFlags(
                excludedFlags,
                mode: excludeFlagMatchMode,
                in: $0.flags
            )
        }
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
        return
            grouped
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
        return UUID(
            uuid: (
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
