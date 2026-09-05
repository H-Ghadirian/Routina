import Foundation

extension GoalsFeature {
    struct GoalTaskSummary: Equatable, Hashable {
        var routineCount: Int
        var todoCount: Int
        var openTaskCount: Int
        var completedTodoCount: Int
        var nextDueDate: Date?

        init(linkedTasks: [GoalTaskDisplay]) {
            routineCount = linkedTasks.count { $0.taskType == .routine }
            todoCount = linkedTasks.count(where: \.isOneOffTask)
            openTaskCount = linkedTasks.count { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
            completedTodoCount = linkedTasks.count(where: \.isCompletedOneOff)
            nextDueDate = linkedTasks.compactMap(\.dueDate).min()
        }
    }

    struct GoalDisplay: Identifiable, Equatable, Hashable {
        var id: UUID
        var title: String
        var emoji: String?
        var notes: String?
        var targetDate: Date?
        var tags: [String]
        var status: RoutineGoalStatus
        var color: RoutineTaskColor
        var parentGoalID: UUID?
        var parentGoal: GoalLinkDisplay?
        var childGoals: [GoalLinkDisplay]
        var createdAt: Date?
        var sortOrder: Int
        var linkedTasks: [GoalTaskDisplay]
        var taskSuggestions: [GoalTaskSuggestionDisplay]
        var taskSummary: GoalTaskSummary?
        var normalizedSearchText: String?

        var displayEmoji: String {
            emoji.flatMap(RoutineGoal.cleanedEmoji) ?? "\u{1F3AF}"
        }

        var displayTitle: String {
            RoutineGoal.cleanedTitle(title) ?? "Untitled goal"
        }

        var routineCount: Int {
            taskSummary?.routineCount ?? linkedTasks.count { $0.taskType == .routine }
        }

        var todoCount: Int {
            taskSummary?.todoCount ?? linkedTasks.count(where: \.isOneOffTask)
        }

        var openTaskCount: Int {
            taskSummary?.openTaskCount
                ?? linkedTasks.count { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
        }

        var completedTodoCount: Int {
            taskSummary?.completedTodoCount ?? linkedTasks.count(where: \.isCompletedOneOff)
        }

        var childGoalCount: Int {
            childGoals.count
        }

        var nextDueDate: Date? {
            taskSummary?.nextDueDate ?? linkedTasks.compactMap(\.dueDate).min()
        }

        var searchableText: String {
            normalizedSearchText ?? makeSearchableText()
        }

        private func makeSearchableText() -> String {
            ([displayTitle, notes ?? "", parentGoal?.displayTitle ?? ""]
                + tags
                + childGoals.map(\.displayTitle)
                + linkedTasks.map(\.displayName))
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }

        static func displays(
            goals: [RoutineGoal],
            tasks: [RoutineTask],
            referenceDate: Date,
            calendar: Calendar
        ) -> [GoalDisplay] {
            var tasksByGoalID: [UUID: [GoalTaskDisplay]] = [:]
            let taskDisplays = tasks.map { task in
                (
                    task: task,
                    display: GoalTaskDisplay(
                        task: task,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                )
            }
            for taskDisplay in taskDisplays {
                for goalID in taskDisplay.task.goalIDs {
                    tasksByGoalID[goalID, default: []].append(taskDisplay.display)
                }
            }
            let linkDisplaysByID = Dictionary(
                uniqueKeysWithValues: goals.map { ($0.id, GoalLinkDisplay(goal: $0)) }
            )
            var validParentGoalIDsByGoalID: [UUID: UUID] = [:]
            for goal in goals {
                validParentGoalIDsByGoalID[goal.id] = RoutineGoalHierarchy.sanitizedParentGoalID(
                    goal.parentGoalID,
                    for: goal.id,
                    in: goals,
                    id: { $0.id },
                    parentGoalID: { $0.parentGoalID }
                )
            }
            var childGoalsByParentID: [UUID: [GoalLinkDisplay]] = [:]
            for goal in goals {
                guard let parentGoalID = validParentGoalIDsByGoalID[goal.id],
                    let childLink = linkDisplaysByID[goal.id]
                else { continue }
                childGoalsByParentID[parentGoalID, default: []].append(childLink)
            }

            return
                goals
                .map { goal in
                    let parentGoalID = validParentGoalIDsByGoalID[goal.id]
                    var display = GoalDisplay(
                        id: goal.id,
                        title: goal.displayTitle,
                        emoji: goal.emoji,
                        notes: RoutineGoal.cleanedNotes(goal.notes),
                        targetDate: goal.targetDate,
                        tags: goal.tags,
                        status: goal.status,
                        color: goal.color,
                        parentGoalID: parentGoalID,
                        parentGoal: parentGoalID.flatMap { linkDisplaysByID[$0] },
                        childGoals: (childGoalsByParentID[goal.id] ?? []).sorted(),
                        createdAt: goal.createdAt,
                        sortOrder: goal.sortOrder,
                        linkedTasks: (tasksByGoalID[goal.id] ?? []).sorted(),
                        taskSuggestions: taskSuggestions(for: goal, from: taskDisplays),
                        taskSummary: nil,
                        normalizedSearchText: nil
                    )
                    display.taskSummary = GoalTaskSummary(linkedTasks: display.linkedTasks)
                    display.normalizedSearchText = display.makeSearchableText()
                    return display
                }
                .sorted()
        }

        private static func taskSuggestions(
            for goal: RoutineGoal,
            from tasks: [(task: RoutineTask, display: GoalTaskDisplay)]
        ) -> [GoalTaskSuggestionDisplay] {
            let goalTags = goal.tags
            guard !goalTags.isEmpty else { return [] }
            let rejectedTaskIDs = Set(goal.rejectedTaskSuggestionIDs)

            return tasks.compactMap { task, display in
                guard !task.goalIDs.contains(goal.id),
                    !rejectedTaskIDs.contains(task.id)
                else {
                    return nil
                }
                let matchedTags = goalTags.filter { RoutineTag.contains($0, in: task.tags) }
                guard !matchedTags.isEmpty else { return nil }
                return GoalTaskSuggestionDisplay(task: display, matchedTags: matchedTags)
            }
            .sorted()
        }
    }

    struct GoalTaskDisplay: Identifiable, Equatable, Hashable, Comparable {
        var id: UUID
        var name: String
        var emoji: String?
        var taskType: RoutineTaskType
        var isOneOffTask: Bool
        var isCompletedOneOff: Bool
        var isCanceledOneOff: Bool
        var isPaused: Bool
        var isOngoing: Bool
        var dueDate: Date?

        var displayName: String {
            RoutineTask.trimmedName(name) ?? "Untitled task"
        }

        var displayEmoji: String {
            RoutineTask.sanitizedEmoji(emoji ?? "", fallback: taskType.defaultEmoji)
        }

        var kindText: String {
            taskType.userFacingTitle
        }

        var stateText: String {
            if isCompletedOneOff { return "Done" }
            if isCanceledOneOff { return "Canceled" }
            if isPaused { return "Paused" }
            if isOngoing { return "Ongoing" }
            return kindText
        }

        init(
            task: RoutineTask,
            referenceDate: Date,
            calendar: Calendar
        ) {
            self.id = task.id
            self.name = task.name ?? ""
            self.emoji = task.emoji
            self.taskType = task.scheduleMode.taskType
            self.isOneOffTask = task.isOneOffTask
            self.isCompletedOneOff = task.isCompletedOneOff
            self.isCanceledOneOff = task.isCanceledOneOff
            self.isPaused = task.isArchived(referenceDate: referenceDate, calendar: calendar)
            self.isOngoing = task.isOngoing
            if task.isOneOffTask {
                self.dueDate = task.deadline
            } else if !task.usesEffectiveRoutineCadence {
                self.dueDate = nil
            } else {
                self.dueDate = RoutineDateMath.dueDate(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
        }

        static func < (lhs: GoalTaskDisplay, rhs: GoalTaskDisplay) -> Bool {
            switch (lhs.dueDate, rhs.dueDate) {
            case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
                return lhsDate < rhsDate
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        }
    }

    struct GoalLinkDisplay: Identifiable, Equatable, Hashable, Comparable {
        var id: UUID
        var title: String
        var emoji: String?
        var status: RoutineGoalStatus
        var color: RoutineTaskColor

        var displayEmoji: String {
            emoji.flatMap(RoutineGoal.cleanedEmoji) ?? "\u{1F3AF}"
        }

        var displayTitle: String {
            RoutineGoal.cleanedTitle(title) ?? "Untitled goal"
        }

        init(
            id: UUID,
            title: String,
            emoji: String?,
            status: RoutineGoalStatus,
            color: RoutineTaskColor
        ) {
            self.id = id
            self.title = title
            self.emoji = emoji
            self.status = status
            self.color = color
        }

        init(goal: GoalDisplay) {
            self.init(
                id: goal.id,
                title: goal.displayTitle,
                emoji: goal.emoji,
                status: goal.status,
                color: goal.color
            )
        }

        init(goal: RoutineGoal) {
            self.init(
                id: goal.id,
                title: goal.displayTitle,
                emoji: goal.emoji,
                status: goal.status,
                color: goal.color
            )
        }

        static func < (lhs: GoalLinkDisplay, rhs: GoalLinkDisplay) -> Bool {
            if lhs.status != rhs.status {
                return lhs.status == .active
            }
            return lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle) == .orderedAscending
        }
    }

    struct GoalTaskSuggestionDisplay: Identifiable, Equatable, Hashable, Comparable {
        var task: GoalTaskDisplay
        var matchedTags: [String]

        var id: UUID {
            task.id
        }

        static func < (lhs: GoalTaskSuggestionDisplay, rhs: GoalTaskSuggestionDisplay) -> Bool {
            if lhs.task != rhs.task {
                return lhs.task < rhs.task
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    struct GoalDraft: Codable, Equatable {
        var id: UUID?
        var title = ""
        var emoji = ""
        var notes = ""
        var targetDate: Date?
        var tags: [String] = []
        var tagDraft = ""
        var color: RoutineTaskColor = .none
        var parentGoalID: UUID?

        var hasTargetDate: Bool {
            targetDate != nil
        }

        var cleanedTitle: String? {
            RoutineGoal.cleanedTitle(title)
        }

        init(
            id: UUID? = nil,
            title: String = "",
            emoji: String = "",
            notes: String = "",
            targetDate: Date? = nil,
            tags: [String] = [],
            tagDraft: String = "",
            color: RoutineTaskColor = .none,
            parentGoalID: UUID? = nil
        ) {
            self.id = id
            self.title = title
            self.emoji = emoji
            self.notes = notes
            self.targetDate = targetDate
            self.tags = RoutineTag.deduplicated(tags)
            self.tagDraft = tagDraft
            self.color = color
            self.parentGoalID = parentGoalID
        }

        init(goal: GoalDisplay) {
            self.init(
                id: goal.id,
                title: goal.displayTitle,
                emoji: goal.emoji ?? "",
                notes: goal.notes ?? "",
                targetDate: goal.targetDate,
                tags: goal.tags,
                color: goal.color,
                parentGoalID: goal.parentGoalID
            )
        }
    }
}
