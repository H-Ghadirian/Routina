import Foundation
import SwiftData

private struct DayPlanCompletedFocusResizeUpdate {
    var session: FocusSession
    var resizedDate: Date
    var updatedBlock: DayPlanBlock
}

extension DayPlanPlannerState {
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
        let beforeSide =
            pendingResizeUndo == nil
            ? focusSide(
                snapshots: snapshots(forDayKeys: [dayKey], context: context),
                blockID: id,
                fallbackDate: date,
                fallbackStartMinute: locatedBlock.block.startMinute,
                calendar: calendar
            )
            : nil
        if let beforeSide {
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
        context: ModelContext,
        focusSessions: [FocusSession] = []
    ) {
        clearPlannerUndoHighlight()
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        let focusSession = DayPlanFocusSessionPlannerSync.completedFocusSession(
            matching: block,
            in: focusSessions
        )
        let affectedDayKeys = orderedUniqueDayKeys(
            [dayKey]
                + (focusSession.map {
                    DayPlanFocusSessionPlannerSync.persistedFocusBlocks(
                        for: $0,
                        context: context
                    )
                    .map(\.dayKey)
                } ?? [])
        )
        let beforeSnapshots = snapshots(forDayKeys: affectedDayKeys, context: context)
        guard
            let beforeSide = focusSide(
                snapshots: beforeSnapshots,
                blockID: block.id,
                fallbackDate: date,
                fallbackStartMinute: block.startMinute,
                calendar: calendar,
                focusSession: focusSession.map(DayPlanFocusSessionUndoSnapshot.init(session:))
            )
        else { return }
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

        var focusedBlockID = pendingResizeUndo.blockID
        var focusedDate = pendingResizeUndo.beforeSide.focusedDate
        var focusedStartMinute = pendingResizeUndo.beforeSide.focusedStartMinute
        var updatedFocusSessionSnapshot: DayPlanFocusSessionUndoSnapshot?
        var didUpdateFocusSession = false
        if let focusResizeUpdate = completedFocusResizeUpdate(
            for: pendingResizeUndo,
            calendar: calendar,
            context: context
        ) {
            focusedBlockID = focusResizeUpdate.updatedBlock.id
            focusedDate = focusResizeUpdate.resizedDate
            focusedStartMinute = focusResizeUpdate.updatedBlock.startMinute
            updatedFocusSessionSnapshot = DayPlanFocusSessionUndoSnapshot(
                session: focusResizeUpdate.session
            )

            for snapshot in pendingResizeUndo.beforeSide.snapshots {
                weekBlocksByDayKey[snapshot.dayKey] = DayPlanStorage.loadBlocks(
                    forDayKey: snapshot.dayKey,
                    context: context
                )
            }
            syncSelectedDayBlocks(calendar: calendar, context: context)
            selectedBlockID = focusResizeUpdate.updatedBlock.id
            selectedTaskID = focusResizeUpdate.updatedBlock.taskID
            startMinute = focusResizeUpdate.updatedBlock.startMinute
            durationMinutes = focusResizeUpdate.updatedBlock.durationMinutes
            didUpdateFocusSession = true
        }

        let dayKeys = pendingResizeUndo.beforeSide.snapshots.map(\.dayKey)
        let afterSnapshots = snapshots(forDayKeys: dayKeys, context: context)
        let afterSide = focusSide(
            snapshots: afterSnapshots,
            blockID: focusedBlockID,
            fallbackDate: focusedDate,
            fallbackStartMinute: focusedStartMinute,
            calendar: calendar,
            focusSession: updatedFocusSessionSnapshot
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
        if didUpdateFocusSession {
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    private func completedFocusResizeUpdate(
        for pendingResizeUndo: DayPlanPendingResizeUndo,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanCompletedFocusResizeUpdate? {
        guard let originalFocusSession = pendingResizeUndo.beforeSide.focusSession,
            let session = focusSession(withID: originalFocusSession.id, context: context),
            let resizedBlock = locatedBlock(pendingResizeUndo.blockID, calendar: calendar)?.block,
            let resizedDate = dateForDayKey(resizedBlock.dayKey, calendar: calendar),
            let resizedStart = calendar.date(
                byAdding: .minute,
                value: resizedBlock.startMinute,
                to: calendar.startOfDay(for: resizedDate)
            ),
            let updatedBlock = DayPlanFocusSessionPlannerSync.updateCompletedFocusSession(
                session,
                startedAt: resizedStart,
                durationMinutes: resizedBlock.durationMinutes,
                titleSnapshot: resizedBlock.titleSnapshot,
                emojiSnapshot: resizedBlock.emojiSnapshot,
                calendar: calendar,
                context: context
            )
        else { return nil }

        return DayPlanCompletedFocusResizeUpdate(
            session: session,
            resizedDate: resizedDate,
            updatedBlock: updatedBlock
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

    func registerPlannerUndoIfNeeded(
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
        if let focusSessionSnapshot = side.focusSession {
            if let session = focusSession(withID: focusSessionSnapshot.id, context: context) {
                focusSessionSnapshot.apply(to: session)
            }
        }

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

    func snapshots(
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

    func focusSide(
        snapshots: [DayPlanPlannerUndoSnapshot],
        blockID: UUID,
        fallbackDate: Date,
        fallbackStartMinute: Int,
        calendar: Calendar,
        focusSession: DayPlanFocusSessionUndoSnapshot? = nil
    ) -> DayPlanPlannerUndoSide? {
        let focusedSnapshot = snapshots.first { snapshot in
            snapshot.blocks.contains { $0.id == blockID }
        }
        let focusedBlock = focusedSnapshot?.blocks.first { $0.id == blockID }
        let focusedDate =
            focusedSnapshot
            .flatMap { dateForDayKey($0.dayKey, calendar: calendar) }
            ?? calendar.startOfDay(for: fallbackDate)

        return DayPlanPlannerUndoSide(
            snapshots: snapshots,
            focusedBlockID: blockID,
            focusedDate: focusedDate,
            focusedStartMinute: focusedBlock?.startMinute ?? fallbackStartMinute,
            focusSession: focusSession
        )
    }

    private func focusSession(withID id: UUID, context: ModelContext) -> FocusSession? {
        do {
            return try context.fetch(FetchDescriptor<FocusSession>()).first { $0.id == id }
        } catch {
            NSLog("Failed to load Focus session for Planner resize: \(error.localizedDescription)")
            return nil
        }
    }

    func orderedUniqueDayKeys(_ dayKeys: [String]) -> [String] {
        var seen: Set<String> = []
        return dayKeys.filter { dayKey in
            seen.insert(dayKey).inserted
        }
    }

    func dateForDayKey(_ dayKey: String, calendar: Calendar) -> Date? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    func clearPlannerUndoHighlight() {
        highlightedBlockID = nil
        highlightedBlockScrollMinute = nil
    }

}
