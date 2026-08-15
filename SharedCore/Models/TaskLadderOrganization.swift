import Foundation

enum TaskLadderNodeID: Codable, Equatable, Hashable, Sendable {
    case task(UUID)
    case group(UUID)

    var rawID: UUID {
        switch self {
        case let .task(id), let .group(id):
            return id
        }
    }

    var storageComponent: String {
        switch self {
        case let .task(id):
            return "task:\(id.uuidString.lowercased())"
        case let .group(id):
            return "group:\(id.uuidString.lowercased())"
        }
    }
}

struct TaskLadderGroup: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var pressureRawValue: String?
    var urgencyRawValue: String?
    var importanceRawValue: String?
    var thinkingNeededRawValue: String?
    var inheritedMetricRawValues: [String]?
    var taskRankingOrders: [String: Int64]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "📁",
        pressure: RoutineTaskPressure? = nil,
        urgency: RoutineTaskUrgency? = nil,
        importance: RoutineTaskImportance? = nil,
        thinkingNeeded: RoutineTaskThinkingNeeded? = nil,
        inheritedMetrics: Set<TaskRankingMetric> = [],
        taskRankingOrders: [String: Int64] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        pressureRawValue = pressure.flatMap { $0 == .none ? nil : $0.rawValue }
        urgencyRawValue = urgency?.rawValue
        importanceRawValue = importance?.rawValue
        thinkingNeededRawValue = thinkingNeeded.flatMap { $0 == .none ? nil : $0.rawValue }
        inheritedMetricRawValues = Self.storedInheritedMetrics(inheritedMetrics)
        self.taskRankingOrders = taskRankingOrders
        self.createdAt = createdAt
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled group" : trimmed
    }

    var displayEmoji: String {
        let trimmed = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "📁" : trimmed
    }

    var pressure: RoutineTaskPressure? {
        get {
            guard let pressureRawValue,
                  let value = RoutineTaskPressure(rawValue: pressureRawValue),
                  value != .none else { return nil }
            return value
        }
        set { pressureRawValue = newValue.flatMap { $0 == .none ? nil : $0.rawValue } }
    }

    var urgency: RoutineTaskUrgency? {
        get { urgencyRawValue.flatMap(RoutineTaskUrgency.init(rawValue:)) }
        set { urgencyRawValue = newValue?.rawValue }
    }

    var importance: RoutineTaskImportance? {
        get { importanceRawValue.flatMap(RoutineTaskImportance.init(rawValue:)) }
        set { importanceRawValue = newValue?.rawValue }
    }

    var thinkingNeeded: RoutineTaskThinkingNeeded? {
        get {
            guard let thinkingNeededRawValue,
                  let value = RoutineTaskThinkingNeeded(rawValue: thinkingNeededRawValue),
                  value != .none else { return nil }
            return value
        }
        set { thinkingNeededRawValue = newValue.flatMap { $0 == .none ? nil : $0.rawValue } }
    }

    var inheritedMetrics: Set<TaskRankingMetric> {
        Set(
            (inheritedMetricRawValues ?? []).compactMap { rawValue in
                guard let metric = TaskRankingMetric(rawValue: rawValue),
                      metric.supportsManualLadder else { return nil }
                return metric
            }
        )
    }

    func inheritsValue(for metric: TaskRankingMetric) -> Bool {
        inheritedMetrics.contains(metric)
    }

    mutating func setInheritsValue(_ inherits: Bool, for metric: TaskRankingMetric) {
        guard metric.supportsManualLadder else { return }
        var metrics = inheritedMetrics
        if inherits {
            metrics.insert(metric)
        } else {
            metrics.remove(metric)
        }
        inheritedMetricRawValues = Self.storedInheritedMetrics(metrics)
    }

    mutating func normalizeInheritedMetrics() {
        inheritedMetricRawValues = Self.storedInheritedMetrics(inheritedMetrics)
    }

    func taskRankingOrder(
        for metric: TaskRankingMetric,
        value: TaskRankingMetricValue,
        scopeNodeID: TaskLadderNodeID? = nil
    ) -> Int64? {
        taskRankingOrders[
            TaskLadderOrganizationStorage.rankKey(
                metric: metric,
                value: value,
                scopeNodeID: scopeNodeID
            )
        ]
    }

    mutating func setTaskRankingOrder(
        _ order: Int64,
        for metric: TaskRankingMetric,
        value: TaskRankingMetricValue,
        scopeNodeID: TaskLadderNodeID? = nil
    ) {
        taskRankingOrders[
            TaskLadderOrganizationStorage.rankKey(
                metric: metric,
                value: value,
                scopeNodeID: scopeNodeID
            )
        ] = order
    }

    private static func storedInheritedMetrics(
        _ metrics: Set<TaskRankingMetric>
    ) -> [String]? {
        let rawValues = metrics
            .filter(\.supportsManualLadder)
            .map(\.rawValue)
            .sorted()
        return rawValues.isEmpty ? nil : rawValues
    }
}

struct TaskLadderPlacement: Codable, Equatable, Hashable, Identifiable, Sendable {
    var taskID: UUID
    var parent: TaskLadderNodeID

    var id: UUID { taskID }
}

struct TaskLadderOrganization: Codable, Equatable, Sendable {
    var groups: [TaskLadderGroup]
    var placements: [TaskLadderPlacement]

    init(
        groups: [TaskLadderGroup] = [],
        placements: [TaskLadderPlacement] = []
    ) {
        self.groups = groups
        self.placements = placements
    }

    func parent(of taskID: UUID) -> TaskLadderNodeID? {
        placements.first(where: { $0.taskID == taskID })?.parent
    }

    func childTaskIDs(of parent: TaskLadderNodeID) -> Set<UUID> {
        Set(placements.lazy.filter { $0.parent == parent }.map(\.taskID))
    }

    func group(id: UUID) -> TaskLadderGroup? {
        groups.first(where: { $0.id == id })
    }

    mutating func upsert(_ group: TaskLadderGroup) {
        var sanitizedGroup = group
        sanitizedGroup.name = group.displayName
        sanitizedGroup.emoji = group.displayEmoji
        sanitizedGroup.normalizeInheritedMetrics()
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = sanitizedGroup
        } else {
            groups.append(sanitizedGroup)
        }
        groups.sort { lhs, rhs in
            let comparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            return comparison == .orderedSame
                ? lhs.id.uuidString < rhs.id.uuidString
                : comparison == .orderedAscending
        }
    }

    mutating func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        placements.removeAll { $0.parent == .group(id) }
    }

    @discardableResult
    mutating func place(
        taskID: UUID,
        inside parent: TaskLadderNodeID?,
        validTaskIDs: Set<UUID>
    ) -> Bool {
        guard let parent else {
            placements.removeAll { $0.taskID == taskID }
            return true
        }
        guard validTaskIDs.contains(taskID), isValid(parent: parent, validTaskIDs: validTaskIDs) else {
            return false
        }
        if case let .task(parentTaskID) = parent {
            guard parentTaskID != taskID,
                  !wouldCreateCycle(taskID: taskID, parentTaskID: parentTaskID) else {
                return false
            }
        }
        placements.removeAll { $0.taskID == taskID }
        placements.append(TaskLadderPlacement(taskID: taskID, parent: parent))
        return true
    }

    func validParents(for taskID: UUID, validTaskIDs: Set<UUID>) -> Set<TaskLadderNodeID> {
        var result = Set(groups.map { TaskLadderNodeID.group($0.id) })
        for candidateID in validTaskIDs where candidateID != taskID {
            if !wouldCreateCycle(taskID: taskID, parentTaskID: candidateID) {
                result.insert(.task(candidateID))
            }
        }
        return result
    }

    func sanitized(validTaskIDs: Set<UUID>) -> Self {
        var uniqueGroupsByID: [UUID: TaskLadderGroup] = [:]
        for group in groups where !validTaskIDs.contains(group.id) {
            var sanitizedGroup = group
            sanitizedGroup.name = group.displayName
            sanitizedGroup.emoji = group.displayEmoji
            sanitizedGroup.normalizeInheritedMetrics()
            uniqueGroupsByID[group.id] = sanitizedGroup
        }

        var result = Self(groups: Array(uniqueGroupsByID.values), placements: [])
        result.groups.sort { lhs, rhs in
            let comparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            return comparison == .orderedSame
                ? lhs.id.uuidString < rhs.id.uuidString
                : comparison == .orderedAscending
        }

        for placement in placements where validTaskIDs.contains(placement.taskID) {
            _ = result.place(
                taskID: placement.taskID,
                inside: placement.parent,
                validTaskIDs: validTaskIDs
            )
        }
        result.placements.sort { $0.taskID.uuidString < $1.taskID.uuidString }
        return result
    }

    private func isValid(parent: TaskLadderNodeID, validTaskIDs: Set<UUID>) -> Bool {
        switch parent {
        case let .task(id):
            return validTaskIDs.contains(id)
        case let .group(id):
            return groups.contains(where: { $0.id == id })
        }
    }

    private func wouldCreateCycle(taskID: UUID, parentTaskID: UUID) -> Bool {
        var visited: Set<UUID> = [taskID]
        var cursor: UUID? = parentTaskID
        while let current = cursor {
            guard visited.insert(current).inserted else { return true }
            guard case let .task(next)? = parent(of: current) else { return false }
            cursor = next
        }
        return false
    }
}

enum TaskLadderCompletionBehavior: String, CaseIterable, Equatable, Hashable, Sendable {
    case none
    case canComplete
    case completes

    var title: String {
        switch self {
        case .none: return "Does not complete parent"
        case .canComplete: return "Can complete parent — ask me"
        case .completes: return "Completes parent automatically"
        }
    }

    var relationshipKind: RoutineTaskRelationshipKind? {
        switch self {
        case .none: return nil
        case .canComplete: return .canComplete
        case .completes: return .completes
        }
    }

    init(relationshipKind: RoutineTaskRelationshipKind?) {
        switch relationshipKind {
        case .canComplete: self = .canComplete
        case .completes: self = .completes
        default: self = .none
        }
    }
}

enum TaskLadderOrganizationStorage {
    static func encode(_ organization: TaskLadderOrganization) -> String? {
        guard !organization.groups.isEmpty || !organization.placements.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(organization),
              let rawValue = String(data: data, encoding: .utf8) else {
            return nil
        }
        return rawValue
    }

    static func decode(_ rawValue: String?) -> TaskLadderOrganization {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let organization = try? JSONDecoder().decode(TaskLadderOrganization.self, from: data) else {
            return TaskLadderOrganization()
        }
        return organization
    }

    static func rankKey(
        metric: TaskRankingMetric,
        value: TaskRankingMetricValue,
        scopeNodeID: TaskLadderNodeID?
    ) -> String {
        let metricKey = "\(metric.rawValue):\(value.storageComponent)"
        guard let scopeNodeID else { return metricKey }
        return "scope:\(scopeNodeID.storageComponent):\(metricKey)"
    }
}
