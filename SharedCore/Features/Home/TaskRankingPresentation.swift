import Foundation

/// The task attributes that can be inspected in the Mac task-ranking workspace.
/// Estimated time deliberately remains a factual sort rather than a manual ladder.
enum TaskRankingMetric: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case pressure
    case urgency
    case estimatedTime
    case importance
    case thinkingNeeded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pressure: return "Pressure"
        case .urgency: return "Urgency"
        case .estimatedTime: return "Estimated time"
        case .importance: return "Importance"
        case .thinkingNeeded: return "Thinking needed"
        }
    }

    var supportsManualLadder: Bool {
        self != .estimatedTime
    }

    /// True when the standard presentation starts with the strongest value.
    var sortsHighToLowByDefault: Bool {
        switch self {
        case .pressure, .urgency, .importance:
            return true
        case .estimatedTime, .thinkingNeeded:
            return false
        }
    }

    func sortsHighToLow(isReversed: Bool) -> Bool {
        sortsHighToLowByDefault != isReversed
    }

    func directionTitle(isReversed: Bool) -> String {
        let highToLow = sortsHighToLow(isReversed: isReversed)
        switch self {
        case .pressure:
            return highToLow ? "Most pressure" : "Least pressure"
        case .urgency:
            return highToLow ? "Most urgent" : "Least urgent"
        case .estimatedTime:
            return highToLow ? "Longest first" : "Shortest first"
        case .importance:
            return highToLow ? "Most important" : "Least important"
        case .thinkingNeeded:
            return highToLow ? "Deep work" : "Quick wins"
        }
    }

    func value(for task: RoutineTask) -> TaskRankingMetricValue? {
        switch self {
        case .pressure:
            guard task.pressure != .none else { return nil }
            return .pressure(task.pressure)
        case .urgency:
            guard task.hasExplicitUrgency else { return nil }
            return .urgency(task.urgency)
        case .estimatedTime:
            return task.estimatedDurationMinutes.map(TaskRankingMetricValue.estimatedTime)
        case .importance:
            guard task.hasExplicitImportance else { return nil }
            return .importance(task.importance)
        case .thinkingNeeded:
            guard task.thinkingNeeded != .none else { return nil }
            return .thinkingNeeded(task.thinkingNeeded)
        }
    }

    func apply(_ value: TaskRankingMetricValue?, to task: RoutineTask) {
        switch self {
        case .pressure:
            let pressure = value?.pressureValue ?? .none
            if task.pressure != pressure {
                task.pressure = pressure
            }
        case .urgency:
            if let urgency = value?.urgencyValue {
                task.urgency = urgency
                task.hasExplicitUrgency = true
            } else {
                task.hasExplicitUrgency = false
            }
        case .estimatedTime:
            break
        case .importance:
            if let importance = value?.importanceValue {
                task.importance = importance
                task.hasExplicitImportance = true
            } else {
                task.hasExplicitImportance = false
            }
        case .thinkingNeeded:
            task.thinkingNeeded = value?.thinkingNeededValue ?? .none
        }
    }

    var missingValueTitle: String {
        switch self {
        case .estimatedTime: return "No estimate"
        default: return "No \(title.lowercased())"
        }
    }
}

enum TaskRankingDirectionStorage {
    static func encode(_ reversedMetrics: Set<TaskRankingMetric>) -> String {
        reversedMetrics
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }

    static func decode(_ rawValue: String?) -> Set<TaskRankingMetric> {
        Set(
            (rawValue ?? "")
                .split(separator: ",")
                .compactMap { TaskRankingMetric(rawValue: String($0)) }
        )
    }
}

enum TaskRankingMetricValue: Equatable, Hashable, Sendable {
    case pressure(RoutineTaskPressure)
    case urgency(RoutineTaskUrgency)
    case estimatedTime(Int)
    case importance(RoutineTaskImportance)
    case thinkingNeeded(RoutineTaskThinkingNeeded)

    var metric: TaskRankingMetric {
        switch self {
        case .pressure: return .pressure
        case .urgency: return .urgency
        case .estimatedTime: return .estimatedTime
        case .importance: return .importance
        case .thinkingNeeded: return .thinkingNeeded
        }
    }

    var sortOrder: Int {
        switch self {
        case let .pressure(value): return value.sortOrder
        case let .urgency(value): return value.sortOrder
        case let .estimatedTime(value): return value
        case let .importance(value): return value.sortOrder
        case let .thinkingNeeded(value): return value.sortOrder
        }
    }

    var title: String {
        switch self {
        case let .pressure(value): return "\(value.title) pressure"
        case let .urgency(value): return "\(value.title) urgency"
        case let .estimatedTime(value): return Self.durationTitle(minutes: value)
        case let .importance(value): return "\(value.title) importance"
        case let .thinkingNeeded(value): return "\(value.title) thinking"
        }
    }

    var storageComponent: String {
        switch self {
        case let .pressure(value): return value.rawValue
        case let .urgency(value): return value.rawValue
        case let .estimatedTime(value): return "\(value)"
        case let .importance(value): return value.rawValue
        case let .thinkingNeeded(value): return value.rawValue
        }
    }

    fileprivate var pressureValue: RoutineTaskPressure? {
        guard case let .pressure(value) = self else { return nil }
        return value
    }

    fileprivate var urgencyValue: RoutineTaskUrgency? {
        guard case let .urgency(value) = self else { return nil }
        return value
    }

    fileprivate var importanceValue: RoutineTaskImportance? {
        guard case let .importance(value) = self else { return nil }
        return value
    }

    fileprivate var thinkingNeededValue: RoutineTaskThinkingNeeded? {
        guard case let .thinkingNeeded(value) = self else { return nil }
        return value
    }

    private static func durationTitle(minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        switch (hours, remainingMinutes) {
        case (0, _): return "\(minutes) min"
        case (_, 0): return hours == 1 ? "1 hour" : "\(hours) hours"
        default: return "\(hours)h \(remainingMinutes)m"
        }
    }
}

/// A stable, feature-owned snapshot consumed directly by the scrolling Mac task-ranking view.
struct TaskRankingPresentation: Equatable {
    struct RowMetadata: Equatable, Sendable {
        let tagLabels: [String]
        let isRepeating: Bool

        init(task: RoutineTask) {
            tagLabels = task.tags.map { "#\($0)" }
            isRepeating = !task.isOneOffTask
        }
    }

    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        /// Nil identifies the final, intentionally separate missing-value section.
        let value: TaskRankingMetricValue?
        let tasks: [RoutineTask]
        let isMissingValue: Bool
        let supportsManualOrdering: Bool
    }

    let metric: TaskRankingMetric
    let isReversed: Bool
    let sections: [Section]
    let rowMetadataByTaskID: [UUID: RowMetadata]

    var taskCount: Int {
        sections.reduce(0) { $0 + $1.tasks.count }
    }

    var isEmpty: Bool {
        taskCount == 0
    }

    static func empty(metric: TaskRankingMetric = .pressure, isReversed: Bool = false) -> Self {
        Self(
            metric: metric,
            isReversed: isReversed,
            sections: [],
            rowMetadataByTaskID: [:]
        )
    }

    static func make(
        tasks: [RoutineTask],
        flagRules: [RoutineFlagRule],
        metric: TaskRankingMetric,
        isReversed: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        let taskLadderExclusionFlagIDs = RoutineFlagRules.normalizedFlagIDs(
            for: .hideFromTaskLadder,
            in: flagRules
        )
        let activeTasks = tasks.filter { task in
            let isHiddenFromTaskLadder = task.flags.contains { flag in
                RoutineFlag.normalized(flag).map(taskLadderExclusionFlagIDs.contains) ?? false
            }
            return !task.isArchived(referenceDate: referenceDate, calendar: calendar)
                && !task.isCompletedOneOff
                && !task.isCanceledOneOff
                && task.todoState != .blocked
                && !isHiddenFromTaskLadder
        }
        let rowMetadataByTaskID = Dictionary(
            uniqueKeysWithValues: activeTasks.map { task in
                (task.id, RowMetadata(task: task))
            }
        )

        guard metric.supportsManualLadder else {
            return estimatedTimePresentation(
                activeTasks,
                metric: metric,
                isReversed: isReversed,
                rowMetadataByTaskID: rowMetadataByTaskID
            )
        }

        let knownTasks = activeTasks.compactMap { task -> (RoutineTask, TaskRankingMetricValue)? in
            metric.value(for: task).map { (task, $0) }
        }
        let values = Array(Set(knownTasks.map(\.1))).sorted {
            metric.sortsHighToLow(isReversed: isReversed)
                ? $0.sortOrder > $1.sortOrder
                : $0.sortOrder < $1.sortOrder
        }
        let sections = values.compactMap { value -> Section? in
            let sectionTasks = knownTasks
                .filter { $0.1 == value }
                .map(\.0)
            guard !sectionTasks.isEmpty else { return nil }
            return Section(
                id: "\(metric.rawValue):\(value.storageComponent)",
                title: value.title,
                value: value,
                tasks: sortedLadderTasks(
                    sectionTasks,
                    metric: metric,
                    value: value,
                    isReversed: isReversed
                ),
                isMissingValue: false,
                supportsManualOrdering: true
            )
        }

        let missingTasks = activeTasks.filter { metric.value(for: $0) == nil }
        let missingSection: [Section]
        if missingTasks.isEmpty {
            missingSection = []
        } else {
            missingSection = [
                Section(
                    id: "\(metric.rawValue):missing",
                    title: metric.missingValueTitle,
                    value: nil,
                    tasks: sortedFallbackTasks(missingTasks, isReversed: false),
                    isMissingValue: true,
                    supportsManualOrdering: false
                )
            ]
        }

        return Self(
            metric: metric,
            isReversed: isReversed,
            sections: sections + missingSection,
            rowMetadataByTaskID: rowMetadataByTaskID
        )
    }

    private static func estimatedTimePresentation(
        _ activeTasks: [RoutineTask],
        metric: TaskRankingMetric,
        isReversed: Bool,
        rowMetadataByTaskID: [UUID: RowMetadata]
    ) -> Self {
        let knownTasks = activeTasks.compactMap { task -> (RoutineTask, Int)? in
            task.estimatedDurationMinutes.map { (task, $0) }
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 {
                return metric.sortsHighToLow(isReversed: isReversed)
                    ? lhs.1 > rhs.1
                    : lhs.1 < rhs.1
            }
            return fallbackComesBefore(lhs.0, rhs.0, isReversed: isReversed)
        }.map(\.0)

        var sections: [Section] = []
        if !knownTasks.isEmpty {
            sections.append(
                Section(
                    id: "estimated-time:known",
                    title: metric.directionTitle(isReversed: isReversed),
                    value: nil,
                    tasks: knownTasks,
                    isMissingValue: false,
                    supportsManualOrdering: false
                )
            )
        }

        let missingTasks = activeTasks.filter { $0.estimatedDurationMinutes == nil }
        if !missingTasks.isEmpty {
            sections.append(
                Section(
                    id: "estimated-time:missing",
                    title: metric.missingValueTitle,
                    value: nil,
                    tasks: sortedFallbackTasks(missingTasks, isReversed: false),
                    isMissingValue: true,
                    supportsManualOrdering: false
                )
            )
        }
        return Self(
            metric: metric,
            isReversed: isReversed,
            sections: sections,
            rowMetadataByTaskID: rowMetadataByTaskID
        )
    }

    private static func sortedLadderTasks(
        _ tasks: [RoutineTask],
        metric: TaskRankingMetric,
        value: TaskRankingMetricValue,
        isReversed: Bool
    ) -> [RoutineTask] {
        tasks.sorted { lhs, rhs in
            let lhsOrder = lhs.taskRankingOrder(for: metric, value: value)
            let rhsOrder = rhs.taskRankingOrder(for: metric, value: value)
            switch (lhsOrder, rhsOrder) {
            case let (.some(lhsOrder), .some(rhsOrder)) where lhsOrder != rhsOrder:
                return isReversed ? lhsOrder > rhsOrder : lhsOrder < rhsOrder
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return fallbackComesBefore(lhs, rhs, isReversed: isReversed)
            }
        }
    }

    private static func sortedFallbackTasks(
        _ tasks: [RoutineTask],
        isReversed: Bool
    ) -> [RoutineTask] {
        tasks.sorted { fallbackComesBefore($0, $1, isReversed: isReversed) }
    }

    private static func fallbackComesBefore(
        _ lhs: RoutineTask,
        _ rhs: RoutineTask,
        isReversed: Bool
    ) -> Bool {
        let lhsCreatedAt = lhs.createdAt ?? .distantPast
        let rhsCreatedAt = rhs.createdAt ?? .distantPast
        if lhsCreatedAt != rhsCreatedAt {
            return isReversed ? lhsCreatedAt < rhsCreatedAt : lhsCreatedAt > rhsCreatedAt
        }

        let lhsName = lhs.name ?? ""
        let rhsName = rhs.name ?? ""
        let comparison = lhsName.localizedCaseInsensitiveCompare(rhsName)
        if comparison != .orderedSame {
            return isReversed ? comparison == .orderedDescending : comparison == .orderedAscending
        }
        return isReversed
            ? lhs.id.uuidString > rhs.id.uuidString
            : lhs.id.uuidString < rhs.id.uuidString
    }
}

struct TaskRankingRankUpdate: Equatable, Sendable {
    let taskID: UUID
    let value: TaskRankingMetricValue
    let order: Int64
}

struct TaskRankingOrderUpdate: Equatable, Sendable {
    let metric: TaskRankingMetric
    let taskID: UUID
    let destinationValue: TaskRankingMetricValue?
    let rankUpdates: [TaskRankingRankUpdate]
}

enum TaskRankingMoveDirection: Equatable, Sendable {
    case up
    case down
}

enum TaskRankingOrderingSupport {
    private static let rankSpacing: Int64 = 1_000_000

    static func moveTask(
        taskID: UUID,
        direction: TaskRankingMoveDirection,
        in presentation: TaskRankingPresentation
    ) -> TaskRankingOrderUpdate? {
        guard presentation.metric.supportsManualLadder,
              let sourceSectionIndex = presentation.sections.firstIndex(where: { section in
                  section.tasks.contains(where: { $0.id == taskID })
              }),
              let sourceTaskIndex = presentation.sections[sourceSectionIndex].tasks.firstIndex(where: { $0.id == taskID }),
              let sourceTask = presentation.sections[sourceSectionIndex].tasks[safe: sourceTaskIndex]
        else {
            return nil
        }

        let sourceSection = presentation.sections[sourceSectionIndex]
        let destination: (section: TaskRankingPresentation.Section, index: Int)
        switch direction {
        case .up:
            if sourceTaskIndex > 0, sourceSection.value != nil {
                destination = (sourceSection, sourceTaskIndex - 1)
            } else {
                let destinationSectionIndex = sourceSectionIndex - 1
                guard presentation.sections.indices.contains(destinationSectionIndex),
                      let destinationValue = presentation.sections[destinationSectionIndex].value,
                      destinationValue.metric == presentation.metric
                else { return nil }
                destination = (presentation.sections[destinationSectionIndex], presentation.sections[destinationSectionIndex].tasks.count)
            }
        case .down:
            if sourceTaskIndex + 1 < sourceSection.tasks.count, sourceSection.value != nil {
                destination = (sourceSection, sourceTaskIndex + 1)
            } else {
                let destinationSectionIndex = sourceSectionIndex + 1
                guard presentation.sections.indices.contains(destinationSectionIndex) else { return nil }
                let destinationSection = presentation.sections[destinationSectionIndex]
                if let destinationValue = destinationSection.value,
                   destinationValue.metric == presentation.metric {
                    destination = (destinationSection, 0)
                } else if destinationSection.isMissingValue {
                    return TaskRankingOrderUpdate(
                        metric: presentation.metric,
                        taskID: taskID,
                        destinationValue: nil,
                        rankUpdates: []
                    )
                } else {
                    return nil
                }
            }
        }

        guard let destinationValue = destination.section.value,
              destinationValue.metric == presentation.metric
        else { return nil }

        let targetTasks = destination.section.tasks.filter { $0.id != taskID }
        var visualTasks = targetTasks
        let insertionIndex = min(max(destination.index, 0), visualTasks.count)
        visualTasks.insert(sourceTask, at: insertionIndex)
        let rankUpdates = rankUpdatesForInsertion(
            movingTask: sourceTask,
            visualTasks: visualTasks,
            existingTargetTasks: targetTasks,
            metric: presentation.metric,
            value: destinationValue,
            isReversed: presentation.isReversed
        )

        return TaskRankingOrderUpdate(
            metric: presentation.metric,
            taskID: taskID,
            destinationValue: destinationValue,
            rankUpdates: rankUpdates
        )
    }

    static func apply(_ update: TaskRankingOrderUpdate, to tasks: inout [RoutineTask]) {
        guard let movedTaskIndex = tasks.firstIndex(where: { $0.id == update.taskID }) else { return }
        update.metric.apply(update.destinationValue, to: tasks[movedTaskIndex])

        for rankUpdate in update.rankUpdates {
            guard let taskIndex = tasks.firstIndex(where: { $0.id == rankUpdate.taskID }) else { continue }
            tasks[taskIndex].setTaskRankingOrder(
                rankUpdate.order,
                for: update.metric,
                value: rankUpdate.value
            )
        }
    }

    private static func rankUpdatesForInsertion(
        movingTask: RoutineTask,
        visualTasks: [RoutineTask],
        existingTargetTasks: [RoutineTask],
        metric: TaskRankingMetric,
        value: TaskRankingMetricValue,
        isReversed: Bool
    ) -> [TaskRankingRankUpdate] {
        guard !visualTasks.isEmpty else { return [] }

        // The first move in a bucket establishes a durable, spaced baseline for
        // its current tasks. Later moves update only the moved task unless the
        // gap between its neighbours is exhausted.
        if existingTargetTasks.contains(where: {
            $0.taskRankingOrder(for: metric, value: value) == nil
        }) {
            return normalizedRankUpdates(
                visualTasks: visualTasks,
                value: value,
                isReversed: isReversed
            )
        }

        guard let movedTaskIndex = visualTasks.firstIndex(where: { $0.id == movingTask.id }) else {
            return []
        }
        let previousRank = visualTasks.indices.contains(movedTaskIndex - 1)
            ? visualTasks[movedTaskIndex - 1].taskRankingOrder(for: metric, value: value)
            : nil
        let nextRank = visualTasks.indices.contains(movedTaskIndex + 1)
            ? visualTasks[movedTaskIndex + 1].taskRankingOrder(for: metric, value: value)
            : nil

        let order: Int64
        switch (previousRank, nextRank) {
        case let (.some(previous), .some(next)):
            let upper = max(previous, next)
            let lower = min(previous, next)
            guard upper - lower > 1 else {
                return normalizedRankUpdates(
                    visualTasks: visualTasks,
                    value: value,
                    isReversed: isReversed
                )
            }
            order = lower + (upper - lower) / 2
        case let (.some(previous), .none):
            order = isReversed ? previous - rankSpacing : previous + rankSpacing
        case let (.none, .some(next)):
            order = isReversed ? next + rankSpacing : next - rankSpacing
        case (.none, .none):
            order = 0
        }

        return [TaskRankingRankUpdate(taskID: movingTask.id, value: value, order: order)]
    }

    private static func normalizedRankUpdates(
        visualTasks: [RoutineTask],
        value: TaskRankingMetricValue,
        isReversed: Bool
    ) -> [TaskRankingRankUpdate] {
        let count = visualTasks.count
        return visualTasks.enumerated().map { index, task in
            let position = isReversed ? count - index : index
            return TaskRankingRankUpdate(
                taskID: task.id,
                value: value,
                order: Int64(position) * rankSpacing
            )
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
