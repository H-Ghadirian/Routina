import Foundation
import SwiftData

public struct RoutinaAITaskQuery: Codable, Equatable, Sendable {
    public var searchText: String?
    public var includeArchived: Bool
    public var includeCompleted: Bool
    public var limit: Int?

    public init(
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

public struct RoutinaAITaskSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var query: RoutinaAITaskQuery
    public var counts: RoutinaAITaskSnapshotCounts
    public var tasks: [RoutinaAITaskSummary]
}

public struct RoutinaAITaskSnapshotCounts: Codable, Equatable, Sendable {
    public var totalTasks: Int
    public var matchingTasks: Int
    public var returnedTasks: Int
    public var overdueTasks: Int
    public var archivedTasks: Int
    public var completedTasks: Int
}

public struct RoutinaAITaskSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var emoji: String
    public var kind: String
    public var primaryStatus: RoutinaAIPrimaryStatus
    public var scheduleMode: String
    public var scheduleDescription: String
    public var recurrenceKind: String
    public var dueDate: Date?
    public var deadline: Date?
    public var daysUntilDue: Int?
    public var overdueDays: Int
    public var lastDone: Date?
    public var createdAt: Date?
    public var notes: String?
    public var link: String?
    public var tags: [String]
    public var goals: [String]
    public var placeName: String?
    public var todoState: String?
    public var estimatedDurationMinutes: Int?
    public var storyPoints: Int?
    public var isArchived: Bool
    public var isPaused: Bool
    public var isSnoozed: Bool
    public var isPinned: Bool
    public var isOngoing: Bool
    public var isInProgress: Bool
    public var isCompleted: Bool
    public var isCanceled: Bool
    public var progress: RoutinaAITaskProgress
}

public enum RoutinaAIPrimaryStatus: String, Codable, Equatable, Sendable {
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

public struct RoutinaAITaskProgress: Codable, Equatable, Sendable {
    public var completedSteps: Int
    public var totalSteps: Int
    public var completedChecklistItems: Int
    public var totalChecklistItems: Int
    public var dueChecklistItems: Int
    public var nextStepTitle: String?
    public var nextChecklistItemTitle: String?
}

public enum RoutinaAIQueryService {
    @MainActor
    public static func snapshot(
        in context: ModelContext,
        query: RoutinaAITaskQuery = RoutinaAITaskQuery(),
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> RoutinaAITaskSnapshot {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let placesByID = Dictionary(places.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let goalsByID = Dictionary(goals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        let allSummaries = tasks.map {
            makeSummary(
                for: $0,
                placesByID: placesByID,
                goalsByID: goalsByID,
                now: now,
                calendar: calendar
            )
        }
        let matchingSummaries = allSummaries
            .filter { matchesQuery($0, query: query) }
            .sorted(by: compareSummaries)

        let returnedSummaries: [RoutinaAITaskSummary]
        if let limit = query.limit {
            returnedSummaries = Array(matchingSummaries.prefix(limit))
        } else {
            returnedSummaries = matchingSummaries
        }

        return RoutinaAITaskSnapshot(
            generatedAt: now,
            query: query,
            counts: RoutinaAITaskSnapshotCounts(
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
}

private extension RoutinaAIQueryService {
    static func makeSummary(
        for task: RoutineTask,
        placesByID: [UUID: RoutinePlace],
        goalsByID: [UUID: RoutineGoal],
        now: Date,
        calendar: Calendar
    ) -> RoutinaAITaskSummary {
        let placeName = task.placeID.flatMap { placesByID[$0]?.displayName }
        let goalTitles = task.goalIDs.compactMap { goalsByID[$0]?.displayTitle }
        let isPaused = task.pausedAt != nil
        let isSnoozed = task.isSnoozed(referenceDate: now, calendar: calendar)
        let isArchived = task.isArchived(referenceDate: now, calendar: calendar)
        let isCompleted = task.isCompletedOneOff
        let isCanceled = task.isCanceledOneOff
        let dueDate = resolvedDueDate(for: task, now: now, calendar: calendar)
        let daysUntilDue = resolvedDaysUntilDue(
            for: task,
            dueDate: dueDate,
            now: now,
            calendar: calendar
        )
        let overdueDays = max(-(daysUntilDue ?? 0), 0)
        let dueChecklistItems = task.dueChecklistItems(referenceDate: now, calendar: calendar)
        let nextChecklistItemTitle = task.isChecklistDriven
            ? task.nextDueChecklistItem(referenceDate: now, calendar: calendar)?.title
            : task.nextPendingChecklistItemTitle

        return RoutinaAITaskSummary(
            id: task.id,
            name: task.name ?? "Unnamed task",
            emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
            kind: task.isOneOffTask ? "todo" : "routine",
            primaryStatus: primaryStatus(
                for: task,
                isArchived: isArchived,
                isPaused: isPaused,
                isSnoozed: isSnoozed,
                isCompleted: isCompleted,
                isCanceled: isCanceled,
                overdueDays: overdueDays,
                daysUntilDue: daysUntilDue
            ),
            scheduleMode: task.scheduleMode.rawValue,
            scheduleDescription: task.isOneOffTask
                ? (task.deadline.map { "One-off due \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "One-off task")
                : task.recurrenceRule.displayText(calendar: calendar),
            recurrenceKind: task.recurrenceRule.kind.rawValue,
            dueDate: dueDate,
            deadline: task.deadline,
            daysUntilDue: daysUntilDue,
            overdueDays: overdueDays,
            lastDone: task.lastDone,
            createdAt: task.createdAt,
            notes: task.notes,
            link: task.link,
            tags: task.tags,
            goals: goalTitles,
            placeName: placeName,
            todoState: task.todoState?.rawValue,
            estimatedDurationMinutes: task.estimatedDurationMinutes,
            storyPoints: task.storyPoints,
            isArchived: isArchived,
            isPaused: isPaused,
            isSnoozed: isSnoozed,
            isPinned: task.isPinned,
            isOngoing: task.isOngoing,
            isInProgress: task.isInProgress || task.isChecklistInProgress,
            isCompleted: isCompleted,
            isCanceled: isCanceled,
            progress: RoutinaAITaskProgress(
                completedSteps: task.completedSteps,
                totalSteps: task.totalSteps,
                completedChecklistItems: task.completedChecklistItemCount,
                totalChecklistItems: task.totalChecklistItemCount,
                dueChecklistItems: dueChecklistItems.count,
                nextStepTitle: task.nextStepTitle,
                nextChecklistItemTitle: nextChecklistItemTitle
            )
        )
    }

    static func resolvedDueDate(
        for task: RoutineTask,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard !task.isCompletedOneOff, !task.isCanceledOneOff else { return nil }
        guard !task.isSoftIntervalRoutine else { return nil }
        if task.isOneOffTask {
            return task.deadline
        }
        return RoutineDateMath.dueDate(for: task, referenceDate: now, calendar: calendar)
    }

    static func resolvedDaysUntilDue(
        for task: RoutineTask,
        dueDate: Date?,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        guard let dueDate else { return nil }
        let todayStart = calendar.startOfDay(for: now)
        let dueStart = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: todayStart, to: dueStart).day ?? 0
    }

    static func primaryStatus(
        for task: RoutineTask,
        isArchived: Bool,
        isPaused: Bool,
        isSnoozed: Bool,
        isCompleted: Bool,
        isCanceled: Bool,
        overdueDays: Int,
        daysUntilDue: Int?
    ) -> RoutinaAIPrimaryStatus {
        if isCanceled {
            return .canceled
        }
        if isCompleted || task.todoState == .done {
            return .completed
        }
        if task.todoState == .blocked {
            return .blocked
        }
        if isPaused || task.todoState == .paused {
            return .paused
        }
        if isSnoozed {
            return .snoozed
        }
        if task.isOngoing {
            return .ongoing
        }
        if overdueDays > 0 {
            return .overdue
        }
        if daysUntilDue == 0 {
            return .dueToday
        }
        if task.isInProgress || task.isChecklistInProgress || task.todoState == .inProgress {
            return .inProgress
        }
        if isArchived {
            return .paused
        }
        return .ready
    }

    static func matchesQuery(
        _ summary: RoutinaAITaskSummary,
        query: RoutinaAITaskQuery
    ) -> Bool {
        if !query.includeArchived && summary.isArchived {
            return false
        }
        if !query.includeCompleted && (summary.isCompleted || summary.isCanceled) {
            return false
        }

        let searchTerms = normalizedSearchTerms(query.searchText)
        guard !searchTerms.isEmpty else {
            return true
        }

        let haystack = [
            summary.name,
            summary.notes ?? "",
            summary.link ?? "",
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

    static func normalizedSearchTerms(_ value: String?) -> [String] {
        guard let value else { return [] }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }

    static func compareSummaries(
        _ lhs: RoutinaAITaskSummary,
        _ rhs: RoutinaAITaskSummary
    ) -> Bool {
        let lhsRank = statusRank(lhs)
        let rhsRank = statusRank(rhs)
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

    static func statusRank(_ summary: RoutinaAITaskSummary) -> Int {
        switch summary.primaryStatus {
        case .overdue:
            return 0
        case .dueToday:
            return 1
        case .ongoing:
            return 2
        case .inProgress, .blocked:
            return 3
        case .ready:
            return 4
        case .paused, .snoozed:
            return 5
        case .completed:
            return 6
        case .canceled:
            return 7
        }
    }
}
