import Combine
import Foundation
import SwiftData

private struct ExactTimedTaskSynchronizationContext {
    var date: Date
    var dayKey: String
    var blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    var now: Date
    var calendar: Calendar
}

private extension DayPlanBlock {
    func moved(
        toDayKey dayKey: String,
        startMinute: Int,
        durationMinutes: Int,
        minimumDurationMinutes: Int
    ) -> DayPlanBlock {
        DayPlanBlock(
            id: id,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            titleSnapshot: titleSnapshot,
            emojiSnapshot: emojiSnapshot,
            createdAt: createdAt,
            updatedAt: Date(),
            minimumDurationMinutes: minimumDurationMinutes
        )
    }
}

@MainActor
final class DayPlanPlannerState: ObservableObject {
    @Published var selectedDate: Date
    @Published var blocks: [DayPlanBlock] = []
    @Published var weekBlocksByDayKey: [String: [DayPlanBlock]] = [:]
    @Published var selectedTaskID: UUID?
    @Published var selectedBlockID: UUID?
    @Published var searchText = ""
    @Published var startMinute = 9 * 60
    @Published var durationMinutes = 60
    @Published var focusedUnplannedCompletedDate: Date?
    @Published var focusedSleep: DayPlanFocusedSleep?
    @Published private(set) var visibleRangeMode: DayPlanVisibleRangeMode
    @Published var dayHourSpacing: DayPlanHourSpacing = .standard
    @Published var highlightedBlockID: UUID?
    @Published var highlightedBlockScrollMinute: Int?

    @Published private var visibleDate: Date
    private var preferredVisibleRangeMode: DayPlanVisibleRangeMode
    private let preferredVisibleRangeModeDidChange: ((DayPlanVisibleRangeMode) -> Void)?
    @Published private var maximumAdaptiveVisibleRangeMode: DayPlanVisibleRangeMode = .week
    var pendingResizeUndo: DayPlanPendingResizeUndo?
    var plannerUndoChange: DayPlanPlannerUndoChange?
    var plannerRedoChange: DayPlanPlannerUndoChange?
    let undoTarget = DayPlanPlannerUndoTarget()

    init(
        selectedDate: Date = DayPlanPlannerState.defaultSelectedDate(),
        visibleRangeMode: DayPlanVisibleRangeMode = .week,
        preferredVisibleRangeModeDidChange: ((DayPlanVisibleRangeMode) -> Void)? = nil
    ) {
        self.selectedDate = selectedDate
        self.visibleDate = selectedDate
        self.visibleRangeMode = visibleRangeMode
        self.preferredVisibleRangeMode = visibleRangeMode
        self.preferredVisibleRangeModeDidChange = preferredVisibleRangeModeDidChange
        undoTarget.planner = self
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

    var calendarHourHeight: Double {
        switch visibleRangeMode {
        case .day:
            return dayHourSpacing.hourHeight
        case .threeDays, .week:
            return DayPlanHourSpacing.standard.hourHeight
        }
    }

    var visibleRangeNavigationDayCount: Int {
        visibleRangeMode.navigationDayCount
    }

    var availableVisibleRangeModes: [DayPlanVisibleRangeMode] {
        switch maximumAdaptiveVisibleRangeMode {
        case .day:
            return [.day]
        case .threeDays:
            return [.day, .threeDays]
        case .week:
            return DayPlanVisibleRangeMode.allCases
        }
    }

    var canIncreaseDayHourSpacing: Bool {
        dayHourSpacing.next != dayHourSpacing
    }

    var canDecreaseDayHourSpacing: Bool {
        dayHourSpacing.previous != dayHourSpacing
    }

    var conflictingBlock: DayPlanBlock? {
        conflict(startMinute: startMinute, durationMinutes: durationMinutes, ignoring: selectedBlockID)
    }

    func increaseDayHourSpacing() {
        dayHourSpacing = dayHourSpacing.next
    }

    func decreaseDayHourSpacing() {
        dayHourSpacing = dayHourSpacing.previous
    }

    static func adaptiveVisibleRangeMode(
        forAvailableWidth width: Double,
        isExternalInspectorPresented: Bool = false
    ) -> DayPlanVisibleRangeMode {
        guard width > 0 else { return .week }

        let inspectorRequiresSingleDay =
            isExternalInspectorPresented
            && width < Double(DayPlanWeekCalendarSizing.inspectorMultiDayMinimumCalendarWidth)
        if inspectorRequiresSingleDay {
            return .day
        }

        let availableDayWidth = max(
            width - Double(DayPlanWeekCalendarSizing.timeColumnWidth),
            0
        )
        let minimumDayWidth = Double(
            DayPlanWeekCalendarSizing.minimumDayWidth(
                isExternalInspectorPresented: isExternalInspectorPresented
            )
        )
        if availableDayWidth >= Double(DayPlanVisibleRangeMode.week.visibleDayCount) * minimumDayWidth {
            return .week
        }
        if availableDayWidth >= Double(DayPlanVisibleRangeMode.threeDays.visibleDayCount) * minimumDayWidth {
            return .threeDays
        }
        return .day
    }

    func setAdaptiveVisibleRangeMode(
        forAvailableWidth width: Double,
        isExternalInspectorPresented: Bool = false,
        calendar: Calendar,
        context: ModelContext
    ) {
        guard width > 0 else { return }
        setAdaptiveVisibleRangeMode(
            Self.adaptiveVisibleRangeMode(
                forAvailableWidth: width,
                isExternalInspectorPresented: isExternalInspectorPresented
            ),
            calendar: calendar,
            context: context
        )
    }

    func setAdaptiveVisibleRangeMode(
        _ maximumMode: DayPlanVisibleRangeMode,
        calendar: Calendar,
        context: ModelContext
    ) {
        guard maximumAdaptiveVisibleRangeMode != maximumMode else { return }
        maximumAdaptiveVisibleRangeMode = maximumMode
        applyEffectiveVisibleRangeMode(
            Self.effectiveVisibleRangeMode(
                preferred: preferredVisibleRangeMode,
                maximum: maximumAdaptiveVisibleRangeMode
            ),
            resetsVisibleDate: false,
            calendar: calendar,
            context: context
        )
    }

    func loadBlocks(
        calendar: Calendar,
        context: ModelContext,
        preservingCachedUnassignedFocusBlocks: Bool = false
    ) {
        let weekDates = visibleAndSelectedDates(calendar: calendar)
        let cachedBlocksByDayKey = weekBlocksByDayKey
        var loadedBlocksByDayKey: [String: [DayPlanBlock]] = [:]

        for date in weekDates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
            loadedBlocksByDayKey[dayKey] = blocksForLoadedDay(
                loadedBlocks,
                cachedBlocks: cachedBlocksByDayKey[dayKey],
                preservingCachedUnassignedFocusBlocks: preservingCachedUnassignedFocusBlocks
            )
        }

        let selectedDayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        if loadedBlocksByDayKey[selectedDayKey] == nil {
            let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: selectedDayKey, context: context)
            loadedBlocksByDayKey[selectedDayKey] = blocksForLoadedDay(
                loadedBlocks,
                cachedBlocks: cachedBlocksByDayKey[selectedDayKey],
                preservingCachedUnassignedFocusBlocks: preservingCachedUnassignedFocusBlocks
            )
        }

        weekBlocksByDayKey = loadedBlocksByDayKey
        syncSelectedDayBlocks(calendar: calendar, context: context)
        clearMissingSelectedBlock()
    }

    func showExactTimedTasks(
        from tasks: [RoutineTask],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        context: ModelContext
    ) {
        let visibleDates = visibleAndSelectedDates(calendar: calendar)
        let candidateTasks = tasks.filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
        let now = Date()
        var updatedBlocksByDayKey = weekBlocksByDayKey

        for date in visibleDates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            var dayBlocks = cachedOrLoadedBlocks(
                forDayKey: dayKey,
                in: updatedBlocksByDayKey,
                context: context
            )
            let synchronizationContext = ExactTimedTaskSynchronizationContext(
                date: date,
                dayKey: dayKey,
                blockedIntervalsByDayKey: blockedIntervalsByDayKey,
                now: now,
                calendar: calendar
            )
            var didChangeDay = false

            for task in candidateTasks {
                let didChangeTask = synchronizeExactTimedTask(
                    task,
                    dayBlocks: &dayBlocks,
                    context: synchronizationContext
                )
                didChangeDay = didChangeTask || didChangeDay
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
        clearMissingSelectedBlock()
    }

    private func synchronizeExactTimedTask(
        _ task: RoutineTask,
        dayBlocks: inout [DayPlanBlock],
        context: ExactTimedTaskSynchronizationContext
    ) -> Bool {
        var didChange = removeStaleWindowBlockIfNeeded(
            for: task,
            from: &dayBlocks,
            context: context
        )
        guard
            let scheduledBlock = exactScheduledBlock(
                for: task,
                on: context.date,
                calendar: context.calendar
            )
        else {
            return didChange
        }

        let startMinute = startMinute(for: scheduledBlock.startDate, calendar: context.calendar)
        let durationMinutes = scheduledDurationMinutes(
            for: scheduledBlock,
            task: task,
            startMinute: startMinute
        )
        if task.isArchived(referenceDate: scheduledBlock.startDate, calendar: context.calendar) {
            let removedStaleBlock = removeStaleScheduledBlocks(
                from: &dayBlocks,
                taskID: task.id,
                scheduledStartMinute: startMinute,
                scheduledDurationMinutes: durationMinutes
            )
            return removedStaleBlock || didChange
        }

        if let existingIndex = dayBlocks.firstIndex(where: { $0.taskID == task.id }) {
            let updatedExistingBlock = updateExistingExactTimedBlock(
                at: existingIndex,
                in: &dayBlocks,
                for: task,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                context: context
            )
            return updatedExistingBlock || didChange
        }

        guard
            !isBlocked(
                dayKey: context.dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                blockedIntervalsByDayKey: context.blockedIntervalsByDayKey
            )
        else {
            return didChange
        }

        dayBlocks.append(
            synchronizedExactTimedBlock(
                for: task,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                existingBlock: nil,
                context: context
            )
        )
        didChange = true
        return didChange
    }

    private func removeStaleWindowBlockIfNeeded(
        for task: RoutineTask,
        from dayBlocks: inout [DayPlanBlock],
        context: ExactTimedTaskSynchronizationContext
    ) -> Bool {
        guard
            let windowBlock = automaticWindowScheduledBlock(
                for: task,
                on: context.date,
                calendar: context.calendar
            )
        else {
            return false
        }

        let windowStartMinute = startMinute(for: windowBlock.startDate, calendar: context.calendar)
        let windowDurationMinutes = scheduledDurationMinutes(
            for: windowBlock,
            task: task,
            startMinute: windowStartMinute
        )
        return removeStaleScheduledBlocks(
            from: &dayBlocks,
            taskID: task.id,
            scheduledStartMinute: windowStartMinute,
            scheduledDurationMinutes: windowDurationMinutes
        )
    }

    private func updateExistingExactTimedBlock(
        at index: Int,
        in dayBlocks: inout [DayPlanBlock],
        for task: RoutineTask,
        startMinute: Int,
        durationMinutes: Int,
        context: ExactTimedTaskSynchronizationContext
    ) -> Bool {
        let existingBlock = dayBlocks[index]
        guard
            shouldAutomaticallyManageScheduledBlock(
                existingBlock,
                scheduledStartMinute: startMinute,
                scheduledDurationMinutes: durationMinutes
            )
        else {
            return false
        }
        let needsUpdate =
            existingBlock.placementSource != .automatic
            || existingBlock.startMinute != startMinute
            || existingBlock.durationMinutes != durationMinutes
        guard needsUpdate else { return false }

        dayBlocks[index] = synchronizedExactTimedBlock(
            for: task,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            existingBlock: existingBlock,
            context: context
        )
        return true
    }

    private func synchronizedExactTimedBlock(
        for task: RoutineTask,
        startMinute: Int,
        durationMinutes: Int,
        existingBlock: DayPlanBlock?,
        context: ExactTimedTaskSynchronizationContext
    ) -> DayPlanBlock {
        DayPlanBlock(
            id: existingBlock?.id ?? UUID(),
            taskID: task.id,
            dayKey: context.dayKey,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            titleSnapshot: DayPlanTaskSorting.title(for: task),
            emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            createdAt: existingBlock?.createdAt ?? context.now,
            updatedAt: context.now,
            placementSource: .automatic,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
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
        focusedSleep = nil
        clearPlannerUndoHighlight()
        selectedTaskID = task.id
        if selectedBlock == nil, let estimate = task.estimatedDurationMinutes {
            durationMinutes = DayPlanBlock.clampedDuration(
                estimate,
                startMinute: startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            )
        }
    }

    func focusUnplannedCompletedTasks(on date: Date, calendar: Calendar) {
        focusedSleep = nil
        focusedUnplannedCompletedDate = calendar.startOfDay(for: date)
        searchText = ""
    }

    func clearFocusedUnplannedCompletedTasks() {
        focusedUnplannedCompletedDate = nil
    }

    func focusSleepSession(_ session: SleepSession, calendar: Calendar, context: ModelContext) {
        guard let startedAt = session.startedAt else { return }
        showDate(startedAt, calendar: calendar, context: context)
        let sleepStartMinute = startMinute(for: startedAt, calendar: calendar)
        selectedTaskID = nil
        selectedBlockID = nil
        startMinute = sleepStartMinute
        focusedUnplannedCompletedDate = nil
        searchText = ""
        focusedSleep = DayPlanFocusedSleep(sessionID: session.id, startMinute: sleepStartMinute)
    }

    func clearFocusedSleep() {
        focusedSleep = nil
    }

    func selectSlot(on date: Date, startMinute: Int, calendar: Calendar, context: ModelContext) {
        focusedSleep = nil
        clearPlannerUndoHighlight()
        selectedDate = date
        selectedBlockID = nil
        syncSelectedDayBlocks(calendar: calendar, context: context)
        self.startMinute = DayPlanBlock.clampedStartMinute(startMinute)
        clampDurationForCurrentStart()
    }

    func edit(_ block: DayPlanBlock, on date: Date? = nil, calendar: Calendar? = nil, context: ModelContext) {
        focusedSleep = nil
        clearPlannerUndoHighlight()
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
        let affectedDayKeys = orderedUniqueDayKeys([locatedBlock.dayKey, targetDayKey])
        let beforeSnapshots = snapshots(forDayKeys: affectedDayKeys, context: context)
        let targetMinimumDuration = minimumDurationForExistingBlock(locatedBlock.block)
        let targetStartMinute = DayPlanBlock.clampedStartMinute(
            startMinute,
            minimumDurationMinutes: targetMinimumDuration
        )
        let targetDuration = DayPlanBlock.clampedDuration(
            locatedBlock.block.durationMinutes,
            startMinute: targetStartMinute,
            minimumDurationMinutes: targetMinimumDuration
        )
        var targetBlocks =
            weekBlocksByDayKey[targetDayKey]
            ?? DayPlanStorage.loadBlocks(forDayKey: targetDayKey, context: context)
        let targetEndMinute = targetStartMinute + targetDuration
        let hasConflict = targetBlocks.contains { block in
            guard block.id != id else { return false }
            return max(targetStartMinute, block.startMinute) < min(targetEndMinute, block.endMinute)
        }

        guard !hasConflict else { return false }

        let movedBlock = locatedBlock.block.moved(
            toDayKey: targetDayKey,
            startMinute: targetStartMinute,
            durationMinutes: targetDuration,
            minimumDurationMinutes: targetMinimumDuration
        )
        var sourceBlocks =
            weekBlocksByDayKey[locatedBlock.dayKey]
            ?? DayPlanStorage.loadBlocks(forDayKey: locatedBlock.dayKey, context: context)
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
        focusedSleep = nil
        selectedBlockID = movedBlock.id
        selectedTaskID = movedBlock.taskID
        self.startMinute = movedBlock.startMinute
        durationMinutes = movedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar, context: context)
        let afterSnapshots = snapshots(forDayKeys: affectedDayKeys, context: context)
        registerPlannerUndoIfNeeded(
            actionName: "Move Planner Block",
            beforeSnapshots: beforeSnapshots,
            afterSnapshots: afterSnapshots,
            beforeFocus: focusSide(
                snapshots: beforeSnapshots,
                blockID: id,
                fallbackDate: dateForDayKey(locatedBlock.dayKey, calendar: calendar) ?? selectedDate,
                fallbackStartMinute: locatedBlock.block.startMinute,
                calendar: calendar
            ),
            afterFocus: focusSide(
                snapshots: afterSnapshots,
                blockID: id,
                fallbackDate: date,
                fallbackStartMinute: movedBlock.startMinute,
                calendar: calendar
            ),
            calendar: calendar,
            context: context
        )
        return true
    }

    @discardableResult
    func duplicateBlock(_ id: DayPlanBlock.ID, to date: Date, startMinute: Int, calendar: Calendar, context: ModelContext) -> Bool {
        guard let locatedBlock = locatedBlock(id, calendar: calendar) else { return false }

        let targetDayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let beforeSnapshots = snapshots(forDayKeys: [targetDayKey], context: context)
        let targetMinimumDuration = minimumDurationForExistingBlock(locatedBlock.block)
        let targetStartMinute = DayPlanBlock.clampedStartMinute(
            startMinute,
            minimumDurationMinutes: targetMinimumDuration
        )
        let targetDuration = DayPlanBlock.clampedDuration(
            locatedBlock.block.durationMinutes,
            startMinute: targetStartMinute,
            minimumDurationMinutes: targetMinimumDuration
        )
        var targetBlocks =
            weekBlocksByDayKey[targetDayKey]
            ?? DayPlanStorage.loadBlocks(forDayKey: targetDayKey, context: context)
        let targetEndMinute = targetStartMinute + targetDuration
        let hasConflict = targetBlocks.contains { block in
            max(targetStartMinute, block.startMinute) < min(targetEndMinute, block.endMinute)
        }

        guard !hasConflict else { return false }

        let now = Date()
        let duplicatedBlock = DayPlanBlock(
            taskID: locatedBlock.block.taskID,
            dayKey: targetDayKey,
            startMinute: targetStartMinute,
            durationMinutes: targetDuration,
            titleSnapshot: locatedBlock.block.titleSnapshot,
            emojiSnapshot: locatedBlock.block.emojiSnapshot,
            createdAt: now,
            updatedAt: now,
            minimumDurationMinutes: targetMinimumDuration
        )

        targetBlocks.append(duplicatedBlock)
        let sortedTargetBlocks = sortedDayBlocks(targetBlocks)
        weekBlocksByDayKey[targetDayKey] = sortedTargetBlocks
        DayPlanStorage.saveBlocks(sortedTargetBlocks, forDayKey: targetDayKey, context: context)

        let targetDate = calendar.startOfDay(for: date)
        selectedDate = targetDate
        focusedSleep = nil
        selectedBlockID = duplicatedBlock.id
        selectedTaskID = duplicatedBlock.taskID
        self.startMinute = duplicatedBlock.startMinute
        durationMinutes = duplicatedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar, context: context)
        let afterSnapshots = snapshots(forDayKeys: [targetDayKey], context: context)
        let sourceDate = dateForDayKey(locatedBlock.dayKey, calendar: calendar) ?? selectedDate
        registerPlannerUndoIfNeeded(
            actionName: "Duplicate Planner Block",
            beforeSnapshots: beforeSnapshots,
            afterSnapshots: afterSnapshots,
            beforeFocus: DayPlanPlannerUndoSide(
                snapshots: beforeSnapshots,
                focusedBlockID: locatedBlock.block.id,
                focusedDate: sourceDate,
                focusedStartMinute: locatedBlock.block.startMinute
            ),
            afterFocus: DayPlanPlannerUndoSide(
                snapshots: afterSnapshots,
                focusedBlockID: duplicatedBlock.id,
                focusedDate: targetDate,
                focusedStartMinute: duplicatedBlock.startMinute
            ),
            calendar: calendar,
            context: context
        )
        return true
    }

    @discardableResult
    func confirmTimelineActivity(
        _ activity: DayPlanTimelineActivityBlock,
        on date: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> Bool {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        var dayBlocks = weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)

        if let existingBlock = dayBlocks.first(where: { $0.taskID == activity.block.taskID }) {
            selectedDate = date
            focusedSleep = nil
            selectedBlockID = existingBlock.id
            selectedTaskID = existingBlock.taskID
            startMinute = existingBlock.startMinute
            durationMinutes = existingBlock.durationMinutes
            weekBlocksByDayKey[dayKey] = dayBlocks
            syncSelectedDayBlocks(calendar: calendar, context: context)
            return true
        }

        let now = Date()
        let confirmedBlock = DayPlanBlock(
            taskID: activity.block.taskID,
            dayKey: dayKey,
            startMinute: activity.block.startMinute,
            durationMinutes: activity.block.durationMinutes,
            titleSnapshot: activity.block.titleSnapshot,
            emojiSnapshot: activity.block.emojiSnapshot,
            createdAt: now,
            updatedAt: now
        )

        dayBlocks.append(confirmedBlock)
        let sortedBlocks = sortedDayBlocks(dayBlocks)
        weekBlocksByDayKey[dayKey] = sortedBlocks
        DayPlanStorage.saveBlocks(sortedBlocks, forDayKey: dayKey, context: context)

        selectedDate = date
        focusedSleep = nil
        selectedBlockID = confirmedBlock.id
        selectedTaskID = confirmedBlock.taskID
        startMinute = confirmedBlock.startMinute
        durationMinutes = confirmedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar, context: context)
        return true
    }

    func commitBlock(task: RoutineTask, calendar: Calendar, context: ModelContext) {
        guard conflictingBlock == nil else { return }
        focusedSleep = nil
        clearPlannerUndoHighlight()

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
                updatedAt: now,
                minimumDurationMinutes: minimumDurationForDraftDuration()
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
                updatedAt: now,
                minimumDurationMinutes: minimumDurationForDraftDuration()
            )
            blocks.append(block)
            selectedBlockID = block.id
        }

        blocks.sort { $0.startMinute < $1.startMinute }
        persistBlocks(calendar: calendar, context: context)
    }

    func blocks(on date: Date, calendar: Calendar, context: ModelContext) -> [DayPlanBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return cachedOrLoadedBlocks(forDayKey: dayKey, in: weekBlocksByDayKey, context: context)
    }

    func visibleDates(calendar: Calendar) -> [Date] {
        switch visibleRangeMode {
        case .day:
            return [calendar.startOfDay(for: selectedDate)]
        case .threeDays:
            return rangeDates(
                containing: visibleDate,
                dayCount: DayPlanVisibleRangeMode.threeDays.visibleDayCount,
                calendar: calendar
            )
        case .week:
            return weekDates(calendar: calendar)
        }
    }

    func visibleAndSelectedDates(calendar: Calendar) -> [Date] {
        let visibleDates = visibleDates(calendar: calendar)
        guard !visibleDates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) else {
            return visibleDates
        }

        return visibleDates + [selectedDate]
    }

    func weekDates(calendar: Calendar) -> [Date] {
        rangeDates(
            containing: visibleDate,
            dayCount: DayPlanVisibleRangeMode.week.visibleDayCount,
            calendar: calendar
        )
    }

    func setVisibleRangeMode(
        _ mode: DayPlanVisibleRangeMode,
        calendar: Calendar,
        context: ModelContext
    ) {
        let preferredModeChanged = preferredVisibleRangeMode != mode
        preferredVisibleRangeMode = mode
        if preferredModeChanged {
            preferredVisibleRangeModeDidChange?(mode)
        }
        applyEffectiveVisibleRangeMode(
            Self.effectiveVisibleRangeMode(
                preferred: preferredVisibleRangeMode,
                maximum: maximumAdaptiveVisibleRangeMode
            ),
            resetsVisibleDate: true,
            calendar: calendar,
            context: context
        )
    }

    func moveVisibleRange(by value: Int, calendar: Calendar, context: ModelContext) {
        let dayDelta = value * visibleRangeNavigationDayCount
        selectedDate = calendar.date(byAdding: .day, value: dayDelta, to: selectedDate) ?? selectedDate
        visibleDate = calendar.date(byAdding: .day, value: dayDelta, to: visibleDate) ?? visibleDate
        focusedSleep = nil
        selectedBlockID = nil
        loadBlocks(calendar: calendar, context: context)
    }

    func moveWeek(by value: Int, calendar: Calendar, context: ModelContext) {
        moveVisibleRange(by: value, calendar: calendar, context: context)
    }

    func moveToToday(calendar: Calendar, context: ModelContext) {
        let today = calendar.startOfDay(for: Date())
        selectedDate = today
        visibleDate = today
        focusedSleep = nil
        selectedBlockID = nil
        loadBlocks(calendar: calendar, context: context)
    }

    func showDate(_ date: Date, calendar: Calendar, context: ModelContext) {
        let selectedDay = calendar.startOfDay(for: date)
        selectedDate = selectedDay
        visibleDate = selectedDay
        focusedSleep = nil
        selectedBlockID = nil
        loadBlocks(calendar: calendar, context: context)
    }

    func visibleRangeTitle(calendar: Calendar) -> String {
        switch visibleRangeMode {
        case .day:
            return selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
        case .threeDays:
            return rangeTitle(
                rangeDates(
                    containing: visibleDate,
                    dayCount: DayPlanVisibleRangeMode.threeDays.visibleDayCount,
                    calendar: calendar
                ),
                calendar: calendar
            )
        case .week:
            return weekTitle(calendar: calendar)
        }
    }

    func weekTitle(calendar: Calendar) -> String {
        rangeTitle(weekDates(calendar: calendar), calendar: calendar)
    }

    func rangeTitle(_ dates: [Date], calendar: Calendar) -> String {
        guard let first = dates.first, let last = dates.last else {
            return selectedDate.formatted(date: .abbreviated, time: .omitted)
        }

        if calendar.isDate(first, inSameDayAs: last) {
            return first.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
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
        let duration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: start,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        let end = start + duration

        return blocks.first { block in
            guard block.id != ignoredBlockID else { return false }
            return max(start, block.startMinute) < min(end, block.endMinute)
        }
    }

    func sleepConflict(
        in intervals: [DayPlanBlockedInterval],
        startMinute: Int,
        durationMinutes: Int
    ) -> DayPlanBlockedInterval? {
        intervals.first {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    func clampDurationForCurrentStart() {
        durationMinutes = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
    }

    func syncSelectedDayBlocks(calendar: Calendar, context: ModelContext) {
        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        blocks = cachedOrLoadedBlocks(forDayKey: dayKey, in: weekBlocksByDayKey, context: context)
    }

    private func cachedOrLoadedBlocks(
        forDayKey dayKey: String,
        in blocksByDayKey: [String: [DayPlanBlock]],
        context: ModelContext
    ) -> [DayPlanBlock] {
        guard let cachedBlocks = blocksByDayKey[dayKey] else {
            return DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
        }

        guard cachedBlocks.isEmpty else {
            return cachedBlocks
        }

        let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
        return loadedBlocks.isEmpty ? cachedBlocks : loadedBlocks
    }

    private func clearMissingSelectedBlock() {
        guard let selectedBlockID else { return }
        let isStillLoaded = weekBlocksByDayKey.values.contains { blocks in
            blocks.contains { $0.id == selectedBlockID }
        }
        if !isStillLoaded {
            self.selectedBlockID = nil
        }
    }

    private struct ExactScheduledBlock {
        var startDate: Date
        var durationMinutes: Int?
        var fallbackDurationMinutes: Int?
    }

    private func scheduledDurationMinutes(
        for scheduledBlock: ExactScheduledBlock,
        task: RoutineTask,
        startMinute: Int
    ) -> Int {
        DayPlanBlock.clampedDuration(
            scheduledBlock.durationMinutes
                ?? task.estimatedDurationMinutes
                ?? scheduledBlock.fallbackDurationMinutes
                ?? 60,
            startMinute: startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
    }

    private func shouldAutomaticallyManageScheduledBlock(
        _ block: DayPlanBlock,
        scheduledStartMinute: Int,
        scheduledDurationMinutes: Int
    ) -> Bool {
        switch block.placementSource {
        case .automatic:
            return true
        case .manual:
            return false
        case .legacy:
            let matchesCurrentPlacement =
                block.startMinute == scheduledStartMinute
                && block.durationMinutes == scheduledDurationMinutes
            return matchesCurrentPlacement || block.createdAt == block.updatedAt
        }
    }

    private func removeStaleScheduledBlocks(
        from dayBlocks: inout [DayPlanBlock],
        taskID: UUID,
        scheduledStartMinute: Int,
        scheduledDurationMinutes: Int
    ) -> Bool {
        let originalCount = dayBlocks.count
        dayBlocks.removeAll { block in
            block.taskID == taskID
                && block.startMinute == scheduledStartMinute
                && block.durationMinutes == scheduledDurationMinutes
        }
        return dayBlocks.count != originalCount
    }

    private func hasConflict(
        in blocks: [DayPlanBlock],
        ignoring ignoredBlockID: DayPlanBlock.ID,
        startMinute: Int,
        durationMinutes: Int
    ) -> Bool {
        let endMinute = min(DayPlanBlock.minutesPerDay, startMinute + durationMinutes)
        return blocks.contains { block in
            guard block.id != ignoredBlockID else { return false }
            return max(startMinute, block.startMinute) < min(endMinute, block.endMinute)
        }
    }

    private func minimumDurationForExistingBlock(_ block: DayPlanBlock) -> Int {
        block.durationMinutes < DayPlanBlock.minimumDurationMinutes
            ? DayPlanBlock.minimumStoredDurationMinutes
            : DayPlanBlock.minimumDurationMinutes
    }

    private func minimumDurationForDraftDuration() -> Int {
        durationMinutes < DayPlanBlock.minimumDurationMinutes
            ? DayPlanBlock.minimumStoredDurationMinutes
            : DayPlanBlock.minimumDurationMinutes
    }

    private func exactScheduledBlock(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> ExactScheduledBlock? {
        guard !task.isAllDay else { return nil }

        if task.isOneOffTask {
            if isDateWithinAvailabilityDateBounds(date, for: task, calendar: calendar) {
                let scheduledTimeRange =
                    task.recurrenceTimeRangeRole == .scheduledBlock
                    ? task.recurrenceRule.timeRange
                    : nil
                if let timeRange = scheduledTimeRange {
                    let startDate = timeRange.startDate(on: date, calendar: calendar)
                    let endDate = timeRange.endDate(on: date, calendar: calendar)
                    return ExactScheduledBlock(
                        startDate: startDate,
                        durationMinutes: availabilityWindowDuration(start: startDate, end: endDate)
                    )
                }
                if let timeOfDay = task.recurrenceRule.timeOfDay {
                    return ExactScheduledBlock(
                        startDate: timeOfDay.date(on: date, calendar: calendar),
                        durationMinutes: nil
                    )
                }
            }

            guard let deadline = task.deadline,
                calendar.isDate(deadline, inSameDayAs: date),
                hasExplicitTime(deadline, calendar: calendar)
            else {
                return nil
            }
            return ExactScheduledBlock(startDate: deadline, durationMinutes: nil)
        }

        guard let occurrence = RoutineDateMath.scheduledOccurrence(for: task, on: date, calendar: calendar) else {
            return nil
        }
        if let timeRange = task.recurrenceRule.timeRange {
            guard task.recurrenceTimeRangeRole == .scheduledBlock else { return nil }
            let rangeStart = timeRange.startDate(on: occurrence, calendar: calendar)
            return ExactScheduledBlock(
                startDate: rangeStart,
                durationMinutes: availabilityWindowDuration(
                    start: rangeStart,
                    end: timeRange.endDate(on: rangeStart, calendar: calendar)
                )
            )
        }
        return ExactScheduledBlock(startDate: occurrence, durationMinutes: nil)
    }

    private func automaticWindowScheduledBlock(
        for task: RoutineTask,
        on date: Date,
        calendar: Calendar
    ) -> ExactScheduledBlock? {
        guard !task.isAllDay,
            task.recurrenceTimeRangeRole == .availability,
            let timeRange = task.recurrenceRule.timeRange
        else {
            return nil
        }

        if task.isOneOffTask {
            guard isDateWithinAvailabilityDateBounds(date, for: task, calendar: calendar) else {
                return nil
            }
            let startDate = timeRange.startDate(on: date, calendar: calendar)
            let endDate = timeRange.endDate(on: date, calendar: calendar)
            return ExactScheduledBlock(
                startDate: startDate,
                durationMinutes: availabilityWindowDuration(start: startDate, end: endDate)
            )
        }

        guard let occurrence = RoutineDateMath.scheduledOccurrence(for: task, on: date, calendar: calendar) else {
            return nil
        }
        let rangeStart = timeRange.startDate(on: occurrence, calendar: calendar)
        let windowDuration = availabilityWindowDuration(
            start: rangeStart,
            end: timeRange.endDate(on: rangeStart, calendar: calendar)
        )
        return ExactScheduledBlock(
            startDate: rangeStart,
            durationMinutes: nil,
            fallbackDurationMinutes: windowDuration
        )
    }

    private func availabilityWindowDuration(start: Date, end: Date) -> Int? {
        guard end > start else { return nil }
        return max(Int((end.timeIntervalSince(start) / 60).rounded()), DayPlanBlock.minimumDurationMinutes)
    }

    private func isDateWithinAvailabilityDateBounds(
        _ date: Date,
        for task: RoutineTask,
        calendar: Calendar
    ) -> Bool {
        guard let availabilityStartDate = task.availabilityStartDate else { return false }
        let day = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: availabilityStartDate)
        let endDay = calendar.startOfDay(for: task.availabilityEndDate ?? availabilityStartDate)
        return day >= startDay && day <= endDay
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

    func locatedBlock(
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

    private func isBlocked(
        dayKey: String,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> Bool {
        guard let intervals = blockedIntervalsByDayKey[dayKey] else { return false }
        return intervals.contains {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    func sortedDayBlocks(_ blocks: [DayPlanBlock]) -> [DayPlanBlock] {
        blocks.sorted {
            if $0.startMinute != $1.startMinute {
                return $0.startMinute < $1.startMinute
            }
            return $0.createdAt < $1.createdAt
        }
    }

    @discardableResult
    private func applyEffectiveVisibleRangeMode(
        _ mode: DayPlanVisibleRangeMode,
        resetsVisibleDate: Bool,
        calendar: Calendar,
        context: ModelContext
    ) -> Bool {
        let shouldResetVisibleDate = resetsVisibleDate || visibleRangeMode == .day || mode == .day
        if shouldResetVisibleDate {
            visibleDate = selectedDate
        }

        guard visibleRangeMode != mode else { return false }
        visibleRangeMode = mode
        loadBlocks(
            calendar: calendar,
            context: context,
            preservingCachedUnassignedFocusBlocks: true
        )
        return true
    }

    private func blocksForLoadedDay(
        _ loadedBlocks: [DayPlanBlock],
        cachedBlocks: [DayPlanBlock]?,
        preservingCachedUnassignedFocusBlocks: Bool
    ) -> [DayPlanBlock] {
        guard preservingCachedUnassignedFocusBlocks,
            loadedBlocks.isEmpty,
            let cachedFocusBlocks = cachedBlocks?.filter({ $0.taskID == FocusSession.unassignedTaskID }),
            !cachedFocusBlocks.isEmpty
        else {
            return loadedBlocks
        }

        return sortedDayBlocks(cachedFocusBlocks)
    }

    private func rangeDates(containing date: Date, dayCount: Int, calendar: Calendar) -> [Date] {
        let selectedDay = calendar.startOfDay(for: date)
        let normalizedDayCount = Self.normalizedVisibleDayCount(dayCount)
        let leadingDayCount = min(1, normalizedDayCount - 1)
        let startDay = calendar.date(byAdding: .day, value: -leadingDayCount, to: selectedDay) ?? selectedDay
        return (0..<normalizedDayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDay)
        }
    }

    private static func effectiveVisibleRangeMode(
        preferred: DayPlanVisibleRangeMode,
        maximum: DayPlanVisibleRangeMode
    ) -> DayPlanVisibleRangeMode {
        if preferred.visibleDayCount <= maximum.visibleDayCount {
            return preferred
        }
        return maximum
    }

    private static func normalizedVisibleDayCount(_ dayCount: Int) -> Int {
        if dayCount <= 1 {
            return 1
        }
        if dayCount <= 3 {
            return 3
        }
        return 7
    }

    private static func defaultSelectedDate(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        calendar.startOfDay(for: now)
    }
}
