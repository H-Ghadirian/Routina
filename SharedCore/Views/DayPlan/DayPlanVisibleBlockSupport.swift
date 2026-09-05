import Foundation

enum DayPlanVisibleBlocks {
    static func blocks(
        _ blocks: [DayPlanBlock],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
        referenceDate: Date = Date(),
        activeFocusSessions: [FocusSession] = [],
        activeFocusSegmentSearchBlocks: [DayPlanBlock]? = nil
    ) -> [DayPlanBlock] {
        Self.blocks(
            blocks,
            context: DayPlanVisibleBlockContext(
                tasks: tasks,
                logs: logs,
                calendar: calendar,
                referenceDate: referenceDate,
                activeFocusSessions: activeFocusSessions
            ),
            activeFocusSegmentSearchBlocks: activeFocusSegmentSearchBlocks
        )
    }

    static func blocks(
        _ blocks: [DayPlanBlock],
        context: DayPlanVisibleBlockContext,
        activeFocusSegmentSearchBlocks: [DayPlanBlock]? = nil
    ) -> [DayPlanBlock] {
        guard !blocks.isEmpty else { return [] }

        let correctedBlocks = context.correctedActiveFocusBlocks(blocks)
        let activeFocusSearchBlocks = context.correctedActiveFocusBlocks(
            activeFocusSegmentSearchBlocks ?? blocks
        )
        let activeCountUpSegmentBlockIDs = activeCountUpCurrentSegmentBlockIDs(
            activeFocusSearchBlocks,
            activeFocusSessions: context.activeFocusSessions,
            referenceDayKey: activeFocusSegmentSearchBlocks == nil ? nil : context.referenceDayKey
        )

        return correctedBlocks.filter { block in
            if activeCountUpSegmentBlockIDs.contains(block.id) {
                return false
            }

            guard context.tasksByID[block.taskID] != nil else { return true }
            guard !context.canceledOneOffTaskIDs.contains(block.taskID) else { return false }
            return !context.isHiddenTaskDay(taskID: block.taskID, dayKey: block.dayKey)
        }
    }

    private static func activeCountUpCurrentSegmentBlockIDs(
        _ blocks: [DayPlanBlock],
        activeFocusSessions: [FocusSession],
        referenceDayKey: String?
    ) -> Set<UUID> {
        Set(
            activeFocusSessions.compactMap { session in
                guard session.plannedDurationSeconds <= 0,
                    session.completedAt == nil,
                    session.abandonedAt == nil,
                    session.pausedAt == nil,
                    session.startedAt != nil,
                    session.isTaskFocus || session.isTagFocus
                else {
                    return nil
                }

                guard
                    let latestSegmentBlock = DayPlanFocusSessionPlannerSync.latestFocusSegmentBlock(
                        in: blocks,
                        for: session
                    )
                else {
                    return nil
                }

                if let referenceDayKey, latestSegmentBlock.dayKey != referenceDayKey {
                    return nil
                }

                if latestSegmentBlock.id == session.id, session.accumulatedPausedSeconds > 0 {
                    return nil
                }

                return latestSegmentBlock.id
            })
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
