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
    case places = "Places"
    case sleep = "Sleep"
    case done = "Done"
    case missed = "Missed"
    case canceled = "Canceled"
    var id: Self { self }
}

enum TimelineEntryType: Equatable {
    case task
    case sleep
    case placeCheckIn
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
    let importance: RoutineTaskImportance
    let urgency: RoutineTaskUrgency
    let isOneOff: Bool
    let kind: RoutineLogKind
    let entryType: TimelineEntryType
    let durationSeconds: TimeInterval?
    let activityTitle: String?

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
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        isOneOff: Bool,
        kind: RoutineLogKind,
        entryType: TimelineEntryType = .task,
        durationSeconds: TimeInterval? = nil,
        activityTitle: String? = nil
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
        self.importance = importance
        self.urgency = urgency
        self.isOneOff = isOneOff
        self.kind = kind
        self.entryType = entryType
        self.durationSeconds = durationSeconds
        self.activityTitle = activityTitle
    }

    var isSleep: Bool {
        entryType == .sleep
    }

    var isPlaceCheckIn: Bool {
        entryType == .placeCheckIn
    }
}

enum TimelineLogic {
    static func filteredEntries(
        logs: [RoutineLog],
        tasks: [RoutineTask],
        sleepSessions: [SleepSession] = [],
        placeCheckInSessions: [PlaceCheckInSession] = [],
        fileAttachmentTaskIDs: Set<UUID> = [],
        range: TimelineRange,
        filterType: TimelineFilterType,
        mediaFilter: TaskMediaFilter = .all,
        now: Date,
        calendar: Calendar
    ) -> [TimelineEntry] {
        let lookup = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let cutoff: Date? = {
            switch range {
            case .today: return calendar.startOfDay(for: now)
            case .week: return calendar.date(byAdding: .day, value: -7, to: now)
            case .month: return calendar.date(byAdding: .month, value: -1, to: now)
            case .all: return nil
            }
        }()

        let logEntries = logs.compactMap { log -> TimelineEntry? in
            guard let timestamp = log.timestamp else { return nil }
            if let cutoff, timestamp < cutoff { return nil }

            let task = lookup[log.taskID]
            let isOneOff = task?.isOneOffTask ?? false
            let hasImage = task?.hasImage ?? false
            let hasFileAttachment = fileAttachmentTaskIDs.contains(log.taskID)

            guard HomeDisplayFilterSupport.matchesMediaFilter(
                mediaFilter,
                hasImage: hasImage,
                hasFileAttachment: hasFileAttachment
            ) else {
                return nil
            }

            switch filterType {
            case .all: break
            case .routines: if isOneOff { return nil }
            case .todos: if !isOneOff { return nil }
            case .places: return nil
            case .sleep: return nil
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
                importance: task?.importance ?? .level2,
                urgency: task?.urgency ?? .level2,
                isOneOff: isOneOff,
                kind: log.kind
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

        return logEntries + sleepEntries + placeEntries
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
