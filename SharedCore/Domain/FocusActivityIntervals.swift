import Foundation
import SwiftData

struct FocusSessionActionEvent: Equatable, Hashable, Sendable {
    let sessionID: UUID
    let action: RoutinaDeviceActionKind
    let timestamp: Date

    init(
        sessionID: UUID,
        action: RoutinaDeviceActionKind,
        timestamp: Date
    ) {
        self.sessionID = sessionID
        self.action = action
        self.timestamp = timestamp
    }

    init?(_ log: RoutinaDeviceActionLog) {
        guard log.entity == .focusSession,
              log.action == .paused || log.action == .resumed,
              let sessionID = UUID(uuidString: log.entityID) else {
            return nil
        }

        self.init(
            sessionID: sessionID,
            action: log.action,
            timestamp: log.timestamp
        )
    }

    static func events(from logs: [RoutinaDeviceActionLog]) -> [Self] {
        Array(Set(logs.compactMap(Self.init)))
            .sorted(by: areInIncreasingOrder)
    }

    @MainActor
    static func fetch(from context: ModelContext) throws -> [Self] {
        let focusEntity = RoutinaDeviceActionEntity.focusSession.rawValue
        let pausedAction = RoutinaDeviceActionKind.paused.rawValue
        let resumedAction = RoutinaDeviceActionKind.resumed.rawValue
        var descriptor = FetchDescriptor<RoutinaDeviceActionLog>(
            predicate: #Predicate<RoutinaDeviceActionLog> { log in
                log.entityRawValue == focusEntity
                    && (log.actionRawValue == pausedAction || log.actionRawValue == resumedAction)
            }
        )
        descriptor.sortBy = [SortDescriptor(\RoutinaDeviceActionLog.timestamp)]
        return events(from: try context.fetch(descriptor))
    }

    private static func areInIncreasingOrder(_ lhs: Self, _ rhs: Self) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        if lhs.sessionID != rhs.sessionID {
            return lhs.sessionID.uuidString < rhs.sessionID.uuidString
        }
        return actionOrder(lhs.action) < actionOrder(rhs.action)
    }

    private static func actionOrder(_ action: RoutinaDeviceActionKind) -> Int {
        switch action {
        case .paused:
            return 0
        case .resumed:
            return 1
        default:
            return 2
        }
    }
}

struct FocusActivityInterval: Equatable, Sendable {
    let sessionID: UUID
    let startedAt: Date
    let endedAt: Date
    let isOngoing: Bool

    var durationSeconds: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

struct FocusActivityDaySlice: Equatable, Sendable {
    let sessionID: UUID
    let day: Date
    let startedAt: Date
    let endedAt: Date
    let isOngoing: Bool

    var durationSeconds: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

enum FocusActivityIntervalResolver {
    static func eventsBySessionID(
        _ events: [FocusSessionActionEvent]
    ) -> [UUID: [FocusSessionActionEvent]] {
        Dictionary(grouping: events, by: \FocusSessionActionEvent.sessionID)
    }

    static func intervals(
        for session: FocusSession,
        events: [FocusSessionActionEvent],
        referenceDate: Date
    ) -> [FocusActivityInterval] {
        guard session.state != .abandoned,
              let startedAt = session.startedAt else {
            return []
        }

        let terminalDate = session.completedAt
            ?? min(session.pausedAt ?? referenceDate, referenceDate)
        let expectedDuration = session.activeDurationSeconds(at: referenceDate)
        return intervals(
            sessionID: session.id,
            startedAt: startedAt,
            terminalDate: terminalDate,
            isOngoing: session.state == .active && !session.isPaused,
            expectedDuration: expectedDuration,
            accumulatedPausedSeconds: session.accumulatedPausedSeconds,
            events: events
        )
    }

    static func intervals(
        for session: SprintFocusSessionRecord,
        events: [FocusSessionActionEvent],
        referenceDate: Date
    ) -> [FocusActivityInterval] {
        let terminalDate = session.stoppedAt
            ?? min(session.pausedAt ?? referenceDate, referenceDate)
        return intervals(
            sessionID: session.id,
            startedAt: session.startedAt,
            terminalDate: terminalDate,
            isOngoing: session.isActive && !session.isPaused,
            expectedDuration: session.activeDurationSeconds(at: referenceDate),
            accumulatedPausedSeconds: session.accumulatedPausedSeconds,
            events: events
        )
    }

    static func daySlices(
        for intervals: [FocusActivityInterval],
        calendar: Calendar
    ) -> [FocusActivityDaySlice] {
        intervals.flatMap { interval in
            var slices: [FocusActivityDaySlice] = []
            var cursor = interval.startedAt

            while cursor < interval.endedAt {
                let day = calendar.startOfDay(for: cursor)
                let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.endedAt
                let sliceEnd = min(interval.endedAt, nextDay)
                guard sliceEnd > cursor else { break }

                slices.append(
                    FocusActivityDaySlice(
                        sessionID: interval.sessionID,
                        day: day,
                        startedAt: cursor,
                        endedAt: sliceEnd,
                        isOngoing: interval.isOngoing && sliceEnd == interval.endedAt
                    )
                )
                cursor = sliceEnd
            }

            return slices
        }
    }

    static func timelineEntryID(
        sessionID: UUID,
        day: Date,
        usesOriginalSessionID: Bool
    ) -> UUID {
        guard !usesOriginalSessionID else { return sessionID }

        let sessionBytes = sessionID.uuid
        let milliseconds = UInt64(bitPattern: Int64((day.timeIntervalSince1970 * 1_000).rounded()))

        func timestampByte(_ shift: UInt64) -> UInt8 {
            UInt8((milliseconds >> shift) & 0xff)
        }

        let b0 = timestampByte(56)
        let b1 = timestampByte(48)
        let b2 = timestampByte(40)
        let b3 = timestampByte(32)
        let b4 = timestampByte(24)
        let b5 = timestampByte(16)
        let b6 = timestampByte(8)
        let b7 = timestampByte(0)

        return UUID(uuid: (
            sessionBytes.0 ^ b7,
            sessionBytes.1 ^ b6,
            sessionBytes.2 ^ b5,
            sessionBytes.3 ^ b4,
            sessionBytes.4 ^ b3,
            sessionBytes.5 ^ b2,
            sessionBytes.6 ^ b1,
            sessionBytes.7 ^ b0,
            sessionBytes.8 ^ b0,
            sessionBytes.9 ^ b1,
            sessionBytes.10 ^ b2,
            sessionBytes.11 ^ b3,
            sessionBytes.12 ^ b4,
            sessionBytes.13 ^ b5,
            sessionBytes.14 ^ b6,
            sessionBytes.15 ^ b7
        ))
    }

    private static func intervals(
        sessionID: UUID,
        startedAt: Date,
        terminalDate: Date,
        isOngoing: Bool,
        expectedDuration: TimeInterval,
        accumulatedPausedSeconds: TimeInterval,
        events: [FocusSessionActionEvent]
    ) -> [FocusActivityInterval] {
        guard terminalDate > startedAt,
              expectedDuration > 0 else {
            return []
        }

        let relevantEvents = events
            .filter {
                $0.sessionID == sessionID
                    && $0.timestamp >= startedAt
                    && $0.timestamp <= terminalDate
                    && ($0.action == .paused || $0.action == .resumed)
            }
            .sorted {
                if $0.timestamp != $1.timestamp {
                    return $0.timestamp < $1.timestamp
                }
                return $0.action == .paused && $1.action == .resumed
            }

        if !relevantEvents.isEmpty {
            var derivedIntervals: [FocusActivityInterval] = []
            var activeStart: Date? = startedAt

            for event in relevantEvents {
                switch event.action {
                case .paused:
                    guard let segmentStart = activeStart,
                          event.timestamp > segmentStart else {
                        continue
                    }
                    derivedIntervals.append(
                        FocusActivityInterval(
                            sessionID: sessionID,
                            startedAt: segmentStart,
                            endedAt: event.timestamp,
                            isOngoing: false
                        )
                    )
                    activeStart = nil

                case .resumed:
                    guard activeStart == nil else { continue }
                    activeStart = event.timestamp

                default:
                    continue
                }
            }

            if let activeStart,
               terminalDate > activeStart {
                derivedIntervals.append(
                    FocusActivityInterval(
                        sessionID: sessionID,
                        startedAt: activeStart,
                        endedAt: terminalDate,
                        isOngoing: isOngoing
                    )
                )
            }

            let derivedDuration = derivedIntervals.reduce(0) { $0 + $1.durationSeconds }
            if abs(derivedDuration - expectedDuration) <= 1 {
                return derivedIntervals
            }
        }

        // Older synchronized records can retain only aggregate paused seconds.
        // Their exact pause placement is unknowable, so keep the authoritative
        // active-duration total and anchor it at the recorded session start.
        let fallbackEnd = min(
            terminalDate,
            startedAt.addingTimeInterval(max(0, expectedDuration))
        )
        guard fallbackEnd > startedAt else { return [] }

        return [
            FocusActivityInterval(
                sessionID: sessionID,
                startedAt: startedAt,
                endedAt: fallbackEnd,
                isOngoing: isOngoing
                    && accumulatedPausedSeconds <= 0
                    && fallbackEnd == terminalDate
            )
        ]
    }

}
