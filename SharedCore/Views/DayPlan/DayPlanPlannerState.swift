import Combine
import Foundation
import SwiftData

struct DayPlanFocusedSleep: Equatable {
    let sessionID: UUID
    let startMinute: Int
    private let token = UUID()

    var scrollTargetID: UUID {
        token
    }
}

enum DayPlanVisibleRangeMode: String, CaseIterable, Identifiable {
    case day
    case threeDays
    case week

    var id: Self { self }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .threeDays:
            return "3 Days"
        case .week:
            return "Week"
        }
    }

    var navigationDayCount: Int {
        visibleDayCount
    }

    var visibleDayCount: Int {
        switch self {
        case .day:
            return 1
        case .threeDays:
            return 3
        case .week:
            return 7
        }
    }
}

enum DayPlanDisplayMode: String, CaseIterable, Identifiable {
    case calendar
    case list

    var id: Self { self }

    var title: String {
        switch self {
        case .calendar:
            return "Calendar"
        case .list:
            return "Timeline"
        }
    }

    var systemImage: String {
        switch self {
        case .calendar:
            return "calendar"
        case .list:
            return "list.bullet"
        }
    }
}

enum DayPlanHourSpacing: String, CaseIterable, Identifiable {
    case standard
    case spacious
    case expanded

    var id: Self { self }

    var hourHeight: Double {
        switch self {
        case .standard:
            return 64
        case .spacious:
            return 88
        case .expanded:
            return 112
        }
    }

    var next: Self {
        switch self {
        case .standard:
            return .spacious
        case .spacious:
            return .expanded
        case .expanded:
            return .expanded
        }
    }

    var previous: Self {
        switch self {
        case .standard:
            return .standard
        case .spacious:
            return .standard
        case .expanded:
            return .spacious
        }
    }
}

private struct DayPlanPlannerUndoSnapshot: Equatable {
    var dayKey: String
    var blocks: [DayPlanBlock]
}

private struct DayPlanPlannerUndoSide: Equatable {
    var snapshots: [DayPlanPlannerUndoSnapshot]
    var focusedBlockID: UUID
    var focusedDate: Date
    var focusedStartMinute: Int
}

private struct DayPlanPlannerUndoChange: Equatable {
    var actionName: String
    var undoSide: DayPlanPlannerUndoSide
    var redoSide: DayPlanPlannerUndoSide
}

private struct DayPlanPendingResizeUndo {
    var blockID: UUID
    var beforeSide: DayPlanPlannerUndoSide
}

@MainActor
private final class DayPlanPlannerUndoTarget: NSObject {
    weak var planner: DayPlanPlannerState?
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
    private var maximumAdaptiveVisibleRangeMode: DayPlanVisibleRangeMode = .week
    private var pendingResizeUndo: DayPlanPendingResizeUndo?
    private var plannerUndoChange: DayPlanPlannerUndoChange?
    private var plannerRedoChange: DayPlanPlannerUndoChange?
    private let undoTarget = DayPlanPlannerUndoTarget()

    init(
        selectedDate: Date = DayPlanPlannerState.defaultSelectedDate(),
        visibleRangeMode: DayPlanVisibleRangeMode = .week
    ) {
        self.selectedDate = selectedDate
        self.visibleDate = selectedDate
        self.visibleRangeMode = visibleRangeMode
        self.preferredVisibleRangeMode = visibleRangeMode
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

        if isExternalInspectorPresented,
           width < Double(DayPlanWeekCalendarSizing.inspectorMultiDayMinimumCalendarWidth) {
            return .day
        }

        let availableDayWidth = max(width - 64, 0)
        if availableDayWidth >= 7 * 150 {
            return .week
        }
        if availableDayWidth >= 3 * 150 {
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
        clearMissingSelectedBlock()
    }

    func showExactTimedTasks(
        from tasks: [RoutineTask],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        context: ModelContext
    ) {
        let visibleDates = visibleAndSelectedDates(calendar: calendar)
        let availableTasks = DayPlanTaskSorting.availableTasks(from: tasks)
        let now = Date()
        var updatedBlocksByDayKey = weekBlocksByDayKey

        for date in visibleDates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            var dayBlocks = updatedBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
            var didChangeDay = false

            for task in availableTasks {
                guard let scheduledBlock = exactScheduledBlock(for: task, on: date, calendar: calendar) else {
                    continue
                }
                let startMinute = startMinute(for: scheduledBlock.startDate, calendar: calendar)
                let durationMinutes = scheduledDurationMinutes(
                    for: scheduledBlock,
                    task: task,
                    startMinute: startMinute
                )
                guard !task.isArchived(referenceDate: scheduledBlock.startDate, calendar: calendar) else {
                    if removeStaleScheduledBlocks(
                        from: &dayBlocks,
                        taskID: task.id,
                        scheduledStartMinute: startMinute,
                        scheduledDurationMinutes: durationMinutes
                    ) {
                        didChangeDay = true
                    }
                    continue
                }

                if let existingIndex = dayBlocks.firstIndex(where: { $0.taskID == task.id }) {
                    let existingBlock = dayBlocks[existingIndex]
                    guard shouldRefreshScheduledBlock(
                        existingBlock,
                        scheduledStartMinute: startMinute,
                        scheduledDurationMinutes: durationMinutes
                    ) else {
                        continue
                    }
                    guard !hasConflict(
                        in: dayBlocks,
                        ignoring: existingBlock.id,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes
                    ) else {
                        continue
                    }
                    guard !isBlocked(
                        dayKey: dayKey,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        blockedIntervalsByDayKey: blockedIntervalsByDayKey
                    ) else {
                        continue
                    }

                    dayBlocks[existingIndex] = DayPlanBlock(
                        id: existingBlock.id,
                        taskID: task.id,
                        dayKey: dayKey,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        titleSnapshot: DayPlanTaskSorting.title(for: task),
                        emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                        createdAt: existingBlock.createdAt,
                        updatedAt: now,
                        minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
                    )
                    didChangeDay = true
                    continue
                }

                guard !isBlocked(
                    dayKey: dayKey,
                    startMinute: startMinute,
                    durationMinutes: durationMinutes,
                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                ) else {
                    continue
                }

                dayBlocks.append(
                    DayPlanBlock(
                        taskID: task.id,
                        dayKey: dayKey,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        titleSnapshot: DayPlanTaskSorting.title(for: task),
                        emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
                        createdAt: now,
                        updatedAt: now,
                        minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
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
        clearMissingSelectedBlock()
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
            updatedAt: Date(),
            minimumDurationMinutes: targetMinimumDuration
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
        if pendingResizeUndo == nil,
           let beforeSide = focusSide(
                snapshots: snapshots(forDayKeys: [dayKey], context: context),
                blockID: id,
                fallbackDate: date,
                fallbackStartMinute: locatedBlock.block.startMinute,
                calendar: calendar
           ) {
            pendingResizeUndo = DayPlanPendingResizeUndo(blockID: id, beforeSide: beforeSide)
        }
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
        focusedSleep = nil
        selectedBlockID = resizedBlock.id
        selectedTaskID = resizedBlock.taskID
        self.startMinute = resizedBlock.startMinute
        self.durationMinutes = resizedBlock.durationMinutes
        syncSelectedDayBlocks(calendar: calendar, context: context)
        return true
    }

    func beginResizeBlock(
        _ block: DayPlanBlock,
        on date: Date,
        calendar: Calendar,
        context: ModelContext
    ) {
        clearPlannerUndoHighlight()
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        guard let beforeSide = focusSide(
            snapshots: snapshots(forDayKeys: [dayKey], context: context),
            blockID: block.id,
            fallbackDate: date,
            fallbackStartMinute: block.startMinute,
            calendar: calendar
        ) else { return }
        pendingResizeUndo = DayPlanPendingResizeUndo(blockID: block.id, beforeSide: beforeSide)
    }

    func endResizeBlock(
        _ blockID: DayPlanBlock.ID?,
        calendar: Calendar,
        context: ModelContext
    ) {
        guard let pendingResizeUndo,
              blockID == nil || pendingResizeUndo.blockID == blockID
        else {
            self.pendingResizeUndo = nil
            return
        }

        let dayKeys = pendingResizeUndo.beforeSide.snapshots.map(\.dayKey)
        let afterSnapshots = snapshots(forDayKeys: dayKeys, context: context)
        let afterSide = focusSide(
            snapshots: afterSnapshots,
            blockID: pendingResizeUndo.blockID,
            fallbackDate: pendingResizeUndo.beforeSide.focusedDate,
            fallbackStartMinute: pendingResizeUndo.beforeSide.focusedStartMinute,
            calendar: calendar
        )

        self.pendingResizeUndo = nil

        guard let afterSide else { return }
        registerPlannerUndoIfNeeded(
            actionName: "Resize Planner Block",
            beforeSnapshots: pendingResizeUndo.beforeSide.snapshots,
            afterSnapshots: afterSnapshots,
            beforeFocus: pendingResizeUndo.beforeSide,
            afterFocus: afterSide,
            calendar: calendar,
            context: context
        )
    }

    func clearPlannerUndo() {
        pendingResizeUndo = nil
        plannerUndoChange = nil
        plannerRedoChange = nil
        clearPlannerUndoHighlight()
        RoutinaUndoSupport.removeUndoActions(withTarget: undoTarget)
        RoutinaUndoSupport.setActiveUndoManager(nil)
        RoutinaUndoSupport.clearActiveScopedUndo()
    }

    @discardableResult
    func performPlannerUndo(calendar: Calendar, context: ModelContext) -> Bool {
        guard let change = plannerUndoChange else { return false }
        restore(change.undoSide, calendar: calendar, context: context)
        plannerUndoChange = nil
        plannerRedoChange = DayPlanPlannerUndoChange(
            actionName: change.actionName,
            undoSide: change.redoSide,
            redoSide: change.undoSide
        )
        return true
    }

    @discardableResult
    func performPlannerRedo(calendar: Calendar, context: ModelContext) -> Bool {
        guard let change = plannerRedoChange else { return false }
        restore(change.undoSide, calendar: calendar, context: context)
        plannerRedoChange = nil
        plannerUndoChange = DayPlanPlannerUndoChange(
            actionName: change.actionName,
            undoSide: change.redoSide,
            redoSide: change.undoSide
        )
        return true
    }

    private func registerPlannerUndoIfNeeded(
        actionName: String,
        beforeSnapshots: [DayPlanPlannerUndoSnapshot],
        afterSnapshots: [DayPlanPlannerUndoSnapshot],
        beforeFocus: DayPlanPlannerUndoSide?,
        afterFocus: DayPlanPlannerUndoSide?,
        calendar: Calendar,
        context: ModelContext
    ) {
        guard beforeSnapshots != afterSnapshots,
              let beforeFocus,
              let afterFocus
        else { return }

        registerPlannerUndo(
            DayPlanPlannerUndoChange(
                actionName: actionName,
                undoSide: beforeFocus,
                redoSide: afterFocus
            ),
            calendar: calendar,
            context: context
        )
    }

    private func registerPlannerUndo(
        _ change: DayPlanPlannerUndoChange,
        calendar: Calendar,
        context: ModelContext
    ) {
        plannerUndoChange = change
        plannerRedoChange = nil

        guard let undoManager = RoutinaUndoSupport.currentUndoManager,
              undoManager.isUndoRegistrationEnabled
        else { return }

        undoManager.registerUndo(withTarget: undoTarget) { target in
            target.planner?.applyPlannerUndo(change, calendar: calendar, context: context)
        }
        undoManager.setActionName(change.actionName)
    }

    private func applyPlannerUndo(
        _ change: DayPlanPlannerUndoChange,
        calendar: Calendar,
        context: ModelContext
    ) {
        restore(change.undoSide, calendar: calendar, context: context)

        registerPlannerUndo(
            DayPlanPlannerUndoChange(
                actionName: change.actionName,
                undoSide: change.redoSide,
                redoSide: change.undoSide
            ),
            calendar: calendar,
            context: context
        )
    }

    private func restore(
        _ side: DayPlanPlannerUndoSide,
        calendar: Calendar,
        context: ModelContext
    ) {
        for snapshot in side.snapshots {
            DayPlanStorage.saveBlocks(snapshot.blocks, forDayKey: snapshot.dayKey, context: context)
            weekBlocksByDayKey[snapshot.dayKey] = snapshot.blocks
        }

        showDate(side.focusedDate, calendar: calendar, context: context)

        if let focusedBlock = block(withID: side.focusedBlockID) {
            selectedBlockID = focusedBlock.id
            selectedTaskID = focusedBlock.taskID
            startMinute = focusedBlock.startMinute
            durationMinutes = focusedBlock.durationMinutes
            highlightedBlockID = focusedBlock.id
            highlightedBlockScrollMinute = focusedBlock.startMinute
        } else {
            highlightedBlockID = side.focusedBlockID
            highlightedBlockScrollMinute = side.focusedStartMinute
        }

        NotificationCenter.default.postRoutineDidUpdate()
    }

    private func block(withID blockID: UUID) -> DayPlanBlock? {
        blocks.first { $0.id == blockID }
            ?? weekBlocksByDayKey.values.lazy.compactMap { dayBlocks in
                dayBlocks.first { $0.id == blockID }
            }
            .first
    }

    private func snapshots(
        forDayKeys dayKeys: [String],
        context: ModelContext
    ) -> [DayPlanPlannerUndoSnapshot] {
        orderedUniqueDayKeys(dayKeys).map { dayKey in
            DayPlanPlannerUndoSnapshot(
                dayKey: dayKey,
                blocks: weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
            )
        }
    }

    private func focusSide(
        snapshots: [DayPlanPlannerUndoSnapshot],
        blockID: UUID,
        fallbackDate: Date,
        fallbackStartMinute: Int,
        calendar: Calendar
    ) -> DayPlanPlannerUndoSide? {
        let focusedSnapshot = snapshots.first { snapshot in
            snapshot.blocks.contains { $0.id == blockID }
        }
        let focusedBlock = focusedSnapshot?.blocks.first { $0.id == blockID }
        let focusedDate = focusedSnapshot
            .flatMap { dateForDayKey($0.dayKey, calendar: calendar) }
            ?? calendar.startOfDay(for: fallbackDate)

        return DayPlanPlannerUndoSide(
            snapshots: snapshots,
            focusedBlockID: blockID,
            focusedDate: focusedDate,
            focusedStartMinute: focusedBlock?.startMinute ?? fallbackStartMinute
        )
    }

    private func orderedUniqueDayKeys(_ dayKeys: [String]) -> [String] {
        var seen: Set<String> = []
        return dayKeys.filter { dayKey in
            seen.insert(dayKey).inserted
        }
    }

    private func dateForDayKey(_ dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private func clearPlannerUndoHighlight() {
        highlightedBlockID = nil
        highlightedBlockScrollMinute = nil
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
        return weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
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
        preferredVisibleRangeMode = mode
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

    private func syncSelectedDayBlocks(calendar: Calendar, context: ModelContext) {
        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        blocks = weekBlocksByDayKey[dayKey] ?? DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)
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
        var fallbackDurationMinutes: Int? = nil
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

    private func shouldRefreshScheduledBlock(
        _ block: DayPlanBlock,
        scheduledStartMinute: Int,
        scheduledDurationMinutes: Int
    ) -> Bool {
        guard block.startMinute == scheduledStartMinute,
              block.durationMinutes > scheduledDurationMinutes
        else {
            return false
        }

        return block.durationMinutes == 60
            || (
                scheduledDurationMinutes < DayPlanBlock.minimumDurationMinutes
                    && block.durationMinutes == DayPlanBlock.minimumDurationMinutes
            )
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
                if let timeRange = task.recurrenceRule.timeRange {
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
                  hasExplicitTime(deadline, calendar: calendar) else {
                return nil
            }
            return ExactScheduledBlock(startDate: deadline, durationMinutes: nil)
        }

        guard let occurrence = RoutineDateMath.scheduledOccurrence(for: task, on: date, calendar: calendar) else {
            return nil
        }
        let windowDuration = task.recurrenceRule.timeRange.flatMap { timeRange in
            availabilityWindowDuration(
                start: occurrence,
                end: timeRange.endDate(on: occurrence, calendar: calendar)
            )
        }
        return ExactScheduledBlock(
            startDate: occurrence,
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

    private func sortedDayBlocks(_ blocks: [DayPlanBlock]) -> [DayPlanBlock] {
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
        loadBlocks(calendar: calendar, context: context)
        return true
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
