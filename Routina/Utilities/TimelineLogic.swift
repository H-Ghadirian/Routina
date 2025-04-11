import Foundation

enum TimelineRange: String, CaseIterable, Identifiable, Sendable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    case all = "All"
    var id: Self { self }
}

enum TimelineFilterType: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case routines = "Routines"
    case todos = "Todos"
    var id: Self { self }
}

struct TimelineEntry: Identifiable, Equatable {
    let id: UUID
    let taskID: UUID?
    let timestamp: Date
    let taskName: String
    let taskEmoji: String
    let tags: [String]
    let isOneOff: Bool
}

enum TimelineLogic {
    static func filteredEntries(
        logs: [RoutineLog],
        tasks: [RoutineTask],
        range: TimelineRange,
        filterType: TimelineFilterType,
        now: Date,
        calendar: Calendar
    ) -> [TimelineEntry] {
        let lookup = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let cutoff: Date? = {
            switch range {
            case .today: return calendar.startOfDay(for: now)
            case .week: return calendar.date(byAdding: .day, value: -7, to: now)
            case .month: return calendar.date(byAdding: .month, value: -1, to: now)
            case .all: return nil
            }
        }()

        return logs.compactMap { log in
            guard let timestamp = log.timestamp else { return nil }
            if let cutoff, timestamp < cutoff { return nil }

            let task = lookup[log.taskID]
            let isOneOff = task?.isOneOffTask ?? false

            switch filterType {
            case .all: break
            case .routines: if isOneOff { return nil }
            case .todos: if !isOneOff { return nil }
            }

            return TimelineEntry(
                id: log.id,
                taskID: log.taskID,
                timestamp: timestamp,
                taskName: task?.name ?? "Deleted Routine",
                taskEmoji: task?.emoji ?? "🗑️",
                tags: task?.tags ?? [],
                isOneOff: isOneOff
            )
        }
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
            .map { (date: $0.key, entries: $0.value) }
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
