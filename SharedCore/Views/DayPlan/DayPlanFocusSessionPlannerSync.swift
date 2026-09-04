import Foundation
import SwiftData

enum DayPlanFocusSessionPlannerSync {
    static func completedFocusSession(
        matching block: DayPlanBlock,
        in sessions: [FocusSession]
    ) -> FocusSession? {
        sessions.first { session in
            guard session.isTaskFocus || session.isTagFocus,
                session.completedAt != nil,
                session.abandonedAt == nil,
                block.taskID == session.taskID
            else {
                return false
            }

            return block.id == session.id || isFocusSegmentBlock(block, for: session)
        }
    }

    static func completedTagFocusSession(
        matching block: DayPlanBlock,
        in sessions: [FocusSession]
    ) -> FocusSession? {
        completedFocusSession(matching: block, in: sessions).flatMap { session in
            session.isTagFocus ? session : nil
        }
    }

    static func persistedFocusBlocks(
        for session: FocusSession,
        context: ModelContext
    ) -> [DayPlanBlock] {
        do {
            return try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
                .map(\.detachedBlock)
                .filter { block in
                    block.id == session.id || isFocusSegmentBlock(block, for: session)
                }
                .sorted { lhs, rhs in
                    if lhs.dayKey != rhs.dayKey {
                        return lhs.dayKey < rhs.dayKey
                    }
                    return lhs.startMinute < rhs.startMinute
                }
        } catch {
            NSLog("Failed to load Focus Planner blocks for \(session.id): \(error.localizedDescription)")
            return []
        }
    }

    @MainActor
    @discardableResult
    static func updateCompletedFocusSession(
        _ session: FocusSession,
        startedAt: Date,
        durationMinutes: Int,
        titleSnapshot: String,
        emojiSnapshot: String?,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.isTaskFocus || session.isTagFocus,
            session.completedAt != nil,
            session.abandonedAt == nil
        else {
            return nil
        }

        let clampedDurationMinutes = min(max(durationMinutes, 1), DayPlanBlock.minutesPerDay)
        _ = removeFocusBlock(for: session, context: context)

        let durationSeconds = TimeInterval(clampedDurationMinutes * 60)
        session.startedAt = startedAt
        session.completedAt = startedAt.addingTimeInterval(durationSeconds)
        session.abandonedAt = nil
        session.plannedDurationSeconds = durationSeconds
        session.clearPauseTracking()
        let title = session.focusTagTitle ?? titleSnapshot
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: title,
            details: "Updated recorded focus time",
            in: context
        )

        let blocks = focusSegmentBlocks(
            session: session,
            taskID: session.taskID,
            title: title,
            emoji: session.isTagFocus ? nil : emojiSnapshot,
            segmentStartedAt: startedAt,
            durationSeconds: durationSeconds,
            calendar: calendar,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        _ = upsertBlocks(blocks, context: context)
        return blocks.first
    }

    @MainActor
    @discardableResult
    static func updateCompletedTagFocusSession(
        _ session: FocusSession,
        startedAt: Date,
        durationMinutes: Int,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.isTagFocus,
            session.completedAt != nil,
            session.abandonedAt == nil,
            let tagName = session.focusTagName
        else {
            return nil
        }

        return updateCompletedFocusSession(
            session,
            startedAt: startedAt,
            durationMinutes: durationMinutes,
            titleSnapshot: RoutineTag.cleaned(tagName).map { "#\($0)" } ?? "#Tag",
            emojiSnapshot: nil,
            calendar: calendar,
            context: context
        )
    }

    static func allocationBlockID(sessionID: UUID, taskID: UUID) -> UUID {
        let sessionBytes = sessionID.uuid
        let taskBytes = taskID.uuid
        return UUID(
            uuid: (
                sessionBytes.0 ^ taskBytes.15,
                sessionBytes.1 ^ taskBytes.14,
                sessionBytes.2 ^ taskBytes.13,
                sessionBytes.3 ^ taskBytes.12,
                sessionBytes.4 ^ taskBytes.11,
                sessionBytes.5 ^ taskBytes.10,
                sessionBytes.6 ^ taskBytes.9,
                sessionBytes.7 ^ taskBytes.8,
                sessionBytes.8 ^ taskBytes.7,
                sessionBytes.9 ^ taskBytes.6,
                sessionBytes.10 ^ taskBytes.5,
                sessionBytes.11 ^ taskBytes.4,
                sessionBytes.12 ^ taskBytes.3,
                sessionBytes.13 ^ taskBytes.2,
                sessionBytes.14 ^ taskBytes.1,
                sessionBytes.15 ^ taskBytes.0
            ))
    }

    static func focusSegmentBlocks(
        in blocks: [DayPlanBlock],
        for session: FocusSession
    ) -> [DayPlanBlock] {
        blocks
            .filter { isFocusSegmentBlock($0, for: session) }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.startMinute < rhs.startMinute
            }
    }

    static func latestFocusSegmentBlock(
        in blocks: [DayPlanBlock],
        for session: FocusSession
    ) -> DayPlanBlock? {
        focusSegmentBlocks(in: blocks, for: session).last
    }

    static func correctedActiveCountUpFocusSegmentBlocks(
        _ blocks: [DayPlanBlock],
        activeFocusSessions: [FocusSession],
        referenceDate: Date
    ) -> [DayPlanBlock] {
        guard !blocks.isEmpty, !activeFocusSessions.isEmpty else { return blocks }

        var correctedBlocks = blocks
        for session in activeFocusSessions {
            let corrections = correctedCompletedSegmentDurations(
                in: correctedBlocks,
                for: session,
                referenceDate: referenceDate
            )
            guard !corrections.isEmpty else { continue }

            correctedBlocks = correctedBlocks.map { block in
                guard let durationMinutes = corrections[block.id] else {
                    return block
                }

                return copyBlock(block, durationMinutes: durationMinutes)
            }
        }

        return correctedBlocks
    }

    static func isFocusSegmentBlock(
        _ block: DayPlanBlock,
        for session: FocusSession
    ) -> Bool {
        guard session.isTaskFocus || session.isTagFocus,
            let startedAt = session.startedAt,
            block.taskID == session.taskID
        else {
            return false
        }

        if block.id == session.id {
            return true
        }

        guard block.createdAt >= startedAt else {
            return false
        }

        return block.id
            == focusSegmentBlockID(
                sessionID: session.id,
                segmentStartedAt: block.createdAt
            )
    }

    private static func correctedCompletedSegmentDurations(
        in blocks: [DayPlanBlock],
        for session: FocusSession,
        referenceDate: Date
    ) -> [UUID: Int] {
        guard session.plannedDurationSeconds <= 0,
            session.completedAt == nil,
            session.abandonedAt == nil,
            session.accumulatedPausedSeconds > 0,
            session.isTaskFocus || session.isTagFocus
        else {
            return [:]
        }

        let segments = focusSegmentBlocks(in: blocks, for: session)
        guard segments.count > 1,
            let currentSegment = segments.last
        else {
            return [:]
        }

        let renderEnd = session.pausedAt ?? referenceDate
        guard renderEnd >= currentSegment.createdAt else {
            return [:]
        }

        let activeSeconds = session.activeDurationSeconds(at: renderEnd)
        let currentSegmentSeconds = max(0, renderEnd.timeIntervalSince(currentSegment.createdAt))
        let completedBudgetSeconds = max(0, activeSeconds - currentSegmentSeconds)
        return completedSegmentDurationCorrections(
            Array(segments.dropLast()),
            budgetSeconds: completedBudgetSeconds
        )
    }

    static func copyBlock(_ block: DayPlanBlock, durationMinutes: Int) -> DayPlanBlock {
        DayPlanBlock(
            id: block.id,
            taskID: block.taskID,
            dayKey: block.dayKey,
            startMinute: block.startMinute,
            durationMinutes: durationMinutes,
            titleSnapshot: block.titleSnapshot,
            emojiSnapshot: block.emojiSnapshot,
            createdAt: block.createdAt,
            updatedAt: block.updatedAt,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
    }

    static func completedSegmentDurationCorrections(
        _ segments: [DayPlanBlock],
        budgetSeconds: TimeInterval
    ) -> [UUID: Int] {
        let budgetMinutes = Int(ceil(max(0, budgetSeconds) / 60))
        guard budgetMinutes > 0, !segments.isEmpty else {
            return [:]
        }

        let originalMinutes = segments.reduce(0) { total, segment in
            total + max(DayPlanBlock.minimumStoredDurationMinutes, segment.durationMinutes)
        }
        guard originalMinutes > budgetMinutes else {
            return [:]
        }

        var overageMinutes = originalMinutes - budgetMinutes
        var correctedDurations: [UUID: Int] = [:]
        for segment in segments {
            guard overageMinutes > 0 else { break }

            let originalDuration = max(DayPlanBlock.minimumStoredDurationMinutes, segment.durationMinutes)
            let reducibleMinutes = max(0, originalDuration - DayPlanBlock.minimumStoredDurationMinutes)
            let reduction = min(overageMinutes, reducibleMinutes)
            guard reduction > 0 else { continue }

            correctedDurations[segment.id] = originalDuration - reduction
            overageMinutes -= reduction
        }

        return correctedDurations
    }
}
