import Combine
import Foundation

final class DayPlanPlannerState: ObservableObject {
    @Published var selectedDate = Date()
    @Published var blocks: [DayPlanBlock] = []
    @Published var weekBlocksByDayKey: [String: [DayPlanBlock]] = [:]
    @Published var selectedTaskID: UUID?
    @Published var selectedBlockID: UUID?
    @Published var searchText = ""
    @Published var startMinute = 9 * 60
    @Published var durationMinutes = 60

    var selectedBlock: DayPlanBlock? {
        guard let selectedBlockID else { return nil }
        return blocks.first { $0.id == selectedBlockID }
            ?? weekBlocksByDayKey.values.lazy.compactMap { blocks in
                blocks.first { $0.id == selectedBlockID }
            }
            .first
    }

    var plannedMinutes: Int {
        blocks.reduce(0) { $0 + $1.durationMinutes }
    }

    var unplannedMinutes: Int {
        max(DayPlanBlock.minutesPerDay - plannedMinutes, 0)
    }

    var maximumDurationForStart: Int {
        max(
            DayPlanBlock.minimumDurationMinutes,
            DayPlanBlock.minutesPerDay - DayPlanBlock.clampedStartMinute(startMinute)
        )
    }

    var conflictingBlock: DayPlanBlock? {
        conflict(startMinute: startMinute, durationMinutes: durationMinutes, ignoring: selectedBlockID)
    }

    func loadBlocks(calendar: Calendar) {
        let weekDates = weekDates(containing: selectedDate, calendar: calendar)
        var loadedBlocksByDayKey: [String: [DayPlanBlock]] = [:]

        for date in weekDates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            loadedBlocksByDayKey[dayKey] = DayPlanStorage.loadBlocks(forDayKey: dayKey)
        }

        let selectedDayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        if loadedBlocksByDayKey[selectedDayKey] == nil {
            loadedBlocksByDayKey[selectedDayKey] = DayPlanStorage.loadBlocks(forDayKey: selectedDayKey)
        }

        weekBlocksByDayKey = loadedBlocksByDayKey
        syncSelectedDayBlocks(calendar: calendar)
    }

    func handleSelectedDateChanged(calendar: Calendar) {
        let blockIDToPreserve = selectedBlockID
        loadBlocks(calendar: calendar)

        guard
            let blockIDToPreserve,
            let preservedBlock = blocks.first(where: { $0.id == blockIDToPreserve })
        else {
            selectedBlockID = nil
            return
        }

        selectedBlockID = preservedBlock.id
        selectedTaskID = preservedBlock.taskID
        startMinute = preservedBlock.startMinute
        durationMinutes = preservedBlock.durationMinutes
    }

    func persistBlocks(calendar: Calendar) {
        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        let sortedBlocks = blocks.sorted { $0.startMinute < $1.startMinute }
        blocks = sortedBlocks
        weekBlocksByDayKey[dayKey] = sortedBlocks
        DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: dayKey)
    }

    func selectDefaultTaskIfNeeded(from tasks: [RoutineTask]) {
        if let selectedTaskID, tasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }
        selectedTaskID = DayPlanTaskSorting.availableTasks(from: tasks).first?.id
    }

    func selectTask(_ task: RoutineTask) {
        selectedTaskID = task.id
        if selectedBlock == nil, let estimate = task.estimatedDurationMinutes {
            durationMinutes = DayPlanBlock.clampedDuration(estimate, startMinute: startMinute)
        }
    }

    func selectSlot(on date: Date, startMinute: Int, calendar: Calendar) {
        selectedDate = date
        selectedBlockID = nil
        syncSelectedDayBlocks(calendar: calendar)
        self.startMinute = DayPlanBlock.clampedStartMinute(startMinute)
        clampDurationForCurrentStart()
    }

    func edit(_ block: DayPlanBlock, on date: Date? = nil, calendar: Calendar? = nil) {
        if let date, let calendar {
            selectedDate = date
            syncSelectedDayBlocks(calendar: calendar)
        }
        selectedBlockID = block.id
        selectedTaskID = block.taskID
        startMinute = block.startMinute
        durationMinutes = block.durationMinutes
        clampDurationForCurrentStart()
    }

    func deleteBlock(_ id: DayPlanBlock.ID, calendar: Calendar) {
        if let selectedDayIndex = blocks.firstIndex(where: { $0.id == id }) {
            blocks.remove(at: selectedDayIndex)
            persistBlocks(calendar: calendar)
        } else if let dayKey = weekBlocksByDayKey.first(where: { $0.value.contains(where: { $0.id == id }) })?.key {
            var dayBlocks = weekBlocksByDayKey[dayKey] ?? []
            dayBlocks.removeAll { $0.id == id }
            weekBlocksByDayKey[dayKey] = dayBlocks
            DayPlanStorage.saveBlocks(dayBlocks, forDayKey: dayKey)
        }

        if selectedBlockID == id {
            selectedBlockID = nil
        }
    }

    @discardableResult
    func moveBlock(_ id: DayPlanBlock.ID, to date: Date, startMinute: Int, calendar: Calendar) -> Bool {
        guard let locatedBlock = locatedBlock(id, calendar: calendar) else { return false }

        let targetDayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let targetStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        let targetDuration = DayPlanBlock.clampedDuration(
            locatedBlock.block.durationMinutes,
            startMinute: targetStartMinute
        )
        var targetBlocks = weekBlocksByDayKey[targetDayKey] ?? DayPlanStorage.loadBlocks(forDayKey: targetDayKey)
        let targetEndMinute = targetStartMinute + targetDuration
        let hasConflict = targetBlocks.contains { block in
            guard block.id != id else { return false }
            return max(targetStartMinute, block.startMinute) < min(targetEndMinute, block.endMinute)
        }

        guard !hasConflict else { return false }

        let movedBlock = DayPlanBlock(
            id: locatedBlock.block.id,
            taskID: locatedBlock.block.taskID,
            dayKey: targetDayKey,
            startMinute: targetStartMinute,
            durationMinutes: targetDuration,
            titleSnapshot: locatedBlock.block.titleSnapshot,
            emojiSnapshot: locatedBlock.block.emojiSnapshot,
            createdAt: locatedBlock.block.createdAt,
            updatedAt: Date()
        )
        var sourceBlocks = weekBlocksByDayKey[locatedBlock.dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: locatedBlock.dayKey)
        sourceBlocks.removeAll { $0.id == id }

        if locatedBlock.dayKey == targetDayKey {
            sourceBlocks.append(movedBlock)
            let sortedBlocks = sortedDayBlocks(sourceBlocks)
            weekBlocksByDayKey[targetDayKey] = sortedBlocks
            DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: targetDayKey)
        } else {
            let sortedSourceBlocks = sortedDayBlocks(sourceBlocks)
            weekBlocksByDayKey[locatedBlock.dayKey] = sortedSourceBlocks
            DayPlanStorage.saveBlocks(sortedSourceBlocks, forDayKey: locatedBlock.dayKey)

            targetBlocks.removeAll { $0.id == id }
            targetBlocks.append(movedBlock)
            let sortedTargetBlocks = sortedDayBlocks(targetBlocks)
            weekBlocksByDayKey[targetDayKey] = sortedTargetBlocks
            DayPlanStorage.saveBlocks(sortedTargetBlocks, forDayKey: targetDayKey)
        }

        selectedDate = date
        selectedBlockID = movedBlock.id
        selectedTaskID = movedBlock.taskID
        self.startMinute = movedBlock.startMinute
        durationMinutes = movedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar)
        return true
    }

    @discardableResult
    func resizeBlock(
        _ id: DayPlanBlock.ID,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        calendar: Calendar
    ) -> Bool {
        guard let locatedBlock = locatedBlock(id, calendar: calendar) else { return false }

        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let targetStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        let targetDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: targetStartMinute
        )
        let targetEndMinute = targetStartMinute + targetDuration
        var dayBlocks = weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey)
        let hasConflict = dayBlocks.contains { block in
            guard block.id != id else { return false }
            return max(targetStartMinute, block.startMinute) < min(targetEndMinute, block.endMinute)
        }

        guard !hasConflict else { return false }

        let resizedBlock = DayPlanBlock(
            id: locatedBlock.block.id,
            taskID: locatedBlock.block.taskID,
            dayKey: dayKey,
            startMinute: targetStartMinute,
            durationMinutes: targetDuration,
            titleSnapshot: locatedBlock.block.titleSnapshot,
            emojiSnapshot: locatedBlock.block.emojiSnapshot,
            createdAt: locatedBlock.block.createdAt,
            updatedAt: Date()
        )

        dayBlocks.removeAll { $0.id == id }
        dayBlocks.append(resizedBlock)
        let sortedBlocks = sortedDayBlocks(dayBlocks)
        weekBlocksByDayKey[dayKey] = sortedBlocks
        DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: dayKey)

        selectedDate = date
        selectedBlockID = resizedBlock.id
        selectedTaskID = resizedBlock.taskID
        self.startMinute = resizedBlock.startMinute
        self.durationMinutes = resizedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar)
        return true
    }

    func commitBlock(task: RoutineTask, calendar: Calendar) {
        guard conflictingBlock == nil else { return }

        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        let now = Date()
        let title = DayPlanTaskSorting.title(for: task)
        let emoji = CalendarTaskImportSupport.displayEmoji(for: task.emoji)

        if let selectedBlock, let index = blocks.firstIndex(where: { $0.id == selectedBlock.id }) {
            blocks[index] = DayPlanBlock(
                id: selectedBlock.id,
                taskID: task.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: title,
                emojiSnapshot: emoji,
                createdAt: selectedBlock.createdAt,
                updatedAt: now
            )
        } else {
            let block = DayPlanBlock(
                taskID: task.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: title,
                emojiSnapshot: emoji,
                createdAt: now,
                updatedAt: now
            )
            blocks.append(block)
            selectedBlockID = block.id
        }

        blocks.sort { $0.startMinute < $1.startMinute }
        persistBlocks(calendar: calendar)
    }

    func blocks(on date: Date, calendar: Calendar) -> [DayPlanBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey)
    }

    func weekDates(calendar: Calendar) -> [Date] {
        weekDates(containing: selectedDate, calendar: calendar)
    }

    func moveWeek(by value: Int, calendar: Calendar) {
        selectedDate = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) ?? selectedDate
        selectedBlockID = nil
        loadBlocks(calendar: calendar)
    }

    func moveToToday(calendar: Calendar) {
        selectedDate = Date()
        selectedBlockID = nil
        loadBlocks(calendar: calendar)
    }

    func weekTitle(calendar: Calendar) -> String {
        let dates = weekDates(calendar: calendar)
        guard let first = dates.first, let last = dates.last else {
            return selectedDate.formatted(date: .abbreviated, time: .omitted)
        }

        let firstText = first.formatted(.dateTime.month(.abbreviated).day())
        let lastText = last.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(firstText) - \(lastText)"
    }

    func conflict(
        startMinute: Int,
        durationMinutes: Int,
        ignoring ignoredBlockID: DayPlanBlock.ID?
    ) -> DayPlanBlock? {
        let start = DayPlanBlock.clampedStartMinute(startMinute)
        let duration = DayPlanBlock.clampedDuration(durationMinutes, startMinute: start)
        let end = start + duration

        return blocks.first { block in
            guard block.id != ignoredBlockID else { return false }
            return max(start, block.startMinute) < min(end, block.endMinute)
        }
    }

    func clampDurationForCurrentStart() {
        durationMinutes = DayPlanBlock.clampedDuration(durationMinutes, startMinute: startMinute)
    }

    private func syncSelectedDayBlocks(calendar: Calendar) {
        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        blocks = weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey)
    }

    private func locatedBlock(
        _ id: DayPlanBlock.ID,
        calendar: Calendar
    ) -> (block: DayPlanBlock, dayKey: String)? {
        for (dayKey, dayBlocks) in weekBlocksByDayKey {
            if let block = dayBlocks.first(where: { $0.id == id }) {
                return (block, dayKey)
            }
        }

        if let block = blocks.first(where: { $0.id == id }) {
            return (block, DayPlanStorage.dayKey(for: selectedDate, calendar: calendar))
        }

        return nil
    }

    private func sortedDayBlocks(_ blocks: [DayPlanBlock]) -> [DayPlanBlock] {
        blocks.sorted {
            if $0.startMinute != $1.startMinute {
                return $0.startMinute < $1.startMinute
            }
            return $0.createdAt < $1.createdAt
        }
    }

    private func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }
}
