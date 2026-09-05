import Foundation

enum GuidedMissingTaskDataField: Equatable, Sendable {
    case pressure
    case thinkingNeeded
    case estimatedDuration

    var navigationTitle: String {
        switch self {
        case .pressure:
            return "Add missing Pressure"
        case .thinkingNeeded:
            return "Add missing Thinking needed"
        case .estimatedDuration:
            return "Add missing time estimates"
        }
    }

    var question: String {
        switch self {
        case .pressure:
            return "How much pressure does this task create?"
        case .thinkingNeeded:
            return "How much thinking does this task need?"
        case .estimatedDuration:
            return "How long will this task take?"
        }
    }

    var instruction: String {
        switch self {
        case .pressure:
            return "Pressure is how much a task stays on your mind, even when it is not the most urgent."
        case .thinkingNeeded:
            return "Thinking needed is the concentration, understanding, or decision-making this task requires."
        case .estimatedDuration:
            return "Choose the closest estimate. You can fine-tune it in task details."
        }
    }

    var completionMessage: String {
        switch self {
        case .pressure:
            return "Every eligible task has pressure data."
        case .thinkingNeeded:
            return "Every eligible task has thinking needed data."
        case .estimatedDuration:
            return "Every eligible task has a time estimate."
        }
    }

    var saveFailureMessage: String {
        switch self {
        case .pressure:
            return "Couldn’t save pressure. Try again."
        case .thinkingNeeded:
            return "Couldn’t save thinking needed. Try again."
        case .estimatedDuration:
            return "Couldn’t save the time estimate. Try again."
        }
    }

    var activityDetails: String {
        switch self {
        case .pressure:
            return "Updated pressure"
        case .thinkingNeeded:
            return "Updated thinking needed"
        case .estimatedDuration:
            return "Updated time estimate"
        }
    }

    var values: [GuidedMissingTaskDataValue] {
        switch self {
        case .pressure:
            return RoutineTaskPressure.allCases
                .filter { $0 != .none }
                .map(GuidedMissingTaskDataValue.pressure)
        case .thinkingNeeded:
            return RoutineTaskThinkingNeeded.allCases
                .filter { $0 != .none }
                .map(GuidedMissingTaskDataValue.thinkingNeeded)
        case .estimatedDuration:
            return [15, 30, 60, 120, 240, 480, 1_200]
                .map(GuidedMissingTaskDataValue.estimatedDuration)
        }
    }

    var missingValue: GuidedMissingTaskDataValue {
        switch self {
        case .pressure:
            return .pressure(.none)
        case .thinkingNeeded:
            return .thinkingNeeded(.none)
        case .estimatedDuration:
            return .estimatedDuration(0)
        }
    }

    var maximumSegmentsPerRow: Int? {
        switch self {
        case .estimatedDuration:
            return 4
        case .pressure, .thinkingNeeded:
            return nil
        }
    }

    func isEligible(_ task: RoutineTask) -> Bool {
        let hasMissingValue: Bool
        switch self {
        case .pressure:
            hasMissingValue = task.pressure == .none
        case .thinkingNeeded:
            hasMissingValue = task.thinkingNeeded == .none
        case .estimatedDuration:
            hasMissingValue = task.estimatedDurationMinutes == nil
        }

        return !task.isPaused
            && hasMissingValue
            && (!task.isOneOffTask || (task.lastDone == nil && task.canceledAt == nil))
    }

    func apply(_ value: GuidedMissingTaskDataValue, to task: RoutineTask) -> Bool {
        switch (self, value) {
        case let (.pressure, .pressure(pressure)) where pressure != .none:
            task.pressure = pressure
            return true
        case let (.thinkingNeeded, .thinkingNeeded(thinkingNeeded)) where thinkingNeeded != .none:
            task.thinkingNeeded = thinkingNeeded
            return true
        case let (.estimatedDuration, .estimatedDuration(minutes)):
            guard let sanitizedMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(minutes) else {
                return false
            }
            task.estimatedDurationMinutes = sanitizedMinutes
            return true
        default:
            return false
        }
    }
}

enum GuidedMissingTaskDataValue: Hashable, Sendable {
    case pressure(RoutineTaskPressure)
    case thinkingNeeded(RoutineTaskThinkingNeeded)
    case estimatedDuration(Int)

    var field: GuidedMissingTaskDataField {
        switch self {
        case .pressure:
            return .pressure
        case .thinkingNeeded:
            return .thinkingNeeded
        case .estimatedDuration:
            return .estimatedDuration
        }
    }

    var title: String {
        switch self {
        case let .pressure(pressure):
            return pressure.title
        case let .thinkingNeeded(thinkingNeeded):
            return thinkingNeeded.title
        case let .estimatedDuration(minutes):
            return estimatedDurationTitle(for: minutes)
        }
    }

    var isMissing: Bool {
        switch self {
        case let .pressure(pressure):
            return pressure == .none
        case let .thinkingNeeded(thinkingNeeded):
            return thinkingNeeded == .none
        case let .estimatedDuration(minutes):
            return minutes <= 0
        }
    }

    private func estimatedDurationTitle(for minutes: Int) -> String {
        switch minutes {
        case 15: return "15m"
        case 30: return "30m"
        case 60: return "1h"
        case 120: return "2h"
        case 240: return "4h"
        case 480: return "8h"
        case 1_200: return "20h"
        default: return "\(minutes)m"
        }
    }
}
