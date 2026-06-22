import Foundation

enum DayPlanTaskSorting {
    static func availableTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks
            .filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }

                if lhs.isOneOffTask != rhs.isOneOffTask {
                    return lhs.isOneOffTask
                }

                let lhsDeadline = lhs.deadline ?? .distantFuture
                let rhsDeadline = rhs.deadline ?? .distantFuture
                if lhsDeadline != rhsDeadline {
                    return lhsDeadline < rhsDeadline
                }

                return title(for: lhs).localizedCaseInsensitiveCompare(title(for: rhs)) == .orderedAscending
            }
    }

    static func filteredTasks(from tasks: [RoutineTask], query: String) -> [RoutineTask] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tasks }

        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return tasks.filter { task in
            let searchableText = ([title(for: task), task.emoji ?? ""] + task.tags)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return searchableText.contains(normalizedQuery)
        }
    }

    static func title(for task: RoutineTask) -> String {
        let trimmed = RoutineTask.trimmedName(task.name) ?? ""
        return trimmed.isEmpty ? "Untitled task" : trimmed
    }
}

enum DayPlanVisibleBlocks {
    static func blocks(
        _ blocks: [DayPlanBlock],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar
    ) -> [DayPlanBlock] {
        guard !blocks.isEmpty else { return [] }

        let tasksByID = Dictionary(grouping: tasks, by: \.id).compactMapValues(\.first)
        let logsByTaskID = Dictionary(grouping: logs, by: \.taskID)

        return blocks.filter { block in
            guard let task = tasksByID[block.taskID] else { return true }
            return !hasHiddenOutcome(
                for: block,
                task: task,
                logs: logsByTaskID[block.taskID] ?? [],
                calendar: calendar
            )
        }
    }

    private static func hasHiddenOutcome(
        for block: DayPlanBlock,
        task: RoutineTask,
        logs: [RoutineLog],
        calendar: Calendar
    ) -> Bool {
        if task.isCanceledOneOff {
            return true
        }

        guard let blockDate = date(fromDayKey: block.dayKey, calendar: calendar) else {
            return false
        }

        if let canceledAt = task.canceledAt,
           calendar.isDate(canceledAt, inSameDayAs: blockDate) {
            return true
        }

        return logs.contains { log in
            guard log.kind == .canceled || log.kind == .missed,
                  let timestamp = log.timestamp else {
                return false
            }
            return calendar.isDate(timestamp, inSameDayAs: blockDate)
        }
    }

    private static func date(fromDayKey dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components)
    }
}

struct DayPlanTimedBlockColumnItem: Equatable {
    var id: String
    var startMinute: Int
    var endMinute: Int

    init(id: String, startMinute: Int, endMinute: Int) {
        let startMinute = min(max(startMinute, 0), DayPlanBlock.minutesPerDay - 1)
        self.id = id
        self.startMinute = startMinute
        self.endMinute = min(max(endMinute, startMinute + 1), DayPlanBlock.minutesPerDay)
    }
}

struct DayPlanTimedBlockColumnPlacement: Equatable {
    var id: String
    var columnIndex: Int
    var columnCount: Int
}

enum DayPlanTimedBlockColumnLayout {
    static func placements(
        for items: [DayPlanTimedBlockColumnItem]
    ) -> [DayPlanTimedBlockColumnPlacement] {
        guard !items.isEmpty else { return [] }

        let sortedItems = items.sorted { lhs, rhs in
            if lhs.startMinute != rhs.startMinute {
                return lhs.startMinute < rhs.startMinute
            }
            if lhs.endMinute != rhs.endMinute {
                return lhs.endMinute > rhs.endMinute
            }
            return lhs.id < rhs.id
        }

        var groupAssignments: [ColumnAssignment] = []
        var activeAssignments: [ColumnAssignment] = []
        var placementsByID: [String: DayPlanTimedBlockColumnPlacement] = [:]

        func flushGroup() {
            guard !groupAssignments.isEmpty else { return }

            let columnCount = (groupAssignments.map(\.columnIndex).max() ?? 0) + 1
            for assignment in groupAssignments {
                placementsByID[assignment.item.id] = DayPlanTimedBlockColumnPlacement(
                    id: assignment.item.id,
                    columnIndex: assignment.columnIndex,
                    columnCount: columnCount
                )
            }

            groupAssignments.removeAll(keepingCapacity: true)
        }

        for item in sortedItems {
            activeAssignments.removeAll { $0.item.endMinute <= item.startMinute }
            if activeAssignments.isEmpty {
                flushGroup()
            }

            let usedColumns = Set(activeAssignments.map(\.columnIndex))
            var columnIndex = 0
            while usedColumns.contains(columnIndex) {
                columnIndex += 1
            }

            let assignment = ColumnAssignment(item: item, columnIndex: columnIndex)
            groupAssignments.append(assignment)
            activeAssignments.append(assignment)
        }

        flushGroup()

        return items.compactMap { placementsByID[$0.id] }
    }
}

private struct ColumnAssignment {
    var item: DayPlanTimedBlockColumnItem
    var columnIndex: Int
}
