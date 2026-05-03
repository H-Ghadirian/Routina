import Combine
import Foundation
import SwiftData

final class DayPlanPlannerState: ObservableObject {
    @Published var selectedDate: Date
    @Published var blocks: [DayPlanBlock] = []
    @Published var weekBlocksByDayKey: [String: [DayPlanBlock]] = [:]
    @Published var selectedTaskID: UUID?
    @Published var selectedBlockID: UUID?
    @Published var searchText = ""
    @Published var startMinute = 9 * 60
    @Published var durationMinutes = 60

    @Published private var visibleDate: Date

    init(selectedDate: Date = DayPlanPlannerState.defaultSelectedDate()) {
        self.selectedDate = selectedDate
        self.visibleDate = selectedDate
    }

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

    func loadBlocks(calendar: Calendar, context: ModelContext) {
        let weekDates = visibleAndSelectedDates(calendar: calendar)
        var loadedBlocksByDayKey: [String: [DayPlanBlock]] = [:]

        for date in weekDates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            loadedBlocksByDayKey[dayKey] = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
        }

        let selectedDayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        if loadedBlocksByDayKey[selectedDayKey] == nil {
            loadedBlocksByDayKey[selectedDayKey] = DayPlanStorage.loadBlocks(forDayKey: selectedDayKey, context: context)
        }

        weekBlocksByDayKey = loadedBlocksByDayKey
        syncSelectedDayBlocks(calendar: calendar, context: context)
    }

    func showExactTimedTasks(from tasks: [RoutineTask], calendar: Calendar, context: ModelContext) {
        let visibleDates = visibleAndSelectedDates(calendar: calendar)
        let availableTasks = DayPlanTaskSorting.availableTasks(from: tasks)
        let now = Date()
        var updatedBlocksByDayKey = weekBlocksByDayKey

        for date in visibleDates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            var dayBlocks = updatedBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
            var didChangeDay = false

            for task in availableTasks {
                guard let scheduledDate = exactScheduledDate(for: task, on: date, calendar: calendar) else {
                    continue
                }
                guard !task.isArchived(referenceDate: scheduledDate, calendar: calendar) else {
                    continue
                }
                guard !dayBlocks.contains(where: { $0.taskID == task.id }) else {
                    continue
                }

                let startMinute = startMinute(for: scheduledDate, calendar: calendar)
                let durationMinutes = task.estimatedDurationMinutes ?? 60
                dayBlocks.append(
                    DayPlanBlock(
                        taskID: task.id,
                        dayKey: dayKey,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        titleSnapshot: DayPlanTaskSorting.title(for: task),
                        emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                        createdAt: now,
                        updatedAt: now
                    )
                )
                didChangeDay = true
            }

            if didChangeDay {
                let sortedBlocks = sortedDayBlocks(dayBlocks)
                updatedBlocksByDayKey[dayKey] = sortedBlocks
                DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: dayKey, context: context)
            } else {
                updatedBlocksByDayKey[dayKey] = dayBlocks
            }
        }

        weekBlocksByDayKey = updatedBlocksByDayKey
        syncSelectedDayBlocks(calendar: calendar, context: context)
    }

    func handleSelectedDateChanged(calendar: Calendar, context: ModelContext) {
        let blockIDToPreserve = selectedBlockID
        loadBlocks(calendar: calendar, context: context)

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

    func persistBlocks(calendar: Calendar, context: ModelContext) {
        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        let sortedBlocks = blocks.sorted { $0.startMinute < $1.startMinute }
        blocks = sortedBlocks
        weekBlocksByDayKey[dayKey] = sortedBlocks
        DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: dayKey, context: context)
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

    func selectSlot(on date: Date, startMinute: Int, calendar: Calendar, context: ModelContext) {
        selectedDate = date
        selectedBlockID = nil
        syncSelectedDayBlocks(calendar: calendar, context: context)
        self.startMinute = DayPlanBlock.clampedStartMinute(startMinute)
        clampDurationForCurrentStart()
    }

    func edit(_ block: DayPlanBlock, on date: Date? = nil, calendar: Calendar? = nil, context: ModelContext) {
        if let date, let calendar {
            selectedDate = date
            syncSelectedDayBlocks(calendar: calendar, context: context)
        }
        selectedBlockID = block.id
        selectedTaskID = block.taskID
        startMinute = block.startMinute
        durationMinutes = block.durationMinutes
        clampDurationForCurrentStart()
    }

    func deleteBlock(_ id: DayPlanBlock.ID, calendar: Calendar, context: ModelContext) {
        if let selectedDayIndex = blocks.firstIndex(where: { $0.id == id }) {
            blocks.remove(at: selectedDayIndex)
            persistBlocks(calendar: calendar, context: context)
        } else if let dayKey = weekBlocksByDayKey.first(where: { $0.value.contains(where: { $0.id == id }) })?.key {
            var dayBlocks = weekBlocksByDayKey[dayKey] ?? []
            dayBlocks.removeAll { $0.id == id }
            weekBlocksByDayKey[dayKey] = dayBlocks
            DayPlanStorage.saveBlocks(dayBlocks, forDayKey: dayKey, context: context)
        }

        if selectedBlockID == id {
            selectedBlockID = nil
        }
    }

    @discardableResult
    func moveBlock(_ id: DayPlanBlock.ID, to date: Date, startMinute: Int, calendar: Calendar, context: ModelContext) -> Bool {
        guard let locatedBlock = locatedBlock(id, calendar: calendar) else { return false }

        let targetDayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let targetStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        let targetDuration = DayPlanBlock.clampedDuration(
            locatedBlock.block.durationMinutes,
            startMinute: targetStartMinute
        )
        var targetBlocks = weekBlocksByDayKey[targetDayKey] ?? DayPlanStorage.loadBlocks(forDayKey: targetDayKey, context: context)
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
        var sourceBlocks = weekBlocksByDayKey[locatedBlock.dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: locatedBlock.dayKey, context: context)
        sourceBlocks.removeAll { $0.id == id }

        if locatedBlock.dayKey == targetDayKey {
            sourceBlocks.append(movedBlock)
            let sortedBlocks = sortedDayBlocks(sourceBlocks)
            weekBlocksByDayKey[targetDayKey] = sortedBlocks
            DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: targetDayKey, context: context)
        } else {
            let sortedSourceBlocks = sortedDayBlocks(sourceBlocks)
            weekBlocksByDayKey[locatedBlock.dayKey] = sortedSourceBlocks
            DayPlanStorage.saveBlocks(sortedSourceBlocks, forDayKey: locatedBlock.dayKey, context: context)

            targetBlocks.removeAll { $0.id == id }
            targetBlocks.append(movedBlock)
            let sortedTargetBlocks = sortedDayBlocks(targetBlocks)
            weekBlocksByDayKey[targetDayKey] = sortedTargetBlocks
            DayPlanStorage.saveBlocks(sortedTargetBlocks, forDayKey: targetDayKey, context: context)
        }

        selectedDate = date
        selectedBlockID = movedBlock.id
        selectedTaskID = movedBlock.taskID
        self.startMinute = movedBlock.startMinute
        durationMinutes = movedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar, context: context)
        return true
    }

    @discardableResult
    func resizeBlock(
        _ id: DayPlanBlock.ID,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        calendar: Calendar,
        context: ModelContext
    ) -> Bool {
        guard let locatedBlock = locatedBlock(id, calendar: calendar) else { return false }

        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let targetStartMinute = DayPlanBlock.clampedStartMinute(startMinute)
        let targetDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: targetStartMinute
        )
        let targetEndMinute = targetStartMinute + targetDuration
        var dayBlocks = weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
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
        DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: dayKey, context: context)

        selectedDate = date
        selectedBlockID = resizedBlock.id
        selectedTaskID = resizedBlock.taskID
        self.startMinute = resizedBlock.startMinute
        self.durationMinutes = resizedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar, context: context)
        return true
    }

    func commitBlock(task: RoutineTask, calendar: Calendar, context: ModelContext) {
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
        persistBlocks(calendar: calendar, context: context)
    }

    func blocks(on date: Date, calendar: Calendar, context: ModelContext) -> [DayPlanBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
    }

    func weekDates(calendar: Calendar) -> [Date] {
        weekDates(containing: visibleDate, calendar: calendar)
    }

    func moveWeek(by value: Int, calendar: Calendar, context: ModelContext) {
        let dayDelta = value * 7
        selectedDate = calendar.date(byAdding: .day, value: dayDelta, to: selectedDate) ?? selectedDate
        visibleDate = calendar.date(byAdding: .day, value: dayDelta, to: visibleDate) ?? visibleDate
        selectedBlockID = nil
        loadBlocks(calendar: calendar, context: context)
    }

    func moveToToday(calendar: Calendar, context: ModelContext) {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        visibleDate = today
        selectedBlockID = nil
        loadBlocks(calendar: calendar, context: context)
    }

    func showDate(_ date: Date, calendar: Calendar, context: ModelContext) {
        let selectedDay = calendar.startOfDay(for: date)
        selectedDate = selectedDay
        visibleDate = selectedDay
        selectedBlockID = nil
        loadBlocks(calendar: calendar, context: context)
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

    private func syncSelectedDayBlocks(calendar: Calendar, context: ModelContext) {
        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        blocks = weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
    }

    private func exactScheduledDate(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> Date? {
        if task.isOneOffTask {
            guard let deadline = task.deadline,
                  calendar.isDate(deadline, inSameDayAs: date),
                  hasExplicitTime(deadline, calendar: calendar) else {
                return nil
            }
            return deadline
        }

        return RoutineDateMath.scheduledOccurrence(for: task, on: date, calendar: calendar)
    }

    private func hasExplicitTime(_ date: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return (components.hour ?? 0) != 0
            || (components.minute ?? 0) != 0
            || (components.second ?? 0) != 0
            || (components.nanosecond ?? 0) != 0
    }

    private func startMinute(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        return DayPlanBlock.clampedStartMinute(minute)
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
        let selectedDay = calendar.startOfDay(for: date)
        let startDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDay)
        }
    }

    private func visibleAndSelectedDates(calendar: Calendar) -> [Date] {
        let visibleDates = weekDates(calendar: calendar)
        guard !visibleDates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) else {
            return visibleDates
        }

        return visibleDates + [selectedDate]
    }

    private static func defaultSelectedDate(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        calendar.startOfDay(for: now)
    }
}
