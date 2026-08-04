import Foundation

struct MCPTaskQuery: Codable, Equatable, Sendable {
    var searchText: String?
    var includeArchived: Bool
    var includeCompleted: Bool
    var limit: Int?

    init(
        searchText: String? = nil,
        includeArchived: Bool = true,
        includeCompleted: Bool = true,
        limit: Int? = nil
    ) {
        self.searchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.includeArchived = includeArchived
        self.includeCompleted = includeCompleted
        self.limit = limit.map { max($0, 0) }
    }
}

struct MCPTaskSnapshot: Codable, Equatable, Sendable {
    var generatedAt: Date
    var query: MCPTaskQuery
    var counts: MCPTaskSnapshotCounts
    var tasks: [MCPTaskSummary]
}

struct MCPTaskSnapshotCounts: Codable, Equatable, Sendable {
    var totalTasks: Int
    var matchingTasks: Int
    var returnedTasks: Int
    var overdueTasks: Int
    var archivedTasks: Int
    var completedTasks: Int
}

struct MCPTaskSummary: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var kind: String
    var primaryStatus: MCPPrimaryStatus
    var scheduleMode: String
    var scheduleDescription: String
    var recurrenceKind: String
    var dueDate: Date?
    var deadline: Date?
    var daysUntilDue: Int?
    var overdueDays: Int
    var lastDone: Date?
    var createdAt: Date?
    var taskDescription: String?
    var notes: String?
    var link: String?
    var links: [String]
    var tags: [String]
    var goals: [String]
    var placeName: String?
    var todoState: String?
    var estimatedDurationMinutes: Int?
    var storyPoints: Int?
    var isArchived: Bool
    var isPaused: Bool
    var isSnoozed: Bool
    var isPinned: Bool
    var isOngoing: Bool
    var isInProgress: Bool
    var isCompleted: Bool
    var isCanceled: Bool
    var progress: MCPTaskProgress
}

enum MCPPrimaryStatus: String, Codable, Equatable, Sendable {
    case ready
    case dueToday
    case overdue
    case inProgress
    case ongoing
    case blocked
    case paused
    case snoozed
    case completed
    case canceled
}

struct MCPTaskProgress: Codable, Equatable, Sendable {
    var completedSteps: Int
    var totalSteps: Int
    var completedChecklistItems: Int
    var totalChecklistItems: Int
    var dueChecklistItems: Int
    var nextStepTitle: String?
    var nextChecklistItemTitle: String?
}

struct MCPReadOnlyCatalog: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var generatedAt: Date
    var tasks: [MCPTaskSummary]
}

enum MCPReadOnlySnapshotStore {
    static let appGroupIdentifier = "group.ir.hamedgh.Routinam"
    static let productionFileName = "routina_ai_read_only_snapshot.json"
    static let sandboxFileName = "routina_ai_read_only_snapshot_sandbox.json"

    static func defaultFileURL(
        sandboxMode: Bool,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let fileName = sandboxMode ? sandboxFileName : productionFileName
        return containerURL.appendingPathComponent(fileName, isDirectory: false)
    }

    static func load(from fileURL: URL) throws -> MCPReadOnlyCatalog {
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let catalog = try decoder.decode(MCPReadOnlyCatalog.self, from: data)
        guard catalog.schemaVersion == MCPReadOnlyCatalog.currentSchemaVersion else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return catalog
    }
}

enum MCPTaskQueryService {
    static func snapshot(
        from allSummaries: [MCPTaskSummary],
        query: MCPTaskQuery = MCPTaskQuery(),
        generatedAt: Date = Date()
    ) -> MCPTaskSnapshot {
        let matchingSummaries = allSummaries
            .filter { matchesQuery($0, query: query) }
            .sorted(by: compareSummaries)
        let returnedSummaries = query.limit.map {
            Array(matchingSummaries.prefix($0))
        } ?? matchingSummaries

        return MCPTaskSnapshot(
            generatedAt: generatedAt,
            query: query,
            counts: MCPTaskSnapshotCounts(
                totalTasks: allSummaries.count,
                matchingTasks: matchingSummaries.count,
                returnedTasks: returnedSummaries.count,
                overdueTasks: matchingSummaries.filter { $0.primaryStatus == .overdue }.count,
                archivedTasks: matchingSummaries.filter(\.isArchived).count,
                completedTasks: matchingSummaries.filter(\.isCompleted).count
            ),
            tasks: returnedSummaries
        )
    }

    private static func matchesQuery(_ summary: MCPTaskSummary, query: MCPTaskQuery) -> Bool {
        if !query.includeArchived && summary.isArchived {
            return false
        }
        if !query.includeCompleted && (summary.isCompleted || summary.isCanceled) {
            return false
        }

        let searchTerms = normalizedSearchTerms(query.searchText)
        guard !searchTerms.isEmpty else { return true }

        let haystack = [
            summary.name,
            summary.taskDescription ?? "",
            summary.notes ?? "",
            summary.link ?? "",
            summary.links.joined(separator: " "),
            summary.placeName ?? "",
            summary.tags.joined(separator: " "),
            summary.goals.joined(separator: " "),
            summary.scheduleDescription,
            summary.primaryStatus.rawValue,
            summary.todoState ?? "",
            summary.progress.nextStepTitle ?? "",
            summary.progress.nextChecklistItemTitle ?? ""
        ]
            .joined(separator: "\n")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return searchTerms.allSatisfy { haystack.contains($0) }
    }

    private static func normalizedSearchTerms(_ value: String?) -> [String] {
        guard let value else { return [] }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    private static func compareSummaries(_ lhs: MCPTaskSummary, _ rhs: MCPTaskSummary) -> Bool {
        let lhsRank = statusRank(lhs.primaryStatus)
        let rhsRank = statusRank(rhs.primaryStatus)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        switch (lhs.dueDate, rhs.dueDate) {
        case let (.some(left), .some(right)) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }

        switch (lhs.lastDone, rhs.lastDone) {
        case let (.some(left), .some(right)) where left != right:
            return left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            break
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func statusRank(_ status: MCPPrimaryStatus) -> Int {
        switch status {
        case .overdue: return 0
        case .dueToday: return 1
        case .ongoing: return 2
        case .inProgress, .blocked: return 3
        case .ready: return 4
        case .paused, .snoozed: return 5
        case .completed: return 6
        case .canceled: return 7
        }
    }
}
