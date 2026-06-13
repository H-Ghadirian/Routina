import Foundation
import SwiftData

enum AwaySessionPreset: String, Codable, CaseIterable, Equatable, Sendable {
    case wake
    case reset
    case outside
    case windDown
    case meal
    case custom

    var title: String {
        switch self {
        case .wake:
            return "Wake Away"
        case .reset:
            return "Reset Away"
        case .outside:
            return "Outside"
        case .windDown:
            return "Wind Down"
        case .meal:
            return "Meal Away"
        case .custom:
            return "Away"
        }
    }

    var systemImage: String {
        switch self {
        case .wake:
            return "sunrise.fill"
        case .reset:
            return "arrow.counterclockwise.circle.fill"
        case .outside:
            return "figure.walk"
        case .windDown:
            return "moon.stars.fill"
        case .meal:
            return "fork.knife"
        case .custom:
            return "lock.shield.fill"
        }
    }

    var defaultDurationMinutes: Int {
        switch self {
        case .wake:
            return 20
        case .reset:
            return 15
        case .outside:
            return 30
        case .windDown:
            return 30
        case .meal:
            return 20
        case .custom:
            return 20
        }
    }
}

enum AwaySessionState: String, Codable, Equatable, Sendable {
    case active
    case completed
    case endedEarly
}

@Model
final class AwaySession {
    var id: UUID = UUID()
    var presetRawValue: String = AwaySessionPreset.custom.rawValue
    var title: String = AwaySessionPreset.custom.title
    var linkedTaskID: UUID?
    var startedAt: Date?
    var plannedDurationSeconds: TimeInterval = 20 * 60
    var completedAt: Date?
    var endedEarlyAt: Date?
    var extensionCount: Int = 0
    var createdAt: Date?
    var updatedAt: Date?

    var preset: AwaySessionPreset {
        get { AwaySessionPreset(rawValue: presetRawValue) ?? .custom }
        set {
            presetRawValue = newValue.rawValue
            if displayTitle == AwaySessionPreset.custom.title {
                title = newValue.title
            }
        }
    }

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? preset.title : trimmedTitle
    }

    var isActive: Bool {
        completedAt == nil && endedEarlyAt == nil
    }

    var state: AwaySessionState {
        if completedAt != nil { return .completed }
        if endedEarlyAt != nil { return .endedEarly }
        return .active
    }

    var finishedAt: Date? {
        completedAt ?? endedEarlyAt
    }

    var isCountUp: Bool {
        plannedDurationSeconds <= 0
    }

    var plannedEndAt: Date? {
        guard !isCountUp, let startedAt else { return nil }
        return startedAt.addingTimeInterval(max(60, plannedDurationSeconds))
    }

    init(
        id: UUID = UUID(),
        preset: AwaySessionPreset = .custom,
        title: String? = nil,
        linkedTaskID: UUID? = nil,
        startedAt: Date? = Date(),
        plannedDurationSeconds: TimeInterval = 20 * 60,
        completedAt: Date? = nil,
        endedEarlyAt: Date? = nil,
        extensionCount: Int = 0,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.presetRawValue = preset.rawValue
        self.title = Self.cleanedTitle(title) ?? preset.title
        self.linkedTaskID = linkedTaskID
        self.startedAt = startedAt
        self.plannedDurationSeconds = max(0, plannedDurationSeconds)
        self.completedAt = completedAt
        self.endedEarlyAt = endedEarlyAt
        self.extensionCount = max(0, extensionCount)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func remainingSeconds(referenceDate: Date = Date()) -> TimeInterval {
        guard isActive, let plannedEndAt else { return 0 }
        return max(0, plannedEndAt.timeIntervalSince(referenceDate))
    }

    func durationSeconds(referenceDate: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        let endedAt = effectiveEndDate(referenceDate: referenceDate)
        return max(0, endedAt.timeIntervalSince(startedAt))
    }

    func completionProgress(referenceDate: Date = Date()) -> Double {
        guard !isCountUp else { return 1 }
        return min(max(durationSeconds(referenceDate: referenceDate) / plannedDurationSeconds, 0), 1)
    }

    func isExpired(at date: Date = Date()) -> Bool {
        guard isActive, let plannedEndAt else { return false }
        return date >= plannedEndAt
    }

    func complete(at date: Date = Date()) {
        guard isActive else { return }
        completedAt = plannedEndAt.map { min(max(date, startedAt ?? date), $0) } ?? date
        updatedAt = completedAt
    }

    func endEarly(at date: Date = Date()) {
        guard isActive else { return }
        if isCountUp || isExpired(at: date) {
            complete(at: date)
            return
        }
        endedEarlyAt = max(date, startedAt ?? date)
        updatedAt = endedEarlyAt
    }

    func extend(byMinutes minutes: Int, at date: Date = Date()) {
        guard isActive, !isCountUp else { return }
        let addedSeconds = TimeInterval(max(1, minutes) * 60)
        plannedDurationSeconds = max(60, plannedDurationSeconds + addedSeconds)
        extensionCount += 1
        updatedAt = date
    }

    func detachedCopy() -> AwaySession {
        AwaySession(
            id: id,
            preset: preset,
            title: title,
            linkedTaskID: linkedTaskID,
            startedAt: startedAt,
            plannedDurationSeconds: plannedDurationSeconds,
            completedAt: completedAt,
            endedEarlyAt: endedEarlyAt,
            extensionCount: extensionCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func effectiveEndDate(referenceDate: Date) -> Date {
        if let finishedAt {
            return finishedAt
        }
        if let plannedEndAt {
            return min(referenceDate, plannedEndAt)
        }
        return referenceDate
    }

    private static func cleanedTitle(_ title: String?) -> String? {
        guard let title else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension AwaySession: Identifiable, Equatable {
    static func == (lhs: AwaySession, rhs: AwaySession) -> Bool {
        lhs.id == rhs.id
    }
}

enum AwaySessionFormatting {
    static func durationText(seconds: TimeInterval) -> String {
        FocusSessionFormatting.compactDurationText(seconds: seconds)
    }

    static func timerText(seconds: TimeInterval) -> String {
        FocusSessionFormatting.durationText(seconds: seconds)
    }
}
