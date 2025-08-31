import Foundation
import SwiftData

struct RoutineStep: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }

    static func sanitized(_ steps: [RoutineStep]) -> [RoutineStep] {
        steps.compactMap { step in
            guard let title = normalizedTitle(step.title) else { return nil }
            return RoutineStep(id: step.id, title: title)
        }
    }

    static func normalizedTitle(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum RoutineAdvanceResult: Equatable {
    case ignoredPaused
    case ignoredAlreadyCompletedToday
    case advancedStep(completedSteps: Int, totalSteps: Int)
    case completedRoutine
}

private enum RoutineStepStorage {
    static func serialize(_ steps: [RoutineStep]) -> String {
        let sanitized = RoutineStep.sanitized(steps)
        guard !sanitized.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [RoutineStep] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineStep].self, from: data) else {
            return []
        }
        return RoutineStep.sanitized(decoded)
    }
}

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var placeID: UUID?
    var tagsStorage: String = ""
    var stepsStorage: String = ""
    var interval: Int16 = 1
    var lastDone: Date?
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var completedStepCount: Int16 = 0
    var sequenceStartedAt: Date?

    var isPaused: Bool {
        pausedAt != nil
    }

    var tags: [String] {
        get { RoutineTag.deserialize(tagsStorage) }
        set { tagsStorage = RoutineTag.serialize(newValue) }
    }

    var steps: [RoutineStep] {
        get { RoutineStepStorage.deserialize(stepsStorage) }
        set {
            stepsStorage = RoutineStepStorage.serialize(newValue)
            if steps.isEmpty {
                resetStepProgress()
            } else if Int(completedStepCount) > steps.count {
                resetStepProgress()
            }
        }
    }

    var hasSequentialSteps: Bool {
        !steps.isEmpty
    }

    var completedSteps: Int {
        max(min(Int(completedStepCount), steps.count), 0)
    }

    var totalSteps: Int {
        steps.count
    }

    var isInProgress: Bool {
        hasSequentialSteps && completedSteps > 0 && completedSteps < totalSteps
    }

    var currentStepNumber: Int? {
        guard hasSequentialSteps, completedSteps < totalSteps else { return nil }
        return completedSteps + 1
    }

    var nextStepTitle: String? {
        guard hasSequentialSteps, completedSteps < steps.count else { return nil }
        return steps[completedSteps].title
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        emoji: String? = nil,
        placeID: UUID? = nil,
        tags: [String] = [],
        steps: [RoutineStep] = [],
        interval: Int16 = 1,
        lastDone: Date? = nil,
        scheduleAnchor: Date? = nil,
        pausedAt: Date? = nil,
        completedStepCount: Int16 = 0,
        sequenceStartedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.placeID = placeID
        self.tagsStorage = RoutineTag.serialize(tags)
        self.stepsStorage = RoutineStepStorage.serialize(steps)
        self.interval = interval
        self.lastDone = lastDone
        self.scheduleAnchor = scheduleAnchor ?? lastDone
        self.pausedAt = pausedAt
        self.completedStepCount = Int16(max(Int(completedStepCount), 0))
        self.sequenceStartedAt = sequenceStartedAt
        if self.steps.isEmpty || Int(self.completedStepCount) > self.steps.count {
            resetStepProgress()
        }
    }

    func replaceSteps(_ updatedSteps: [RoutineStep]) {
        let sanitized = RoutineStep.sanitized(updatedSteps)
        let previous = steps
        stepsStorage = RoutineStepStorage.serialize(sanitized)

        if sanitized.isEmpty {
            resetStepProgress()
            return
        }

        if sanitized != previous || Int(completedStepCount) > sanitized.count {
            resetStepProgress()
        }
    }

    func resetStepProgress() {
        completedStepCount = 0
        sequenceStartedAt = nil
    }

    @discardableResult
    func advance(completedAt: Date, calendar: Calendar = .current) -> RoutineAdvanceResult {
        guard !isPaused else { return .ignoredPaused }

        if !hasSequentialSteps {
            if let lastDone, calendar.isDate(lastDone, inSameDayAs: completedAt) {
                return .ignoredAlreadyCompletedToday
            }
            if shouldUpdateLastDone(with: completedAt) {
                lastDone = completedAt
                scheduleAnchor = completedAt
            }
            return .completedRoutine
        }

        if completedSteps == 0,
           let lastDone,
           calendar.isDate(lastDone, inSameDayAs: completedAt) {
            return .ignoredAlreadyCompletedToday
        }

        if sequenceStartedAt == nil {
            sequenceStartedAt = completedAt
        }

        let nextCompletedStepCount = min(completedSteps + 1, totalSteps)
        if nextCompletedStepCount < totalSteps {
            completedStepCount = Int16(nextCompletedStepCount)
            return .advancedStep(completedSteps: nextCompletedStepCount, totalSteps: totalSteps)
        }

        if shouldUpdateLastDone(with: completedAt) {
            lastDone = completedAt
            scheduleAnchor = completedAt
        }
        resetStepProgress()
        return .completedRoutine
    }

    private func shouldUpdateLastDone(with candidate: Date) -> Bool {
        guard let lastDone else { return true }
        return candidate > lastDone
    }

    static func trimmedName(_ name: String?) -> String? {
        name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedName(_ name: String?) -> String? {
        guard let trimmed = trimmedName(name), !trimmed.isEmpty else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func sanitizedEmoji(_ input: String, fallback: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return fallback }
        return String(first)
    }
}

@Model
final class RoutineLog {
    var id: UUID = UUID()
    var timestamp: Date?
    var taskID: UUID = UUID()

    init(
        id: UUID = UUID(),
        timestamp: Date? = nil,
        taskID: UUID
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
    }
}

extension RoutineTask: Equatable {
    static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.id == rhs.id
    }
}

extension RoutineLog: Equatable {
    static func == (lhs: RoutineLog, rhs: RoutineLog) -> Bool {
        lhs.id == rhs.id
    }
}
