import Foundation
import SwiftData

@Model
final class SleepSession {
    var id: UUID = UUID()
    var startedAt: Date?
    var endedAt: Date?
    var targetDurationMinutes: Int = 8 * 60
    var createdAt: Date?
    var updatedAt: Date?

    var isActive: Bool {
        endedAt == nil
    }

    var targetWakeAt: Date? {
        guard let startedAt else { return nil }
        return startedAt.addingTimeInterval(TimeInterval(max(targetDurationMinutes, 1) * 60))
    }

    init(
        id: UUID = UUID(),
        startedAt: Date? = Date(),
        endedAt: Date? = nil,
        targetDurationMinutes: Int = 8 * 60,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.targetDurationMinutes = max(targetDurationMinutes, 1)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func end(at endedAt: Date = Date()) {
        self.endedAt = endedAt
        updatedAt = endedAt
    }

    func durationSeconds(referenceDate: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        let finish = endedAt ?? referenceDate
        return max(0, finish.timeIntervalSince(startedAt))
    }

    func durationMinutes(referenceDate: Date = Date()) -> Int {
        max(0, Int((durationSeconds(referenceDate: referenceDate) / 60).rounded()))
    }

    func detachedCopy() -> SleepSession {
        SleepSession(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            targetDurationMinutes: targetDurationMinutes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension SleepSession: Identifiable, Equatable {
    static func == (lhs: SleepSession, rhs: SleepSession) -> Bool {
        lhs.id == rhs.id
    }
}

enum SleepSessionFormatting {
    static func durationText(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}
