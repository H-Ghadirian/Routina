import Foundation

/// A stable, reducer-owned snapshot for the Mac Backlog window.  The main
/// sidebar intentionally does not build this presentation while it scrolls.
struct BacklogTaskListPresentation: Equatable {
    struct Subsection: Identifiable, Equatable {
        let section: HomeCustomTaskSection
        let tasks: [RoutineTask]

        var id: UUID { section.id }
    }

    struct Section: Identifiable, Equatable {
        let section: HomeCustomTaskSection
        let tasks: [RoutineTask]
        let subsections: [Subsection]

        var id: UUID { section.id }
        var taskCount: Int { tasks.count + subsections.reduce(0) { $0 + $1.tasks.count } }
    }

    let sections: [Section]
    /// Tasks hidden by a Flag remain discoverable even before the person gives
    /// them an explicit Backlog path.
    let hiddenByFlagTasks: [RoutineTask]

    var taskCount: Int {
        sections.reduce(0) { $0 + $1.taskCount } + hiddenByFlagTasks.count
    }

    var isEmpty: Bool {
        taskCount == 0
    }

    static var empty: Self {
        Self(sections: [], hiddenByFlagTasks: [])
    }

    static func make(
        tasks: [RoutineTask],
        customSections: [HomeCustomTaskSection],
        flagRules: [RoutineFlagRule],
        referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        let sections = HomeCustomTaskSectionStorage.sanitized(customSections)
        let backlogSections = sections.filter { $0.surface == .backlog }
        let backlogSectionIDs = Set(backlogSections.map(\.id))
        let tasksBySectionID = Dictionary(grouping: tasks.filter { task in
            task.customTaskSectionID.map(backlogSectionIDs.contains) ?? false
        }) { $0.customTaskSectionID! }

        let topLevelSections = HomeCustomTaskSectionStorage.topLevelSections(
            in: backlogSections,
            surface: .backlog
        )
        let presentationSections = topLevelSections.compactMap { section -> Section? in
            let directTasks = sorted(tasksBySectionID[section.id] ?? [])
            let subsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: backlogSections
            ).map { subsection in
                Subsection(
                    section: subsection,
                    tasks: sorted(tasksBySectionID[subsection.id] ?? [])
                )
            }

            guard !directTasks.isEmpty || subsections.contains(where: { !$0.tasks.isEmpty }) else {
                return nil
            }
            return Section(section: section, tasks: directTasks, subsections: subsections)
        }

        let hiddenByFlagTasks = sorted(tasks.filter { task in
            guard task.customTaskSectionID.map(backlogSectionIDs.contains) != true,
                  isActiveBacklogCandidate(task, referenceDate: referenceDate, calendar: calendar)
            else {
                return false
            }
            return RoutineFlagRules.hidesFromTaskLists(flags: task.flags, rules: flagRules)
        })

        return Self(sections: presentationSections, hiddenByFlagTasks: hiddenByFlagTasks)
    }

    private static func isActiveBacklogCandidate(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        !task.isArchived(referenceDate: referenceDate, calendar: calendar)
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
    }

    private static func sorted(_ tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            let lhsDeadline = lhs.deadline ?? .distantFuture
            let rhsDeadline = rhs.deadline ?? .distantFuture
            if lhsDeadline != rhsDeadline {
                return lhsDeadline < rhsDeadline
            }

            let lhsCreatedAt = lhs.createdAt ?? .distantPast
            let rhsCreatedAt = rhs.createdAt ?? .distantPast
            if lhsCreatedAt != rhsCreatedAt {
                return lhsCreatedAt > rhsCreatedAt
            }

            let lhsName = lhs.name ?? ""
            let rhsName = rhs.name ?? ""
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }
}
