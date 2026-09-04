import Foundation
import SwiftData

extension DayPlanFocusSessionPlannerSync {
    static func focusPauseResumeActionLogs(
        for sessionID: UUID,
        context: ModelContext
    ) -> [FocusPauseResumeAction] {
        let sessionIDString = sessionID.uuidString
        let focusEntity = RoutinaDeviceActionEntity.focusSession.rawValue
        let pausedAction = RoutinaDeviceActionKind.paused.rawValue
        let resumedAction = RoutinaDeviceActionKind.resumed.rawValue
        var descriptor = FetchDescriptor<RoutinaDeviceActionLog>(
            predicate: #Predicate<RoutinaDeviceActionLog> { log in
                log.entityRawValue == focusEntity
                    && log.entityID == sessionIDString
                    && (log.actionRawValue == pausedAction || log.actionRawValue == resumedAction)
            }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        do {
            return try context.fetch(descriptor).compactMap { log in
                guard let kind = RoutinaDeviceActionKind(rawValue: log.actionRawValue) else {
                    return nil
                }

                return FocusPauseResumeAction(kind: kind, timestamp: log.timestamp)
            }
        } catch {
            NSLog("Failed to load focus pause/resume action logs for \(sessionID): \(error.localizedDescription)")
            return []
        }
    }

    static func focusSegments(
        startedAt: Date,
        completedAt: Date?,
        pausedAt: Date?,
        actions: [FocusPauseResumeAction]
    ) -> [FocusSegmentInterval] {
        var segments: [FocusSegmentInterval] = []
        var currentStart: Date? = startedAt

        for action in actions where action.timestamp >= startedAt {
            switch action.kind {
            case .paused:
                guard let segmentStart = currentStart,
                    action.timestamp > segmentStart
                else {
                    continue
                }

                segments.append(FocusSegmentInterval(startedAt: segmentStart, endedAt: action.timestamp))
                currentStart = nil

            case .resumed:
                guard currentStart == nil else {
                    continue
                }

                currentStart = action.timestamp

            default:
                continue
            }
        }

        if let terminalSegment = terminalFocusSegment(
            startedAt: startedAt,
            currentStart: currentStart,
            completedAt: completedAt,
            pausedAt: pausedAt
        ) {
            segments.append(terminalSegment)
        }

        return segments
    }

    private static func terminalFocusSegment(
        startedAt: Date,
        currentStart: Date?,
        completedAt: Date?,
        pausedAt: Date?
    ) -> FocusSegmentInterval? {
        guard let segmentStart = currentStart else { return nil }

        if let completedAt, completedAt > segmentStart {
            return FocusSegmentInterval(startedAt: segmentStart, endedAt: completedAt)
        }
        if let pausedAt, pausedAt > segmentStart {
            return FocusSegmentInterval(startedAt: segmentStart, endedAt: pausedAt)
        }
        if segmentStart > startedAt {
            return FocusSegmentInterval(startedAt: segmentStart, endedAt: nil)
        }
        return nil
    }

    static func countUpSegmentStart(
        for session: FocusSession,
        storedSegments: [DayPlanBlock],
        segmentEndedAt: Date,
        canInferCurrentSegment: Bool
    ) -> Date? {
        guard let startedAt = session.startedAt else {
            return nil
        }

        if canInferCurrentSegment && session.accumulatedPausedSeconds > 0 {
            let inferredStart = inferredUnsavedCurrentSegmentStart(
                for: session,
                storedSegments: storedSegments,
                segmentEndedAt: segmentEndedAt
            )
            if let inferredStart {
                if let latestSegment = storedSegments.last {
                    let latestSegmentEnd = latestSegment.createdAt.addingTimeInterval(
                        storedSegmentDurationSeconds(latestSegment)
                    )
                    if inferredStart > latestSegmentEnd {
                        return inferredStart
                    }
                } else if inferredStart > startedAt {
                    return inferredStart
                }
            }
        }

        if let latestSegment = storedSegments.last {
            let isCurrentSegment = isCurrentSegmentPlaceholder(latestSegment, for: session)
            if latestSegment.createdAt > startedAt && isCurrentSegment {
                return latestSegment.createdAt
            }

            let isInitialPlaceholder =
                latestSegment.id == session.id
                && latestSegment.durationMinutes <= DayPlanBlock.minimumStoredDurationMinutes
            if isInitialPlaceholder {
                return startedAt
            }

            if latestSegment.createdAt > startedAt {
                return latestSegment.createdAt
            }

            if canInferCurrentSegment && session.accumulatedPausedSeconds > 0 {
                return nil
            }
        }

        return startedAt
    }

    static func inferredUnsavedCurrentSegmentStart(
        for session: FocusSession,
        storedSegments: [DayPlanBlock],
        segmentEndedAt: Date
    ) -> Date? {
        guard let startedAt = session.startedAt else {
            return nil
        }

        let activeSeconds = session.activeDurationSeconds(at: segmentEndedAt)
        let storedSeconds =
            storedSegments
            .filter { $0.createdAt < segmentEndedAt }
            .reduce(TimeInterval.zero) { total, segment in
                total + storedSegmentDurationSeconds(segment)
            }
        guard storedSeconds > TimeInterval(DayPlanBlock.minimumStoredDurationMinutes * 60) else {
            return nil
        }

        let currentSegmentSeconds = activeSeconds - storedSeconds
        guard currentSegmentSeconds > 0 else {
            return nil
        }

        let inferredStart = segmentEndedAt.addingTimeInterval(-currentSegmentSeconds)
        guard inferredStart > startedAt else {
            return nil
        }

        return inferredStart
    }

    static func isCurrentSegmentPlaceholder(_ segment: DayPlanBlock, for session: FocusSession) -> Bool {
        segment.id != session.id
            && segment.durationMinutes <= DayPlanBlock.minimumStoredDurationMinutes
    }

    static func storedSegmentDurationSeconds(_ segment: DayPlanBlock) -> TimeInterval {
        let storedMinutesSeconds = TimeInterval(max(DayPlanBlock.minimumStoredDurationMinutes, segment.durationMinutes) * 60)
        let timestampSeconds = segment.updatedAt.timeIntervalSince(segment.createdAt)
        guard timestampSeconds > 0, timestampSeconds <= storedMinutesSeconds else {
            return storedMinutesSeconds
        }

        return timestampSeconds
    }

    static func repairOvergrownCompletedSegments(
        for session: FocusSession,
        storedSegments: [DayPlanBlock],
        currentSegmentStartedAt: Date,
        segmentEndedAt: Date,
        context: ModelContext
    ) {
        guard session.accumulatedPausedSeconds > 0 else {
            return
        }

        let completedSegments = storedSegments.filter { $0.createdAt < currentSegmentStartedAt }
        guard !completedSegments.isEmpty else {
            return
        }

        let activeSeconds = session.activeDurationSeconds(at: segmentEndedAt)
        let currentSegmentSeconds = max(0, segmentEndedAt.timeIntervalSince(currentSegmentStartedAt))
        let completedBudgetSeconds = max(0, activeSeconds - currentSegmentSeconds)
        let corrections = completedSegmentDurationCorrections(
            completedSegments,
            budgetSeconds: completedBudgetSeconds
        )
        guard !corrections.isEmpty else {
            return
        }

        for segment in completedSegments {
            guard let durationMinutes = corrections[segment.id] else {
                continue
            }

            upsertBlock(copyBlock(segment, durationMinutes: durationMinutes), context: context)
        }
    }

    static func savePausedCountUpFocusSegment(
        session: FocusSession,
        taskID: UUID,
        title: String,
        emoji: String?,
        pausedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.plannedDurationSeconds <= 0,
            session.startedAt != nil
        else {
            return nil
        }

        let storedSegments = focusSegmentBlocks(for: session, context: context)
        guard
            let segmentStartedAt = countUpSegmentStart(
                for: session,
                storedSegments: storedSegments,
                segmentEndedAt: pausedAt,
                canInferCurrentSegment: true
            )
        else {
            return nil
        }
        guard pausedAt >= segmentStartedAt else {
            return nil
        }

        repairOvergrownCompletedSegments(
            for: session,
            storedSegments: storedSegments,
            currentSegmentStartedAt: segmentStartedAt,
            segmentEndedAt: pausedAt,
            context: context
        )
        let blocks = focusSegmentBlocks(
            session: session,
            taskID: taskID,
            title: title,
            emoji: emoji,
            segmentStartedAt: segmentStartedAt,
            durationSeconds: max(60, pausedAt.timeIntervalSince(segmentStartedAt)),
            calendar: calendar
        )
        _ = upsertBlocks(blocks, context: context)
        return blocks.last
    }

    static func saveResumedCountUpFocusSegment(
        session: FocusSession,
        taskID: UUID,
        title: String,
        emoji: String?,
        resumedAt: Date,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanBlock? {
        guard session.plannedDurationSeconds <= 0,
            let startedAt = session.startedAt,
            resumedAt >= startedAt
        else {
            return nil
        }

        let block = focusSegmentBlock(
            session: session,
            taskID: taskID,
            title: title,
            emoji: emoji,
            segmentStartedAt: resumedAt,
            durationSeconds: 60,
            calendar: calendar
        )
        upsertBlock(block, context: context)
        return block
    }

    static func latestFocusSegmentBlock(for session: FocusSession, context: ModelContext) -> DayPlanBlock? {
        focusSegmentBlocks(for: session, context: context).last
    }

    static func focusSegmentBlock(
        session: FocusSession,
        taskID: UUID,
        title: String,
        emoji: String?,
        segmentStartedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar
    ) -> DayPlanBlock {
        focusSegmentBlocks(
            session: session,
            taskID: taskID,
            title: title,
            emoji: emoji,
            segmentStartedAt: segmentStartedAt,
            durationSeconds: durationSeconds,
            calendar: calendar
        )[0]
    }

    static func focusSegmentBlocks(
        session: FocusSession,
        taskID: UUID,
        title: String,
        emoji: String?,
        segmentStartedAt: Date,
        durationSeconds: TimeInterval,
        calendar: Calendar,
        minimumDurationMinutes: Int = DayPlanBlock.minimumStoredDurationMinutes
    ) -> [DayPlanBlock] {
        let segmentEnd = segmentStartedAt.addingTimeInterval(max(60, durationSeconds))
        var blockStart = segmentStartedAt
        var blocks: [DayPlanBlock] = []

        while blockStart < segmentEnd {
            let dayStart = calendar.startOfDay(for: blockStart)
            let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? segmentEnd
            let blockEnd = min(segmentEnd, nextDayStart)
            guard blockEnd > blockStart else { break }
            let startMinute = startMinute(
                for: blockStart,
                calendar: calendar,
                minimumDurationMinutes: minimumDurationMinutes
            )
            blocks.append(
                DayPlanBlock(
                    id: segmentBlockID(
                        sessionID: session.id,
                        sessionStartedAt: session.startedAt,
                        segmentStartedAt: blockStart
                    ),
                    taskID: taskID,
                    dayKey: DayPlanStorage.dayKey(for: blockStart, calendar: calendar),
                    startMinute: startMinute,
                    durationMinutes: durationMinutes(
                        durationSeconds: blockEnd.timeIntervalSince(blockStart),
                        startMinute: startMinute,
                        minimumDurationMinutes: minimumDurationMinutes
                    ),
                    titleSnapshot: title,
                    emojiSnapshot: emoji,
                    createdAt: blockStart,
                    updatedAt: blockEnd,
                    minimumDurationMinutes: minimumDurationMinutes
                )
            )
            blockStart = blockEnd
        }

        return blocks
    }

    static func segmentBlockID(
        sessionID: UUID,
        sessionStartedAt: Date?,
        segmentStartedAt: Date
    ) -> UUID {
        if let sessionStartedAt {
            if sessionStartedAt == segmentStartedAt {
                return sessionID
            }
        }

        return focusSegmentBlockID(sessionID: sessionID, segmentStartedAt: segmentStartedAt)
    }

    static func focusSegmentBlockID(sessionID: UUID, segmentStartedAt: Date) -> UUID {
        let sessionBytes = sessionID.uuid
        let milliseconds = Int64((segmentStartedAt.timeIntervalSince1970 * 1_000).rounded())
        let timestampBytes = UInt64(bitPattern: milliseconds)

        func timestampByte(_ shift: UInt64) -> UInt8 {
            UInt8((timestampBytes >> shift) & 0xff)
        }

        let b0 = timestampByte(56)
        let b1 = timestampByte(48)
        let b2 = timestampByte(40)
        let b3 = timestampByte(32)
        let b4 = timestampByte(24)
        let b5 = timestampByte(16)
        let b6 = timestampByte(8)
        let b7 = timestampByte(0)

        return UUID(
            uuid: (
                sessionBytes.0 ^ b0,
                sessionBytes.1 ^ b1,
                sessionBytes.2 ^ b2,
                sessionBytes.3 ^ b3,
                sessionBytes.4 ^ b4,
                sessionBytes.5 ^ b5,
                sessionBytes.6 ^ b6,
                sessionBytes.7 ^ b7,
                sessionBytes.8 ^ b7,
                sessionBytes.9 ^ b6,
                sessionBytes.10 ^ b5,
                sessionBytes.11 ^ b4,
                sessionBytes.12 ^ b3,
                sessionBytes.13 ^ b2,
                sessionBytes.14 ^ b1,
                sessionBytes.15 ^ b0
            ))
    }

}
